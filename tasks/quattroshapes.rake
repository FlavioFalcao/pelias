require 'pelias'

namespace :quattroshapes do

  task :download do
    download_shapefiles("qs_neighborhoods.zip")
    download_shapefiles("quattroshapes_gazetteer_gn_then_gp.zip")
    download_shapefiles("gn-qs_localities.zip")
    download_shapefiles("qs_localadmin.zip")
  end

  task :populate_localities do
    index_shapes(Pelias::Locality, "gn-qs_localities.shp")
  end

  task :populate_local_admin do
    index_shapes(Pelias::LocalAdmin, "qs_localadmin.shp")
  end

  task :populate_neighborhoods do
    index_shapes(Pelias::Neighborhood, "qs_neighborhoods.shp")
  end

  task :populate_gazetteer do
    bulk = []
    shp = "data/quattroshapes/quattroshapes_gazetteer_gn_then_gp.shp"
    RGeo::Shapefile::Reader.open(shp) do |file|
      file.each do |record|
        id = record.attributes['gn_id'].to_i
        next if id == 0
        next unless geoname = Pelias::Geoname.find(id)
        center_point = RGeo::GeoJSON.encode(record.geometry)['coordinates']
        attrs = {
          :id => id,
          :center_point => center_point
        }
        geoname = geoname.to_hash
        geoname.delete('id')
        geoname.delete('center_point')
        bulk << attrs.merge(geoname)
        if bulk.count >= 500
          Pelias::Gazette.create(bulk)
          bulk = []
        end
      end
    end
    if bulk.count > 0
      Pelias::Gazette.create(bulk)
    end
  end

  def index_shapes(klass, shp)
    # not using bulk api because some docs are large
    shp = "data/quattroshapes/#{shp}"
    RGeo::Shapefile::Reader.open(shp) do |file|
      file.each do |record|
        id = (record.attributes['gs_gn_id']||record.attributes['gn_id']).to_i
        boundaries = RGeo::GeoJSON.encode(record.geometry)
        name = record.attributes['qs_loc']
        name = name.split(' (').first if name
        loc = klass.new(
          :id => id,
          :name => name,
          :boundaries => boundaries
        )
        geoname = Pelias::Geoname.find(id)
        if geoname.nil?
          loc.center_shape = RGeo::GeoJSON.encode(record.geometry.centroid)
          loc.center_point = loc.center_shape['coordinates']
          geoname = loc.closest_geoname
        end
        next if geoname.nil?
        geoname_hash = geoname.to_hash
        geoname_hash.delete('name')
        loc.update(geoname_hash)
        loc.set_admin_names
        loc.save
      end
    end
  end

  def download_shapefiles(file)
    url = "http://static.quattroshapes.com/#{file}"
    puts "downloading #{url}"
    open("data/quattroshapes/#{file}", 'wb') do |file|
      file << open(url).read
    end
    Zip::File::open("data/quattroshapes/#{file}") do |zip|
      zip.each do |entry|
        name = entry.name.gsub('shp/', '')
        unzipped_file = "data/quattroshapes/#{name}"
        FileUtils.rm(unzipped_file, :force => true)
        puts "extracting #{unzipped_file}"
        entry.extract(unzipped_file)
      end
    end
  end

end

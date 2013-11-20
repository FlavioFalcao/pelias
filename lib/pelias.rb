require "elasticsearch"
require "json"
require "pg"
require 'debugger'
require 'geokit'
require 'rgeo/geo_json'
require 'rgeo/shapefile'
require 'zip'

require 'pelias/server/server'

module Pelias

  autoload :VERSION, 'pelias/version'

  autoload :Address, 'pelias/address'
  autoload :Base, 'pelias/base'
  autoload :Gazette, 'pelias/gazette'
  autoload :Geoname, 'pelias/geoname'
  autoload :LocalAdmin, 'pelias/local_admin'
  autoload :Locality, 'pelias/locality'
  autoload :Neighborhood, 'pelias/neighborhood'
  autoload :Street, 'pelias/street'

  autoload :Osm, 'pelias/osm'
  autoload :Search, 'pelias/search'

  env = ENV['RACK_ENV'] || 'development'

  es_config = YAML::load(File.open('config/elasticsearch.yml'))[env]
  configuration = lambda do |faraday|
    faraday.adapter Faraday.default_adapter
    faraday.response :logger
    faraday.options[:timeout] = 60
    faraday.options[:open_timeout] = 60
  end
  transport = Elasticsearch::Transport::Transport::HTTP::Faraday.new(
    hosts: es_config['hosts'],
    &configuration
  )
  ES_CLIENT = Elasticsearch::Client.new(transport: transport)

  pg_config = YAML::load(File.open('config/postgres.yml'))[env]
  PG_CLIENT = PG.connect(pg_config)

  def self.root
    File.expand_path '../..', __FILE__
  end

end

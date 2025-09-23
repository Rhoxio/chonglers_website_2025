# Warcraft Logs GraphQL Client using graphql-client gem
require 'graphql/client'
require 'graphql/client/http'

class WarcraftLogsGraphQLClient
  # GraphQL endpoint
  HTTP = GraphQL::Client::HTTP.new("https://www.warcraftlogs.com/api/v2/client") do
    def headers(context)
      { "Authorization" => "Bearer #{context[:access_token]}" }
    end
  end

  def initialize
    @client_id = ENV['WARCRAFTLOGS_CLIENT_ID']
    @client_secret = ENV['WARCRAFTLOGS_CLIENT_SECRET']
    @access_token = nil
    @schema = nil
    @client = nil
  end

  # Lazy load schema and client
  def schema
    return @schema if @schema

    # Only load if credentials are available
    return nil unless @client_id && @client_secret

    begin
      authenticate! unless @access_token
      @schema = GraphQL::Client.load_schema(HTTP, context: { access_token: @access_token })
    rescue => e
      Rails.logger.error "Failed to load GraphQL schema: #{e.message}"
      nil
    end
  end

  def client
    return @client if @client
    return nil unless schema

    @client = GraphQL::Client.new(schema: schema, execute: HTTP)
  end

  # Define queries dynamically
  def guild_query
    return nil unless client

    @guild_query ||= client.parse <<~GRAPHQL
    query($guildID: Int!) {
      guildData {
        guild(id: $guildID) {
          id
          name
          server {
            name
            slug
            region {
              name
              slug
            }
          }
          members {
            data {
              id
              name
              classID
              level
              guildRank
            }
          }
        }
      }
    }
  GRAPHQL
  end

  def guild_reports_query
    return nil unless client

    @guild_reports_query ||= client.parse <<~GRAPHQL
    query($guildID: Int!, $limit: Int!) {
      guildData {
        guild(id: $guildID) {
          recentReports(limit: $limit) {
            data {
              id
              title
              startTime
              endTime
              zone {
                name
              }
              fights {
                encounterID
                name
                difficulty
                kill
                startTime
                endTime
              }
            }
          }
        }
      }
    }
  GRAPHQL
  end

  def character_query
    return nil unless client

    @character_query ||= client.parse <<~GRAPHQL
    query($name: String!, $server: String!, $region: String!) {
      characterData {
        character(name: $name, serverSlug: $server, serverRegion: $region) {
          id
          name
          classID
          level
          server {
            name
            slug
            region {
              name
              slug
            }
          }
          guildRank
        }
      }
    }
  GRAPHQL
  end

  # Authenticate and get access token
  def authenticate!
    require 'net/http'
    require 'json'

    uri = URI('https://www.warcraftlogs.com/oauth/token')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request.basic_auth(@client_id, @client_secret)
    request.set_form_data('grant_type' => 'client_credentials')

    response = http.request(request)
    
    if response.code == '200'
      token_data = JSON.parse(response.body)
      @access_token = token_data['access_token']
      true
    else
      raise "Authentication failed: #{response.body}"
    end
  end

  # Get guild information by ID
  def get_guild(guild_id)
    return nil unless client && guild_query

    authenticate! unless @access_token

    result = client.query(guild_query,
                         variables: { guildID: guild_id },
                         context: { access_token: @access_token })

    if result.errors.any?
      raise "GraphQL errors: #{result.errors.map(&:message).join(', ')}"
    end

    result.data.guild_data.guild
  end

  # Get guild reports
  def get_guild_reports(guild_id, limit = 10)
    return nil unless client && guild_reports_query

    authenticate! unless @access_token

    result = client.query(guild_reports_query,
                         variables: { guildID: guild_id, limit: limit },
                         context: { access_token: @access_token })

    if result.errors.any?
      raise "GraphQL errors: #{result.errors.map(&:message).join(', ')}"
    end

    result.data.guild_data.guild.recent_reports.data
  end

  # Get character information
  def get_character(name, server, region = 'US')
    return nil unless client && character_query

    authenticate! unless @access_token

    result = client.query(character_query,
                         variables: { name: name, server: server, region: region },
                         context: { access_token: @access_token })

    if result.errors.any?
      raise "GraphQL errors: #{result.errors.map(&:message).join(', ')}"
    end

    result.data.character_data.character
  end

  # Helper method to get class name from class ID
  def self.class_name(class_id)
    class_names = {
      1 => 'Warrior',
      2 => 'Paladin', 
      3 => 'Hunter',
      4 => 'Rogue',
      5 => 'Priest',
      6 => 'Death Knight',
      7 => 'Shaman',
      8 => 'Mage',
      9 => 'Warlock',
      10 => 'Monk',
      11 => 'Druid',
      12 => 'Demon Hunter'
    }
    class_names[class_id] || "Unknown Class (#{class_id})"
  end
end

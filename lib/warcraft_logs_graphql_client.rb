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

  # Load schema from remote (you can also cache this)
  Schema = GraphQL::Client.load_schema(HTTP)

  # Create client
  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)

  # Define queries as constants
  GUILD_QUERY = Client.parse <<~GRAPHQL
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

  GUILD_REPORTS_QUERY = Client.parse <<~GRAPHQL
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

  CHARACTER_QUERY = Client.parse <<~GRAPHQL
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

  def initialize
    @client_id = ENV['WARCRAFTLOGS_CLIENT_ID']
    @client_secret = ENV['WARCRAFTLOGS_CLIENT_SECRET']
    @access_token = nil
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
    authenticate! unless @access_token
    
    result = Client.query(GUILD_QUERY, 
                         variables: { guildID: guild_id },
                         context: { access_token: @access_token })
    
    if result.errors.any?
      raise "GraphQL errors: #{result.errors.map(&:message).join(', ')}"
    end
    
    result.data.guild_data.guild
  end

  # Get guild reports
  def get_guild_reports(guild_id, limit = 10)
    authenticate! unless @access_token
    
    result = Client.query(GUILD_REPORTS_QUERY,
                         variables: { guildID: guild_id, limit: limit },
                         context: { access_token: @access_token })
    
    if result.errors.any?
      raise "GraphQL errors: #{result.errors.map(&:message).join(', ')}"
    end
    
    result.data.guild_data.guild.recent_reports.data
  end

  # Get character information
  def get_character(name, server, region = 'US')
    authenticate! unless @access_token
    
    result = Client.query(CHARACTER_QUERY,
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

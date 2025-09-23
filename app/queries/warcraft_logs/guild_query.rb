# Guild information queries for Warcraft Logs
class WarcraftLogs::GuildQuery
  attr_reader :client
  
  def initialize(client = nil)
    @client = client || WarcraftLogsClient.new
  end
  
  # Get guild information by ID
  def self.find_by_id(guild_id)
    new.find_by_id(guild_id)
  end
  
  # Get guild information by name and server
  def self.find_by_name_and_server(name, server, region = 'US')
    new.find_by_name_and_server(name, server, region)
  end
  
  # Get guild members
  def self.members(guild_id)
    new.members(guild_id)
  end
  
  # Get recent guild reports
  def self.recent_reports(guild_id, limit = 10)
    new.recent_reports(guild_id, limit)
  end
  
  def find_by_id(guild_id)
    query = <<~GRAPHQL
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
    
    @client.authenticate_client_credentials! unless @client.access_token
    
    begin
      result = @client.public_query(query, { guildID: guild_id })
      result.dig('guildData', 'guild')
    rescue => e
      # Handle case where guild doesn't exist
      if e.message.include?("No guild exists for this id")
        return nil
      else
        raise e
      end
    end
  end
  
  def find_by_name_and_server(name, server, region = 'US')
    query = <<~GRAPHQL
      query($name: String!, $server: String!, $region: String!) {
        guildData {
          guild(name: $name, serverSlug: $server, serverRegion: $region) {
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
    
    @client.authenticate_client_credentials! unless @client.access_token
    
    begin
      result = @client.public_query(query, { name: name, server: server, region: region })
      result.dig('guildData', 'guild')
    rescue => e
      # Handle case where guild doesn't exist
      if e.message.include?("No guild exists") || e.message.include?("Guild not found")
        return nil
      else
        raise e
      end
    end
  end
  
  def members(guild_id)
    guild_data = find_by_id(guild_id)
    guild_data&.dig('members', 'data') || []
  end
  
  def recent_reports(guild_id, limit = 10)
    query = <<~GRAPHQL
      query($guildID: Int!, $limit: Int!) {
        guildData {
          guild(id: $guildID) {
            id
            name
          }
        }
        reportData {
          reports(guildID: $guildID, limit: $limit) {
            data {
              code
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
    GRAPHQL
    
    @client.authenticate_client_credentials! unless @client.access_token
    result = @client.public_query(query, { guildID: guild_id, limit: limit })
    result.dig('reportData', 'reports', 'data') || []
  end
end

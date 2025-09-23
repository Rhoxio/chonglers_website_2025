# Character information queries for Warcraft Logs
class WarcraftLogs::CharacterQuery
  attr_reader :client
  
  def initialize(client = nil)
    @client = client || WarcraftLogsClient.new
  end
  
  # Find character by name and server
  def self.find_by_name_and_server(name, server, region = 'US')
    new.find_by_name_and_server(name, server, region)
  end
  
  # Get character rankings
  def self.rankings(name, server, region = 'US', encounter_id = nil)
    new.rankings(name, server, region, encounter_id)
  end
  
  # Get character's recent reports
  def self.recent_reports(name, server, region = 'US', limit = 10)
    new.recent_reports(name, server, region, limit)
  end
  
  def find_by_name_and_server(name, server, region = 'US')
    query = <<~GRAPHQL
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
    
    @client.authenticate_client_credentials! unless @client.access_token
    result = @client.public_query(query, { name: name, server: server, region: region })
    result.dig('characterData', 'character')&.deep_symbolize_keys
  end
  
  def rankings(name, server, region = 'US', encounter_id = nil)
    query = <<~GRAPHQL
      query($name: String!, $server: String!, $region: String!, $encounterID: Int) {
        characterData {
          character(name: $name, serverSlug: $server, serverRegion: $region) {
            encounterRankings(encounterID: $encounterID)
          }
        }
      }
    GRAPHQL
    
    @client.authenticate_client_credentials! unless @client.access_token
    result = @client.public_query(query, { 
      name: name, 
      server: server, 
      region: region, 
      encounterID: encounter_id 
    })
    rankings_json = result.dig('characterData', 'character', 'encounterRankings')
    return [] unless rankings_json
    rankings_data = JSON.parse(rankings_json) rescue []
    (rankings_data.is_a?(Array) ? rankings_data : []).map(&:deep_symbolize_keys)
  end
  
  def recent_reports(name, server, region = 'US', limit = 10)
    query = <<~GRAPHQL
      query($name: String!, $server: String!, $region: String!, $limit: Int!) {
        characterData {
          character(name: $name, serverSlug: $server, serverRegion: $region) {
            id
            name
          }
        }
        reportData {
          reports(limit: $limit) {
            data {
              title
              startTime
              endTime
              zone {
                name
              }
            }
          }
        }
      }
    GRAPHQL
    
    @client.authenticate_client_credentials! unless @client.access_token
    result = @client.public_query(query, { name: name, server: server, region: region, limit: limit })
    (result.dig('reportData', 'reports', 'data') || []).map(&:deep_symbolize_keys)
  end
end

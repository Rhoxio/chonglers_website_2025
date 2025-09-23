# Performance and parse data queries for Warcraft Logs
require 'date'
require 'json'

module WarcraftLogs
  class PerformanceQuery
    attr_reader :client
    
    def initialize(client = nil)
      @client = client || WarcraftLogsClient.new
    end
    
    # Get performance data for a guild
    def self.get_guild_performance(guild_id, start_date, end_date = nil)
      new.get_guild_performance(guild_id, start_date, end_date)
    end
    
    # Get performance data for specific reports
    def self.get_performance_for_reports(reports, guild_members = nil)
      new.get_performance_for_reports(reports, guild_members)
    end
    
    # Get fight rankings data
    def self.get_fight_rankings(report_code, fight_id)
      new.get_fight_rankings(report_code, fight_id)
    end

    def get_guild_performance(guild_id, start_date, end_date = nil)
      reports = ReportQuery.get_guild_reports(guild_id, start_date, end_date)
      guild_members = GuildQuery.members(guild_id)
      get_performance_for_reports(reports, guild_members)
    rescue RuntimeError => e
      # Handle API errors for invalid guild IDs gracefully
      return {} if e.message.include?('No guild exists for this id')
      raise e
    end

    def get_performance_for_reports(reports, guild_members = nil)
      performance_data = {}
      
      reports.each do |report|
        next unless report && report['startTime']
        
        report_data = ReportQuery.get_report_fights(report['code'])
        next unless report_data
        
        fights = report_data['fights'] || []
        boss_fights = fights.select { |fight| fight['encounterID'] != 0 && fight['kill'] }
        
        boss_fights.each do |fight|
          rankings_data = get_fight_rankings(report['code'], fight['id'])
          next unless rankings_data
          
          characters = rankings_data[:characters]
          
          characters.each do |character|
            player_name = character['name']
            
            # Filter to guild members if provided
            if guild_members
              guild_member_names = guild_members.map { |member| member['name'] }
              next unless guild_member_names.include?(player_name)
            end
            
            performance_data[player_name] ||= {
              fights: 0,
              parse_data: [],
              total_amount: 0,
              avg_parse: 0
            }
            
            performance_data[player_name][:fights] += 1
            performance_data[player_name][:total_amount] += character['amount']
            
            parse_entry = {
              encounter_id: fight['encounterID'],
              encounter_name: fight['name'],
              difficulty: fight['difficulty'],
              ilvl_parse: character['rankPercent'],
              overall_parse: character['rankPercent'],
              ilvl_amount: character['amount'],
              overall_amount: character['amount'],
              spec: character['spec'],
              rank: character['rank'],
              total: character['totalParses'],
              bracket_percent: character['bracketPercent'],
              report_code: report['code'],
              fight_id: fight['id']
            }
            
            performance_data[player_name][:parse_data] << parse_entry
          end
        end
      end
      
      # Calculate averages
      performance_data.each do |player_name, data|
        if data[:fights] > 0
          data[:avg_parse] = data[:parse_data].map { |p| p[:ilvl_parse] }.sum / data[:parse_data].count
          data[:avg_amount] = data[:total_amount] / data[:fights]
        end
      end
      
      performance_data
    end

    def get_fight_rankings(report_code, fight_id)
      query = <<~GRAPHQL
        query($reportCode: String!, $fightID: Int!) {
          reportData {
            report(code: $reportCode) {
              fights(fightIDs: [$fightID]) {
                id
                encounterID
                name
                difficulty
                kill
              }
              rankings(fightIDs: [$fightID], compare: Parses)
            }
          }
        }
      GRAPHQL

      @client.authenticate_client_credentials! unless @client.access_token
      result = @client.public_query(query, { reportCode: report_code, fightID: fight_id })
      fights = result.dig('reportData', 'report', 'fights') || []
      rankings_raw = result.dig('reportData', 'report', 'rankings')
      
      return nil if fights.empty? || !rankings_raw
      
      fight = fights.first
      
      begin
        rankings_data = JSON.parse(rankings_raw) if rankings_raw.is_a?(String)
        rankings_data ||= rankings_raw
        
        rankings = rankings_data.dig('data') || []
        
        # Extract characters from roles
        all_characters = []
        rankings.each do |ranking|
          if ranking['roles']
            ranking['roles'].each do |role_name, role_data|
              if role_data['characters']
                all_characters.concat(role_data['characters'])
              end
            end
          end
        end
        
        {
          fight: fight,
          characters: all_characters
        }
      rescue JSON::ParserError => e
        puts "⚠️ Error parsing rankings JSON: #{e.message}"
        nil
      end
    rescue => e
      puts "⚠️ Error fetching fight rankings: #{e.message}"
      nil
    end
  end
end

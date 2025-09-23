# Encounter statistics queries for Warcraft Logs
require 'date'
require 'set'

module WarcraftLogs
  class EncounterQuery
    attr_reader :client
    
    def initialize(client = nil)
      @client = client || WarcraftLogsClient.new
    end
    
    # Get encounter statistics for a guild
    def self.get_encounter_stats(guild_id, start_date, end_date = nil)
      new.get_encounter_stats(guild_id, start_date, end_date)
    end
    
    # Get encounter statistics for specific reports
    def self.get_encounter_stats_for_reports(reports)
      new.get_encounter_stats_for_reports(reports)
    end

    def get_encounter_stats(guild_id, start_date, end_date = nil)
      reports = ReportQuery.get_guild_reports(guild_id, start_date, end_date)
      get_encounter_stats_for_reports(reports)
    rescue RuntimeError => e
      # Handle API errors for invalid guild IDs gracefully
      return [] if e.message.include?('No guild exists for this id')
      raise e
    end

    def get_encounter_stats_for_reports(reports)
      encounter_stats = {}
      
      reports.each do |report|
        next unless report && report['startTime']
        
        report_data = ReportQuery.get_report_fights(report['code'])
        next unless report_data
        
        fights = report_data['fights'] || []
        boss_fights = fights.select { |fight| fight['encounterID'] != 0 }
        
        boss_fights.each do |fight|
          encounter_key = "#{fight['name']} (#{fight['difficulty']})"
          encounter_stats[encounter_key] ||= { 
            attempts: 0, 
            kills: 0, 
            encounters: Set.new
          }
          
          encounter_stats[encounter_key][:attempts] += 1
          encounter_stats[encounter_key][:encounters].add(fight['encounterID'])
          
          if fight['kill']
            encounter_stats[encounter_key][:kills] += 1
          end
        end
      end
      
      # Convert to final format
      encounter_stats.map do |encounter, stats|
        {
          encounter: encounter,
          kill_rate: (stats[:kills].to_f / stats[:attempts] * 100).round(1),
          kills: stats[:kills],
          attempts: stats[:attempts],
          encounter_ids: stats[:encounters].to_a
        }
      end.sort_by { |stats| -stats[:kill_rate] }
    end
  end
end

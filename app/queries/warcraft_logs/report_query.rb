# Report data queries for Warcraft Logs
require 'date'

module WarcraftLogs
  class ReportQuery
    attr_reader :client
    
    def initialize(client = nil)
      @client = client || WarcraftLogsClient.new
    end
    
    # Get basic report information
    def self.get_report(report_code)
      new.get_report(report_code)
    end
    
    # Get reports for a guild since a specific date
    def self.get_guild_reports(guild_id, start_date, end_date = nil)
      new.get_guild_reports(guild_id, start_date, end_date)
    end
    
    # Get fights for a specific report
    def self.get_report_fights(report_code)
      new.get_report_fights(report_code)
    end
    
    # Get participants for a specific report
    def self.get_report_participants(report_code)
      new.get_report_participants(report_code)
    end

    def get_report(report_code)
      query = <<~GRAPHQL
        query($reportCode: String!) {
          reportData {
            report(code: $reportCode) {
              code
              title
              startTime
              endTime
              zone {
                id
                name
              }
              fights {
                id
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
      GRAPHQL

      @client.authenticate_client_credentials! unless @client.access_token
      result = @client.public_query(query, { reportCode: report_code })
      result.dig('reportData', 'report')
    end

    def get_guild_reports(guild_id, start_date, end_date = nil)
      start_time_ms = start_date.to_time.to_f * 1000
      end_time_ms = end_date ? end_date.to_time.to_f * 1000 : nil
      
      query = <<~GRAPHQL
        query($guildID: Int!, $startTime: Float, $endTime: Float) {
          reportData {
            reports(guildID: $guildID, startTime: $startTime, endTime: $endTime, limit: 100) {
              data {
                code
                title
                startTime
                endTime
                zone {
                  id
                  name
                }
              }
            }
          }
        }
      GRAPHQL

      @client.authenticate_client_credentials! unless @client.access_token
      
      begin
        result = @client.public_query(query, { 
          guildID: guild_id, 
          startTime: start_time_ms, 
          endTime: end_time_ms 
        })
        reports = result.dig('reportData', 'reports', 'data') || []
      rescue => e
        # Handle case where guild doesn't exist
        if e.message.include?("No guild exists for this id")
          return []
        else
          raise e
        end
      end
      
      # Filter to only include reports with boss fights
      reports.select do |report|
        next unless report && report['startTime']
        
        report_data = get_report_fights(report['code'])
        next unless report_data
        
        fights = report_data['fights'] || []
        boss_fights = fights.select { |fight| fight['encounterID'] != 0 }
        boss_fights.count > 0
      end
    end

    def get_report_fights(report_code)
      query = <<~GRAPHQL
        query($reportCode: String!) {
          reportData {
            report(code: $reportCode) {
              fights {
                id
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
    GRAPHQL

    @client.authenticate_client_credentials! unless @client.access_token
    
    begin
      result = @client.public_query(query, { reportCode: report_code })
      result.dig('reportData', 'report')
    rescue => e
      # Handle case where report doesn't exist
      if e.message.include?("This report does not exist")
        return nil
      else
        raise e
      end
    end
  end

  def get_report_participants(report_code)
      query = <<~GRAPHQL
        query($reportCode: String!) {
          reportData {
            report(code: $reportCode) {
              masterData {
                actors {
                  id
                  name
                  type
                  subType
                }
              }
            }
          }
        }
      GRAPHQL

      @client.authenticate_client_credentials! unless @client.access_token
      result = @client.public_query(query, { reportCode: report_code })
      actors = result.dig('reportData', 'report', 'masterData', 'actors') || []
      
      # Filter to only include Player type actors
      actors.select { |actor| actor['type'] == 'Player' }
    end
  end
end

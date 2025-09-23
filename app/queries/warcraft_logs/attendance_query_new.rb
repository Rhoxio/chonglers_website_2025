# Attendance tracking queries for Warcraft Logs
require 'date'
require 'set'

module WarcraftLogs
  class AttendanceQuery
    attr_reader :client
    
    def initialize(client = nil)
      @client = client || WarcraftLogsClient.new
    end
    
    # Get attendance data for a guild
    def self.get_guild_attendance(guild_id, start_date, end_date = nil)
      new.get_guild_attendance(guild_id, start_date, end_date)
    end
    
    # Get attendance data for specific reports
    def self.get_attendance_for_reports(reports, guild_members)
      new.get_attendance_for_reports(reports, guild_members)
    end

    def get_guild_attendance(guild_id, start_date, end_date = nil)
      reports = ReportQuery.get_guild_reports(guild_id, start_date, end_date)
      guild_members = GuildQuery.members(guild_id)
      get_attendance_for_reports(reports, guild_members)
    end

    def get_attendance_for_reports(reports, guild_members)
      attendance = {}
      guild_member_names = Set.new(guild_members.map { |member| member['name'] })
      valid_raids = 0
      
      reports.each do |report|
        next unless report && report['startTime']
        
        report_data = ReportQuery.get_report_fights(report['code'])
        next unless report_data
        
        fights = report_data['fights'] || []
        boss_fights = fights.select { |fight| fight['encounterID'] != 0 }
        next if boss_fights.count == 0
        
        valid_raids += 1
        
        # Get participants for this report
        participants = ReportQuery.get_report_participants(report['code'])
        participant_names = participants.map { |p| p['name'] }.compact.uniq
        
        # Filter to guild members
        guild_member_participants = participant_names.select { |name| guild_member_names.include?(name) }
        
        guild_member_participants.each do |player_name|
          attendance[player_name] ||= { 
            raids_attended: 0, 
            fights: 0,
            raid_details: []
          }
          
          attendance[player_name][:raids_attended] += 1
          attendance[player_name][:fights] += boss_fights.count
          
          # Store raid details
          raid_detail = {
            report_code: report['code'],
            raid_title: report['title'] || 'Unknown',
            zone: report.dig('zone', 'name') || 'Unknown Zone',
            start_time: report['startTime'],
            boss_fights: boss_fights.count,
            kills: boss_fights.count { |f| f['kill'] }
          }
          
          attendance[player_name][:raid_details] << raid_detail
        end
      end
      
      # Calculate attendance percentages
      attendance.each do |player_name, data|
        data[:attendance_percentage] = valid_raids > 0 ? (data[:raids_attended].to_f / valid_raids * 100).round(1) : 0
      end
      
      {
        attendance: attendance,
        total_raids: valid_raids,
        total_reports: reports.count,
        guild_members: guild_members
      }
    end
  end
end

# Analytics service that aggregates data from Warcraft Logs query verticals
require 'date'

class WarcraftLogsAnalyticsService
  
  # Memoized cache for expensive operations
  @@cache = {}
  
  def self.clear_cache
    @@cache = {}
  end
  
  def self.get_guild_summary(guild_id, start_date, end_date = nil)
    cache_key = "guild_summary_#{guild_id}_#{start_date}_#{end_date}"
    return @@cache[cache_key] if @@cache[cache_key]
    
    # Get data from each query vertical
    attendance_data = WarcraftLogs::AttendanceQuery.get_guild_attendance(guild_id, start_date, end_date)
    encounter_stats = WarcraftLogs::EncounterQuery.get_encounter_stats(guild_id, start_date, end_date)
    performance_data = WarcraftLogs::PerformanceQuery.get_guild_performance(guild_id, start_date, end_date)
    
    # Aggregate the data
    summary = {
      # Basic stats
      total_raids: attendance_data[:total_raids],
      total_reports: attendance_data[:total_reports],
      total_guild_members: attendance_data[:guild_members].count,
      active_members: attendance_data[:attendance].count,
      
      # Attendance data
      attendance: attendance_data[:attendance].sort_by { |name, data| -data[:attendance_percentage] },
      
      # Encounter statistics
      encounter_stats: encounter_stats,
      top_encounters: encounter_stats.first(5),
      
      # Performance data
      performance_data: performance_data,
      
      # Top performers (combining attendance and performance)
      top_performers: calculate_top_performers(attendance_data[:attendance], performance_data),
      
      # Overall guild stats
      overall_stats: calculate_overall_stats(attendance_data, encounter_stats, performance_data)
    }
    
    @@cache[cache_key] = summary
    summary
  end
  
  def self.get_attendance_summary(guild_id, start_date, end_date = nil)
    cache_key = "attendance_summary_#{guild_id}_#{start_date}_#{end_date}"
    return @@cache[cache_key] if @@cache[cache_key]
    
    attendance_data = WarcraftLogs::AttendanceQuery.get_guild_attendance(guild_id, start_date, end_date)
    performance_data = WarcraftLogs::PerformanceQuery.get_guild_performance(guild_id, start_date, end_date)
    
    summary = {
      total_raids: attendance_data[:total_raids],
      total_guild_members: attendance_data[:guild_members].count,
      active_members: attendance_data[:attendance].count,
      
      # All member attendance with parse data
      attendance: attendance_data[:attendance].map { |name, data|
        perf_data = performance_data[name] || { fights: 0, parse_data: [], avg_parse: 0 }
        
        {
          name: name,
          attendance_percentage: data[:attendance_percentage],
          raids_attended: data[:raids_attended],
          total_fights: data[:fights],
          avg_ilvl_parse: perf_data[:avg_parse].round(1),
          avg_overall_parse: perf_data[:avg_parse].round(1),
          parse_count: perf_data[:parse_data].count
        }
      }.sort_by { |member| -member[:attendance_percentage] },
      
      # Top 5 performers
      top_performers: calculate_top_performers(attendance_data[:attendance], performance_data).first(5)
    }
    
    @@cache[cache_key] = summary
    summary
  end
  
  def self.get_encounter_summary(guild_id, start_date, end_date = nil)
    cache_key = "encounter_summary_#{guild_id}_#{start_date}_#{end_date}"
    return @@cache[cache_key] if @@cache[cache_key]
    
    encounter_stats = WarcraftLogs::EncounterQuery.get_encounter_stats(guild_id, start_date, end_date)
    
    summary = {
      total_encounters: encounter_stats.count,
      successful_encounters: encounter_stats.count { |enc| enc[:kills] > 0 },
      best_kill_rate: encounter_stats.first ? encounter_stats.first[:kill_rate] : 0,
      worst_kill_rate: encounter_stats.last ? encounter_stats.last[:kill_rate] : 0,
      avg_kill_rate: encounter_stats.any? ? (encounter_stats.map { |enc| enc[:kill_rate] }.sum / encounter_stats.count).round(1) : 0,
      
      encounter_stats: encounter_stats,
      top_encounters: encounter_stats.first(5),
      worst_encounters: encounter_stats.last(5)
    }
    
    @@cache[cache_key] = summary
    summary
  end
  
  def self.get_performance_summary(guild_id, start_date, end_date = nil)
    cache_key = "performance_summary_#{guild_id}_#{start_date}_#{end_date}"
    return @@cache[cache_key] if @@cache[cache_key]
    
    performance_data = WarcraftLogs::PerformanceQuery.get_guild_performance(guild_id, start_date, end_date)
    
    summary = {
      total_players: performance_data.count,
      total_fights: performance_data.values.map { |data| data[:fights] }.sum,
      avg_parse: performance_data.any? ? (performance_data.values.map { |data| data[:avg_parse] }.sum / performance_data.count).round(1) : 0,
      
      performance_data: performance_data,
      top_parsers: performance_data.sort_by { |name, data| -data[:avg_parse] }.first(10),
      most_active: performance_data.sort_by { |name, data| -data[:fights] }.first(10)
    }
    
    @@cache[cache_key] = summary
    summary
  end
  
  private
  
  def self.calculate_top_performers(attendance_data, performance_data)
    attendance_data.map do |name, attendance|
      perf_data = performance_data[name] || { fights: 0, parse_data: [], avg_parse: 0 }
      
      {
        name: name,
        attendance_percentage: attendance[:attendance_percentage],
        raids_attended: attendance[:raids_attended],
        total_fights: attendance[:fights],
        avg_ilvl_parse: perf_data[:avg_parse].round(1),
        avg_overall_parse: perf_data[:avg_parse].round(1),
        parse_count: perf_data[:parse_data].count
      }
    end.sort_by { |player| -player[:attendance_percentage] }
  end
  
  def self.calculate_overall_stats(attendance_data, encounter_stats, performance_data)
    {
      avg_attendance: attendance_data[:attendance].values.map { |data| data[:attendance_percentage] }.sum / attendance_data[:attendance].count,
      total_encounters: encounter_stats.count,
      successful_encounters: encounter_stats.count { |enc| enc[:kills] > 0 },
      best_kill_rate: encounter_stats.first ? encounter_stats.first[:kill_rate] : 0,
      worst_kill_rate: encounter_stats.last ? encounter_stats.last[:kill_rate] : 0,
      avg_parse: performance_data.any? ? (performance_data.values.map { |data| data[:avg_parse] }.sum / performance_data.count).round(1) : 0
    }
  end
end

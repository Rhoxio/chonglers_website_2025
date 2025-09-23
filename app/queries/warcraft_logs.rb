# Main Warcraft Logs module
module WarcraftLogs
  # Load the main client first using Rails.root
  require Rails.root.join('lib', 'warcraft_logs_client')
  
  # Load all query classes
  require_relative 'warcraft_logs/guild_query'
  require_relative 'warcraft_logs/character_query'
  require_relative 'warcraft_logs/attendance_query'
  require_relative 'warcraft_logs/class_helper'
  
  # New modular query verticals
  require_relative 'warcraft_logs/report_query'
  require_relative 'warcraft_logs/encounter_query'
  require_relative 'warcraft_logs/performance_query'
  require_relative 'warcraft_logs/attendance_query_new'
end

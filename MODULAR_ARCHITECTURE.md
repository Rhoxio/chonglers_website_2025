# Warcraft Logs Modular Query Architecture

## Overview

The Warcraft Logs integration has been refactored into a modular architecture with distinct query verticals and memoized caching. This provides better separation of concerns, improved performance, and easier maintenance.

## Query Verticals

### 1. ReportQuery
**Responsibility**: Basic report data and fight information
- `get_report(report_code)` - Get basic report information
- `get_guild_reports(guild_id, start_date, end_date)` - Get reports for a guild
- `get_report_fights(report_code)` - Get fights for a specific report
- `get_report_participants(report_code)` - Get participants for a report

### 2. EncounterQuery
**Responsibility**: Encounter statistics and kill rates
- `get_encounter_stats(guild_id, start_date, end_date)` - Get encounter statistics for a guild
- `get_encounter_stats_for_reports(reports)` - Get encounter stats for specific reports

### 3. PerformanceQuery
**Responsibility**: Parse data and player rankings
- `get_guild_performance(guild_id, start_date, end_date)` - Get performance data for a guild
- `get_performance_for_reports(reports, guild_members)` - Get performance data for specific reports
- `get_fight_rankings(report_code, fight_id)` - Get fight rankings data

### 4. AttendanceQuery (New)
**Responsibility**: Attendance tracking only
- `get_guild_attendance(guild_id, start_date, end_date)` - Get attendance data for a guild
- `get_attendance_for_reports(reports, guild_members)` - Get attendance data for specific reports

## Analytics Service

### WarcraftLogsAnalyticsService
**Responsibility**: Aggregates data from query verticals with memoized caching

#### Methods:
- `get_guild_summary(guild_id, start_date, end_date)` - Complete guild summary
- `get_attendance_summary(guild_id, start_date, end_date)` - Attendance-focused summary
- `get_encounter_summary(guild_id, start_date, end_date)` - Encounter-focused summary
- `get_performance_summary(guild_id, start_date, end_date)` - Performance-focused summary
- `clear_cache()` - Clear memoized cache

## Benefits

### 1. **Separation of Concerns**
- Each query vertical has a single, focused responsibility
- Easy to test and maintain individual components
- Clear boundaries between different data types

### 2. **Performance Optimization**
- Memoized caching prevents duplicate API calls
- Efficient data aggregation from multiple sources
- One API call per fight instead of per player per fight

### 3. **Modularity**
- Query verticals can be used independently
- Easy to add new query types
- Flexible data aggregation through AnalyticsService

### 4. **Maintainability**
- Clear code organization
- Easy to debug individual components
- Simple to extend functionality

## Usage Examples

### Basic Usage
```ruby
# Get attendance summary
summary = WarcraftLogsAnalyticsService.get_attendance_summary(guild_id, start_date)

# Get encounter statistics
encounters = WarcraftLogs::EncounterQuery.get_encounter_stats(guild_id, start_date)

# Get performance data
performance = WarcraftLogs::PerformanceQuery.get_guild_performance(guild_id, start_date)
```

### Advanced Usage
```ruby
# Get specific reports
reports = WarcraftLogs::ReportQuery.get_guild_reports(guild_id, start_date)

# Get encounter stats for specific reports
encounter_stats = WarcraftLogs::EncounterQuery.get_encounter_stats_for_reports(reports.first(5))

# Get performance data for specific reports
guild_members = WarcraftLogs::GuildQuery.members(guild_id)
performance = WarcraftLogs::PerformanceQuery.get_performance_for_reports(reports, guild_members)
```

## File Structure

```
app/
├── queries/
│   └── warcraft_logs/
│       ├── base_client.rb           # Base client for all queries
│       ├── report_query.rb          # Report data queries
│       ├── encounter_query.rb       # Encounter statistics
│       ├── performance_query.rb     # Parse data and rankings
│       ├── attendance_query_new.rb  # Attendance tracking
│       ├── guild_query.rb           # Guild information
│       ├── character_query.rb       # Character information
│       └── class_helper.rb          # Helper utilities
└── services/
    └── warcraft_logs_analytics_service.rb  # Analytics aggregation
```

## Migration Notes

- The original `attendance_query.rb` is preserved for backward compatibility
- New modular classes are prefixed with `_new` to avoid conflicts
- AnalyticsService provides the same interface as the original attendance methods
- All existing functionality is maintained while providing better organization

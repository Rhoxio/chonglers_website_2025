# Attendance analysis queries for Warcraft Logs
require 'set'
require 'date'
require 'json'

module WarcraftLogs
  class AttendanceQuery
    attr_reader :client
    
    def initialize(client = nil)
      @client = client || WarcraftLogsClient.new
    end

    # Get member attendance from a specific date
    def self.attendance_from_date(guild_id, start_date, end_date = nil)
      new.attendance_from_date(guild_id, start_date, end_date)
    end

    # Get summary attendance data (high-level only)
    def self.attendance_summary(guild_id, start_date, end_date = nil)
      new.attendance_summary(guild_id, start_date, end_date)
    end

    def attendance_from_date(guild_id, start_date, end_date = nil)
      puts "📊 Analyzing attendance from #{start_date}..."
      puts "Guild ID: #{guild_id}\n"

      start_time_ms = start_date.to_time.to_f * 1000
      end_time_ms = end_date ? end_date.to_time.to_f * 1000 : nil

      reports = get_reports_since_date(guild_id, start_time_ms, end_time_ms)
      guild_members = get_guild_members(guild_id)
      
      analyze_attendance(reports, guild_members)
    rescue RuntimeError => e
      # Handle API errors for invalid guild IDs gracefully
      if e.message.include?('No guild exists for this id')
        return {
          total_raids: 0,
          total_reports: 0,
          guild_members: [],
          attendance: {},
          encounter_stats: {},
          raid_details: [],
          reports_analyzed: []
        }.deep_symbolize_keys
      end
      raise e
    end

    def attendance_summary(guild_id, start_date, end_date = nil)
      start_time_ms = start_date.to_time.to_f * 1000
      end_time_ms = end_date ? end_date.to_time.to_f * 1000 : nil

      reports = get_reports_since_date(guild_id, start_time_ms, end_time_ms)
      guild_members = get_guild_members(guild_id)
      
      # Get basic stats without all the detailed output
      attendance = {}
      encounter_stats = {}
      valid_raids = 0
      guild_member_names = Set.new(guild_members.map { |member| member['name'] })

      reports.each do |report|
        next unless report && report['startTime']

        report_data = get_report_fights(report['code'])
        next unless report_data

        fights = report_data['fights'] || []
        boss_fights = fights.select { |fight| fight['encounterID'] != 0 }
        next if boss_fights.count == 0

        valid_raids += 1

        actors = report_data.dig('masterData', 'actors') || []
        players = actors.select { |actor| actor['type'] == 'Player' }
        all_participant_names = players.map { |player| player['name'] }.compact.uniq
        guild_member_participants = all_participant_names.select { |name| guild_member_names.include?(name) }

        guild_member_participants.each do |player_name|
          attendance[player_name] ||= { raids_attended: 0, fights: 0, parse_data: [] }
          attendance[player_name][:raids_attended] += 1
          attendance[player_name][:fights] += boss_fights.count
        end
        
        # Collect parse data for all kills in this raid (more efficient - one API call per fight)
        boss_fights.each do |fight|
          if fight['kill'] # Only include kills, not wipes
            puts "      🔍 Fetching parse data for #{fight['name']} (#{fight['difficulty']})"
            rankings_data = get_fight_rankings_data(report['code'], fight['id'])
            
            if rankings_data
              characters = rankings_data[:characters]
              puts "      📊 Found #{characters.count} characters with parse data"
              
              # Look up parse data for each guild member who participated
              guild_member_participants.each do |player_name|
                player_ranking = characters.find { |character| character['name'] == player_name }
                
                if player_ranking
                  parse_data = {
                    encounter_id: fight['encounterID'],
                    encounter_name: fight['name'],
                    difficulty: fight['difficulty'],
                    ilvl_parse: player_ranking['rankPercent'],
                    overall_parse: player_ranking['rankPercent'],
                    ilvl_amount: player_ranking['amount'],
                    overall_amount: player_ranking['amount'],
                    spec: player_ranking['spec'],
                    rank: player_ranking['rank'],
                    total: player_ranking['totalParses'],
                    bracket_percent: player_ranking['bracketPercent']
                  }
                  attendance[player_name][:parse_data] << parse_data
                  puts "      ✅ #{player_name}: #{player_ranking['rankPercent']}%"
                else
                  puts "      ❌ No parse data for #{player_name}"
                end
              end
            else
              puts "      ❌ No rankings data found for #{fight['name']}"
            end
          end
        end

        boss_fights.each do |fight|
          encounter_key = "#{fight['name']} (#{fight['difficulty']})"
          encounter_stats[encounter_key] ||= { attempts: 0, kills: 0 }
          encounter_stats[encounter_key][:attempts] += 1
          encounter_stats[encounter_key][:kills] += 1 if fight['kill']
        end
      end

      # Calculate summary metrics
      sorted_attendance = attendance.sort_by { |name, data| -data[:raids_attended] }
      sorted_encounters = encounter_stats.sort_by { |k, v| -v[:kills].to_f / v[:attempts] }
      
      {
        total_raids: valid_raids,
        total_reports: reports.count,
        total_guild_members: guild_members.count,
        active_members: attendance.count,
        
        # Full attendance data (all members)
        attendance: sorted_attendance.map { |name, data|
          parse_data = data[:parse_data] || []
          avg_ilvl_parse = parse_data.any? ? parse_data.map { |p| p[:ilvl_parse] }.compact.sum / parse_data.count { |p| p[:ilvl_parse] } : 0
          avg_overall_parse = parse_data.any? ? parse_data.map { |p| p[:overall_parse] }.compact.sum / parse_data.count { |p| p[:overall_parse] } : 0
          
          {
            name: name,
            attendance_percentage: (data[:raids_attended].to_f / valid_raids * 100).round(1),
            raids_attended: data[:raids_attended],
            total_fights: data[:fights],
            avg_ilvl_parse: avg_ilvl_parse.round(1),
            avg_overall_parse: avg_overall_parse.round(1),
            parse_count: parse_data.count
          }
        },
        
        # Top 5 performers
        top_performers: sorted_attendance.first(5).map { |name, data| 
          parse_data = data[:parse_data] || []
          avg_ilvl_parse = parse_data.any? ? parse_data.map { |p| p[:ilvl_parse] }.compact.sum / parse_data.count { |p| p[:ilvl_parse] } : 0
          avg_overall_parse = parse_data.any? ? parse_data.map { |p| p[:overall_parse] }.compact.sum / parse_data.count { |p| p[:overall_parse] } : 0
          
          { 
            name: name, 
            attendance_percentage: (data[:raids_attended].to_f / valid_raids * 100).round(1),
            raids_attended: data[:raids_attended],
            total_fights: data[:fights],
            avg_ilvl_parse: avg_ilvl_parse.round(1),
            avg_overall_parse: avg_overall_parse.round(1),
            parse_count: parse_data.count
          }
        },
        
        # All encounter stats with kill rates
        encounter_stats: encounter_stats.map { |encounter, stats|
          {
            encounter: encounter,
            kill_rate: (stats[:kills].to_f / stats[:attempts] * 100).round(1),
            kills: stats[:kills],
            attempts: stats[:attempts]
          }
        },
        
        # Top 5 encounters by kill rate
        top_encounters: sorted_encounters.first(5).map { |encounter, stats|
          {
            encounter: encounter,
            kill_rate: (stats[:kills].to_f / stats[:attempts] * 100).round(1),
            kills: stats[:kills],
            attempts: stats[:attempts]
          }
        },
        
        # Overall guild stats
        overall_stats: {
          avg_attendance: attendance.values.map { |data| data[:raids_attended] }.sum.to_f / attendance.count,
          total_encounters: encounter_stats.count,
          successful_encounters: encounter_stats.count { |k, v| v[:kills] > 0 },
          best_kill_rate: sorted_encounters.first ? (sorted_encounters.first[1][:kills].to_f / sorted_encounters.first[1][:attempts] * 100).round(1) : 0,
          worst_kill_rate: sorted_encounters.last ? (sorted_encounters.last[1][:kills].to_f / sorted_encounters.last[1][:attempts] * 100).round(1) : 0
        }
      }.deep_symbolize_keys
    end

    private

    def get_reports_since_date(guild_id, start_time, end_time = nil)
      query = <<~GRAPHQL
        query($guildID: Int!, $limit: Int!, $startTime: Float!, $endTime: Float) {
          reportData {
            reports(guildID: $guildID, limit: $limit, startTime: $startTime, endTime: $endTime) {
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

      variables = {
        guildID: guild_id,
        limit: 50,
        startTime: start_time
      }

      variables[:endTime] = end_time if end_time

      @client.authenticate_client_credentials! unless @client.access_token
      result = @client.public_query(query, variables)
      result.dig('reportData', 'reports', 'data') || []
    end

    def analyze_attendance(reports, guild_members)
      attendance = {}
      encounter_stats = {}
      raid_details = []
      valid_raids = 0
      guild_member_names = Set.new(guild_members.map { |member| member['name'] })

      puts "📊 Found #{reports.count} raids since start date"
      puts "🏰 Found #{guild_members.count} current guild members"
      puts "🔍 Analyzing attendance for guild members only...\n"

      reports.each_with_index do |report, index|
        next unless report && report['startTime']

        start_time = Time.at(report['startTime'] / 1000)
        title = report['title'] || 'Unknown'
        zone_name = report.dig('zone', 'name') || 'Unknown Zone'
        report_code = report['code']

        puts "   #{index + 1}. #{title} - #{start_time.strftime('%Y-%m-%d')}"
        puts "      Zone: #{zone_name}"

        report_data = get_report_fights(report_code)

        if report_data
          fights = report_data['fights'] || []
          boss_fights = fights.select { |fight| fight['encounterID'] != 0 }
          
          next if boss_fights.count == 0
          
          valid_raids += 1
          
          actors = report_data.dig('masterData', 'actors') || []
          players = actors.select { |actor| actor['type'] == 'Player' }
          all_participant_names = players.map { |player| player['name'] }.compact.uniq
          
          guild_member_participants = all_participant_names.select { |name| guild_member_names.include?(name) }
          
          puts "      Guild members present: #{guild_member_participants.count}/#{guild_member_names.count}"
          
          # Store raid details
          raid_details << {
            title: title,
            date: start_time.strftime('%Y-%m-%d'),
            zone: zone_name,
            report_code: report_code,
            guild_members_present: guild_member_participants,
            guild_members_count: guild_member_participants.count,
            total_guild_members: guild_member_names.count,
            boss_fights: boss_fights.map { |fight| {
              encounter_id: fight['encounterID'],
              name: fight['name'],
              difficulty: fight['difficulty'],
              killed: fight['kill'],
              start_time: fight['startTime'],
              end_time: fight['endTime']
            }}
          }
          
          guild_member_participants.each do |player_name|
            attendance[player_name] ||= { raids_attended: 0, fights: 0 }
            attendance[player_name][:raids_attended] += 1
            attendance[player_name][:fights] += boss_fights.count
          end

          boss_fights.each do |fight|
            encounter_id = fight['encounterID']
            encounter_name = fight['name']
            difficulty = fight['difficulty']
            killed = fight['kill']

            encounter_key = "#{encounter_name} (#{difficulty})"
            encounter_stats[encounter_key] ||= { 
              attempts: 0, 
              kills: 0, 
              participants: Set.new,
              kill_rate: 0.0,
              encounter_name: encounter_name,
              difficulty: difficulty
            }
            encounter_stats[encounter_key][:attempts] += 1
            encounter_stats[encounter_key][:kills] += 1 if killed
            encounter_stats[encounter_key][:participants].merge(guild_member_participants)
            encounter_stats[encounter_key][:kill_rate] = encounter_stats[encounter_key][:kills].to_f / encounter_stats[encounter_key][:attempts] * 100
          end
        end

        puts ""
      end

      show_encounter_summary(encounter_stats)
      show_attendance_summary(attendance, valid_raids)

      {
        total_raids: valid_raids,
        total_reports: reports.count,
        guild_members: guild_members,
        attendance: attendance,
        encounter_stats: encounter_stats.transform_values { |v| v.merge(participants: v[:participants].to_a) },
        raid_details: raid_details,
        reports_analyzed: reports.map { |r| r['title'] }
      }.deep_symbolize_keys
    end

    def show_encounter_summary(encounter_stats)
      puts "🏆 Encounter Summary:"
      encounter_stats.each do |encounter, stats|
        kill_rate = stats[:attempts] > 0 ? (stats[:kills].to_f / stats[:attempts] * 100).round(1) : 0
        puts "   #{encounter}: #{stats[:kills]}/#{stats[:attempts]} (#{kill_rate}% kill rate)"
      end
    end

    def show_attendance_summary(attendance, valid_raids)
      puts "\n✅ Guild Member Attendance (#{attendance.count} members):"
      puts "📊 Valid raids (with boss fights): #{valid_raids}"
      
      sorted_attendance = attendance.sort_by { |name, data| -data[:raids_attended] }

      sorted_attendance.each_with_index do |(player_name, data), index|
        percentage = valid_raids > 0 ? (data[:raids_attended].to_f / valid_raids * 100).round(1) : 0
        puts "#{index + 1}. #{player_name}"
        puts "   Raids: #{data[:raids_attended]}/#{valid_raids} (#{percentage}%)"
        puts "   Fights: #{data[:fights]}"
      end

      puts "\n🏆 Top Performers:"
      sorted_attendance.first(5).each_with_index do |(player_name, data), index|
        percentage = valid_raids > 0 ? (data[:raids_attended].to_f / valid_raids * 100).round(1) : 0
        puts "   #{index + 1}. #{player_name} - #{percentage}%"
      end
    end

    def get_report_fights(report_code)
      query = <<~GRAPHQL
        query($reportCode: String!) {
          reportData {
            report(code: $reportCode) {
              title
              startTime
              endTime
              zone {
                name
              }
              masterData {
                actors {
                  id
                  name
                  type
                  subType
                }
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
    rescue => e
      puts "      ⚠️ Error fetching fight data: #{e.message}"
      nil
    end

    def get_guild_members(guild_id)
      query = <<~GRAPHQL
        query($guildID: Int!) {
          guildData {
            guild(id: $guildID) {
              id
              name
              members {
                data {
                  name
                  classID
                  guildRank
                }
              }
            }
          }
        }
      GRAPHQL

      @client.authenticate_client_credentials! unless @client.access_token
      result = @client.public_query(query, { guildID: guild_id })
      result.dig('guildData', 'guild', 'members', 'data') || []
  rescue => e
    puts "⚠️ Error fetching guild members: #{e.message}"
    []
  end

  def get_fight_rankings_data(report_code, fight_id)
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
    
    # Parse the rankings JSON
    begin
      rankings_data = JSON.parse(rankings_raw) if rankings_raw.is_a?(String)
      rankings_data ||= rankings_raw
      
      # Extract the data array from rankings
      rankings = rankings_data.dig('data') || []
      
      # The rankings structure has roles with characters
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
      puts "        ⚠️ Error parsing rankings JSON: #{e.message}"
      nil
    end
  rescue => e
    puts "        ⚠️ Error fetching fight rankings: #{e.message}"
    nil
  end


  def find_player_in_details(details_data, player_name)
    puts "          🔎 Searching in #{details_data.class} for #{player_name}"
    
    # This is a simplified approach - the actual structure may vary
    # We'll need to explore the JSON structure to find the right path
    if details_data.is_a?(Hash)
      puts "          📁 Hash with keys: #{details_data.keys}"
      # Look for arrays that might contain player data
      details_data.each do |key, value|
        puts "          🔑 Checking key: #{key} (#{value.class})"
        if value.is_a?(Array)
          puts "          📋 Array with #{value.count} items"
          if key == 'data' && value.count > 0
            puts "          🔍 Sample array items:"
            value.first(3).each_with_index do |item, idx|
              puts "            #{idx}: #{item.class} - #{item.keys if item.is_a?(Hash)}"
              if item.is_a?(Hash) && item['name']
                puts "              Name: #{item['name']}"
              elsif item.is_a?(Hash) && item['bracketData']
                puts "              Has bracketData: #{item['bracketData'].class}"
                if item['bracketData'].is_a?(Hash)
                  puts "                BracketData keys: #{item['bracketData'].keys}"
                end
              end
            end
          end
          player = value.find { |item| item.is_a?(Hash) && item['name'] == player_name }
          if player
            puts "          ✅ Found player in array under key: #{key}"
            return player
          end
        elsif value.is_a?(Hash)
          puts "          🔍 Recursing into hash under key: #{key}"
          player = find_player_in_details(value, player_name)
          return player if player
        end
      end
    elsif details_data.is_a?(Array)
      puts "          📋 Array with #{details_data.count} items"
      details_data.each_with_index do |item, index|
        puts "          📄 Item #{index}: #{item.class}"
        if item.is_a?(Hash) && item['name'] == player_name
          puts "          ✅ Found player at index #{index}"
          return item
        end
      end
    end
    
    puts "          ❌ Player not found in this structure"
    nil
  end

  def get_fight_rankings(report_code, fight_id, player_name)
    puts "        🏆 Querying parse data for #{player_name} in fight #{fight_id}"
    
    # Use the correct GraphQL query structure for parse data
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
    
    puts "        📊 Found #{fights.count} fights, rankings: #{rankings_raw ? 'present' : 'missing'}"
    
    return nil if fights.empty? || !rankings_raw
    
    fight = fights.first
    
    puts "        🎯 Processing parse data for fight: #{fight['name']} (#{fight['difficulty']})"
    
    # Parse the rankings JSON
    begin
      rankings_data = JSON.parse(rankings_raw) if rankings_raw.is_a?(String)
      rankings_data ||= rankings_raw
      
      puts "        📋 Rankings structure: #{rankings_data.class} - #{rankings_data.keys if rankings_data.is_a?(Hash)}"
      
      # Extract the data array from rankings
      rankings = rankings_data.dig('data') || []
      puts "        📊 Found #{rankings.count} fight rankings"
      
      # The rankings structure has roles with characters
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
      
      puts "        📊 Found #{all_characters.count} characters with parse data"
      
      # Debug: show what names are in the rankings (limited output)
      if all_characters.any?
        puts "        🔍 Found #{all_characters.count} players with parse data"
      end
      
      # Find the specific player in the rankings
      player_ranking = all_characters.find { |character| character['name'] == player_name }
    rescue JSON::ParserError => e
      puts "        ⚠️ Error parsing rankings JSON: #{e.message}"
      puts "        📄 Raw rankings: #{rankings_raw}"
      return nil
    end
    
    if player_ranking
      puts "        ✅ Found parse data for #{player_name}: #{player_ranking.keys}"
      
      # Extract parse data from character ranking
      {
        encounter_id: fight['encounterID'],
        encounter_name: fight['name'],
        difficulty: fight['difficulty'],
        ilvl_parse: player_ranking['rankPercent'],
        overall_parse: player_ranking['rankPercent'], # Same percentile for both
        ilvl_amount: player_ranking['amount'],
        overall_amount: player_ranking['amount'],
        spec: player_ranking['spec'],
        rank: player_ranking['rank'],
        total: player_ranking['totalParses'],
        bracket_percent: player_ranking['bracketPercent']
      }
    else
      puts "        ❌ Player #{player_name} not found in parse rankings"
      nil
    end
  rescue => e
    puts "        ⚠️ Error fetching parse data for #{player_name}: #{e.message}"
    nil
  end
  end
end
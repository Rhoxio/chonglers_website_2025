require 'rails_helper'

RSpec.describe WarcraftLogs::AttendanceQuery, type: :model do
  let(:guild_id) { 123456 }
  let(:start_date) { Date.parse('2024-01-01') }
  let(:end_date) { Date.parse('2024-01-31') }
  
  let(:sample_reports) do
    [
      {
        'code' => 'ABC123',
        'title' => 'Raid Night 1',
        'startTime' => start_date.to_time.to_f * 1000,
        'zone' => { 'name' => 'Test Raid' }
      },
      {
        'code' => 'DEF456',
        'title' => 'Raid Night 2',
        'startTime' => (start_date + 1.day).to_time.to_f * 1000,
        'zone' => { 'name' => 'Test Raid' }
      }
    ]
  end

  let(:sample_guild_members) do
    [
      { 'name' => 'Player1', 'classID' => 1, 'guildRank' => 2 },
      { 'name' => 'Player2', 'classID' => 3, 'guildRank' => 3 },
      { 'name' => 'Player3', 'classID' => 8, 'guildRank' => 4 }
    ]
  end

  describe '.get_guild_attendance', :vcr do
    context 'with valid guild ID and date range' do
      it 'returns guild attendance data' do
        VCR.use_cassette('warcraft_logs/attendance_query_new/get_guild_attendance_success') do
          result = described_class.get_guild_attendance(guild_id, start_date, end_date)
          
          expect(result).to be_a(Hash)
          expect(result).to include('attendance', 'total_raids', 'total_reports', 'guild_members')
          
          expect(result['attendance']).to be_a(Hash)
          expect(result['total_raids']).to be_a(Integer)
          expect(result['total_reports']).to be_a(Integer)
          expect(result['guild_members']).to be_an(Array)
        end
      end

      it 'calculates attendance percentages correctly' do
        VCR.use_cassette('warcraft_logs/attendance_query_new/attendance_percentages') do
          result = described_class.get_guild_attendance(guild_id, start_date, end_date)
          
          result['attendance'].each do |player_name, data|
            expect(data).to include('raids_attended', 'fights', 'raid_details', 'attendance_percentage')
            
            if result['total_raids'] > 0
              expected_percentage = (data['raids_attended'].to_f / result['total_raids'] * 100).round(1)
              expect(data['attendance_percentage']).to eq(expected_percentage)
            else
              expect(data['attendance_percentage']).to eq(0)
            end
          end
        end
      end
    end

    context 'with only start date' do
      it 'returns attendance from start date onwards' do
        VCR.use_cassette('warcraft_logs/attendance_query_new/get_guild_attendance_no_end') do
          result = described_class.get_guild_attendance(guild_id, start_date)
          
          expect(result).to be_a(Hash)
          expect(result).to include('attendance', 'total_raids')
        end
      end
    end

    context 'with invalid guild ID' do
      it 'handles non-existent guild gracefully' do
        VCR.use_cassette('warcraft_logs/attendance_query_new/get_guild_attendance_not_found') do
          result = described_class.get_guild_attendance(999999, start_date, end_date)
          
          expect(result).to be_a(Hash)
          expect(result['total_raids']).to eq(0)
          expect(result['attendance']).to eq({})
        end
      end
    end
  end

  describe '.get_attendance_for_reports', :vcr do
    context 'with valid reports and guild members' do
      it 'calculates attendance from provided reports' do
        # Mock ReportQuery dependencies
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights) do |code|
          case code
          when 'ABC123'
            {
              'fights' => [
                { 'encounterID' => 2917, 'name' => 'Boss A', 'difficulty' => 4, 'kill' => true },
                { 'encounterID' => 2918, 'name' => 'Boss B', 'difficulty' => 4, 'kill' => false }
              ]
            }
          when 'DEF456'
            {
              'fights' => [
                { 'encounterID' => 2917, 'name' => 'Boss A', 'difficulty' => 4, 'kill' => true }
              ]
            }
          else
            nil
          end
        end

        allow(WarcraftLogs::ReportQuery).to receive(:get_report_participants) do |code|
          case code
          when 'ABC123'
            [
              { 'name' => 'Player1', 'type' => 'Player' },
              { 'name' => 'Player2', 'type' => 'Player' },
              { 'name' => 'NonGuildPlayer', 'type' => 'Player' }
            ]
          when 'DEF456'
            [
              { 'name' => 'Player1', 'type' => 'Player' },
              { 'name' => 'Player3', 'type' => 'Player' }
            ]
          else
            []
          end
        end

        result = described_class.get_attendance_for_reports(sample_reports, sample_guild_members)
        
        expect(result).to be_a(Hash)
        expect(result).to include('attendance', 'total_raids', 'total_reports', 'guild_members')
        
        # Player1 should be in both raids
        expect(result['attendance']).to have_key('Player1')
        player1_data = result['attendance']['Player1']
        expect(player1_data['raids_attended']).to eq(2)
        expect(player1_data['fights']).to eq(3) # 2 fights in first raid + 1 fight in second raid
        expect(player1_data['attendance_percentage']).to eq(100.0)
        
        # Player2 should only be in first raid
        expect(result['attendance']).to have_key('Player2')
        player2_data = result['attendance']['Player2']
        expect(player2_data['raids_attended']).to eq(1)
        expect(player2_data['fights']).to eq(2)
        expect(player2_data['attendance_percentage']).to eq(50.0)
        
        # Player3 should only be in second raid
        expect(result['attendance']).to have_key('Player3')
        player3_data = result['attendance']['Player3']
        expect(player3_data['raids_attended']).to eq(1)
        expect(player3_data['fights']).to eq(1)
        expect(player3_data['attendance_percentage']).to eq(50.0)
        
        # Non-guild player should not be tracked
        expect(result['attendance']).not_to have_key('NonGuildPlayer')
      end

      it 'stores detailed raid information' do
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
          {
            'fights' => [
              { 'encounterID' => 2917, 'name' => 'Boss', 'difficulty' => 4, 'kill' => true }
            ]
          }
        )

        allow(WarcraftLogs::ReportQuery).to receive(:get_report_participants).and_return(
          [{ 'name' => 'Player1', 'type' => 'Player' }]
        )

        result = described_class.get_attendance_for_reports([sample_reports.first], sample_guild_members)
        
        if result['attendance']['Player1']
          raid_details = result['attendance']['Player1']['raid_details']
          expect(raid_details).to be_an(Array)
          expect(raid_details.length).to eq(1)
          
          raid_detail = raid_details.first
          expect(raid_detail).to include(
            'report_code', 'raid_title', 'zone', 'start_time', 'boss_fights', 'kills'
          )
          expect(raid_detail['report_code']).to eq('ABC123')
          expect(raid_detail['raid_title']).to eq('Raid Night 1')
          expect(raid_detail['zone']).to eq('Test Raid')
          expect(raid_detail['boss_fights']).to eq(1)
          expect(raid_detail['kills']).to eq(1)
        end
      end

      it 'filters out reports without boss fights' do
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
          {
            'fights' => [
              { 'encounterID' => 0, 'name' => 'Trash', 'difficulty' => 0, 'kill' => true }
            ]
          }
        )

        allow(WarcraftLogs::ReportQuery).to receive(:get_report_participants).and_return(
          [{ 'name' => 'Player1', 'type' => 'Player' }]
        )

        result = described_class.get_attendance_for_reports(sample_reports, sample_guild_members)
        
        expect(result['total_raids']).to eq(0)
        expect(result['attendance']).to eq({})
      end
    end

    context 'with empty reports or guild members' do
      it 'handles empty reports array' do
        result = described_class.get_attendance_for_reports([], sample_guild_members)
        
        expect(result['total_raids']).to eq(0)
        expect(result['total_reports']).to eq(0)
        expect(result['attendance']).to eq({})
      end

      it 'handles empty guild members array' do
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
          { 'fights' => [{ 'encounterID' => 2917, 'name' => 'Boss', 'difficulty' => 4, 'kill' => true }] }
        )
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_participants).and_return(
          [{ 'name' => 'Player1', 'type' => 'Player' }]
        )

        result = described_class.get_attendance_for_reports(sample_reports, [])
        
        expect(result['total_raids']).to eq(2)
        expect(result['attendance']).to eq({})
      end
    end
  end

  describe 'instance methods' do
    let(:instance) { described_class.new }

    describe '#get_guild_attendance', :vcr do
      it 'works as instance method' do
        VCR.use_cassette('warcraft_logs/attendance_query_new/instance_get_guild_attendance') do
          result = instance.get_guild_attendance(guild_id, start_date, end_date)
          expect(result).to be_a(Hash)
        end
      end
    end

    describe '#get_attendance_for_reports' do
      it 'works as instance method' do
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(nil)
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_participants).and_return([])
        
        result = instance.get_attendance_for_reports(sample_reports, sample_guild_members)
        expect(result).to be_a(Hash)
      end
    end
  end

  describe 'data structure validation' do
    context 'when attendance data is returned' do
      it 'has expected structure for each player' do
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
          {
            'fights' => [
              { 'encounterID' => 2917, 'name' => 'Test Boss', 'difficulty' => 4, 'kill' => true }
            ]
          }
        )

        allow(WarcraftLogs::ReportQuery).to receive(:get_report_participants).and_return(
          [{ 'name' => 'Player1', 'type' => 'Player' }]
        )

        result = described_class.get_attendance_for_reports([sample_reports.first], sample_guild_members)
        
        if result['attendance']['Player1']
          player_data = result['attendance']['Player1']
          expect(player_data).to be_a(Hash)
          expect(player_data).to include('raids_attended', 'fights', 'raid_details', 'attendance_percentage')
          
          expect(player_data['raids_attended']).to be_a(Integer)
          expect(player_data['fights']).to be_a(Integer)
          expect(player_data['raid_details']).to be_an(Array)
          expect(player_data['attendance_percentage']).to be_a(Numeric)
          
          # Validate raid details structure
          if player_data['raid_details'].any?
            raid_detail = player_data['raid_details'].first
            expect(raid_detail).to include('report_code', 'raid_title', 'zone', 'start_time', 'boss_fights', 'kills')
          end
        end
      end
    end
  end

  describe 'integration with other query classes' do
    it 'correctly integrates with ReportQuery and GuildQuery' do
      # Mock ReportQuery methods
      allow(WarcraftLogs::ReportQuery).to receive(:get_guild_reports)
        .with(guild_id, start_date, end_date)
        .and_return(sample_reports)
      
      allow(WarcraftLogs::GuildQuery).to receive(:members)
        .with(guild_id)
        .and_return(sample_guild_members)

      allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
        {
          'fights' => [
            { 'encounterID' => 2917, 'name' => 'Integration Boss', 'difficulty' => 4, 'kill' => true }
          ]
        }
      )

      allow(WarcraftLogs::ReportQuery).to receive(:get_report_participants).and_return(
        [{ 'name' => 'Player1', 'type' => 'Player' }]
      )

      result = described_class.get_guild_attendance(guild_id, start_date, end_date)
      
      expect(result).to be_a(Hash)
      expect(result['guild_members']).to eq(sample_guild_members)
      if result['attendance']['Player1']
        raid_detail = result['attendance']['Player1']['raid_details'].first
        expect(raid_detail['raid_title']).to eq('Raid Night 1')
      end
    end
  end

  describe 'attendance percentage calculations' do
    it 'calculates percentages correctly for various scenarios' do
      test_cases = [
        { raids_attended: 0, total_raids: 1, expected_percentage: 0.0 },
        { raids_attended: 1, total_raids: 1, expected_percentage: 100.0 },
        { raids_attended: 1, total_raids: 3, expected_percentage: 33.3 },
        { raids_attended: 2, total_raids: 3, expected_percentage: 66.7 },
        { raids_attended: 5, total_raids: 7, expected_percentage: 71.4 }
      ]

      test_cases.each do |test_case|
        raids_attended = test_case[:raids_attended]
        total_raids = test_case[:total_raids]
        expected = test_case[:expected_percentage]
        
        # Create report data to match the test case
        reports = Array.new(total_raids) do |i|
          {
            'code' => "RAID#{i}",
            'title' => "Raid #{i}",
            'startTime' => (start_date + i.days).to_time.to_f * 1000,
            'zone' => { 'name' => 'Test Zone' }
          }
        end

        # Mock ReportQuery to return controlled data
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
          {
            'fights' => [
              { 'encounterID' => 2917, 'name' => 'Test Boss', 'difficulty' => 4, 'kill' => true }
            ]
          }
        )

        allow(WarcraftLogs::ReportQuery).to receive(:get_report_participants) do |code|
          raid_index = code.gsub('RAID', '').to_i
          if raid_index < raids_attended
            [{ 'name' => 'TestPlayer', 'type' => 'Player' }]
          else
            []
          end
        end

        guild_members = [{ 'name' => 'TestPlayer', 'classID' => 1 }]
        result = described_class.get_attendance_for_reports(reports, guild_members)
        
        if result['attendance']['TestPlayer']
          player_data = result['attendance']['TestPlayer']
          expect(player_data['raids_attended']).to eq(raids_attended)
          expect(player_data['attendance_percentage']).to eq(expected)
        end
      end
    end
  end

  describe 'error handling' do
    context 'when ReportQuery methods fail' do
      it 'handles get_report_fights failures gracefully' do
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(nil)
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_participants).and_return([])

        result = described_class.get_attendance_for_reports(sample_reports, sample_guild_members)
        
        expect(result['total_raids']).to eq(0)
        expect(result['attendance']).to eq({})
      end

      it 'handles get_report_participants failures gracefully' do
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
          {
            'fights' => [
              { 'encounterID' => 2917, 'name' => 'Boss', 'difficulty' => 4, 'kill' => true }
            ]
          }
        )
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_participants).and_return(nil)

        result = described_class.get_attendance_for_reports(sample_reports, sample_guild_members)
        
        expect(result['total_raids']).to eq(2) # Reports still processed
        expect(result['attendance']).to eq({}) # But no attendance tracked
      end
    end

    context 'when reports have missing data' do
      it 'handles reports without startTime' do
        invalid_reports = [
          {
            'code' => 'ABC123',
            'title' => 'Invalid Report'
            # Missing startTime
          }
        ]

        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
          {
            'fights' => [
              { 'encounterID' => 2917, 'name' => 'Boss', 'difficulty' => 4, 'kill' => true }
            ]
          }
        )
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_participants).and_return(
          [{ 'name' => 'Player1', 'type' => 'Player' }]
        )

        expect { described_class.get_attendance_for_reports(invalid_reports, sample_guild_members) }.not_to raise_error
      end

      it 'handles reports with missing zone information' do
        reports_without_zone = [
          {
            'code' => 'ABC123',
            'title' => 'Raid Without Zone',
            'startTime' => start_date.to_time.to_f * 1000
            # Missing zone
          }
        ]

        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
          {
            'fights' => [
              { 'encounterID' => 2917, 'name' => 'Boss', 'difficulty' => 4, 'kill' => true }
            ]
          }
        )
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_participants).and_return(
          [{ 'name' => 'Player1', 'type' => 'Player' }]
        )

        result = described_class.get_attendance_for_reports(reports_without_zone, sample_guild_members)
        
        if result['attendance']['Player1']
          raid_detail = result['attendance']['Player1']['raid_details'].first
          expect(raid_detail['zone']).to eq('Unknown Zone')
        end
      end
    end
  end

  describe 'fight counting logic' do
    it 'counts only boss fights for attendance tracking' do
      allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
        {
          'fights' => [
            { 'encounterID' => 2917, 'name' => 'Boss A', 'difficulty' => 4, 'kill' => true },    # Boss fight
            { 'encounterID' => 0, 'name' => 'Trash Pack 1', 'difficulty' => 0, 'kill' => true }, # Trash fight
            { 'encounterID' => 2918, 'name' => 'Boss B', 'difficulty' => 4, 'kill' => false },   # Boss fight (wipe)
            { 'encounterID' => 0, 'name' => 'Trash Pack 2', 'difficulty' => 0, 'kill' => true }  # Trash fight
          ]
        }
      )

      allow(WarcraftLogs::ReportQuery).to receive(:get_report_participants).and_return(
        [{ 'name' => 'Player1', 'type' => 'Player' }]
      )

      result = described_class.get_attendance_for_reports([sample_reports.first], sample_guild_members)
      
      if result['attendance']['Player1']
        player_data = result['attendance']['Player1']
        expect(player_data['fights']).to eq(2) # Only the 2 boss fights
        
        raid_detail = player_data['raid_details'].first
        expect(raid_detail['boss_fights']).to eq(2)
        expect(raid_detail['kills']).to eq(1) # Only Boss A was killed
      end
    end
  end
end

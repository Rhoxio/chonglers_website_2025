require 'rails_helper'

RSpec.describe WarcraftLogs::EncounterQuery, type: :model do
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

  describe '.get_encounter_stats', :vcr do
    context 'with valid guild ID and date range' do
      it 'returns encounter statistics' do
        VCR.use_cassette('warcraft_logs/encounter_query/get_encounter_stats_success') do
          result = described_class.get_encounter_stats(guild_id, start_date, end_date)
          
          expect(result).to be_an(Array)
          
          if result.any?
            stat = result.first
            expect(stat).to include(:encounter, :kill_rate, :kills, :attempts, :encounter_ids)
            expect(stat[:kill_rate]).to be_a(Numeric)
            expect(stat[:kills]).to be <= stat[:attempts]
            expect(stat[:encounter_ids]).to be_an(Array)
          end
        end
      end

      it 'sorts results by kill rate descending' do
        VCR.use_cassette('warcraft_logs/encounter_query/get_encounter_stats_sorted') do
          result = described_class.get_encounter_stats(guild_id, start_date, end_date)
          
          if result.length > 1
            kill_rates = result.map { |stat| stat[:kill_rate] }
            expect(kill_rates).to eq(kill_rates.sort.reverse)
          end
        end
      end
    end

    context 'with invalid guild ID' do
      it 'returns empty array for non-existent guild' do
        VCR.use_cassette('warcraft_logs/encounter_query/get_encounter_stats_not_found') do
          result = described_class.get_encounter_stats(999999999, start_date, end_date)
          expect(result).to eq([])
        end
      end
    end
  end

  describe '.get_encounter_stats_for_reports', :vcr do
    context 'with valid reports' do
      it 'calculates encounter statistics from provided reports' do
        # Mock ReportQuery.get_report_fights to return controlled data
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights) do |code|
          case code
          when 'ABC123'
            {
              'fights' => [
                { 'encounterID' => 2917, 'name' => 'Boss A', 'difficulty' => 4, 'kill' => true },
                { 'encounterID' => 2917, 'name' => 'Boss A', 'difficulty' => 4, 'kill' => false },
                { 'encounterID' => 2918, 'name' => 'Boss B', 'difficulty' => 4, 'kill' => true }
              ]
            }
          when 'DEF456'
            {
              'fights' => [
                { 'encounterID' => 2917, 'name' => 'Boss A', 'difficulty' => 4, 'kill' => true },
                { 'encounterID' => 2919, 'name' => 'Boss C', 'difficulty' => 4, 'kill' => false }
              ]
            }
          else
            nil
          end
        end

        result = described_class.get_encounter_stats_for_reports(sample_reports)
        
        expect(result).to be_an(Array)
        expect(result.length).to eq(3) # Boss A, Boss B, Boss C
        
        # Find Boss A stats (should have 2 kills out of 3 attempts)
        boss_a_stats = result.find { |stat| stat[:encounter].include?('Boss A') }
        expect(boss_a_stats[:kills]).to eq(2)
        expect(boss_a_stats[:attempts]).to eq(3)
        expect(boss_a_stats[:kill_rate]).to eq(66.7)
        expect(boss_a_stats[:encounter_ids]).to eq([2917])
        
        # Find Boss B stats (should have 1 kill out of 1 attempt)
        boss_b_stats = result.find { |stat| stat[:encounter].include?('Boss B') }
        expect(boss_b_stats[:kills]).to eq(1)
        expect(boss_b_stats[:attempts]).to eq(1)
        expect(boss_b_stats[:kill_rate]).to eq(100.0)
        
        # Find Boss C stats (should have 0 kills out of 1 attempt)
        boss_c_stats = result.find { |stat| stat[:encounter].include?('Boss C') }
        expect(boss_c_stats[:kills]).to eq(0)
        expect(boss_c_stats[:attempts]).to eq(1)
        expect(boss_c_stats[:kill_rate]).to eq(0.0)
      end

      it 'handles reports with no boss fights' do
        reports_with_no_bosses = [
          {
            'code' => 'XYZ789',
            'title' => 'Trash Clear',
            'startTime' => start_date.to_time.to_f * 1000
          }
        ]

        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
          { 'fights' => [{ 'encounterID' => 0, 'name' => 'Trash', 'difficulty' => 0, 'kill' => true }] }
        )

        result = described_class.get_encounter_stats_for_reports(reports_with_no_bosses)
        expect(result).to eq([])
      end

      it 'handles empty reports array' do
        result = described_class.get_encounter_stats_for_reports([])
        expect(result).to eq([])
      end
    end
  end

  describe 'instance methods' do
    let(:instance) { described_class.new }

    describe '#get_encounter_stats', :vcr do
      it 'works as instance method' do
        VCR.use_cassette('warcraft_logs/encounter_query/instance_get_encounter_stats') do
          result = instance.get_encounter_stats(guild_id, start_date, end_date)
          expect(result).to be_an(Array)
        end
      end
    end

    describe '#get_encounter_stats_for_reports' do
      it 'works as instance method' do
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(nil)
        
        result = instance.get_encounter_stats_for_reports(sample_reports)
        expect(result).to be_an(Array)
      end
    end
  end

  describe 'data structure validation' do
    context 'when encounter stats are returned' do
      it 'has expected structure for each stat entry' do
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
          {
            'fights' => [
              { 'encounterID' => 2917, 'name' => 'Test Boss', 'difficulty' => 4, 'kill' => true }
            ]
          }
        )

        result = described_class.get_encounter_stats_for_reports(sample_reports)
        
        if result.any?
          stat = result.first
          expect(stat).to be_a(Hash)
          expect(stat).to include(:encounter, :kill_rate, :kills, :attempts, :encounter_ids)
          
          expect(stat[:encounter]).to be_a(String)
          expect(stat[:kill_rate]).to be_a(Numeric)
          expect(stat[:kills]).to be_a(Integer)
          expect(stat[:attempts]).to be_a(Integer)
          expect(stat[:encounter_ids]).to be_an(Array)
          
          # Validate kill rate calculation
          expected_kill_rate = (stat[:kills].to_f / stat[:attempts] * 100).round(1)
          expect(stat[:kill_rate]).to eq(expected_kill_rate)
        end
      end
    end
  end

  describe 'encounter grouping' do
    it 'groups encounters by name and difficulty' do
      allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights) do |code|
        case code
        when 'ABC123'
          {
            'fights' => [
              { 'encounterID' => 2917, 'name' => 'Same Boss', 'difficulty' => 3, 'kill' => true },  # Normal
              { 'encounterID' => 2917, 'name' => 'Same Boss', 'difficulty' => 4, 'kill' => true }   # Heroic
            ]
          }
        when 'DEF456'
          {
            'fights' => [
              { 'encounterID' => 2917, 'name' => 'Same Boss', 'difficulty' => 3, 'kill' => false }  # Normal again
            ]
          }
        else
          { 'fights' => [] }
        end
      end

      result = described_class.get_encounter_stats_for_reports(sample_reports)
      
      # Should have separate entries for Normal and Heroic difficulties
      normal_entry = result.find { |stat| stat[:encounter].include?('Same Boss') && stat[:encounter].include?('(3)') }
      heroic_entry = result.find { |stat| stat[:encounter].include?('Same Boss') && stat[:encounter].include?('(4)') }
      
      expect(normal_entry).not_to be_nil
      expect(heroic_entry).not_to be_nil
      
      # Normal should have 1 kill out of 2 attempts
      expect(normal_entry[:kills]).to eq(1)
      expect(normal_entry[:attempts]).to eq(2)
      
      # Heroic should have 1 kill out of 1 attempt
      expect(heroic_entry[:kills]).to eq(1)
      expect(heroic_entry[:attempts]).to eq(1)
    end
  end

  describe 'integration with ReportQuery' do
    it 'correctly integrates with ReportQuery.get_guild_reports' do
      # Mock ReportQuery methods
      allow(WarcraftLogs::ReportQuery).to receive(:get_guild_reports)
        .with(guild_id, start_date, end_date)
        .and_return(sample_reports)
      
      allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
        {
          'fights' => [
            { 'encounterID' => 2917, 'name' => 'Integration Test Boss', 'difficulty' => 4, 'kill' => true }
          ]
        }
      )

      result = described_class.get_encounter_stats(guild_id, start_date, end_date)
      
      expect(result).to be_an(Array)
      if result.any?
        expect(result.first[:encounter]).to include('Integration Test Boss')
      end
    end
  end

  describe 'error handling' do
    context 'when ReportQuery returns nil' do
      it 'handles nil report data gracefully' do
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(nil)
        
        result = described_class.get_encounter_stats_for_reports(sample_reports)
        expect(result).to eq([])
      end
    end

    context 'when ReportQuery returns data without fights' do
      it 'handles missing fights data gracefully' do
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return({})
        
        result = described_class.get_encounter_stats_for_reports(sample_reports)
        expect(result).to eq([])
      end
    end

    context 'when reports have invalid timestamps' do
      it 'handles invalid report data gracefully' do
        invalid_reports = [
          { 'code' => 'ABC123', 'title' => 'Invalid Report' }  # No startTime
        ]
        
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
          {
            'fights' => [
              { 'encounterID' => 2917, 'name' => 'Test Boss', 'difficulty' => 4, 'kill' => true }
            ]
          }
        )

        expect { described_class.get_encounter_stats_for_reports(invalid_reports) }.not_to raise_error
      end
    end
  end

  describe 'kill rate calculations' do
    it 'calculates kill rates correctly for various scenarios' do
      test_cases = [
        { kills: 0, attempts: 1, expected_rate: 0.0 },
        { kills: 1, attempts: 1, expected_rate: 100.0 },
        { kills: 1, attempts: 3, expected_rate: 33.3 },
        { kills: 2, attempts: 3, expected_rate: 66.7 },
        { kills: 5, attempts: 7, expected_rate: 71.4 }
      ]

      test_cases.each do |test_case|
        kills = test_case[:kills]
        attempts = test_case[:attempts]
        expected = test_case[:expected_rate]
        
        # Create fight data to match the test case
        fights = Array.new(attempts) do |i|
          {
            'encounterID' => 2917,
            'name' => 'Test Boss',
            'difficulty' => 4,
            'kill' => i < kills  # First 'kills' number of fights are kills
          }
        end

        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
          { 'fights' => fights }
        )

        result = described_class.get_encounter_stats_for_reports([sample_reports.first])
        
        if result.any?
          stat = result.first
          expect(stat[:kills]).to eq(kills)
          expect(stat[:attempts]).to eq(attempts)
          expect(stat[:kill_rate]).to eq(expected)
        end
      end
    end
  end
end

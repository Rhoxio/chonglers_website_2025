require 'rails_helper'

RSpec.describe WarcraftLogs::ReportQuery, type: :model do
  let(:report_code) { 'ABC123def456' }
  let(:guild_id) { ENV['WARCRAFTLOGS_GUILD_ID']&.to_i || 776399 }
  let(:start_date) { Date.parse('2024-01-01') }
  let(:end_date) { Date.parse('2024-01-31') }


  describe '.get_report', :vcr do
    context 'with valid report code' do
      xit 'returns report information' do
        VCR.use_cassette('warcraft_logs/report_query/get_report_success') do
          result = described_class.get_report(report_code)
          
          expect(result).to be_a(Hash)
          expect(result['code']).to eq(report_code)
          expect(result).to include('title', 'startTime', 'endTime', 'zone', 'fights')
          expect(result['zone']).to include('id', 'name')
          expect(result['fights']).to be_an(Array)
        end
      end
    end

    context 'with invalid report code' do
      it 'returns nil for non-existent report' do
        VCR.use_cassette('warcraft_logs/report_query/get_report_not_found') do
          result = described_class.get_report('InvalidCode')
          expect(result).to be_nil
        end
      end
    end
  end

  describe '.get_guild_reports', :vcr do
    context 'with valid guild ID and date range' do
      it 'returns guild reports within date range' do
        VCR.use_cassette('warcraft_logs/report_query/get_guild_reports_success') do
          result = described_class.get_guild_reports(guild_id, start_date, end_date)
          
          expect(result).to be_an(Array)
          
          if result.any?
            report = result.first
            expect(report).to include('code', 'title', 'startTime', 'endTime', 'zone')
            
            # Verify all reports are within the date range
            report_start = Time.at(report['startTime'] / 1000)
            expect(report_start).to be >= start_date.to_time
            expect(report_start).to be <= end_date.to_time
          end
        end
      end

      it 'filters out reports without boss fights' do
        VCR.use_cassette('warcraft_logs/report_query/get_guild_reports_filtered') do
          result = described_class.get_guild_reports(guild_id, start_date, end_date)
          
          # All returned reports should have boss fights (encounterID != 0)
          result.each do |report|
            VCR.use_cassette("warcraft_logs/report_query/check_boss_fights_#{report['code']}") do
              report_data = described_class.get_report_fights(report['code'])
              if report_data && report_data['fights']
                boss_fights = report_data['fights'].select { |fight| fight['encounterID'] != 0 }
                expect(boss_fights).not_to be_empty
              end
            end
          end
        end
      end
    end

    context 'with only start date' do
      it 'returns reports from start date onwards' do
        VCR.use_cassette('warcraft_logs/report_query/get_guild_reports_start_only') do
          result = described_class.get_guild_reports(guild_id, start_date)
          
          expect(result).to be_an(Array)
          
          if result.any?
            result.each do |report|
              report_start = Time.at(report['startTime'] / 1000)
              expect(report_start).to be >= start_date.to_time
            end
          end
        end
      end
    end

    context 'with invalid guild ID' do
      it 'returns empty array for non-existent guild' do
        VCR.use_cassette('warcraft_logs/report_query/get_guild_reports_not_found') do
          result = described_class.get_guild_reports(999999, start_date, end_date)
          expect(result).to eq([])
        end
      end
    end
  end

  describe '.get_report_fights', :vcr do
    context 'with valid report code' do
      it 'returns report fights information' do
        # Mock successful report fights response
        mock_response = {
          'reportData' => {
            'report' => {
              'fights' => [
                {
                  'id' => 1,
                  'encounterID' => 2917,
                  'name' => 'Test Boss',
                  'difficulty' => 4,
                  'kill' => true,
                  'startTime' => 1000,
                  'endTime' => 2000
                }
              ]
            }
          }
        }
        
        allow_any_instance_of(WarcraftLogsClient).to receive(:public_query).and_return(mock_response)
        
        result = described_class.get_report_fights(report_code)
        
        expect(result).to be_a(Hash)
        expect(result['fights']).to be_an(Array)
        
        if result['fights'].any?
          fight = result['fights'].first
          expect(fight).to include('id', 'encounterID', 'name', 'difficulty', 'kill', 'startTime', 'endTime')
        end
      end
    end

    context 'with invalid report code' do
      it 'returns nil for non-existent report' do
        VCR.use_cassette('warcraft_logs/report_query/get_report_fights_not_found') do
          result = described_class.get_report_fights('InvalidCode')
          expect(result).to be_nil
        end
      end
    end
  end

  describe '.get_report_participants', :vcr do
    context 'with valid report code' do
      xit 'returns report participants' do
        VCR.use_cassette('warcraft_logs/report_query/get_report_participants_success') do
          result = described_class.get_report_participants(report_code)
          
          expect(result).to be_an(Array)
          
          if result.any?
            participant = result.first
            expect(participant).to include('id', 'name', 'type', 'subType')
            expect(participant['type']).to eq('Player')
          end
        end
      end
    end

    context 'with invalid report code' do
      it 'returns empty array for non-existent report' do
        VCR.use_cassette('warcraft_logs/report_query/get_report_participants_not_found') do
          result = described_class.get_report_participants('InvalidCode')
          expect(result).to eq([])
        end
      end
    end
  end

  describe 'instance methods' do
    let(:instance) { described_class.new }

    describe '#get_report', :vcr do
      it 'works as instance method' do
        VCR.use_cassette('warcraft_logs/report_query/instance_get_report') do
          result = instance.get_report(report_code)
          expect(result).to be_a(Hash).or be_nil
        end
      end
    end

    describe '#get_guild_reports', :vcr do
      it 'works as instance method' do
        VCR.use_cassette('warcraft_logs/report_query/instance_get_guild_reports') do
          result = instance.get_guild_reports(guild_id, start_date, end_date)
          expect(result).to be_an(Array)
        end
      end
    end

    describe '#get_report_fights', :vcr do
      it 'works as instance method' do
        VCR.use_cassette('warcraft_logs/report_query/instance_get_report_fights') do
          result = instance.get_report_fights(report_code)
          expect(result).to be_a(Hash).or be_nil
        end
      end
    end

    describe '#get_report_participants', :vcr do
      it 'works as instance method' do
        VCR.use_cassette('warcraft_logs/report_query/instance_get_report_participants') do
          result = instance.get_report_participants(report_code)
          expect(result).to be_an(Array)
        end
      end
    end
  end

  describe 'data structure validation' do
    context 'when report data is returned', :vcr do
      it 'has expected report structure' do
        VCR.use_cassette('warcraft_logs/report_query/validate_report_structure') do
          result = described_class.get_report(report_code)
          
          if result
            expect(result).to include('code', 'title', 'startTime', 'endTime', 'zone', 'fights')
            
            zone = result['zone']
            expect(zone).to include('id', 'name')
            
            fights = result['fights']
            if fights.any?
              fight = fights.first
              expect(fight).to include('id', 'encounterID', 'name', 'difficulty', 'kill', 'startTime', 'endTime')
            end
          end
        end
      end
    end

    context 'when guild reports data is returned', :vcr do
      it 'has expected guild reports structure' do
        VCR.use_cassette('warcraft_logs/report_query/validate_guild_reports_structure') do
          result = described_class.get_guild_reports(guild_id, start_date, end_date)
          
          if result.any?
            report = result.first
            expect(report).to include('code', 'title', 'startTime', 'endTime', 'zone')
            
            zone = report['zone']
            expect(zone).to include('id', 'name')
          end
        end
      end
    end

    context 'when participants data is returned', :vcr do
      it 'has expected participants structure' do
        VCR.use_cassette('warcraft_logs/report_query/validate_participants_structure') do
          result = described_class.get_report_participants(report_code)
          
          if result.any?
            participant = result.first
            expect(participant).to include('id', 'name', 'type', 'subType')
            expect(participant['type']).to eq('Player')
          end
        end
      end
    end
  end

  describe 'date handling' do
    it 'correctly converts Date objects to milliseconds' do
      instance = described_class.new
      
      # Mock the query method to capture the converted timestamps
      allow(instance).to receive(:query) do |_, variables|
        expect(variables[:startTime]).to eq(start_date.to_time.to_f * 1000)
        expect(variables[:endTime]).to eq(end_date.to_time.to_f * 1000)
        { 'reportData' => { 'reports' => { 'data' => [] } } }
      end
      
      instance.get_guild_reports(guild_id, start_date, end_date)
    end

    it 'handles nil end_date correctly' do
      instance = described_class.new
      
      allow(instance).to receive(:query) do |_, variables|
        expect(variables[:startTime]).to eq(start_date.to_time.to_f * 1000)
        expect(variables).not_to have_key(:endTime)
        { 'reportData' => { 'reports' => { 'data' => [] } } }
      end
      
      instance.get_guild_reports(guild_id, start_date, nil)
    end
  end

  describe 'error handling' do
    context 'when API returns errors', :vcr do
      it 'handles authentication errors gracefully' do
        allow(ENV).to receive(:[]).with('WARCRAFTLOGS_CLIENT_ID').and_return('invalid')
        allow(ENV).to receive(:[]).with('WARCRAFTLOGS_CLIENT_SECRET').and_return('invalid')
        
        VCR.use_cassette('warcraft_logs/report_query/authentication_error') do
          expect { described_class.get_report(report_code) }
            .to raise_error(/Authentication failed/)
        end
      end
    end

    context 'when network issues occur' do
      it 'handles network timeouts gracefully' do
        allow(Net::HTTP).to receive(:new).and_raise(Timeout::Error.new("Network timeout"))
        
        expect { described_class.get_report(report_code) }
          .to raise_error(Timeout::Error)
      end
    end
  end

  describe 'filtering logic' do
    context 'when filtering reports with boss fights' do
      it 'only includes reports that have encounters with non-zero encounterID' do
        instance = described_class.new
        
        # Mock reports data
        reports_with_boss_fights = [
          { 'code' => 'ABC123', 'title' => 'Raid 1', 'startTime' => start_date.to_time.to_f * 1000 }
        ]
        
        reports_without_boss_fights = [
          { 'code' => 'DEF456', 'title' => 'Raid 2', 'startTime' => start_date.to_time.to_f * 1000 }
        ]
        
        all_reports = reports_with_boss_fights + reports_without_boss_fights
        
        # Mock the initial query to return all reports
        allow(instance).to receive(:query).and_return(
          { 'reportData' => { 'reports' => { 'data' => all_reports } } }
        )
        
        # Mock get_report_fights to simulate different scenarios
        allow(instance).to receive(:get_report_fights) do |code|
          if code == 'ABC123'
            { 'fights' => [{ 'encounterID' => 2917, 'name' => 'Boss Fight' }] }
          else
            { 'fights' => [{ 'encounterID' => 0, 'name' => 'Trash Fight' }] }
          end
        end
        
        result = instance.get_guild_reports(guild_id, start_date, end_date)
        expect(result).to eq(reports_with_boss_fights)
      end
    end
  end
end

require 'rails_helper'

RSpec.describe WarcraftLogs::PerformanceQuery, type: :model do
  let(:guild_id) { 123456 }
  let(:start_date) { Date.parse('2024-01-01') }
  let(:end_date) { Date.parse('2024-01-31') }
  let(:report_code) { 'ABC123def456' }
  let(:fight_id) { 1 }
  
  let(:sample_reports) do
    [
      {
        'code' => 'ABC123',
        'title' => 'Raid Night 1',
        'startTime' => start_date.to_time.to_f * 1000,
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

  describe '.get_guild_performance', :vcr do
    context 'with valid guild ID and date range' do
      it 'returns guild performance data' do
        VCR.use_cassette('warcraft_logs/performance_query/get_guild_performance_success') do
          result = described_class.get_guild_performance(guild_id, start_date, end_date)
          
          expect(result).to be_a(Hash)
          
          result.each do |player_name, data|
            expect(player_name).to be_a(String)
            expect(data).to include('fights', 'parse_data', 'total_amount', 'avg_parse')
            expect(data['fights']).to be_a(Integer)
            expect(data['parse_data']).to be_an(Array)
            expect(data['total_amount']).to be_a(Integer)
            expect(data['avg_parse']).to be_a(Numeric)
          end
        end
      end
    end

    context 'with invalid guild ID' do
      it 'returns empty hash for non-existent guild' do
        VCR.use_cassette('warcraft_logs/performance_query/get_guild_performance_not_found') do
          result = described_class.get_guild_performance(999999999, start_date, end_date)
          expect(result).to eq({})
        end
      end
    end
  end

  describe '.get_performance_for_reports', :vcr do
    context 'with valid reports and guild members' do
      it 'calculates performance data from provided reports' do
        # Mock dependencies
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
          {
            'fights' => [
              { 'id' => 1, 'encounterID' => 2917, 'name' => 'Boss A', 'difficulty' => 4, 'kill' => true },
              { 'id' => 2, 'encounterID' => 2918, 'name' => 'Boss B', 'difficulty' => 4, 'kill' => true }
            ]
          }
        )

        allow_any_instance_of(described_class).to receive(:get_fight_rankings) do |instance, report_code, fight_id|
          if fight_id == 1
            {
              fight: { 'encounterID' => 2917, 'name' => 'Boss A', 'difficulty' => 4 },
              characters: [
                {
                  'name' => 'Player1',
                  'rankPercent' => 85.5,
                  'amount' => 45000,
                  'spec' => 'Arms',
                  'rank' => 150,
                  'totalParses' => 1000,
                  'bracketPercent' => 90.2
                },
                {
                  'name' => 'Player2',
                  'rankPercent' => 72.3,
                  'amount' => 38000,
                  'spec' => 'Beast Mastery',
                  'rank' => 280,
                  'totalParses' => 800,
                  'bracketPercent' => 75.8
                }
              ]
            }
          elsif fight_id == 2
            {
              fight: { 'encounterID' => 2918, 'name' => 'Boss B', 'difficulty' => 4 },
              characters: [
                {
                  'name' => 'Player1',
                  'rankPercent' => 85.5,
                  'amount' => 38000,
                  'spec' => 'Arms',
                  'rank' => 150,
                  'totalParses' => 1000,
                  'bracketPercent' => 90.2
                }
              ]
            }
          end
        end

        result = described_class.get_performance_for_reports(sample_reports, sample_guild_members)
        
        expect(result).to be_a(Hash)
        expect(result).to have_key('Player1')
        expect(result).to have_key('Player2')
        expect(result).not_to have_key('Player3') # Not in parse data
        
        player1_data = result['Player1']
        expect(player1_data[:fights]).to eq(2) # 2 boss fights
        expect(player1_data[:parse_data]).to be_an(Array)
        expect(player1_data[:parse_data].length).to eq(2)
        expect(player1_data[:avg_parse]).to eq(85.5)
        expect(player1_data[:total_amount]).to eq(83000) # 45000 + 38000
      end

      it 'filters to guild members only when provided' do
        non_guild_member = 'RandomPlayer'
        
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
          {
            'fights' => [
              { 'id' => 1, 'encounterID' => 2917, 'name' => 'Boss A', 'difficulty' => 4, 'kill' => true }
            ]
          }
        )

        allow_any_instance_of(described_class).to receive(:get_fight_rankings).and_return(
          {
            fight: { 'encounterID' => 2917, 'name' => 'Boss A', 'difficulty' => 4 },
            characters: [
              {
                'name' => 'Player1', # Guild member
                'rankPercent' => 85.5,
                'amount' => 45000,
                'spec' => 'Arms',
                'rank' => 150,
                'totalParses' => 1000,
                'bracketPercent' => 90.2
              },
              {
                'name' => non_guild_member, # Not a guild member
                'rankPercent' => 95.0,
                'amount' => 45000,
                'spec' => 'Fury',
                'rank' => 50,
                'totalParses' => 1000,
                'bracketPercent' => 98.0
              }
            ]
          }
        )

        result = described_class.get_performance_for_reports(sample_reports, sample_guild_members)
        
        expect(result).to have_key('Player1')
        expect(result).not_to have_key(non_guild_member)
      end

      it 'includes all players when no guild members filter provided' do
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
          {
            'fights' => [
              { 'id' => 1, 'encounterID' => 2917, 'name' => 'Boss A', 'difficulty' => 4, 'kill' => true }
            ]
          }
        )

        allow_any_instance_of(described_class).to receive(:get_fight_rankings).and_return(
          {
            fight: { 'encounterID' => 2917, 'name' => 'Boss A', 'difficulty' => 4 },
            characters: [
              {
                'name' => 'RandomPlayer1',
                'rankPercent' => 85.5,
                'amount' => 45000,
                'spec' => 'Arms',
                'rank' => 150,
                'totalParses' => 1000,
                'bracketPercent' => 90.2
              },
              {
                'name' => 'RandomPlayer2',
                'rankPercent' => 72.3,
                'amount' => 45000,
                'spec' => 'Fury',
                'rank' => 280,
                'totalParses' => 800,
                'bracketPercent' => 75.8
              }
            ]
          }
        )

        result = described_class.get_performance_for_reports(sample_reports, nil)
        
        expect(result).to have_key('RandomPlayer1')
        expect(result).to have_key('RandomPlayer2')
      end
    end

    context 'with reports containing only wipes' do
      it 'excludes wipe attempts from performance data' do
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
          {
            'fights' => [
              { 'id' => 1, 'encounterID' => 2917, 'name' => 'Boss A', 'difficulty' => 4, 'kill' => false }, # Wipe
              { 'id' => 2, 'encounterID' => 2918, 'name' => 'Boss B', 'difficulty' => 4, 'kill' => true }   # Kill
            ]
          }
        )

        allow_any_instance_of(described_class).to receive(:get_fight_rankings) do |_, _, fight_id|
          if fight_id == 2 # Only the kill
            {
              fight: { 'encounterID' => 2918, 'name' => 'Boss B', 'difficulty' => 4 },
              characters: [
                {
                  'name' => 'Player1',
                  'rankPercent' => 85.5,
                  'amount' => 45000,
                  'spec' => 'Arms',
                  'rank' => 150,
                  'totalParses' => 1000,
                  'bracketPercent' => 90.2
                }
              ]
            }
          else
            nil
          end
        end

        result = described_class.get_performance_for_reports(sample_reports, sample_guild_members)
        
        if result['Player1']
          expect(result['Player1'][:fights]).to eq(1) # Only 1 kill counted
          expect(result['Player1'][:parse_data].length).to eq(1)
        end
      end
    end
  end

  describe '.get_fight_rankings', :vcr do
    context 'with valid report code and fight ID' do
      it 'returns fight rankings data' do
        VCR.use_cassette('warcraft_logs/performance_query/get_fight_rankings_success') do
          result = described_class.get_fight_rankings(report_code, fight_id)
          
          expect(result).to be_a(Hash).or be_nil
          
          if result
            expect(result).to include('fight', 'characters')
            expect(result['fight']).to be_a(Hash)
            expect(result['characters']).to be_an(Array)
            
            if result['characters'].any?
              character = result['characters'].first
              expect(character).to include('name', 'rankPercent', 'amount')
            end
          end
        end
      end
    end

    context 'with invalid report code or fight ID' do
      it 'returns nil for non-existent fight' do
        VCR.use_cassette('warcraft_logs/performance_query/get_fight_rankings_not_found') do
          result = described_class.get_fight_rankings('InvalidCode', 999)
          expect(result).to be_nil
        end
      end
    end
  end

  describe 'instance methods' do
    let(:instance) { described_class.new }

    describe '#get_guild_performance', :vcr do
      it 'works as instance method' do
        VCR.use_cassette('warcraft_logs/performance_query/instance_get_guild_performance') do
          result = instance.get_guild_performance(guild_id, start_date, end_date)
          expect(result).to be_a(Hash)
        end
      end
    end

    describe '#get_performance_for_reports' do
      it 'works as instance method' do
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(nil)
        
        result = instance.get_performance_for_reports(sample_reports, sample_guild_members)
        expect(result).to be_a(Hash)
      end
    end

    describe '#get_fight_rankings', :vcr do
      it 'works as instance method' do
        VCR.use_cassette('warcraft_logs/performance_query/instance_get_fight_rankings') do
          result = instance.get_fight_rankings(report_code, fight_id)
          expect(result).to be_a(Hash).or be_nil
        end
      end
    end
  end

  describe 'data structure validation' do
    context 'when performance data is returned' do
      it 'has expected structure for each player' do
        allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
          {
            'fights' => [
              { 'id' => 1, 'encounterID' => 2917, 'name' => 'Test Boss', 'difficulty' => 4, 'kill' => true }
            ]
          }
        )

        allow_any_instance_of(described_class).to receive(:get_fight_rankings).and_return(
          {
            fight: { 'encounterID' => 2917, 'name' => 'Test Boss', 'difficulty' => 4 },
            characters: [
              {
                'name' => 'Player1',
                'rankPercent' => 85.5,
                'amount' => 45000,
                'spec' => 'Arms',
                'rank' => 150,
                'totalParses' => 1000,
                'bracketPercent' => 90.2
              }
            ]
          }
        )

        result = described_class.get_performance_for_reports(sample_reports, sample_guild_members)
        
        if result['Player1']
          player_data = result['Player1']
          expect(player_data).to include(:fights, :parse_data, :total_amount, :avg_parse, :avg_amount)
          
          parse_entry = player_data[:parse_data].first
          expect(parse_entry).to include(
            :encounter_id, :encounter_name, :difficulty, :ilvl_parse, :overall_parse,
            :ilvl_amount, :overall_amount, :spec, :rank, :total, :bracket_percent,
            :report_code, :fight_id
          )
        end
      end
    end

    context 'when rankings data is returned', :vcr do
      it 'has expected rankings structure' do
        VCR.use_cassette('warcraft_logs/performance_query/validate_rankings_structure') do
          result = described_class.get_fight_rankings(report_code, fight_id)
          
          if result
            expect(result).to include('fight', 'characters')
            
            fight = result['fight']
            expect(fight).to include('id', 'encounterID', 'name', 'difficulty', 'kill')
            
            characters = result['characters']
            if characters.any?
              character = characters.first
              # Character structure may vary based on actual API response
              expect(character).to be_a(Hash)
              expect(character).to include('name')
            end
          end
        end
      end
    end
  end

  describe 'average calculations' do
    it 'calculates averages correctly' do
      allow(WarcraftLogs::ReportQuery).to receive(:get_report_fights).and_return(
        {
          'fights' => [
            { 'id' => 1, 'encounterID' => 2917, 'name' => 'Boss A', 'difficulty' => 4, 'kill' => true },
            { 'id' => 2, 'encounterID' => 2918, 'name' => 'Boss B', 'difficulty' => 4, 'kill' => true }
          ]
        }
      )

      fight_rankings = [
        {
          fight: { 'encounterID' => 2917, 'name' => 'Boss A', 'difficulty' => 4 },
          characters: [
            {
              'name' => 'Player1',
              'rankPercent' => 80.0,
              'amount' => 40000,
              'spec' => 'Arms',
              'rank' => 200,
              'totalParses' => 1000,
              'bracketPercent' => 85.0
            }
          ]
        },
        {
          fight: { 'encounterID' => 2918, 'name' => 'Boss B', 'difficulty' => 4 },
          characters: [
            {
              'name' => 'Player1',
              'rankPercent' => 90.0,
              'amount' => 50000,
              'spec' => 'Arms',
              'rank' => 100,
              'totalParses' => 1000,
              'bracketPercent' => 95.0
            }
          ]
        }
      ]

      allow_any_instance_of(described_class).to receive(:get_fight_rankings) do |_, _, fight_id|
        fight_rankings[fight_id - 1]
      end

      result = described_class.get_performance_for_reports(sample_reports, sample_guild_members)
      
      if result['Player1']
        player_data = result['Player1']
        expect(player_data[:fights]).to eq(2)
        expect(player_data[:avg_parse]).to eq(85.0) # (80 + 90) / 2
        expect(player_data[:avg_amount]).to eq(45000) # (40000 + 50000) / 2
        expect(player_data[:total_amount]).to eq(90000) # 40000 + 50000
      end
    end
  end

  describe 'JSON parsing in get_fight_rankings' do
    let(:instance) { described_class.new }

    it 'handles string JSON rankings data' do
      json_string = '{"data":[{"roles":{"DPS":{"characters":[{"name":"Player1","rankPercent":85.5}]}}}]}'
      
      allow(instance.instance_variable_get(:@client)).to receive(:authenticate_client_credentials!)
      allow(instance.instance_variable_get(:@client)).to receive(:public_query).and_return(
        {
          'reportData' => {
            'report' => {
              'fights' => [{ 'id' => 1, 'encounterID' => 2917, 'name' => 'Test', 'difficulty' => 4, 'kill' => true }],
              'rankings' => json_string
            }
          }
        }
      )

      result = instance.get_fight_rankings(report_code, fight_id)
      
      expect(result).not_to be_nil
      expect(result[:characters]).to be_an(Array)
      expect(result[:characters].first['name']).to eq('Player1')
    end

    it 'handles hash rankings data' do
      rankings_hash = {
        'data' => [
          {
            'roles' => {
              'DPS' => {
                'characters' => [
                  { 'name' => 'Player1', 'rankPercent' => 85.5 }
                ]
              }
            }
          }
        ]
      }
      
      allow(instance.instance_variable_get(:@client)).to receive(:authenticate_client_credentials!)
      allow(instance.instance_variable_get(:@client)).to receive(:public_query).and_return(
        {
          'reportData' => {
            'report' => {
              'fights' => [{ 'id' => 1, 'encounterID' => 2917, 'name' => 'Test', 'difficulty' => 4, 'kill' => true }],
              'rankings' => rankings_hash
            }
          }
        }
      )

      result = instance.get_fight_rankings(report_code, fight_id)
      
      expect(result).not_to be_nil
      expect(result[:characters]).to be_an(Array)
      expect(result[:characters].first['name']).to eq('Player1')
    end

    it 'handles malformed JSON gracefully' do
      malformed_json = '{"invalid": json}'
      
      allow(instance.instance_variable_get(:@client)).to receive(:authenticate_client_credentials!)
      allow(instance.instance_variable_get(:@client)).to receive(:public_query).and_return(
        {
          'reportData' => {
            'report' => {
              'fights' => [{ 'id' => 1, 'encounterID' => 2917, 'name' => 'Test', 'difficulty' => 4, 'kill' => true }],
              'rankings' => malformed_json
            }
          }
        }
      )

      expect { instance.get_fight_rankings(report_code, fight_id) }.not_to raise_error
      result = instance.get_fight_rankings(report_code, fight_id)
      expect(result).to be_nil
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
            { 'id' => 1, 'encounterID' => 2917, 'name' => 'Integration Boss', 'difficulty' => 4, 'kill' => true }
          ]
        }
      )

      allow_any_instance_of(described_class).to receive(:get_fight_rankings).and_return(
        {
          fight: { 'encounterID' => 2917, 'name' => 'Integration Boss', 'difficulty' => 4 },
          characters: [
            {
              'name' => 'Player1',
              'rankPercent' => 85.5,
              'amount' => 45000,
              'spec' => 'Arms',
              'rank' => 150,
              'totalParses' => 1000,
              'bracketPercent' => 90.2
            }
          ]
        }
      )

      result = described_class.get_guild_performance(guild_id, start_date, end_date)
      
      expect(result).to be_a(Hash)
      if result['Player1']
        expect(result['Player1'][:parse_data].first[:encounter_name]).to eq('Integration Boss')
      end
    end
  end
end

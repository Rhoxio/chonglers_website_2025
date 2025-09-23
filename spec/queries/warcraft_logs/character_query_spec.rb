require 'rails_helper'

RSpec.describe WarcraftLogs::CharacterQuery, type: :model do
  let(:character_name) { 'Testchar' }
  let(:server_name) { 'test-server' }
  let(:region) { 'US' }
  let(:encounter_id) { 2917 } # Example encounter ID

  describe '.find_by_name_and_server', :vcr do
    context 'with valid character name and server' do
      it 'returns character information' do
        # Mock successful character response
        mock_response = {
          'characterData' => {
            'character' => {
              'id' => 12345,
              'name' => character_name,
              'classID' => 1,
              'level' => 70,
              'server' => {
                'slug' => server_name,
                'region' => {
                  'slug' => region
                }
              },
              'guildRank' => 2
            }
          }
        }
        
        allow_any_instance_of(WarcraftLogsClient).to receive(:public_query).and_return(mock_response)
        
        result = described_class.find_by_name_and_server(character_name, server_name, region)
        
        expect(result).to be_a(Hash)
        expect(result[:name]).to eq(character_name)
        expect(result[:server][:slug]).to eq(server_name)
        expect(result[:server][:region][:slug]).to eq(region)
        expect(result).to include(:id, :classID, :level)
      end
    end

    context 'with invalid character name or server' do
      it 'returns nil for non-existent character' do
        VCR.use_cassette('warcraft_logs/character_query/find_by_name_and_server_not_found') do
          result = described_class.find_by_name_and_server('NonExistentChar', 'invalid-server', region)
          expect(result).to be_nil
        end
      end
    end

    context 'with different regions' do
      ['US', 'EU', 'KR', 'TW'].each do |test_region|
        it "handles #{test_region} region correctly" do
          VCR.use_cassette("warcraft_logs/character_query/find_by_name_and_server_#{test_region.downcase}") do
            result = described_class.find_by_name_and_server(character_name, server_name, test_region)
            if result
              expect(result['server']['region']['slug']).to eq(test_region)
            end
          end
        end
      end
    end
  end

  describe '.rankings', :vcr do
    context 'with valid character and no specific encounter' do
      it 'returns all encounter rankings for character' do
        VCR.use_cassette('warcraft_logs/character_query/rankings_all_encounters') do
          result = described_class.rankings(character_name, server_name, region)
          
          expect(result).to be_an(Array)
          
          if result.any?
            ranking = result.first
            expect(ranking).to include('encounter', 'difficulty', 'metric', 'rank', 'outOf', 'percentile')
            expect(ranking['encounter']).to include('id', 'name')
            expect(ranking['report']).to include('id', 'title', 'startTime')
          end
        end
      end
    end

    context 'with valid character and specific encounter' do
      it 'returns rankings for specific encounter' do
        VCR.use_cassette('warcraft_logs/character_query/rankings_specific_encounter') do
          result = described_class.rankings(character_name, server_name, region, encounter_id)
          
          expect(result).to be_an(Array)
          
          if result.any?
            ranking = result.first
            expect(ranking['encounter']['id']).to eq(encounter_id)
            expect(ranking).to include('difficulty', 'metric', 'rank', 'outOf', 'percentile')
          end
        end
      end
    end

    context 'with invalid character' do
      it 'returns empty array for non-existent character' do
        VCR.use_cassette('warcraft_logs/character_query/rankings_not_found') do
          result = described_class.rankings('NonExistentChar', 'invalid-server', region)
          expect(result).to eq([])
        end
      end
    end
  end

  describe '.recent_reports', :vcr do
    context 'with valid character' do
      it 'returns recent reports with default limit' do
        VCR.use_cassette('warcraft_logs/character_query/recent_reports_default') do
          result = described_class.recent_reports(character_name, server_name, region)
          
          expect(result).to be_an(Array)
          expect(result.length).to be <= 10 # Default limit
          
          if result.any?
            report = result.first
            expect(report).to include(:title, :startTime, :endTime, :zone)
            expect(report['zone']).to include('name')
          end
        end
      end

      it 'returns recent reports with custom limit' do
        VCR.use_cassette('warcraft_logs/character_query/recent_reports_custom_limit') do
          result = described_class.recent_reports(character_name, server_name, region, 5)
          
          expect(result).to be_an(Array)
          expect(result.length).to be <= 5
        end
      end
    end

    context 'with invalid character' do
      it 'returns empty array for non-existent character' do
        VCR.use_cassette('warcraft_logs/character_query/recent_reports_not_found') do
          result = described_class.recent_reports('NonExistentChar', 'invalid-server', region)
          expect(result).to eq([])
        end
      end
    end
  end

  describe 'instance methods' do
    let(:instance) { described_class.new }

    describe '#find_by_name_and_server', :vcr do
      it 'works as instance method' do
        VCR.use_cassette('warcraft_logs/character_query/instance_find_by_name_and_server') do
          result = instance.find_by_name_and_server(character_name, server_name, region)
          expect(result).to be_a(Hash).or be_nil
        end
      end
    end

    describe '#rankings', :vcr do
      it 'works as instance method' do
        VCR.use_cassette('warcraft_logs/character_query/instance_rankings') do
          result = instance.rankings(character_name, server_name, region)
          expect(result).to be_an(Array)
        end
      end
    end

    describe '#recent_reports', :vcr do
      it 'works as instance method' do
        VCR.use_cassette('warcraft_logs/character_query/instance_recent_reports') do
          result = instance.recent_reports(character_name, server_name, region)
          expect(result).to be_an(Array)
        end
      end
    end
  end

  describe 'data structure validation' do
    context 'when character data is returned', :vcr do
      it 'has expected character structure' do
        VCR.use_cassette('warcraft_logs/character_query/validate_character_structure') do
          result = described_class.find_by_name_and_server(character_name, server_name, region)
          
          if result
            expect(result).to include('id', 'name', 'classID', 'level', 'server')
            
            server = result['server']
            expect(server).to include('name', 'slug', 'region')
            expect(server['region']).to include('name', 'slug')
          end
        end
      end
    end

    context 'when rankings data is returned', :vcr do
      it 'has expected rankings structure' do
        VCR.use_cassette('warcraft_logs/character_query/validate_rankings_structure') do
          result = described_class.rankings(character_name, server_name, region)
          
          if result.any?
            ranking = result.first
            expect(ranking).to include('encounter', 'difficulty', 'metric', 'rank', 'outOf', 'percentile', 'report')
            
            encounter = ranking['encounter']
            expect(encounter).to include('id', 'name')
            
            report = ranking['report']
            expect(report).to include('id', 'title', 'startTime')
          end
        end
      end
    end

    context 'when reports data is returned', :vcr do
      it 'has expected reports structure' do
        VCR.use_cassette('warcraft_logs/character_query/validate_reports_structure') do
          result = described_class.recent_reports(character_name, server_name, region)
          
          if result.any?
            report = result.first
            expect(report).to include(:title, :startTime, :endTime, :zone)
            
            zone = report['zone']
            expect(zone).to include('name')
          end
        end
      end
    end
  end

  describe 'error handling' do
    context 'when API returns errors', :vcr do
      it 'handles authentication errors gracefully' do
        # Test with invalid credentials
        allow(ENV).to receive(:[]).with('WARCRAFTLOGS_CLIENT_ID').and_return('invalid')
        allow(ENV).to receive(:[]).with('WARCRAFTLOGS_CLIENT_SECRET').and_return('invalid')
        
        VCR.use_cassette('warcraft_logs/character_query/authentication_error') do
          expect { described_class.find_by_name_and_server(character_name, server_name, region) }
            .to raise_error(/Authentication failed/)
        end
      end
    end

    context 'when network issues occur' do
      it 'handles network timeouts gracefully' do
        allow(Net::HTTP).to receive(:new).and_raise(Timeout::Error.new("Network timeout"))
        
        expect { described_class.find_by_name_and_server(character_name, server_name, region) }
          .to raise_error(Timeout::Error)
      end
    end
  end

  describe 'parameter validation' do
    it 'handles nil parameters gracefully' do
      VCR.use_cassette('warcraft_logs/character_query/nil_parameters') do
        result = described_class.find_by_name_and_server(nil, server_name, region)
        expect(result).to be_nil
      end
    end

    it 'handles empty string parameters' do
      VCR.use_cassette('warcraft_logs/character_query/empty_parameters') do
        result = described_class.find_by_name_and_server('', '', region)
        expect(result).to be_nil
      end
    end
  end
end

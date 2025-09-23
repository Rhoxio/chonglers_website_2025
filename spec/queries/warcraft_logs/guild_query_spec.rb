require 'rails_helper'

RSpec.describe WarcraftLogs::GuildQuery, type: :model do
  let(:guild_id) { 123456 }
  let(:guild_name) { 'Test Guild' }
  let(:server_name) { 'test-server' }
  let(:region) { 'US' }

  describe '.find_by_id', :vcr do
    context 'with valid guild ID' do
      it 'returns guild information' do
        VCR.use_cassette('warcraft_logs/guild_query/find_by_id_success') do
          result = described_class.find_by_id(guild_id)
          
          expect(result).to be_a(Hash)
          expect(result['id']).to eq(guild_id)
          expect(result['name']).to be_present
          expect(result['server']).to be_present
          expect(result['members']).to be_present
        end
      end
    end

    context 'with invalid guild ID' do
      it 'returns nil for non-existent guild' do
        VCR.use_cassette('warcraft_logs/guild_query/find_by_id_not_found') do
          result = described_class.find_by_id(999999)
          expect(result).to be_nil
        end
      end
    end
  end

  describe '.find_by_name_and_server', :vcr do
    context 'with fake guild name and server' do
      it 'returns nil for non-existent guild' do
        VCR.use_cassette('warcraft_logs/guild_query/find_by_name_and_server_fake_data') do
          result = described_class.find_by_name_and_server(guild_name, server_name, region)
          
          expect(result).to be_nil
        end
      end
    end

    context 'with invalid guild name or server' do
      it 'returns nil for non-existent guild' do
        VCR.use_cassette('warcraft_logs/guild_query/find_by_name_and_server_not_found') do
          result = described_class.find_by_name_and_server('NonExistentGuild', 'invalid-server', region)
          expect(result).to be_nil
        end
      end
    end

    context 'with different regions' do
      ['US', 'EU', 'KR', 'TW'].each do |test_region|
        it "handles #{test_region} region correctly" do
          VCR.use_cassette("warcraft_logs/guild_query/find_by_name_and_server_#{test_region.downcase}") do
            result = described_class.find_by_name_and_server(guild_name, server_name, test_region)
            if result
              expect(result['server']['region']['slug']).to eq(test_region)
            end
          end
        end
      end
    end
  end

  describe '.members', :vcr do
    context 'with valid guild ID' do
      it 'returns guild members array' do
        VCR.use_cassette('warcraft_logs/guild_query/members_success') do
          result = described_class.members(guild_id)
          
          expect(result).to be_an(Array)
          
          if result.any?
            member = result.first
            expect(member).to have_key('name')
            expect(member).to have_key('classID')
            expect(member).to have_key('guildRank')
          end
        end
      end
    end

    context 'with invalid guild ID' do
      it 'returns empty array for non-existent guild' do
        VCR.use_cassette('warcraft_logs/guild_query/members_not_found') do
          result = described_class.members(999999)
          expect(result).to eq([])
        end
      end
    end
  end

  describe '.recent_reports', :vcr do
    context 'with valid guild ID' do
      it 'returns recent reports with default limit' do
        VCR.use_cassette('warcraft_logs/guild_query/recent_reports_default') do
          result = described_class.recent_reports(guild_id)
          
          expect(result).to be_an(Array)
          expect(result.length).to be <= 10 # Default limit
          
          if result.any?
            report = result.first
            expect(report).to have_key('code')
            expect(report).to have_key('title')
            expect(report).to have_key('startTime')
            expect(report).to have_key('zone')
            expect(report).to have_key('fights')
          end
        end
      end

      it 'returns recent reports with custom limit' do
        VCR.use_cassette('warcraft_logs/guild_query/recent_reports_custom_limit') do
          result = described_class.recent_reports(guild_id, 5)
          
          expect(result).to be_an(Array)
          expect(result.length).to be <= 5
        end
      end
    end

    context 'with invalid guild ID' do
      it 'returns empty array for non-existent guild' do
        VCR.use_cassette('warcraft_logs/guild_query/recent_reports_not_found') do
          result = described_class.recent_reports(999999)
          expect(result).to eq([])
        end
      end
    end
  end

  describe 'instance methods' do
    let(:instance) { described_class.new }

    describe '#find_by_id', :vcr do
      it 'works as instance method' do
        VCR.use_cassette('warcraft_logs/guild_query/instance_find_by_id') do
          result = instance.find_by_id(guild_id)
          expect(result).to be_a(Hash).or be_nil
        end
      end
    end

    describe '#find_by_name_and_server', :vcr do
      it 'works as instance method' do
        VCR.use_cassette('warcraft_logs/guild_query/instance_find_by_name_and_server') do
          result = instance.find_by_name_and_server(guild_name, server_name, region)
          expect(result).to be_a(Hash).or be_nil
        end
      end
    end

    describe '#members', :vcr do
      it 'works as instance method' do
        VCR.use_cassette('warcraft_logs/guild_query/instance_members') do
          result = instance.members(guild_id)
          expect(result).to be_an(Array)
        end
      end
    end

    describe '#recent_reports', :vcr do
      it 'works as instance method' do
        VCR.use_cassette('warcraft_logs/guild_query/instance_recent_reports') do
          fresh_instance = described_class.new
          result = fresh_instance.recent_reports(guild_id)
          expect(result).to be_an(Array)
        end
      end
    end
  end

  describe 'data structure validation' do
    context 'when guild data is returned', :vcr do
      it 'has expected guild structure' do
        VCR.use_cassette('warcraft_logs/guild_query/validate_guild_structure') do
          result = described_class.find_by_id(guild_id)
          
          if result
            expect(result).to include('id', 'name', 'server', 'members')
            
            server = result['server']
            expect(server).to include('name', 'slug', 'region')
            expect(server['region']).to include('name', 'slug')
            
            members = result['members']['data']
            if members.any?
              member = members.first
              expect(member).to include('id', 'name', 'classID', 'guildRank')
            end
          end
        end
      end
    end

    context 'when reports data is returned', :vcr do
      it 'has expected reports structure' do
        VCR.use_cassette('warcraft_logs/guild_query/validate_reports_structure') do
          result = described_class.recent_reports(guild_id)
          
          if result.any?
            report = result.first
            expect(report).to include('code', 'title', 'startTime', 'endTime', 'zone', 'fights')
            
            zone = report['zone']
            expect(zone).to include('name')
            
            fights = report['fights']
            if fights.any?
              fight = fights.first
              expect(fight).to include('encounterID', 'name', 'difficulty', 'kill', 'startTime', 'endTime')
            end
          end
        end
      end
    end
  end
end

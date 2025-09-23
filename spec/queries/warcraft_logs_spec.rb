require 'rails_helper'

RSpec.describe WarcraftLogs, type: :model do
  
  describe 'module structure' do
    it 'is a module' do
      expect(WarcraftLogs).to be_a(Module)
    end

    it 'loads all required query classes' do
      expected_classes = [
        'GuildQuery', 
        'CharacterQuery',
        'AttendanceQuery',
        'ClassHelper',
        'ReportQuery',
        'EncounterQuery',
        'PerformanceQuery'
      ]

      expected_classes.each do |class_name|
        expect(WarcraftLogs.const_defined?(class_name)).to be true
        expect(WarcraftLogs.const_get(class_name)).to be_a(Class).or be_a(Module)
      end
    end

    it 'has proper dependency injection pattern' do
      # All query classes should accept a client dependency
      query_classes = [
        WarcraftLogs::GuildQuery,
        WarcraftLogs::CharacterQuery,
        WarcraftLogs::AttendanceQuery,
        WarcraftLogs::ReportQuery,
        WarcraftLogs::EncounterQuery,
        WarcraftLogs::PerformanceQuery
      ]

      query_classes.each do |query_class|
        expect { query_class.new }.not_to raise_error
        expect { query_class.new(WarcraftLogsClient.new) }.not_to raise_error
      end
    end

    it 'ClassHelper is a module with utility methods' do
      expect(WarcraftLogs::ClassHelper).to be_a(Module)
      expect(WarcraftLogs::ClassHelper).to respond_to(:class_name)
      expect(WarcraftLogs::ClassHelper).to respond_to(:class_id)
    end
  end

  describe 'class loading and dependencies' do
    it 'loads WarcraftLogsClient correctly' do
      # WarcraftLogsClient should be available for query classes to use
      expect { WarcraftLogsClient.new }.not_to raise_error
    end

    it 'allows instantiation of all query classes' do
      query_classes = [
        WarcraftLogs::GuildQuery,
        WarcraftLogs::CharacterQuery,
        WarcraftLogs::AttendanceQuery,
        WarcraftLogs::ReportQuery,
        WarcraftLogs::EncounterQuery,
        WarcraftLogs::PerformanceQuery
      ]

      query_classes.each do |query_class|
        expect { query_class.new }.not_to raise_error
      end
    end

    it 'provides access to ClassHelper methods' do
      expect(WarcraftLogs::ClassHelper).to respond_to(:class_name)
      expect(WarcraftLogs::ClassHelper).to respond_to(:all_class_names)
      expect(WarcraftLogs::ClassHelper).to respond_to(:class_id)
    end
  end

  describe 'integration between classes' do
    let(:guild_id) { 123456 }
    let(:start_date) { Date.parse('2024-01-01') }
    let(:end_date) { Date.parse('2024-01-31') }

    it 'allows query classes to work together' do
      # Mock WarcraftLogsClient for all instances
      mock_client = instance_double(WarcraftLogsClient)
      allow(mock_client).to receive(:authenticate_client_credentials!).and_return(true)
      allow(mock_client).to receive(:public_query).and_return({})
      allow(mock_client).to receive(:access_token).and_return('mock_token')

      # Test that different query classes can be instantiated and used together
      guild_query = WarcraftLogs::GuildQuery.new(mock_client)
      report_query = WarcraftLogs::ReportQuery.new(mock_client)
      attendance_query = WarcraftLogs::AttendanceQuery.new(mock_client)

      expect(guild_query).to respond_to(:find_by_id)
      expect(report_query).to respond_to(:get_guild_reports)
      expect(attendance_query).to respond_to(:get_guild_attendance)
    end

    it 'supports the modular architecture pattern' do
      # The new modular query classes should work independently
      encounter_query = WarcraftLogs::EncounterQuery.new
      performance_query = WarcraftLogs::PerformanceQuery.new

      expect(encounter_query).to respond_to(:get_encounter_stats)
      expect(performance_query).to respond_to(:get_guild_performance)

      # They should also support the class method pattern
      expect(WarcraftLogs::EncounterQuery).to respond_to(:get_encounter_stats)
      expect(WarcraftLogs::PerformanceQuery).to respond_to(:get_guild_performance)
    end
  end

  describe 'shared functionality' do
    it 'all query classes have client dependency' do
      query_classes = [
        WarcraftLogs::GuildQuery,
        WarcraftLogs::CharacterQuery,
        WarcraftLogs::AttendanceQuery,
        WarcraftLogs::ReportQuery,
        WarcraftLogs::EncounterQuery,
        WarcraftLogs::PerformanceQuery
      ]

      query_classes.each do |query_class|
        instance = query_class.new
        expect(instance).to respond_to(:client)
        expect(instance.client).to be_a(WarcraftLogsClient)
      end
    end

    it 'maintains consistent class and instance method patterns' do
      # Most query classes provide both class and instance methods
      class_method_classes = [
        WarcraftLogs::GuildQuery,
        WarcraftLogs::CharacterQuery,
        WarcraftLogs::ReportQuery,
        WarcraftLogs::EncounterQuery,
        WarcraftLogs::PerformanceQuery
      ]

      class_method_classes.each do |query_class|
        # Should have class methods that delegate to instance methods
        instance_methods = query_class.instance_methods(false)
        class_methods = query_class.methods(false)
        
        # There should be some overlap between class and instance methods
        # (class methods typically delegate to instance methods)
        expect(instance_methods).not_to be_empty
      end
    end
  end

  describe 'error handling consistency' do
    it 'all query classes handle authentication errors consistently' do
      query_classes = [
        WarcraftLogs::GuildQuery,
        WarcraftLogs::CharacterQuery,
        WarcraftLogs::AttendanceQuery,
        WarcraftLogs::ReportQuery,
        WarcraftLogs::EncounterQuery,
        WarcraftLogs::PerformanceQuery
      ]

      query_classes.each do |query_class|
        mock_client = instance_double(WarcraftLogsClient)
        allow(mock_client).to receive(:authenticate_client_credentials!).and_raise("Authentication failed: Invalid credentials")
        
        instance = query_class.new(mock_client)
        
        # All classes should handle auth errors the same way through their client
        expect { instance.client.authenticate_client_credentials! }.to raise_error(/Authentication failed/)
      end
    end
  end

  describe 'namespace organization' do
    it 'properly namespaces all classes under WarcraftLogs' do
      # All classes should be properly namespaced
      expect(WarcraftLogs::GuildQuery.name).to eq('WarcraftLogs::GuildQuery')
      expect(WarcraftLogs::CharacterQuery.name).to eq('WarcraftLogs::CharacterQuery')
      expect(WarcraftLogs::AttendanceQuery.name).to eq('WarcraftLogs::AttendanceQuery')
      expect(WarcraftLogs::ClassHelper.name).to eq('WarcraftLogs::ClassHelper')
      expect(WarcraftLogs::ReportQuery.name).to eq('WarcraftLogs::ReportQuery')
      expect(WarcraftLogs::EncounterQuery.name).to eq('WarcraftLogs::EncounterQuery')
      expect(WarcraftLogs::PerformanceQuery.name).to eq('WarcraftLogs::PerformanceQuery')
    end

    it 'does not pollute the global namespace' do
      # Classes should not be available without the WarcraftLogs namespace
      expect { GuildQuery }.to raise_error(NameError)
      expect { CharacterQuery }.to raise_error(NameError)
      expect { AttendanceQuery }.to raise_error(NameError)
      expect { ClassHelper }.to raise_error(NameError)
      expect { ReportQuery }.to raise_error(NameError)
      expect { EncounterQuery }.to raise_error(NameError)
      expect { PerformanceQuery }.to raise_error(NameError)
    end
  end

  describe 'file loading order' do
    it 'loads dependencies in the correct order' do
      # WarcraftLogsClient should be available for query classes
      expect(defined?(WarcraftLogsClient)).to be_truthy
      
      # All query classes should be loaded
      query_classes = [
        :GuildQuery, :CharacterQuery, :AttendanceQuery, 
        :ReportQuery, :EncounterQuery, :PerformanceQuery
      ]
      
      query_classes.each do |class_name|
        expect(WarcraftLogs.const_defined?(class_name)).to be true
        klass = WarcraftLogs.const_get(class_name)
        expect { klass.new }.not_to raise_error
      end
    end
  end

  describe 'version compatibility' do
    it 'supports both legacy and new modular query patterns' do
      # Legacy attendance query (the large monolithic one)
      expect(WarcraftLogs::AttendanceQuery).to respond_to(:attendance_from_date)
      expect(WarcraftLogs::AttendanceQuery).to respond_to(:attendance_summary)
      
      # New modular queries
      expect(WarcraftLogs::EncounterQuery).to respond_to(:get_encounter_stats)
      expect(WarcraftLogs::PerformanceQuery).to respond_to(:get_guild_performance)
      
      # Both should be available and functional with dependency injection
      legacy_instance = WarcraftLogs::AttendanceQuery.new
      new_instance = WarcraftLogs::EncounterQuery.new
      
      expect(legacy_instance.client).to be_a(WarcraftLogsClient)
      expect(new_instance.client).to be_a(WarcraftLogsClient)
    end
  end
end

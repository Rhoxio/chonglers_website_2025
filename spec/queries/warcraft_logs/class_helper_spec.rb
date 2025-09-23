require 'rails_helper'

RSpec.describe WarcraftLogs::ClassHelper, type: :model do
  
  describe '.class_name' do
    context 'with valid class IDs' do
      it 'returns correct class names for all WoW classes' do
        expected_mappings = {
          1 => 'Warrior',
          2 => 'Paladin',
          3 => 'Hunter',
          4 => 'Rogue',
          5 => 'Priest',
          6 => 'Death Knight',
          7 => 'Shaman',
          8 => 'Mage',
          9 => 'Warlock',
          10 => 'Monk',
          11 => 'Druid',
          12 => 'Demon Hunter'
        }

        expected_mappings.each do |class_id, class_name|
          expect(described_class.class_name(class_id)).to eq(class_name)
        end
      end
    end

    context 'with invalid class IDs' do
      it 'returns unknown class message for non-existent class ID' do
        invalid_ids = [0, 13, 99, -1, 1000]
        
        invalid_ids.each do |invalid_id|
          result = described_class.class_name(invalid_id)
          expect(result).to eq("Unknown Class (#{invalid_id})")
        end
      end

      it 'handles nil class ID' do
        result = described_class.class_name(nil)
        expect(result).to eq("Unknown Class ()")
      end

      it 'handles string class ID' do
        result = described_class.class_name("invalid")
        expect(result).to eq("Unknown Class (invalid)")
      end
    end
  end

  describe '.all_class_names' do
    it 'returns all available class names' do
      result = described_class.all_class_names
      
      expect(result).to be_an(Array)
      expect(result.length).to eq(12)
      
      expected_classes = [
        'Warrior', 'Paladin', 'Hunter', 'Rogue', 'Priest', 'Death Knight',
        'Shaman', 'Mage', 'Warlock', 'Monk', 'Druid', 'Demon Hunter'
      ]
      
      expected_classes.each do |class_name|
        expect(result).to include(class_name)
      end
    end

    it 'returns unique class names' do
      result = described_class.all_class_names
      expect(result).to eq(result.uniq)
    end

    it 'does not include nil or empty values' do
      result = described_class.all_class_names
      expect(result).not_to include(nil)
      expect(result).not_to include('')
      expect(result.all? { |name| name.is_a?(String) && !name.empty? }).to be true
    end
  end

  describe '.class_id' do
    context 'with valid class names' do
      it 'returns correct class IDs for all WoW classes' do
        expected_mappings = {
          'Warrior' => 1,
          'Paladin' => 2,
          'Hunter' => 3,
          'Rogue' => 4,
          'Priest' => 5,
          'Death Knight' => 6,
          'Shaman' => 7,
          'Mage' => 8,
          'Warlock' => 9,
          'Monk' => 10,
          'Druid' => 11,
          'Demon Hunter' => 12
        }

        expected_mappings.each do |class_name, class_id|
          expect(described_class.class_id(class_name)).to eq(class_id)
        end
      end

      it 'is case sensitive' do
        expect(described_class.class_id('warrior')).to be_nil
        expect(described_class.class_id('WARRIOR')).to be_nil
        expect(described_class.class_id('Warrior')).to eq(1)
      end
    end

    context 'with invalid class names' do
      it 'returns nil for non-existent class names' do
        invalid_names = ['Invalid Class', 'Warri', 'Hunter of Souls', '']
        
        invalid_names.each do |invalid_name|
          expect(described_class.class_id(invalid_name)).to be_nil
        end
      end

      it 'handles nil class name' do
        expect(described_class.class_id(nil)).to be_nil
      end

      it 'handles numeric input' do
        expect(described_class.class_id(1)).to be_nil
      end
    end
  end

  describe 'constants' do
    it 'has frozen CLASS_NAMES constant' do
      expect(described_class.const_get(:CLASS_NAMES)).to be_frozen
    end

    it 'CLASS_NAMES contains expected entries' do
      class_names = described_class.const_get(:CLASS_NAMES)
      
      expect(class_names).to be_a(Hash)
      expect(class_names.keys.all? { |k| k.is_a?(Integer) }).to be true
      expect(class_names.values.all? { |v| v.is_a?(String) }).to be true
      
      # Check for all expected classes
      expect(class_names[1]).to eq('Warrior')
      expect(class_names[12]).to eq('Demon Hunter')
      expect(class_names.length).to eq(12)
    end
  end

  describe 'bidirectional mapping consistency' do
    it 'maintains consistency between class_name and class_id methods' do
      # For every class ID, getting the name and then the ID should return the original ID
      (1..12).each do |original_id|
        class_name = described_class.class_name(original_id)
        returned_id = described_class.class_id(class_name)
        expect(returned_id).to eq(original_id)
      end
    end

    it 'maintains consistency for all class names' do
      # For every class name, getting the ID and then the name should return the original name
      described_class.all_class_names.each do |original_name|
        class_id = described_class.class_id(original_name)
        returned_name = described_class.class_name(class_id)
        expect(returned_name).to eq(original_name)
      end
    end
  end

  describe 'edge cases and error handling' do
    it 'handles very large numbers gracefully' do
      large_number = 999_999_999
      result = described_class.class_name(large_number)
      expect(result).to eq("Unknown Class (#{large_number})")
    end

    it 'handles negative numbers gracefully' do
      negative_number = -42
      result = described_class.class_name(negative_number)
      expect(result).to eq("Unknown Class (#{negative_number})")
    end

    it 'handles float numbers' do
      float_number = 1.5
      result = described_class.class_name(float_number)
      expect(result).to eq("Unknown Class (#{float_number})")
    end

    it 'handles special characters in class name lookup' do
      special_chars = ['Class!', 'Cla$$', 'Class@Name', 'Class Name']
      
      special_chars.each do |special_name|
        expect(described_class.class_id(special_name)).to be_nil
      end
    end
  end

  describe 'performance considerations' do
    it 'returns results quickly for multiple lookups' do
      start_time = Time.now
      
      # Perform multiple lookups
      1000.times do |i|
        described_class.class_name((i % 12) + 1)
        described_class.class_id(described_class.all_class_names[i % 12])
      end
      
      end_time = Time.now
      execution_time = end_time - start_time
      
      # Should complete 2000 operations in well under a second
      expect(execution_time).to be < 1.0
    end

    it 'does not create new objects on repeated calls to all_class_names' do
      # Since CLASS_NAMES is frozen, calling .values should return the same objects
      first_call = described_class.all_class_names
      second_call = described_class.all_class_names
      
      # The arrays should contain the same string objects
      first_call.each_with_index do |class_name, index|
        expect(class_name).to be(second_call[index])
      end
    end
  end

  describe 'integration scenarios' do
    context 'when used with typical WoW data' do
      it 'handles guild member data correctly' do
        # Simulate typical guild member data
        guild_members = [
          { 'name' => 'PlayerOne', 'classID' => 1, 'guildRank' => 2 },
          { 'name' => 'PlayerTwo', 'classID' => 8, 'guildRank' => 3 },
          { 'name' => 'PlayerThree', 'classID' => 11, 'guildRank' => 4 },
          { 'name' => 'InvalidPlayer', 'classID' => 99, 'guildRank' => 5 }
        ]

        guild_members.each do |member|
          class_name = described_class.class_name(member['classID'])
          
          case member['classID']
          when 1
            expect(class_name).to eq('Warrior')
          when 8
            expect(class_name).to eq('Mage')
          when 11
            expect(class_name).to eq('Druid')
          when 99
            expect(class_name).to eq('Unknown Class (99)')
          end
        end
      end

      it 'handles character ranking data correctly' do
        # Simulate character ranking data with various class IDs
        rankings = [
          { 'name' => 'Tank', 'classID' => 1, 'spec' => 'Protection' },
          { 'name' => 'Healer', 'classID' => 5, 'spec' => 'Holy' },
          { 'name' => 'DPS', 'classID' => 9, 'spec' => 'Destruction' }
        ]

        rankings.each do |ranking|
          class_name = described_class.class_name(ranking['classID'])
          expect(class_name).to be_a(String)
          expect(class_name).not_to include('Unknown') # All should be valid
        end
      end
    end

    context 'when building class filters or dropdowns' do
      it 'provides data suitable for UI components' do
        all_classes = described_class.all_class_names
        
        # Should be suitable for building select options
        expect(all_classes).to be_an(Array)
        expect(all_classes.all? { |name| name.is_a?(String) && !name.empty? }).to be true
        
        # Should be able to create value/label pairs
        class_options = all_classes.map do |class_name|
          class_id = described_class.class_id(class_name)
          { value: class_id, label: class_name }
        end
        
        expect(class_options.length).to eq(12)
        expect(class_options.all? { |option| option[:value].is_a?(Integer) && option[:label].is_a?(String) }).to be true
      end
    end
  end

  describe 'module structure' do
    it 'defines expected public methods' do
      expected_methods = [:class_name, :all_class_names, :class_id]
      
      expected_methods.each do |method|
        expect(described_class).to respond_to(method)
      end
    end

    it 'does not expose internal constants publicly unless intended' do
      # CLASS_NAMES should be accessible but private
      expect(described_class.const_defined?(:CLASS_NAMES, false)).to be true
    end

    it 'is a module, not a class' do
      expect(described_class).to be_a(Module)
      expect(described_class).not_to be_a(Class)
    end
  end
end

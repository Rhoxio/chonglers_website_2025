# Helper methods for WoW class information
module WarcraftLogs::ClassHelper
  
  # Convert class ID to class name
  def self.class_name(class_id)
    CLASS_NAMES[class_id] || "Unknown Class (#{class_id})"
  end
  
  # Get all available class names
  def self.all_class_names
    CLASS_NAMES.values
  end
  
  # Get class ID by name
  def self.class_id(class_name)
    CLASS_NAMES.key(class_name)
  end
  
  private
  
  CLASS_NAMES = {
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
  }.freeze
end

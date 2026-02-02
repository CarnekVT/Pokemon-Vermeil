#===============================================================================
#  Sky Essentials Box Auto-Sort
#  Automatic PC box sorting system with multiple sorting algorithms
#===============================================================================

#===============================================================================
# Box Auto-Sort - Settings
#===============================================================================

module BoxAutoSort
  # Enable/disable the Box Auto-Sort feature
  ENABLED = true
  
  # Show preview before sorting (recommended)
  SHOW_PREVIEW = false
  
  # Maximum number of Pokemon to show in preview
  PREVIEW_COUNT = 30
end 

#===============================================================================
# Box Auto-Sort - Sorting Algorithms
#===============================================================================

module BoxAutoSort
  #=============================================================================
  # Main sorting class
  #=============================================================================
  class BoxSorter
    def initialize(storage, box_index)
      @storage = storage
      @box_index = box_index
      @box = @storage[@box_index]
    end
    
    # Get all Pokemon in the current box (excluding empty slots)
    def get_pokemon_list
      pokemon_list = []
      (0...PokemonBox::BOX_SIZE).each do |i|
        pokemon = @storage[@box_index, i]
        pokemon_list << [pokemon, i] if pokemon
      end
      return pokemon_list
    end
    
    # Sort Pokemon based on the selected method
    def sort_pokemon(sort_method)
      pokemon_list = get_pokemon_list
      return false if pokemon_list.empty?
      
      # Create sorted list
      sorted_list = case sort_method
      when :LEVEL_ASC
        pokemon_list.sort { |a, b| a[0].level <=> b[0].level }
      when :LEVEL_DESC
        pokemon_list.sort { |a, b| b[0].level <=> a[0].level }
      when :ALPHABET
        pokemon_list.sort { |a, b| a[0].name <=> b[0].name }
      when :ALPHABET_REV
        pokemon_list.sort { |a, b| b[0].name <=> a[0].name }
      when :TYPE_PRIMARY
        pokemon_list.sort { |a, b| compare_types(a[0], b[0]) }
      when :TYPE_DUAL
        pokemon_list.sort { |a, b| compare_types_dual(a[0], b[0]) }
      when :CATCH_DATE
        pokemon_list.sort { |a, b| compare_catch_date(a[0], b[0]) }
      when :SHINY_FIRST
        pokemon_list.sort { |a, b| compare_shiny_first(a[0], b[0]) }
      when :SPECIES_ID
        pokemon_list.sort { |a, b| compare_species_id(a[0], b[0]) }
      when :FORM_ID
        pokemon_list.sort { |a, b| compare_form_id(a[0], b[0]) }
      when :FRIENDSHIP
        pokemon_list.sort { |a, b| b[0].happiness <=> a[0].happiness }
      when :NATURE
        pokemon_list.sort { |a, b| a[0].nature.name <=> b[0].nature.name }
      else
        return false
      end
      
      # Apply the sorted order to the box
      apply_sorted_order(sorted_list)
      return true
    end
    
    # Preview what the sort would look like without applying it
    def preview_sort(sort_method)
      pokemon_list = get_pokemon_list
      return [] if pokemon_list.empty?
      
      case sort_method
      when :LEVEL_ASC
        return pokemon_list.sort { |a, b| a[0].level <=> b[0].level }
      when :LEVEL_DESC
        return pokemon_list.sort { |a, b| b[0].level <=> a[0].level }
      when :ALPHABET
        return pokemon_list.sort { |a, b| a[0].name <=> b[0].name }
      when :ALPHABET_REV
        return pokemon_list.sort { |a, b| b[0].name <=> a[0].name }
      when :TYPE_PRIMARY
        return pokemon_list.sort { |a, b| compare_types(a[0], b[0]) }
      when :TYPE_DUAL
        return pokemon_list.sort { |a, b| compare_types_dual(a[0], b[0]) }
      when :CATCH_DATE
        return pokemon_list.sort { |a, b| compare_catch_date(a[0], b[0]) }
      when :SHINY_FIRST
        return pokemon_list.sort { |a, b| compare_shiny_first(a[0], b[0]) }
      when :SPECIES_ID
        return pokemon_list.sort { |a, b| compare_species_id(a[0], b[0]) }
      when :FORM_ID
        return pokemon_list.sort { |a, b| compare_form_id(a[0], b[0]) }
      when :FRIENDSHIP
        return pokemon_list.sort { |a, b| b[0].happiness <=> a[0].happiness }
      when :NATURE
        return pokemon_list.sort { |a, b| a[0].nature.name <=> b[0].nature.name }
      else
        return pokemon_list
      end
    end
    
    private
    
    # Apply the sorted order to the actual box
    def apply_sorted_order(sorted_list)
      # Clear the box first
      (0...PokemonBox::BOX_SIZE).each do |i|
        @storage[@box_index, i] = nil
      end
      
      # Place Pokemon in new order
      sorted_list.each_with_index do |pokemon_data, new_index|
        @storage[@box_index, new_index] = pokemon_data[0]
      end
    end
    
    # Type comparison (primary type only)
    def compare_types(pokemon_a, pokemon_b)
      type_a = pokemon_a.types[0].to_s
      type_b = pokemon_b.types[0].to_s
      comparison = type_a <=> type_b
      return comparison != 0 ? comparison : pokemon_a.name <=> pokemon_b.name
    end
    
    # Type comparison (dual types)
    def compare_types_dual(pokemon_a, pokemon_b)
      types_a = pokemon_a.types.map(&:to_s).join("/")
      types_b = pokemon_b.types.map(&:to_s).join("/")
      comparison = types_a <=> types_b
      return comparison != 0 ? comparison : pokemon_a.name <=> pokemon_b.name
    end
    
    # Catch date comparison (newer first, fallback to name)
    def compare_catch_date(pokemon_a, pokemon_b)
      date_a = pokemon_a.timeReceived || Time.new(2000, 1, 1)
      date_b = pokemon_b.timeReceived || Time.new(2000, 1, 1)
      comparison = date_b <=> date_a  # Newer first
      return comparison != 0 ? comparison : pokemon_a.name <=> pokemon_b.name
    end
    
    # Shiny first, then by name
    def compare_shiny_first(pokemon_a, pokemon_b)
      shiny_a = pokemon_a.shiny? ? 0 : 1
      shiny_b = pokemon_b.shiny? ? 0 : 1
      comparison = shiny_a <=> shiny_b
      return comparison != 0 ? comparison : pokemon_a.name <=> pokemon_b.name
    end
    
    # Species ID comparison (National Dex order)
    def compare_species_id(pokemon_a, pokemon_b)
      species_data_a = GameData::Species.get(pokemon_a.species)
      species_data_b = GameData::Species.get(pokemon_b.species)
      
      # Use id_number if available, otherwise internal ID
      id_a = species_data_a.respond_to?(:id_number) ? species_data_a.id_number : species_data_a.id
      id_b = species_data_b.respond_to?(:id_number) ? species_data_b.id_number : species_data_b.id
      
      # If ID is a Symbol, convert to String and then to Hash for comparison
      if id_a.is_a?(Symbol)
        id_a = GameData::Species.keys.index(id_a) || 0
      end
      if id_b.is_a?(Symbol)
        id_b = GameData::Species.keys.index(id_b) || 0
      end
      
      comparison = id_a <=> id_b
      return comparison != 0 ? comparison : pokemon_a.name <=> pokemon_b.name
    end
    
    # Form ID comparison (species first, then form)
    def compare_form_id(pokemon_a, pokemon_b)
      species_comparison = compare_species_id(pokemon_a, pokemon_b)
      return species_comparison if species_comparison != 0
      
      form_a = pokemon_a.form || 0
      form_b = pokemon_b.form || 0
      form_comparison = form_a <=> form_b
      return form_comparison != 0 ? form_comparison : pokemon_a.name <=> pokemon_b.name
    end
  end
  
  #=============================================================================
  # Helper methods for sort descriptions
  #=============================================================================
  def self.get_sort_name(sort_method)
    case sort_method
    when :LEVEL_ASC then return _INTL("Level (Low to High)")
    when :LEVEL_DESC then return _INTL("Level (High to Low)")
    when :ALPHABET then return _INTL("Alphabetical (A-Z)")
    when :ALPHABET_REV then return _INTL("Alphabetical (Z-A)")
    when :TYPE_PRIMARY then return _INTL("Primary Type")
    when :TYPE_DUAL then return _INTL("Type Combination")
    when :CATCH_DATE then return _INTL("Catch Date")
    when :SHINY_FIRST then return _INTL("Shiny First")
    when :SPECIES_ID then return _INTL("National Dex")
    when :FORM_ID then return _INTL("Form")
    when :FRIENDSHIP then return _INTL("Friendship")
    when :NATURE then return _INTL("Nature")
    else return _INTL("Unknown")
    end
  end
  
  def self.get_sort_description(sort_method)
    case sort_method
    when :LEVEL_ASC then return _INTL("Sort by level from lowest to highest (1 to 100)")
    when :LEVEL_DESC then return _INTL("Sort by level from highest to lowest (100 to 1)")
    when :ALPHABET then return _INTL("Sort alphabetically from A to Z")
    when :ALPHABET_REV then return _INTL("Sort alphabetically from Z to A")
    when :TYPE_PRIMARY then return _INTL("Sort by primary type")
    when :TYPE_DUAL then return _INTL("Sort by type combination")
    when :CATCH_DATE then return _INTL("Sort by catch date (new to old)")
    when :SHINY_FIRST then return _INTL("Sort by Shiny (Shiny first)")
    when :SPECIES_ID then return _INTL("Sort by National Dex number")
    when :FORM_ID then return _INTL("Sort by form")
    when :FRIENDSHIP then return _INTL("Sort by friendship")
    when :NATURE then return _INTL("Sort by nature")
    else return _INTL("Unknown sorting method")
    end
  end
end 

#===============================================================================
# Box Auto-Sort - Box Integration
#===============================================================================

module BoxAutoSort
  # Main sort menu
  def self.show_sort_menu(storage, current_box = nil)
    current_box ||= storage.currentBox
    
    commands = [
      _INTL("Level (Low to High)"),
      _INTL("Level (High to Low)"),
      _INTL("Alphabetical (A-Z)"),
      _INTL("Alphabetical (Z-A)"),
      _INTL("Primary Type"),
      _INTL("Type Combination"),
      _INTL("Catch Date"),
      _INTL("Shiny First"),
      _INTL("National Dex"),
      _INTL("Form"),
      _INTL("Friendship"),
      _INTL("Nature"),
      _INTL("Cancel")
    ]
    
    choice = pbMessage(_INTL("How do you want to sort this box?"), commands, commands.length - 1)
    
    return if choice < 0 || choice >= commands.length - 1
    
    sort_method = case choice
    when 0 then :LEVEL_ASC
    when 1 then :LEVEL_DESC
    when 2 then :ALPHABET
    when 3 then :ALPHABET_REV
    when 4 then :TYPE_PRIMARY
    when 5 then :TYPE_DUAL
    when 6 then :CATCH_DATE
    when 7 then :SHINY_FIRST
    when 8 then :SPECIES_ID
    when 9 then :FORM_ID
    when 10 then :FRIENDSHIP
    when 11 then :NATURE
    end
    
    perform_sort(storage, current_box, sort_method)
  end

  # Perform sorting
  def self.perform_sort(storage, box, method)
    sorter = BoxSorter.new(storage, box)
    
    # Show preview
    preview_list = sorter.preview_sort(method)
    if preview_list.empty?
      pbMessage("This box is empty!")
      return
    end
    
    # Create preview text (show only first 8 Pokemon)
    confirm = true
    if BoxAutoSort::SHOW_PREVIEW
      preview_count = [preview_list.length, BoxAutoSort::PREVIEW_COUNT].min
      preview_text = "Preview of the first #{preview_count} Pokémon:\n"
      preview_list[0, preview_count].each_with_index do |pokemon_data, i|
        pokemon = pokemon_data[0]  # Pokemon is the first element in the array
        name = pokemon.name
        level = pokemon.level
        preview_text += "#{i+1}. #{name} (Lv.#{level})\n"
      end
      preview_text += "\nDo you want to apply this sorting?"
      confirm = pbConfirmMessage(preview_text)
    end

    if confirm
      pbMessage("Sorting box...") if BoxAutoSort::SHOW_PREVIEW
      success = sorter.sort_pokemon(method)
      if success
        pbMessage("Box sorted!") if BoxAutoSort::SHOW_PREVIEW
        pbPlayDecisionSE
      else
        pbMessage("Sorting failed!")
        pbPlayBuzzerSE
      end
    end
  end
end

# =============================================================================
# PC MENU INTEGRATION - Direct Access
# =============================================================================

MenuHandlers.add(:pc_menu, :box_auto_sort, {
  "name"      => _INTL("PC Sorting"),
  "order"     => 15,
  "effect"    => proc { |menu|
    pbMessage("\\se[PC access]" + _INTL("PC Sorting System opened."))
    
    # Select box
    commands = []
    $PokemonStorage.maxBoxes.times do |i|
      box = $PokemonStorage[i]
      if box
        commands.push(_INTL("{1} ({2}/{3})", box.name, box.nitems, box.length))
      end
    end
    commands.push(_INTL("Cancel"))
    
    choice = pbMessage(_INTL("Which box do you want to sort?"), commands, commands.length - 1)
    
    if choice >= 0 && choice < $PokemonStorage.maxBoxes
      selected_box = choice
      BoxAutoSort.show_sort_menu($PokemonStorage, selected_box)
    end
    
    next false
  }
})

# =============================================================================
# DIRECT OVERRIDE - Loads immediately!
# =============================================================================

# Define the pbBoxCommands override in a standalone module
module BoxAutoSortOverride
  def pbBoxCommands
    commands = [
      _INTL("Jump"),
      _INTL("Wallpaper"),
      _INTL("Name"),
      _INTL("Sort Box"),
      _INTL("Release Box"),
      _INTL("Cancel")
    ]
    
    # Add Swap if Storage System Utilities is active
    if defined?(CAN_SWAP_BOXES) && CAN_SWAP_BOXES
      commands.insert(1, _INTL("Swap"))
    end
    
    command = pbShowCommands(_INTL("What do you want to do?"), commands)
    
    case command
    when commands.index(_INTL("Jump"))
      destbox = @scene.pbChooseBox(_INTL("Jump to which Box?"))
      @scene.pbJumpToBox(destbox) if destbox >= 0
      
    when commands.index(_INTL("Swap"))
      if defined?(CAN_SWAP_BOXES) && CAN_SWAP_BOXES && @scene.respond_to?(:pbSwapBoxes)
        destbox = @scene.pbChooseBox(_INTL("Swap with which Box?"))
        @scene.pbSwapBoxes(destbox) if destbox >= 0
      end
      
    when commands.index(_INTL("Wallpaper"))
      papers = @storage.availableWallpapers
      index = 0
      papers[1].length.times do |i|
        if papers[1][i] == @storage[@storage.currentBox].background
          index = i
          break
        end
      end
      wpaper = pbShowCommands(_INTL("Which wallpaper do you want to use?"), papers[0], index)
      @scene.pbChangeBackground(papers[1][wpaper]) if wpaper >= 0
      
    when commands.index(_INTL("Name"))
      @scene.pbBoxName(_INTL("Box Name?"), 0, 12)
      
    when commands.index(_INTL("Sort Box"))
      BoxAutoSort.show_sort_menu(@storage, @storage.currentBox)
      @scene.pbHardRefresh if @scene.respond_to?(:pbHardRefresh)
      @scene.pbRefresh if @scene.respond_to?(:pbRefresh)
    
    when commands.index(_INTL("Release Box"))
      pbReleaseBox(@storage.currentBox)
    end
  end
end

# Wait briefly and then override ALL storage classes
Thread.new do
  sleep(2) # Wait 2 seconds for all plugins to load
  
  # Standard Storage Screen
  if defined?(PokemonStorageScreen)
    PokemonStorageScreen.prepend(BoxAutoSortOverride)
  end
  
  # BW Storage Screen
  if defined?(PokemonStorageScreenBW)
    PokemonStorageScreenBW.prepend(BoxAutoSortOverride)
  end
end

# =============================================================================
# Debug Commands for Testing
# =============================================================================

if $DEBUG
  MenuHandlers.add(:debug_menu, :box_auto_sort_test, {
    "name"        => "Test Box Auto-Sort",
    "parent"      => :plugins_menu,
    "description" => "Test the Box Auto-Sort functionality",
    "effect"      => proc {
      if $player&.storage
        pbMessage("Testing Box Auto-Sort directly...")
        BoxAutoSort.show_sort_menu($PokemonStorage)
      else
        pbMessage("No storage system available!")
      end
    }
  })
end 

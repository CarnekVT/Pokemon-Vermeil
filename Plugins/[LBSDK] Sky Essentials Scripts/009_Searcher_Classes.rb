#===============================================================================
# SEARCHER CLASSES
# Base class and specific searchers for creating searchable interfaces with text input.
#===============================================================================

#-------------------------------------------------------------------------------
# 1. BaseSearcher - Base class for creating searchable interfaces
#-------------------------------------------------------------------------------

# Base class for creating searchable interfaces with text input.
# Provides common functionality for searching through collections of items.
#
# To create a new searcher:
# 1. Inherit from BaseSearcher
# 2. Implement required methods: #get_item_name, #get_search_list, #get_current_index, #refresh_display
# 3. Optionally override: #valid_item?, #search_prompt, #on_search_complete
#
# @example Creating a custom searcher
#   class MyCustomSearcher < BaseSearcher
#     def get_item_name(item)
#       item.name
#     end
#
#     def get_search_list
#       @my_list
#     end
#
#     def get_current_index
#       @current_index
#     end
#
#     def refresh_display(index)
#       @display.update(index)
#     end
#   end
class BaseSearcher
  SEARCH_BOX_MAX_LENGTH = 32
  SEARCH_BOX_WIDTH = 240

  # Opens the search box and initiates the search process.
  # @return [Boolean, Integer] Returns false if search is cancelled, otherwise returns search result.
  def open_search_box(position = :right)
    on_input = ->(text, char = '') { search_by_name(text, char) }
    term = pb_message_free_text_with_on_input(search_prompt, "", false, SEARCH_BOX_MAX_LENGTH, width = SEARCH_BOX_WIDTH, on_input = on_input, position = position)

    return false if ['', nil].include?(term)

    search_by_name(term)
  end

  # Searches for items by name, wrapping around the list if necessary.
  # @param text [String] The search term.
  # @param _char [String] Optional character parameter (for compatibility with on_input callback).
  # @return [Boolean, Integer] Returns the index if found, false otherwise.
  def search_by_name(text, _char = '')
    current_index = get_current_index
    search_list = get_search_list
    
    # Search from current position to end
    index = search(text, current_index, search_list.length)
    return on_search_complete(index) if index

    # Wrap around: search from beginning to current position
    if current_index.positive?
      index = search(text, 0, current_index)
      return on_search_complete(index) if index
    end
    
    false
  end

  # Searches through a range of items in the list.
  # @param text [String] The search term.
  # @param start_index [Integer] Starting index for the search.
  # @param end_index [Integer] Ending index for the search.
  # @return [Integer, Boolean] Returns the index if found, false otherwise.
  def search(text, start_index, end_index)
    get_search_list[start_index...end_index].each_with_index do |item, offset|
      next unless valid_item?(item)
      
      item_name = get_item_name(item)
      return start_index + offset if matches_name?(item_name, text)
    end
    false
  end

  # Checks if an item name matches the search text (case-insensitive).
  # @param item_name [String] The item name to check.
  # @param text [String] The search text.
  # @return [Boolean] True if the name contains the search text.
  def matches_name?(item_name, text)
    pbSmartMatch?(item_name, text)
  end

  # Validates whether an item should be included in the search.
  # Override this method to implement custom validation logic.
  # @param item [Object] The item to validate.
  # @return [Boolean] True if the item is valid for searching.
  def valid_item?(item)
    true
  end

  # Called when a search successfully finds an item.
  # Override this to customize behavior after finding an item.
  # @param index [Integer] The index of the found item.
  # @return [Integer] The index (or transformed value).
  def on_search_complete(index)
    refresh_display(index)
    index
  end

  # ========== ABSTRACT METHODS - Must be implemented by subclasses ==========

  # Gets the display name for an item.
  # @abstract
  # @param item [Object] The item to get the name from.
  # @return [String] The item's name.
  def get_item_name(item)
    raise NotImplementedError, "#{self.class} must implement #get_item_name"
  end

  # Gets the list to search through.
  # @abstract
  # @return [Array] The searchable list.
  def get_search_list
    raise NotImplementedError, "#{self.class} must implement #get_search_list"
  end

  # Gets the current index in the list.
  # @abstract
  # @return [Integer] The current index.
  def get_current_index
    raise NotImplementedError, "#{self.class} must implement #get_current_index"
  end

  # Refreshes the display with the new index.
  # @abstract
  # @param index [Integer] The index to display.
  def refresh_display(index)
    raise NotImplementedError, "#{self.class} must implement #refresh_display"
  end

  # Gets the prompt text for the search box.
  # Override this to customize the search prompt.
  # @return [String] The prompt text.
  def search_prompt
    _INTL("What are you looking for?")
  end
end

#-------------------------------------------------------------------------------
# 2. PokedexSearcher - Searches for Pokémon in the Pokédex
#-------------------------------------------------------------------------------

class PokemonPokedex_Scene
  attr_reader :sprites
end

# Searches for a Pokémon in the dexlist based on the given text.
# Inherits common search functionality from BaseSearcher.
#
# @example Usage
#   searcher = PokedexSearcher.new(dexlist, dex_instance)
class PokedexSearcher < BaseSearcher
  def initialize(dexlist, dex_instance)
    @dexlist = dexlist
    @dex_instance = dex_instance
    open_search_box
  end

  # Gets the Pokémon name from a dex entry.
  # @param item [Hash] A dex entry with :name key.
  # @return [String] The Pokémon's name.
  def get_item_name(item)
    item[:name]
  end

  # Gets the dexlist to search through.
  # @return [Array<Hash>] The dex entries list.
  def get_search_list
    @dexlist
  end

  # Gets the current selected index in the Pokédex.
  # @return [Integer] The current index.
  def get_current_index
    @dex_instance.sprites['pokedex'].index
  end

  # Refreshes the Pokédex display with the found Pokémon.
  # @param index [Integer] The dex number minus 1.
  def refresh_display(index)
    @dex_instance.pbRefreshDexList(index)
  end

  # Validates if a Pokémon entry should be searchable.
  # Only seen Pokémon (excluding shift entries) are valid.
  # @param item [Hash] A dex entry with :species and :shift keys.
  # @return [Boolean] True if the Pokémon has been seen.
  def valid_item?(item)
    ($player.seen?(item[:species]) && !item[:shift]) || $player.seen?(item[:species])
  end

  # Transforms the found index to the correct dex number format.
  # @param index [Integer] The array index where the Pokémon was found.
  # @return [Integer] The dex number minus 1.
  def on_search_complete(index)
    return false unless index
    dex_number = @dexlist[index][:number] - 1
    refresh_display(dex_number)
    dex_number
  end

  # Customized search prompt for Pokédex.
  # @return [String] The localized prompt text.
  def search_prompt
    _INTL("Which Pokémon are you looking for?")
  end
end

#-------------------------------------------------------------------------------
# 3. BagSearcher - Searches for items in the bag
#-------------------------------------------------------------------------------

# Searches for an item in the bag pocket based on the given text.
# Inherits common search functionality from BaseSearcher.
#
# @example Usage
#   searcher = BagSearcher.new(pocket, itemwindow, bag)
class BagSearcher < BaseSearcher
	def initialize(pocket, itemwindow, bag)
		@pocket = pocket
		@bag_instance = bag
		@current_index = itemwindow.index
		@itemwindow = itemwindow
		open_search_box
	end

	# Gets the item name, including TM/HM move names for machines.
	# @param item [Array] An item entry [item_id, quantity].
	# @return [String] The item's display name.
	def get_item_name(item)
		item_data = GameData::Item.get(item[0])
		if item_data.is_machine?
			"#{item_data.name} #{GameData::Move.get(item_data.move).name}"
		else
			item_data.name
		end
	end

	# Gets the pocket list to search through.
	# @return [Array] The bag pocket items.
	def get_search_list
		@pocket
	end

	# Gets the current selected index in the bag.
	# @return [Integer] The current index.
	def get_current_index
		@current_index
	end

	# Refreshes the bag display and updates the current index.
	# @param index [Integer] The index of the found item.
	def refresh_display(index)
		@current_index = index
		@itemwindow.index = index
		@bag_instance.pbRefresh
	end

	# Customized search prompt for bag items.
	# @return [String] The localized prompt text.
	def search_prompt
		_INTL("Which item are you looking for?")
	end
end

#-------------------------------------------------------------------------------
# 4. SpeciesSearcher - Searches for Pokémon in species lists
#-------------------------------------------------------------------------------

# Searches for a Pokémon in the dexlist based on the given text.
# Inherits common search functionality from BaseSearcher.
#
# @example Usage
#   searcher = SpeciesSearcher.new(species_list)
class SpeciesSearcher < BaseSearcher
  def initialize(species_list, window, class_instance = nil)
    @species_list = species_list
    @window = window
    @class_instance = class_instance
    open_search_box(:left)
  end

  # Gets the Pokémon name from a dex entry.
  # @param item [Hash] A dex entry with :name key.
  # @return [String] The Pokémon's name.
  def get_item_name(item)
    item[3]
  end

  # Gets the dexlist to search through.
  # @return [Array<Hash>] The dex entries list.
  def get_search_list
    @species_list
  end

  # Gets the current selected index in the Pokédex.
  # @return [Integer] The current index.
  def get_current_index
    @window.index
  end

  # Refreshes the Pokédex display with the found Pokémon.
  # @param index [Integer] The dex number minus 1.
  def refresh_display(index)
    @window.index = index
    @class_instance.refresh if @class_instance
  end

  # Customized search prompt for Pokédex.
  # @return [String] The localized prompt text.
  def search_prompt
    _INTL("Which Pokémon are you looking for?")
  end
end

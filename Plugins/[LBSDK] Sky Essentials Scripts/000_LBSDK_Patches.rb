#-------------------------------------------------------------------------------
# Sky Base Settings (for compatibility with UI scripts from Sky Base)
#-------------------------------------------------------------------------------
module Settings
  # Exp Share Configuration from Sky Base
  # Enable new Exp Share system (each Pokémon can receive exp individually)
  USE_NEW_EXP_SHARE = defined?(USE_NEW_EXP_SHARE) ? USE_NEW_EXP_SHARE : false
  
  # Enable Exp Share from the start of the game without needing the item
  # or $player.has_exp_all. If you want Exp Share for all Pokémon using
  # either method mentioned above, leave this variable as false.
  EXPSHARE_ENABLED = defined?(EXPSHARE_ENABLED) ? EXPSHARE_ENABLED : false
  
  # Group Exp Share message (true = show single message, false = show individual messages)
  GROUP_EXP_SHARE_MESSAGE = defined?(GROUP_EXP_SHARE_MESSAGE) ? GROUP_EXP_SHARE_MESSAGE : true
  
  # UI Editor Compatibility - Add Sky Base UI classes to editable classes
  # These classes will be recognized by the UI Editor for position adjustment
  UI_EDITABLE_CLASS = [
    "UI::MoveReminderVisuals", "UI::BaseVisuals",
    "PokemonParty_Scene", "PokemonPokedex_Scene", "PokemonBag_Scene",
    "PokemonSummary_Scene", "PokemonLoad_Scene", "PokemonPokedexMenu_Scene", "Battle::Scene",
    "PokemonPokedexInfo_Scene", "PokemonTrainerCard_Scene", "PokemonRegionMap_Scene",
    "Battle::Scene::MenuBase", "ItemStorage_Scene", "PokemonStorageScene", "PurifyChamberScene",
    "PokemonReadyMenu_Scene", "MoveRelearner_Scene"
  ] unless const_defined?(:UI_EDITABLE_CLASS)
end

#-------------------------------------------------------------------------------
# JSON helper (used by Options UI)
#-------------------------------------------------------------------------------
def json_remove_comments(json_str)
  json_str.gsub(/\/\/.*$/, '').gsub(/\/\*.*?\*\//m, '')
end

module System
  def self.is_really_windows?
    return !!(RUBY_PLATFORM =~ /mswin|mingw|windows/i)
  end
end

#-------------------------------------------------------------------------------
# PageHandlers (needed by tabbed Options UI)
#-------------------------------------------------------------------------------
unless defined?(PageHandlers)
  module PageHandlers
    @@handlers = {}

    module_function

    def add(menu, page, hash)
      @@handlers[menu] = HandlerHash.new if !@@handlers.has_key?(menu)
      @@handlers[menu].add(page, hash)
    end

    def remove(menu, page)
      @@handlers[menu]&.remove(page)
    end

    def clear(menu)
      @@handlers[menu]&.clear
    end

    def get(menu, page)
      return @@handlers[menu]&.[](page)
    end

    def each(menu)
      return if !@@handlers.has_key?(menu)
      @@handlers[menu].each { |page, hash| yield page, hash }
    end

    def each_available(menu, *args)
      return if !@@handlers.has_key?(menu)
      pages = @@handlers[menu]
      keys = pages.keys
      sorted_keys = keys.sort_by { |page| pages[page][:order] || keys.index(page) }
      sorted_keys.each do |page|
        hash = pages[page]
        next if hash[:condition] && !hash[:condition].call(*args)
        if hash[:name].is_a?(Proc)
          name = hash[:name].call(*args)
        else
          name = _INTL(hash[:name])
        end
        yield page, hash, name
      end
    end

    def has_any?(menu, page)
      page_options = get(menu, page)
      return false if page_options.nil?
      has_menu_handlers = false
      MenuHandlers.each(menu) do |option, hash|
        if hash["page"] == page && (!hash["condition"] || hash["condition"].call)
          has_menu_handlers = true
          break
        end
      end
      return has_menu_handlers
    end

    def call(menu, page)
      return @@handlers[menu]&.[](page)
    end
  end
end
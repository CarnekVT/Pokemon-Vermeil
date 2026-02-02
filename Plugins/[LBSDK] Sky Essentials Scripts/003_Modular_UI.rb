#===============================================================================
#  Sky Essentials Modular UI Extensions
#  Extensions to the Modular UI Scenes system
#===============================================================================

#===============================================================================
# Extend UIHandlers module from Modular UI Scenes
#===============================================================================
module UIHandlers
  # Add options_labels support if not already defined
  unless class_variable_defined?(:@@options_labels)
    @@options_labels = {}
  end

  # Extend add method to support options_labels
  unless singleton_class.method_defined?(:add_without_options_labels)
    singleton_class.alias_method :add_without_options_labels, :add
    
    def self.add(ui, option, hash)
      add_without_options_labels(ui, option, hash)
      if hash["options"] && hash["options_labels"]
        @@options_labels[ui] ||= {}
        @@options_labels[ui][option] ||= {}
        @@options_labels[ui][option] = hash["options_labels"]
        if hash["options_labels"].keys != hash["options"]
          remaining_options = hash["options_labels"].keys - hash["options"]
          all_options = hash["options"] + remaining_options
          edit_hash(ui, option, "options", all_options)
        end
      elsif hash["options_labels"]
        edit_hash(ui, option, "options", hash["options_labels"].keys)
        @@options_labels[ui] ||= {}
        @@options_labels[ui][option] ||= {}
        @@options_labels[ui][option] = hash["options_labels"]
      end
    end
  end

  # Extend get_info method to support options_labels
  unless singleton_class.method_defined?(:get_info_without_options_labels)
    singleton_class.alias_method :get_info_without_options_labels, :get_info
    
    def self.get_info(menu, option, type = nil)
      case type
      when :options_labels
        return @@options_labels[menu] ? @@options_labels[menu][option] || {} : {}
      end
      return get_info_without_options_labels(menu, option, type)
    end
  end

  # Extend edit_hash method to support options_labels
  unless singleton_class.method_defined?(:edit_hash_without_options_labels)
    singleton_class.alias_method :edit_hash_without_options_labels, :edit_hash
    
    def self.edit_hash(menu, page, field, new_data)
      if field == "options_labels"
        @@options_labels[menu] ||= {}
        @@options_labels[menu][page] ||= {}
        old_labels = @@options_labels[menu][page]
        if old_labels != new_data && new_data.is_a?(Hash)
          @@options_labels[menu][page] = new_data
          if exists?(menu, page)
            old_data = get_info(menu, page, :options)
            if !old_data
              edit_hash_without_options_labels(menu, page, "options", new_data.keys)
            elsif old_data != new_data.keys
              missing_entries = new_data.keys - old_data
              new_options = old_data.concat(missing_entries) unless missing_entries.empty?
              edit_hash_without_options_labels(menu, page, "options", new_options)
            end   
          end
        end
      else
        edit_hash_without_options_labels(menu, page, field, new_data)
      end
    end
  end

  # Add exists? method if not already defined
  unless singleton_class.method_defined?(:exists?)
    def self.exists?(menu, page)
      return true if @@handlers && @@handlers[menu] && @@handlers[menu][page]
      false
    end
  end

  # Add define_option_label method if not already defined
  unless singleton_class.method_defined?(:define_option_label)
    def self.define_option_label(menu, page, option, label)
      return unless exists?(menu, page)
      options = get_info(menu, page, :options)
      unless options.include?(option)
        options << option
      end
      @@options_labels[menu] ||= {}
      @@options_labels[menu][page] ||= {}
      @@options_labels[menu][page][option] = label
      edit_hash(menu, page, "options", options)
    end
  end

  # Add define_options_labels method if not already defined
  unless singleton_class.method_defined?(:define_options_labels)
    def self.define_options_labels(menu, page, options_with_labels)
      return unless exists?(menu, page)
      options_with_labels.each_pair do |key, value|
        define_option_label(menu, page, key, value)
      end
    end
  end

  # Extend clear method to clear options_labels
  unless singleton_class.method_defined?(:clear_without_options_labels)
    singleton_class.alias_method :clear_without_options_labels, :clear
    
    def self.clear(ui)
      clear_without_options_labels(ui)
      @@options_labels[ui]&.clear
    end
  end
end

#===============================================================================
# Extend PluginManager to include Sky Essentials plugins in version check
#===============================================================================
module PluginManager
  class << self
    unless method_defined?(:mui_register_with_sky)
      alias_method :mui_register_with_sky, :register
      def register(options)
        mui_register_with_sky(options)
        self.plugin_check_MUI
      end
    end
    
    #-----------------------------------------------------------------------------
    # Used to ensure all plugins that rely on Modular UI Scenes are up to date.
    #-----------------------------------------------------------------------------
    def self.plugin_check_MUI(version = "2.0.8")
      if self.installed?("Modular UI Scenes", version, true)
        {
          "[MUI] Enhanced Pokemon UI"   => "1.0.6",
          "[MUI] Pokedex Data Page"     => "2.0.1",
          "[MUI] Improved Mementos"     => "1.0.3",
          "[MUI] Improved Field Skills" => "1.0.1",
        }.each do |p_name, v_num|
          next if !self.installed?(p_name)
          p_ver = self.version(p_name)
          valid = self.compare_versions(p_ver, v_num)
          next if valid > -1
          link = self.link(p_name)
          self.error("Plugin '#{p_name}' is out of date.\nPlease download the latest version at:\n#{link}")
        end
      end
    end
  end
end

module GameData
  class Species
    def self.check_graphic_file(path, species, form = 0, gender = 0, shiny = false, shadow = false, subfolder = "")
      try_subfolder = sprintf("%s/", subfolder)
      try_species = species
      try_form    = (form > 0) ? sprintf("_%d", form) : ""
      try_gender  = (gender == 1) ? "_female" : ""
      try_shadow  = (shadow) ? "_shadow" : ""
      factors = []
      factors.push([4, sprintf("%s shiny/", subfolder), try_subfolder]) if shiny
      factors.push([3, try_shadow, ""]) if shadow
      factors.push([2, try_gender, ""]) if gender == 1
      factors.push([1, try_form, ""]) if form > 0
      factors.push([0, try_species, "000"])
      # Go through each combination of parameters in turn to find an existing sprite
      (2**factors.length).times do |i|
        # Set try_ parameters for this combination
        factors.each_with_index do |factor, index|
          value = ((i / (2**index)).even?) ? factor[1] : factor[2]
          case factor[0]
          when 0 then try_species   = value
          when 1 then try_form      = value
          when 2 then try_gender    = value
          when 3 then try_shadow    = value
          when 4 then try_subfolder = value   # Shininess
          end
        end
        # Look for a graphic matching this combination's parameters
        try_species_text = try_species
        ret = pbResolveBitmap(sprintf("%s%s%s%s%s%s", path, try_subfolder,
                                      try_species_text, try_form, try_gender, try_shadow))
        return ret if ret
      end
      return nil
    end

    def self.check_egg_graphic_file(path, species, form, suffix = "")
      species_data = self.get_species_form(species, form)
      return nil if species_data.nil?
      
      if form > 0
        ret = pbResolveBitmap(sprintf("%s%s_%d%s", path, species_data.species, form, suffix))
        return ret if ret
      end
      
      ret = pbResolveBitmap(sprintf("%s%s%s", path, species_data.species, suffix))
      return ret if ret
      
      # Try baby species as fallback (first pre-evolution)
      baby_species = species_data.get_baby_species
      return nil if baby_species.nil? || baby_species == species_data.species
      
      if form > 0
        ret = pbResolveBitmap(sprintf("%s%s_%d%s", path, baby_species, form, suffix))
        return ret if ret
      end
      
      pbResolveBitmap(sprintf("%s%s%s", path, baby_species, suffix))
    end

    def self.front_sprite_filename(species, form = 0, gender = 0, shiny = false, shadow = false, super_shiny = false)
      if super_shiny
        ret = self.check_graphic_file("Graphics/Pokemon/", species, form, gender, false, shadow, "Front supershiny")
        return ret if ret
        # Sin gráfico dedicado: usar sprite normal como base (no el shiny).
        return self.check_graphic_file("Graphics/Pokemon/", species, form, gender, false, shadow, "Front")
      end
      return self.check_graphic_file("Graphics/Pokemon/", species, form, gender, shiny, shadow, "Front")
    end

    def self.back_sprite_filename(species, form = 0, gender = 0, shiny = false, shadow = false, super_shiny = false)
      if super_shiny
        ret = self.check_graphic_file("Graphics/Pokemon/", species, form, gender, false, shadow, "Back supershiny")
        return ret if ret
        # Sin gráfico dedicado: usar sprite normal como base (no el shiny).
        return self.check_graphic_file("Graphics/Pokemon/", species, form, gender, false, shadow, "Back")
      end
      return self.check_graphic_file("Graphics/Pokemon/", species, form, gender, shiny, shadow, "Back")
    end

    def self.egg_sprite_filename(species, form)
      ret = self.check_egg_graphic_file("Graphics/Pokemon/Eggs/", species, form)
      return (ret) ? ret : pbResolveBitmap("Graphics/Pokemon/Eggs/000")
    end

    def self.egg_cracks_sprite_filename(species, form)
      ret = self.check_egg_graphic_file("Graphics/Pokemon/Eggs/", species, form, "_cracks")
      return (ret) ? ret : pbResolveBitmap("Graphics/Pokemon/Eggs/000_cracks")
    end

    def self.sprite_filename(species, form = 0, gender = 0, shiny = false, shadow = false, back = false, egg = false, super_shiny = false)
      return self.egg_sprite_filename(species, form) if egg
      return self.back_sprite_filename(species, form, gender, shiny, shadow, super_shiny) if back
      return self.front_sprite_filename(species, form, gender, shiny, shadow, super_shiny)
    end

    def self.front_sprite_bitmap(species, form = 0, gender = 0, shiny = false, shadow = false)
      filename = self.front_sprite_filename(species, form, gender, shiny, shadow)
      return (filename) ? AnimatedBitmap.new(filename) : nil
    end

    def self.back_sprite_bitmap(species, form = 0, gender = 0, shiny = false, shadow = false)
      filename = self.back_sprite_filename(species, form, gender, shiny, shadow)
      return (filename) ? AnimatedBitmap.new(filename) : nil
    end

    def self.egg_sprite_bitmap(species, form = 0)
      filename = self.egg_sprite_filename(species, form)
      return (filename) ? AnimatedBitmap.new(filename) : nil
    end

    def self.super_shiny_hue_for(species, form = 0, for_display = false)
      return 0 if !for_display && !Settings::SUPER_SHINY_HUE_SHIFT
      sp_data = self.get_species_form(species, form)
      hue_pool = sp_data.super_shiny_hue
      hue_pool = Settings::SUPER_SHINY_HUES if hue_pool.nil? || hue_pool.empty?
      return 0 if hue_pool.empty?
      return hue_pool[0] if hue_pool.length == 1
      if Settings::SUPER_SHINY_HUE_BY_SPECIES
        baby_species = self.get(species).get_baby_species.to_s
        seed = 0
        baby_species.each_byte { |b| seed = (seed * 31) + b }
        srand(seed)
        hue = hue_pool[rand(hue_pool.length)]
        srand
        return hue
      end
      return hue_pool[0]
    end

    def self.apply_super_shiny_hue_to_bitmap(ret, species, form, filename)
      return ret if !ret
      return ret if filename && filename.include?("supershiny")
      hue = self.super_shiny_hue_for(species, form, true)
      return ret if hue == 0
      new_ret = ret.copy
      ret.dispose
      new_ret.bitmap.apply_super_shiny_hue(hue)
      return new_ret
    end

    def self.sprite_bitmap(species, form = 0, gender = 0, shiny = false, shadow = false, back = false, egg = false, super_shiny = false)
      return self.egg_sprite_bitmap(species, form) if egg
      if back
        filename = self.back_sprite_filename(species, form, gender, shiny, shadow, super_shiny)
      else
        filename = self.front_sprite_filename(species, form, gender, shiny, shadow, super_shiny)
      end
      ret = (filename) ? AnimatedBitmap.new(filename) : nil
      return self.apply_super_shiny_hue_to_bitmap(ret, species, form, filename) if super_shiny
      return ret
    end

    def self.sprite_bitmap_from_pokemon(pkmn, back = false, species = nil)
      form = pkmn.form
      if species
        species_data = GameData::Species.get(species)
        species = species_data.species
        form = species_data.form if species_data.form > 0
      else
        species = pkmn.species
        species = GameData::Species.get(species).species   # Just to be sure it's a symbol
      end
      return self.egg_sprite_bitmap(species, form) if pkmn.egg?
      if back
        filename = self.back_sprite_filename(species, form, pkmn.gender, pkmn.shiny?, pkmn.shadowPokemon?, pkmn.super_shiny?)
      else
        filename = self.front_sprite_filename(species, form, pkmn.gender, pkmn.shiny?, pkmn.shadowPokemon?, pkmn.super_shiny?)
      end
      ret = (filename) ? AnimatedBitmap.new(filename) : nil
      if ret && pkmn.super_shiny? && !(filename && filename.include?("supershiny"))
        hue = self.super_shiny_hue_for(species, form, true)
        if hue != 0
          new_ret = ret.copy
          ret.dispose
          new_ret.bitmap.apply_super_shiny_hue(hue)
          ret = new_ret
        end
      end
      
      alter_bitmap_function = MultipleForms.getFunction(species, "alterBitmap")
      if ret && alter_bitmap_function
        new_ret = ret.copy
        ret.dispose
        new_ret.each { |bitmap| alter_bitmap_function.call(pkmn, bitmap) }
        ret = new_ret
      end
      return ret
    end

    #===========================================================================

    def self.egg_icon_filename(species, form)
      ret = self.check_egg_graphic_file("Graphics/Pokemon/Eggs/", species, form, "_icon")
      return (ret) ? ret : pbResolveBitmap("Graphics/Pokemon/Eggs/000_icon")
    end

    def self.icon_filename(species, form = 0, gender = 0, shiny = false, shadow = false, egg = false, super_shiny = false)
      return self.egg_icon_filename(species, form) if egg
      if super_shiny
        ret = self.check_graphic_file("Graphics/Pokemon/", species, form, gender, false, shadow, "Icons supershiny")
        return ret if ret
        # Sin gráfico dedicado: usar icono normal como base (no el shiny).
        return self.check_graphic_file("Graphics/Pokemon/", species, form, gender, false, shadow, "Icons")
      end
      return self.check_graphic_file("Graphics/Pokemon/", species, form, gender, shiny, shadow, "Icons")
    end

    def self.icon_filename_from_pokemon(pkmn)
      return self.icon_filename(pkmn.species, pkmn.form, pkmn.gender, pkmn.shiny?, pkmn.shadowPokemon?, pkmn.egg?, pkmn.super_shiny?)
    end

    def self.egg_icon_bitmap(species, form)
      filename = self.egg_icon_filename(species, form)
      return (filename) ? AnimatedBitmap.new(filename).deanimate : nil
    end

    def self.icon_bitmap(species, form = 0, gender = 0, shiny = false, shadow = false, egg = false, super_shiny = false)
      return self.egg_icon_bitmap(species, form) if egg
      filename = self.icon_filename(species, form, gender, shiny, shadow, false, super_shiny)
      ret = (filename) ? AnimatedBitmap.new(filename).deanimate : nil
      return self.apply_super_shiny_hue_to_bitmap(ret, species, form, filename) if super_shiny
      return ret
    end

    def self.icon_bitmap_from_pokemon(pkmn)
      return self.icon_bitmap(pkmn.species, pkmn.form, pkmn.gender, pkmn.shiny?, pkmn.shadowPokemon?, pkmn.egg?)
    end

    #===========================================================================

    def self.footprint_filename(species, form = 0)
      species_data = self.get_species_form(species, form)
      return nil if species_data.nil?
      if form > 0
        ret = pbResolveBitmap(sprintf("Graphics/Pokemon/Footprints/%s_%d", species_data.species, form))
        return ret if ret
      end
      return pbResolveBitmap(sprintf("Graphics/Pokemon/Footprints/%s", species_data.species))
    end

    #===========================================================================

    def self.shadow_filename(species, form = 0)
      species_data = self.get_species_form(species, form)
      return nil if species_data.nil?
      # Look for species-specific shadow graphic
      if form > 0
        ret = pbResolveBitmap(sprintf("Graphics/Pokemon/Shadow/%s_%d", species_data.species, form))
        return ret if ret
      end
      ret = pbResolveBitmap(sprintf("Graphics/Pokemon/Shadow/%s", species_data.species))
      return ret if ret
      # Use general shadow graphic
      metrics_data = GameData::SpeciesMetrics.get_species_form(species_data.species, form)
      return pbResolveBitmap(sprintf("Graphics/Pokemon/Shadow/%d", metrics_data.shadow_size))
    end

    def self.shadow_bitmap(species, form = 0)
      filename = self.shadow_filename(species, form)
      return (filename) ? AnimatedBitmap.new(filename) : nil
    end

    def self.shadow_bitmap_from_pokemon(pkmn)
      filename = self.shadow_filename(pkmn.species, pkmn.form)
      return (filename) ? AnimatedBitmap.new(filename) : nil
    end

    #===========================================================================

    def self.check_cry_file(species, form, suffix = "")
      species_data = self.get_species_form(species, form)
      return nil if species_data.nil?
      if form > 0
        ret = sprintf("Cries/%s_%d%s", species_data.species, form, suffix)
        return ret if pbResolveAudioSE(ret)
      end
      ret = sprintf("Cries/%s%s", species_data.species, suffix)
      return (pbResolveAudioSE(ret)) ? ret : nil
    end

    def self.cry_filename(species, form = 0, suffix = "")
      return self.check_cry_file(species, form || 0, suffix)
    end

    def self.cry_filename_from_pokemon(pkmn, suffix = "")
      return self.check_cry_file(pkmn.species, pkmn.form, suffix)
    end

    def self.play_cry_from_species(species, form = 0, volume = 90, pitch = 100)
      filename = self.cry_filename(species, form)
      return if !filename
      pbPokemonCryPlay(RPG::AudioFile.new(filename, volume, pitch)) rescue nil
    end

    def self.play_cry_from_pokemon(pkmn, volume = 90, pitch = 100)
      return if !pkmn || pkmn.egg?
      filename = self.cry_filename_from_pokemon(pkmn)
      return if !filename
      pitch ||= 100
      pbPokemonCryPlay(RPG::AudioFile.new(filename, volume, pitch)) rescue nil
    end

    def self.play_cry(pkmn, volume = 90, pitch = 100)
      if pkmn.is_a?(Pokemon)
        self.play_cry_from_pokemon(pkmn, volume, pitch)
      else
        self.play_cry_from_species(pkmn, 0, volume, pitch)
      end
    end

    def self.cry_length(species, form = 0, pitch = 100, suffix = "")
      pitch ||= 100
      return 0 if !species || pitch <= 0
      pitch = pitch.to_f / 100
      ret = 0.0
      if species.is_a?(Pokemon)
        if !species.egg?
          filename = self.cry_filename_from_pokemon(species, suffix)
          filename = self.cry_filename_from_pokemon(species) if !filename && !nil_or_empty?(suffix)
          filename = pbResolveAudioSE(filename)
          ret = getPlayTime(filename) if filename
        end
      else
        filename = self.cry_filename(species, form, suffix)
        filename = self.cry_filename(species, form) if !filename && !nil_or_empty?(suffix)
        filename = pbResolveAudioSE(filename)
        ret = getPlayTime(filename) if filename
      end
      ret /= pitch   # Sound played at a lower pitch lasts longer
      return ret
    end
  end
end

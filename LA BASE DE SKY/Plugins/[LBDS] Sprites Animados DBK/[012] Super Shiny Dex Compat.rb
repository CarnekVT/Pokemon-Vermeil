# Compatibilidad dex súper variocolor: funciona con base antigua o actualizada.
# Hue: Pokemon#super_shiny_hue del DBK. Base gráfica: sprite shiny + hue_change (como el summary DBK).
# Restaura DeluxeBitmapWrapper en sprite_bitmap (la base nueva usa AnimatedBitmap).

module DBKSuperShinyCompat
  module_function

  def method_accepts_param?(method, param_name)
    return method.parameters.any? { |_, name| name == param_name }
  end

  def species_method_accepts?(method_name, param_name)
    return false if !GameData::Species.respond_to?(method_name)
    return method_accepts_param?(GameData::Species.method(method_name), param_name)
  end

  def hue_for_species_form(species, form, female = false)
    metrics = GameData::SpeciesMetrics.get_species_form(species, form, female)
    species_hue = metrics.instance_variable_get(:@super_shiny_hue)
    return species_hue if species_hue && species_hue != 0
    species_symbol = GameData::Species.get_species_form(species, form).id
    species_hash = species_symbol.to_s.sum
    return ((species_hash % 7) + 1) * 45
  end

  def super_shiny_active?(shiny, super_shiny = false)
    return true if super_shiny
    return shiny.is_a?(Integer) && shiny >= 2
  end

  def icon_filename(species, form, gender, shiny, super_shiny)
    file_shiny = (shiny && shiny != 0)
    file_shiny = true if super_shiny && !file_shiny
    if super_shiny && species_method_accepts?(:icon_filename, :super_shiny)
      dedicated = GameData::Species.icon_filename(species, form, gender, shiny, false, false, true)
      return dedicated if dedicated && dedicated.include?("supershiny")
      return GameData::Species.icon_filename(species, form, gender, file_shiny, false, false, false)
    end
    if species_method_accepts?(:icon_filename, :super_shiny)
      return GameData::Species.icon_filename(species, form, gender, shiny, false, false, super_shiny)
    end
    return GameData::Species.icon_filename(species, form, gender, file_shiny)
  end

  def resolve_sprite_filename(species, form, gender, shiny, shadow, back, super_shiny)
    file_shiny = (shiny && shiny != 0)
    file_shiny = true if super_shiny && !file_shiny
    if super_shiny && species_method_accepts?(:front_sprite_filename, :super_shiny)
      if back
        dedicated = GameData::Species.back_sprite_filename(species, form, gender, false, shadow, true)
        return dedicated if dedicated && dedicated.include?("supershiny")
        return GameData::Species.back_sprite_filename(species, form, gender, file_shiny, shadow)
      end
      dedicated = GameData::Species.front_sprite_filename(species, form, gender, false, shadow, true)
      return dedicated if dedicated && dedicated.include?("supershiny")
      return GameData::Species.front_sprite_filename(species, form, gender, file_shiny, shadow)
    end
    if back
      return GameData::Species.back_sprite_filename(species, form, gender, file_shiny, shadow)
    end
    return GameData::Species.front_sprite_filename(species, form, gender, file_shiny, shadow)
  end

  def super_shiny_sprite_bitmap(species, form, gender, shiny, shadow, back)
    filename = resolve_sprite_filename(species, form, gender, shiny, shadow, back, true)
    return nil if !filename
    sp_data = GameData::SpeciesMetrics.get_species_form(species, form, gender == 1)
    ret = DeluxeBitmapWrapper.new(filename, sp_data, back)
    hue = hue_for_species_form(species, form, gender == 1)
    ret.hue_change(hue) if hue != 0 && !filename.include?("supershiny")
    return ret
  end
end

module DBK_SpeciesSpriteBitmap
  def sprite_bitmap(species, form = 0, gender = 0, shiny = false, shadow = false, back = false, egg = false, super_shiny = false)
    return self.egg_sprite_bitmap(species, form) if egg
    if super_shiny
      return DBKSuperShinyCompat.super_shiny_sprite_bitmap(species, form, gender, shiny, shadow, back)
    end
    return self.back_sprite_bitmap(species, form, gender, shiny, shadow) if back
    return self.front_sprite_bitmap(species, form, gender, shiny, shadow)
  end
end
GameData::Species.singleton_class.prepend(DBK_SpeciesSpriteBitmap)

if GameData::Species.respond_to?(:super_shiny_hue_for)
  module DBK_SpeciesSuperShinyHue
    def super_shiny_hue_for(species, form = 0, for_display = false)
      return DBKSuperShinyCompat.hue_for_species_form(species, form, false)
    end
  end
  GameData::Species.singleton_class.prepend(DBK_SpeciesSuperShinyHue)
end

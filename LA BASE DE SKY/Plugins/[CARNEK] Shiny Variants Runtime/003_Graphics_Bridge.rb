#===============================================================================
# [CARNEK] Shiny Variants Runtime - Intercepción y Resolución de Gráficos
#===============================================================================
module GameData
  class Species
    class << self
      alias __orig_shinyvar_front_sprite_filename front_sprite_filename
      def front_sprite_filename(species, form = 0, gender = 0, shiny = false, shadow = false, super_shiny = false, variant = nil)
        if variant && variant != :none && variant != :shiny
          folder = "Front #{variant}"
          ret = self.check_graphic_file("Graphics/Pokemon/", species, form, gender, false, shadow, folder)
          return ret if ret
        end
        if super_shiny
          ret = self.check_graphic_file("Graphics/Pokemon/", species, form, gender, false, shadow, "Front supershiny")
          return ret if ret
        end
        return __orig_shinyvar_front_sprite_filename(species, form, gender, shiny, shadow, super_shiny)
      end

      alias __orig_shinyvar_back_sprite_filename back_sprite_filename
      def back_sprite_filename(species, form = 0, gender = 0, shiny = false, shadow = false, super_shiny = false, variant = nil)
        if variant && variant != :none && variant != :shiny
          folder = "Back #{variant}"
          ret = self.check_graphic_file("Graphics/Pokemon/", species, form, gender, false, shadow, folder)
          return ret if ret
        end
        if super_shiny
          ret = self.check_graphic_file("Graphics/Pokemon/", species, form, gender, false, shadow, "Back supershiny")
          return ret if ret
        end
        return __orig_shinyvar_back_sprite_filename(species, form, gender, shiny, shadow, super_shiny)
      end

      alias __orig_shinyvar_icon_filename icon_filename
      def icon_filename(species, form = 0, gender = 0, shiny = false, shadow = false, egg = false, super_shiny = false, variant = nil)
        return self.egg_icon_filename(species, form) if egg
        if variant && variant != :none && variant != :shiny
          folder = "Icons #{variant}"
          ret = self.check_graphic_file("Graphics/Pokemon/", species, form, gender, false, shadow, folder)
          return ret if ret
        end
        if super_shiny
          ret = self.check_graphic_file("Graphics/Pokemon/", species, form, gender, false, shadow, "Icons supershiny")
          return ret if ret
        end
        return __orig_shinyvar_icon_filename(species, form, gender, shiny, shadow, egg, super_shiny)
      end

      alias __orig_shinyvar_icon_filename_from_pokemon icon_filename_from_pokemon
      def icon_filename_from_pokemon(pkmn)
        return self.egg_icon_filename(pkmn.species, pkmn.form) if pkmn.egg?
        v = pkmn.shiny_variant
        if v != :none && v != :shiny
          ret = self.icon_filename(pkmn.species, pkmn.form, pkmn.gender, pkmn.shiny?, pkmn.shadowPokemon?, pkmn.egg?, (v == :supershiny), v)
          return ret if ret
        end
        return __orig_shinyvar_icon_filename_from_pokemon(pkmn)
      end

      # Método de utilidad para resolver la ruta de sprite de un Pokémon con variantes
      def sprite_filename_from_pokemon(pkmn, back = false, species = nil)
        return self.egg_sprite_filename(species || pkmn.species, pkmn.form) if pkmn.egg?
        sp = species || pkmn.species
        v = pkmn.shiny_variant
        if v != :none && v != :shiny
          folder = back ? "Back #{v}" : "Front #{v}"
          ret = self.check_graphic_file("Graphics/Pokemon/", sp, pkmn.form, pkmn.gender, false, pkmn.shadowPokemon?, folder)
          return ret if ret
        end
        if back
          return self.back_sprite_filename(sp, pkmn.form, pkmn.gender, pkmn.shiny?, pkmn.shadowPokemon?, pkmn.super_shiny?)
        else
          return self.front_sprite_filename(sp, pkmn.form, pkmn.gender, pkmn.shiny?, pkmn.shadowPokemon?, pkmn.super_shiny?)
        end
      end

      alias __orig_shinyvar_sprite_bitmap_from_pokemon sprite_bitmap_from_pokemon
      def sprite_bitmap_from_pokemon(pkmn, back = false, species = nil)
        return self.egg_sprite_bitmap(species || pkmn.species, pkmn.form) if pkmn.egg?
        sp = species || pkmn.species
        sp = GameData::Species.get(sp).species
        v = pkmn.shiny_variant
        if v != :none && v != :shiny
          fn = self.sprite_filename_from_pokemon(pkmn, back, sp)
          if fn && pbResolveBitmap(fn)
            is_dedicated = fn.include?("supershiny") || ShinyVariantRegistry.all.any? { |entry| fn.include?(entry["id"]) }
            if is_dedicated
              if defined?(DeluxeBitmapWrapper)
                sp_data = GameData::SpeciesMetrics.get_species_form(sp, pkmn.form, pkmn.gender == 1)
                ret = DeluxeBitmapWrapper.new(fn, sp_data, back)
                ret.compile_strip(pkmn, back) if ret.respond_to?(:compile_strip)
                return ret
              else
                ret = AnimatedBitmap.new(fn)
                alter_bitmap_function = MultipleForms.getFunction(sp, "alterBitmap")
                if ret && alter_bitmap_function
                  new_ret = ret.copy
                  ret.dispose
                  new_ret.each { |bitmap| alter_bitmap_function.call(pkmn, bitmap) }
                  ret = new_ret
                end
                return ret
              end
            end
          end
        end
        return __orig_shinyvar_sprite_bitmap_from_pokemon(pkmn, back, species)
      end
    end
  end
end

# Hook para evitar que DeluxeBitmapWrapper altere el tono (hue) de sprites con arte dedicado
if defined?(DeluxeBitmapWrapper)
  class DeluxeBitmapWrapper
    alias __shinyvar_setPokemon setPokemon
    def setPokemon(pokemon, back = false, hue = nil, species = nil)
      is_dedicated = false
      if @bmp_file.is_a?(String)
        is_dedicated = @bmp_file.include?("supershiny") || 
                       ShinyVariantRegistry.all.any? { |v| @bmp_file.include?(v["id"]) }
      end
      if is_dedicated
        @pokemon = pokemon
        return if !@pokemon
        pk = @pokemon.is_a?(Battle::Battler) ? @pokemon.visiblePokemon : @pokemon
        sp = species || pk.species
        metrics = GameData::SpeciesMetrics.get_species_form(sp, pk.form, pk.gender == 1)
        if $PokemonSystem.animated_sprites == 0
          @speed = (back) ? metrics.back_sprite_speed : metrics.front_sprite_speed
          @base_speed = @speed
        end
        if pk.fainted?
          @speed = 0
          @base_speed = 0
        end
        @changed_hue = true
        return
      end
      __shinyvar_setPokemon(pokemon, back, hue, species)
    end
  end
end

# Hook para pantalla de resumen (Summary Scene)
class PokemonSprite < Sprite
  alias __shinyvar_setSummaryBitmap setSummaryBitmap if method_defined?(:setSummaryBitmap)
  def setSummaryBitmap(pkmn, back = false)
    if pkmn && pkmn.respond_to?(:shiny_variant) && pkmn.shiny_variant != :none && pkmn.shiny_variant != :shiny
      fn = GameData::Species.sprite_filename_from_pokemon(pkmn, back)
      if fn && pbResolveBitmap(fn) && (fn.include?("supershiny") || ShinyVariantRegistry.all.any? { |v| fn.include?(v["id"]) })
        @_iconbitmap&.dispose
        @pkmn = pkmn
        scale = defined?(Settings::FRONT_BATTLER_SPRITE_SCALE) ? Settings::FRONT_BATTLER_SPRITE_SCALE : 1
        bitmap = DeluxeBitmapWrapper.new(fn, [scale, 1], back)
        bitmap.compile_strip(@pkmn, back) if bitmap.respond_to?(:compile_strip)
        bitmap.setPokemon(@pkmn, back)
        bitmap.update_pokemon_sprite if bitmap.respond_to?(:update_pokemon_sprite)
        @_iconbitmap = bitmap
        self.bitmap = @_iconbitmap.bitmap
        self.color = Color.new(0, 0, 0, 0)
        self.set_plugin_pattern(@pkmn) if respond_to?(:set_plugin_pattern)
        changeOrigin if respond_to?(:changeOrigin)
        pbSetDisplay if respond_to?(:pbSetDisplay)
        return
      end
    end
    __shinyvar_setSummaryBitmap(pkmn, back) if defined?(__shinyvar_setSummaryBitmap)
  end
end

# Hook para icono en equipo / menús (PokemonIconSprite) sin distorsión de tono cuando hay icono dedicado
class PokemonIconSprite < Sprite
  alias __shinyvar_pokemon_assign pokemon= if method_defined?(:pokemon=)
  def pokemon=(value)
    __shinyvar_pokemon_assign(value) if defined?(__shinyvar_pokemon_assign)
    return if !value || (value.respond_to?(:egg?) && value.egg?) || !value.respond_to?(:shiny_variant)
    v = value.shiny_variant
    if v != :none && v != :shiny
      fn = GameData::Species.icon_filename_from_pokemon(value)
      if fn && pbResolveBitmap(fn) && (fn.include?("supershiny") || ShinyVariantRegistry.all.any? { |var| fn.include?(var["id"].to_s) })
        @animBitmap&.dispose
        @animBitmap = AnimatedBitmap.new(fn, 0)
        self.bitmap = @animBitmap.bitmap
        self.src_rect.width  = @animBitmap.height
        self.src_rect.height = @animBitmap.height
        self.set_plugin_icon_pattern if respond_to?(:set_plugin_icon_pattern)
        @frames_count = @animBitmap.width / @animBitmap.height
        @current_frame = 0 if @current_frame >= @frames_count
        changeOrigin if respond_to?(:changeOrigin)
      end
    end
  end
end

# Hook para icono en almacenamiento / cajas del PC (PokemonBoxIcon)
class PokemonBoxIcon < IconSprite
  alias __shinyvar_box_refresh refresh if method_defined?(:refresh)
  def refresh
    return if !@pokemon || (respond_to?(:egg?) && egg?)
    v = @pokemon.respond_to?(:shiny_variant) ? @pokemon.shiny_variant : :none
    if v != :none && v != :shiny
      fn = GameData::Species.icon_filename_from_pokemon(@pokemon)
      if fn && pbResolveBitmap(fn) && (fn.include?("supershiny") || ShinyVariantRegistry.all.any? { |var| fn.include?(var["id"].to_s) })
        self.setBitmap(fn, 0)
        self.src_rect = Rect.new(0, 0, self.bitmap.height, self.bitmap.height)
        self.set_shadow_pattern(@pokemon) if respond_to?(:set_shadow_pattern)
        return
      end
    end
    __shinyvar_box_refresh if defined?(__shinyvar_box_refresh)
  end
end

# Hook para icono de especie (PokemonSpeciesIconSprite) sin distorsión de tono cuando hay icono dedicado
if defined?(PokemonSpeciesIconSprite)
  class PokemonSpeciesIconSprite < Sprite
    attr_accessor :shiny_variant
    alias __shinyvar_species_refresh refresh if method_defined?(:refresh)
    def refresh
      __shinyvar_species_refresh if defined?(__shinyvar_species_refresh)
      return if !@species
      v = instance_variable_defined?(:@shiny_variant) ? @shiny_variant : :none
      if v != :none && v != :shiny
        fn = GameData::Species.icon_filename(@species, @form, @gender, @shiny, false, false, (v == :supershiny), v)
        if fn && pbResolveBitmap(fn) && (fn.include?("supershiny") || ShinyVariantRegistry.all.any? { |var| fn.include?(var["id"].to_s) })
          @animBitmap&.dispose
          @animBitmap = AnimatedBitmap.new(fn, 0)
          self.bitmap = @animBitmap.bitmap
          self.src_rect.width  = @animBitmap.height
          self.src_rect.height = @animBitmap.height
          @frames_count = @animBitmap.width / @animBitmap.height
          @current_frame = 0 if @current_frame >= @frames_count
          changeOrigin if respond_to?(:changeOrigin)
        end
      end
    end
  end
end


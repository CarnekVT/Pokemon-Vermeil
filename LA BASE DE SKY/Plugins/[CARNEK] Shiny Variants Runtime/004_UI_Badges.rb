#===============================================================================
# [CARNEK] Shiny Variants Runtime - Insignias y Marcadores de UI
#===============================================================================

#-------------------------------------------------------------------------------
# 1. Marcador en la pantalla del equipo (Party Screen)
#-------------------------------------------------------------------------------
class PokemonPartyPanel < Sprite
  alias __orig_shinyvar_draw_shiny_icon draw_shiny_icon if method_defined?(:draw_shiny_icon)
  def draw_shiny_icon
    return if !@pokemon || @pokemon.egg? || !@pokemon.shiny?
    v = @pokemon.respond_to?(:shiny_variant) ? @pokemon.shiny_variant : :none
    if v != :none && v != :shiny
      badge_path = ShinyVariantRegistry.badge_path(v)
      if badge_path && pbResolveBitmap(badge_path)
        x = self.class.const_defined?(:UI_SHINY_X) ? self.class.const_get(:UI_SHINY_X) : (defined?(UI_SHINY_X) ? UI_SHINY_X : 80)
        y = self.class.const_defined?(:UI_SHINY_Y) ? self.class.const_get(:UI_SHINY_Y) : (defined?(UI_SHINY_Y) ? UI_SHINY_Y : 48)
        pbDrawImagePositions(@overlaysprite.bitmap, [[badge_path, x, y]])
        return
      end
    end
    __orig_shinyvar_draw_shiny_icon if defined?(__orig_shinyvar_draw_shiny_icon)
  end
end

#-------------------------------------------------------------------------------
# 2. Marcador en la pantalla de Resumen (Summary Scene)
#-------------------------------------------------------------------------------
class PokemonSummary_Scene
  alias __orig_shinyvar_drawPage drawPage if method_defined?(:drawPage)
  def drawPage(page)
    __orig_shinyvar_drawPage(page) if defined?(__orig_shinyvar_drawPage)
    draw_shiny_variant_badge
  end

  def draw_shiny_variant_badge
    return if !@pokemon || @pokemon.egg? || !@pokemon.shiny?
    v = @pokemon.respond_to?(:shiny_variant) ? @pokemon.shiny_variant : :none
    return if v == :shiny || v == :none
    badge_path = ShinyVariantRegistry.badge_path(v)
    return if !badge_path || !pbResolveBitmap(badge_path)
    overlay = @sprites["overlay"]&.bitmap
    return if !overlay || overlay.disposed?

    x = self.class.const_defined?(:IMG_SHINY_X) ? self.class.const_get(:IMG_SHINY_X) : (defined?(IMG_SHINY_X) ? IMG_SHINY_X : 174)
    y = self.class.const_defined?(:IMG_SHINY_Y) ? self.class.const_get(:IMG_SHINY_Y) : (defined?(IMG_SHINY_Y) ? IMG_SHINY_Y : 100)
    # Limpia el icono de shiny vanilla previo y dibuja el badge de la variante
    overlay.fill_rect(x, y, 24, 24, Color.new(0, 0, 0, 0))
    pbDrawImagePositions(overlay, [[badge_path, x, y]])
  end
end

#-------------------------------------------------------------------------------
# 3. Marcador en el PC / Almacenamiento (PokemonStorageScene)
#-------------------------------------------------------------------------------
class PokemonStorageScene
  alias __orig_shinyvar_pbUpdateOverlay pbUpdateOverlay if method_defined?(:pbUpdateOverlay)
  def pbUpdateOverlay(selection, party = nil)
    __orig_shinyvar_pbUpdateOverlay(selection, party) if defined?(__orig_shinyvar_pbUpdateOverlay)
    draw_shiny_variant_badge(selection, party)
  end

  def draw_shiny_variant_badge(selection, party = nil)
    pokemon = nil
    if @screen && @screen.respond_to?(:pbHeldPokemon) && @screen.pbHeldPokemon
      pokemon = @screen.pbHeldPokemon
    elsif selection && selection >= 0
      pokemon = (party) ? party[selection] : (@storage ? @storage[@storage.currentBox, selection] : nil)
    end
    return if !pokemon || pokemon.egg? || !pokemon.shiny?
    v = pokemon.respond_to?(:shiny_variant) ? pokemon.shiny_variant : :none
    return if v == :shiny || v == :none
    badge_path = ShinyVariantRegistry.badge_path(v)
    return if !badge_path || !pbResolveBitmap(badge_path)

    x = self.class.const_defined?(:SHINY_ICON_X) ? self.class.const_get(:SHINY_ICON_X) : (defined?(SHINY_ICON_X) ? SHINY_ICON_X : 160)
    y = self.class.const_defined?(:SHINY_ICON_Y) ? self.class.const_get(:SHINY_ICON_Y) : (defined?(SHINY_ICON_Y) ? SHINY_ICON_Y : 250)

    # Limpiar y dibujar en plugin_overlay si existe (MUI / 640x480 fix) o en overlay vanilla
    target_bitmap = nil
    if @sprites["plugin_overlay"] && !@sprites["plugin_overlay"].disposed? && @sprites["plugin_overlay"].bitmap
      @sprites["plugin_overlay"].bitmap.fill_rect(x, y, 24, 24, Color.new(0, 0, 0, 0))
      target_bitmap = @sprites["plugin_overlay"].bitmap
    end
    if @sprites["overlay"] && !@sprites["overlay"].disposed? && @sprites["overlay"].bitmap
      @sprites["overlay"].bitmap.fill_rect(x, y, 24, 24, Color.new(0, 0, 0, 0))
      target_bitmap ||= @sprites["overlay"].bitmap
    end
    pbDrawImagePositions(target_bitmap, [[badge_path, x, y]]) if target_bitmap
  end
end

#-------------------------------------------------------------------------------
# 4. Marcador en la Bolsa con Equipo (Bag with Party)
#-------------------------------------------------------------------------------
if defined?(PokemonBagPartyPanel)
  class PokemonBagPartyPanel < Sprite
    alias __orig_shinyvar_bag_refresh refresh if method_defined?(:refresh)
    def refresh
      __orig_shinyvar_bag_refresh if defined?(__orig_shinyvar_bag_refresh)
      return if disposed? || !@pokemon || @pokemon.egg? || !@pokemon.shiny?
      return if !@overlaysprite || @overlaysprite.disposed? || !@overlaysprite.bitmap
      return if defined?(BagScreenWiInParty::SHINYICON) && !BagScreenWiInParty::SHINYICON
      v = @pokemon.respond_to?(:shiny_variant) ? @pokemon.shiny_variant : :none
      return if v == :shiny || v == :none
      badge_path = ShinyVariantRegistry.badge_path(v)
      if badge_path && pbResolveBitmap(badge_path)
        x = self.class.const_defined?(:SHINY_ICON_X) ? self.class.const_get(:SHINY_ICON_X) : (defined?(SHINY_ICON_X) ? SHINY_ICON_X : 84)
        y = self.class.const_defined?(:SHINY_ICON_Y) ? self.class.const_get(:SHINY_ICON_Y) : (defined?(SHINY_ICON_Y) ? SHINY_ICON_Y : 44)
        @overlaysprite.bitmap.fill_rect(x, y, 20, 20, Color.new(0, 0, 0, 0))
        pbDrawImagePositions(@overlaysprite.bitmap, [[badge_path, x, y]])
      end
    end
  end
end

#-------------------------------------------------------------------------------
# 5. Marcador en la Barra de Combate (Battle Databox)
#-------------------------------------------------------------------------------
if defined?(Battle::Scene::PokemonDataBox)
  class Battle::Scene::PokemonDataBox < Sprite
    # Modo vanilla
    alias __orig_shinyvar_draw_shiny_icon draw_shiny_icon if method_defined?(:draw_shiny_icon)
    def draw_shiny_icon
      return if !@battler || !@battler.shiny?
      v = @battler.respond_to?(:shiny_variant) ? @battler.shiny_variant : (@battler.pokemon&.shiny_variant || :none)
      if v != :none && v != :shiny
        badge = ShinyVariantRegistry.badge_path(v)
        if badge && pbResolveBitmap(badge)
          shiny_x = (@battler.opposes?(0)) ? SHINY_ICON_FOE_X : SHINY_ICON_PLYR_X
          pbDrawImagePositions(self.bitmap, [[badge, @spriteBaseX + shiny_x, SHINY_ICON_Y]])
          return
        end
      end
      __orig_shinyvar_draw_shiny_icon if defined?(__orig_shinyvar_draw_shiny_icon)
    end

    # Modo estilizado de Deluxe Battle Kit (DBK)
    alias __orig_shinyvar_draw_plugin_elements draw_plugin_elements if method_defined?(:draw_plugin_elements)
    def draw_plugin_elements
      __orig_shinyvar_draw_plugin_elements if defined?(__orig_shinyvar_draw_plugin_elements)
      return if !@battler || !@battler.shiny?
      return if !@style || !@displayPos || !@displayPos[:shiny]
      v = @battler.respond_to?(:shiny_variant) ? @battler.shiny_variant : (@battler.pokemon&.shiny_variant || :none)
      return if v == :none || v == :shiny
      badge = ShinyVariantRegistry.badge_path(v)
      if badge && pbResolveBitmap(badge)
        pos = @displayPos[:shiny]
        if @databoxBitmap && !@databoxBitmap.disposed? && @databoxBitmap.bitmap
          self.bitmap.blt(pos[0], pos[1], @databoxBitmap.bitmap, Rect.new(pos[0], pos[1], 24, 24))
        end
        pbDrawImagePositions(self.bitmap, [[badge, pos[0], pos[1]]])
      end
    end
  end
end

#-------------------------------------------------------------------------------
# 6. Marcador en Info del Combatiente (Enhanced Battle UI / Battler Info)
#-------------------------------------------------------------------------------
if defined?(Battle::Scene)
  class Battle::Scene
    alias __orig_shinyvar_pbUpdateBattlerInfo pbUpdateBattlerInfo if method_defined?(:pbUpdateBattlerInfo)
    def pbUpdateBattlerInfo(battler, effects, idxEffect = 0)
      __orig_shinyvar_pbUpdateBattlerInfo(battler, effects, idxEffect) if defined?(__orig_shinyvar_pbUpdateBattlerInfo)
      return if @enhancedUIToggle != :battler || !@enhancedUIOverlay || @enhancedUIOverlay.disposed?
      poke = (battler.respond_to?(:opposes?) && battler.opposes?) ? battler.displayPokemon : battler.pokemon
      return if !poke || !poke.shiny?
      v = poke.respond_to?(:shiny_variant) ? poke.shiny_variant : :none
      return if v == :none || v == :shiny
      badge_path = ShinyVariantRegistry.badge_path(v)
      if badge_path && pbResolveBitmap(badge_path)
        xpos = 28
        ypos = 24
        bx = xpos + 142
        by = ypos + 102
        @enhancedUIOverlay.fill_rect(bx, by, 24, 24, Color.new(0, 0, 0, 0))
        pbDrawImagePositions(@enhancedUIOverlay, [[badge_path, bx, by]])
      end
    end
  end
end

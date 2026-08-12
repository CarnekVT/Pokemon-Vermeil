#===============================================================================
# [ZBOX] Summary 640 v2.0
# Adapta la pantalla de Resumen (MUI Modular UI Scenes + Enhanced Pokemon UI)
# de 512x384 a 640x480 escalando posiciones y textos x1.25 en runtime.
# Sin dependencia de plugins externos.
#
# Estrategia:
#   - Constantes de posicion numericas se reescriben escaladas x1.25.
#   - El fondo (IconSprite) se escala con zoom_x/zoom_y (setBitmap no lo resetea).
#   - Iconos que van acoplados a una celda (page icons, flechas) se estiran
#     con stretch_blt para que sigan llenando su celda.
#   - Iconos sueltos (ball, status, types, shiny, cursors, cintas...) se dibujan
#     1:1 en su posicion escalada.
#   - Fuentes (26px) y barritas de progreso (HP/Exp/felicidad) NO se escalan.
#
# ponytail: las barritas de progreso y la pantalla de marcas/legacy se dejan en
# tamano nativo (1:1) en posicion escalada; redibujarlas estiradas exigiria
# reimplementar drawPageOne/drawPageThree/pbLegacyMenu completos.
#===============================================================================
module Summary640
  # Escala base: el juego corre a 640 de ancho sobre layouts de 512.
  SCALE = Graphics.width / 512.0

  # page_*.png son sprites de 104x60 = 2 frames de 52x60 (iluminado/apagado).
  PAGE_ICON_FRAME_WIDTH  = 52
  PAGE_ICON_FRAME_HEIGHT = 60

  #-----------------------------------------------------------------------------
  # Escala un valor numerico a enteros de pixel.
  #-----------------------------------------------------------------------------
  def self.scale(value)
    return (value * SCALE).round
  end

  #-----------------------------------------------------------------------------
  # Reescribe una constante numerica (o array de numericos) escalada x1.25.
  #-----------------------------------------------------------------------------
  def self.scale_const(holder, const_name)
    return if !holder.const_defined?(const_name)
    val = holder.const_get(const_name)
    if val.is_a?(Numeric)
      holder.const_set(const_name, scale(val))
    elsif val.is_a?(Array) && val.all? { |v| v.is_a?(Numeric) }
      holder.const_set(const_name, val.map { |v| scale(v) })
    end
  end

  #-----------------------------------------------------------------------------
  # Dibuja un trozo de una imagen estirado x1.25 en (x, y).
  # Usa RPG::Cache (BitmapWrapper con refcount, seguro de dispose).
  #-----------------------------------------------------------------------------
  def self.draw_image(dst_bitmap, path, x, y, src_x, src_y, src_w, src_h)
    bmp = RPG::Cache.load_bitmap("", path)
    dst_bitmap.stretch_blt(Rect.new(x, y, (src_w * SCALE).round, (src_h * SCALE).round),
                           bmp, Rect.new(src_x, src_y, src_w, src_h))
    bmp.dispose
  end

  #-----------------------------------------------------------------------------
  # Escala todas las constantes de posicion de la pantalla de Resumen.
  # NO se escalan: MARK_* (tiles del spritesheet de marcas), MAX_PAGE_ICONS /
  # COLUMNS_PER_ROW (contadores), HAPPY_METER_WIDTH_MAX (fraccion de relleno),
  # PAGE_ARROWS_* (coords src del spritesheet), HP_BAR_*/TYPE_ICON_WIDTH/HEIGHT
  # (coords src, solo usadas por la vista Enhanced desactivada).
  #-----------------------------------------------------------------------------
  def self.scale_summary_constants
    scene = PokemonSummary_Scene
    list = %i[
      UI_POKEMON_SPRITE_X UI_POKEMON_SPRITE_Y UI_POKEICON_X UI_POKEICON_Y
      UI_ITEMICON_X UI_ITEMICON_Y UI_UP_ARROW_X UI_UP_ARROW_Y UI_DOWN_ARROW_X UI_DOWN_ARROW_Y
      UI_MARKING_BG_X UI_MARKING_BG_Y
      TEXT_PAGE_NAME_X TEXT_PAGE_NAME_Y TEXT_NAME_X TEXT_NAME_Y TEXT_LEVEL_X TEXT_LEVEL_Y
      TEXT_ITEM_LABEL_X TEXT_ITEM_LABEL_Y TEXT_ITEM_NAME_X TEXT_ITEM_NAME_Y
      TEXT_GENDER_X TEXT_GENDER_Y
      SHADOW_DESCRIPTION_X_MUI SHADOW_DESCRIPTION_Y_MUI SHADOW_DESCRIPTION_W_MUI
      SHADOW_DESCRIPTION_X_OFFSET SHADOW_DESCRIPTION_Y_OFFSET SHADOW_DESCRIPTION_H
      EGG_DATE_X EGG_DATE_Y EGG_TEXT_X EGG_TEXT_Y EGG_MEMO_WIDTH
      IMG_BALL_X IMG_BALL_Y IMG_STATUS_X IMG_STATUS_Y IMG_POKERUS_X IMG_POKERUS_Y
      IMG_SHINY_X IMG_SHINY_Y IMG_MARKINGS_X IMG_MARKINGS_Y
      P1_DEX_LABEL_X P1_DEX_LABEL_Y P1_SPECIES_LABEL_X P1_SPECIES_LABEL_Y
      P1_SPECIES_TEXT_X P1_SPECIES_TEXT_Y P1_TYPE_LABEL_X P1_TYPE_LABEL_Y
      P1_OT_LABEL_X P1_OT_LABEL_Y P1_ID_LABEL_X P1_ID_LABEL_Y
      P1_DEX_NUM_X P1_DEX_NUM_Y P1_OT_NAME_X P1_OT_NAME_Y P1_ID_NUM_X P1_ID_NUM_Y
      P1_EXP_LABEL_X P1_EXP_LABEL_Y P1_EXP_NUM_X P1_EXP_NUM_Y
      P1_NEXTLV_LABEL_X P1_NEXTLV_LABEL_Y P1_NEXTLV_NUM_X P1_NEXTLV_NUM_Y
      P1_TYPE_ICON_Y P1_TYPE_1_ICON_X P1_TYPE_2_ICON_X P1_EXP_BAR_X P1_EXP_BAR_Y
      P2_MEMO_X P2_MEMO_Y P2_MEMO_WIDTH
      P3_HP_LABEL_X P3_HP_LABEL_Y P3_HP_NUM_X P3_HP_NUM_Y P3_STAT_LABEL_X P3_STAT_NUM_X
      P3_ATTACK_Y P3_DEFENSE_Y P3_SPATK_Y P3_SPDEF_Y P3_SPEED_Y
      P3_ABILITY_LABEL_X P3_ABILITY_LABEL_Y P3_ABILITY_NAME_X P3_ABILITY_NAME_Y
      P3_ABILITY_DESC_X P3_ABILITY_DESC_Y P3_ABILITY_DESC_W P3_HP_BAR_X P3_HP_BAR_Y
      SHINY_CROWN_OFFSET_X SHINY_CROWN_OFFSET_Y SHINY_LEAF_SPACING_X SHINY_LEAF_SPACING_Y
      SHINY_LEAF_X SHINY_LEAF_Y SHINY_LEAF_BW_X SHINY_LEAF_BW_Y
      HAPPY_METER_X HAPPY_METER_Y
      IV_RATING_ICON_SIZE IV_RATING_SPACING_X IV_RATING_SPACING_Y
      IV_RATINGS_X IV_RATINGS_Y IV_RATINGS_BW_X IV_RATINGS_BW_Y
      IV_RATING_HP_GAP_STD IV_RATING_HP_GAP_BW
      P4_MOVE_LIST_Y P4_MOVE_OFFSET_Y P4_TYPE_ICON_X P4_TYPE_ICON_OFFSET_Y
      P4_MOVE_NAME_X P4_PP_LABEL_X P4_PP_LABEL_OFFSET_Y P4_PP_NUM_X P4_PP_NUM_OFFSET_Y
      P4_SEL_CATEGORY_LABEL_X P4_SEL_CATEGORY_LABEL_Y P4_SEL_POWER_LABEL_X P4_SEL_POWER_LABEL_Y
      P4_SEL_ACCURACY_LABEL_X P4_SEL_ACCURACY_LABEL_Y P4_SEL_VAL_X
      P4_SEL_VAL_POWER_Y P4_SEL_VAL_ACCURACY_Y P4_SEL_CAT_ICON_X P4_SEL_CAT_ICON_Y
      P4_SEL_DESC_X P4_SEL_DESC_Y P4_SEL_DESC_WIDTH P4_SEL_TYPE_Y
      P4_LEARN_DATA_LABEL_X P4_LEARN_DATA_LABEL_Y P4_LEARN_BOX_X P4_LEARN_BOX_Y
      P4_LEARN_ACTION_KEY_X P4_LEARN_ACTION_KEY_Y
      P5_RIBBON_COUNT_LABEL_X P5_RIBBON_COUNT_LABEL_Y P5_RIBBON_COUNT_NUM_X P5_RIBBON_COUNT_NUM_Y
      P5_RIBBON_LIST_X P5_RIBBON_LIST_Y P5_RIBBON_OFFSET_X P5_RIBBON_OFFSET_Y
      P5_SEL_BG_X P5_SEL_BG_Y P5_SEL_NAME_X P5_SEL_NAME_Y P5_SEL_DESC_X P5_SEL_DESC_Y P5_SEL_DESC_WIDTH
      BALL_IMAGE_X BALL_IMAGE_Y
      ABILITY_NAME_X ABILITY_NAME_Y ABILITY_NAME_WIDTH ABILITY_LABEL_X ABILITY_LABEL_Y
      ABILITY_DESC_X ABILITY_DESC_Y ABILITY_DESC_WIDTH ABILITY_DESC_HEIGHT
      SHADOW_DESCRIPTION_X SHADOW_DESCRIPTION_Y
      SHADOW_HEART_TEXT_X SHADOW_HEART_TEXT_Y SHADOW_HEART_TEXT_WIDTH
      PAGE_ICONS_POSITION PAGE_ICON_SIZE
      CENTER_ALIGNMENT_X_OFFSET RIGHT_ALIGNMENT_X_OFFSET PAGE_ICON_X_ADJUST
      LEFT_ARROW_X_OFFSET LEFT_ARROW_Y_OFFSET PAGE_ARROW_RIGHT_X_ADJUST
      ENHANCED_HP_X STATS_DEFAULT_X STATS_FIRST_Y STATS_Y_SPACING STATS_HP_Y
      STATS_NAME_SEPARATOR_X STATS_EV_X STATS_IV_X STATS_TOTAL_LABEL_X STATS_TOTAL_VALUE_X
      STATS_REMAIN_LABEL_X STATS_REMAIN_VALUE_X STATS_HIDDENPOWER_LABEL_X
      STATS_TOTAL_Y STATS_REMAIN_Y STATS_HIDDENPOWER_Y TYPE_ICON_X TYPE_ICON_Y
      LEGACY_ICON_X LEGACY_ICON_Y_OFFSET HISTORY_TEXT_X HISTORY_TEXT_Y_OFFSET NAME_Y_OFFSET
      ACHIEVE_X ACHIEVE_Y_OFFSET LEGACY_ARROW_RIGHT_X LEGACY_ARROW_RIGHT_Y_OFFSET
      LEGACY_ARROW_LEFT_X LEGACY_ARROW_LEFT_Y_OFFSET
      TOTAL_LABEL_X TOTAL_LABEL_Y IV_LABEL_X IV_LABEL_Y EV_LABEL_X EV_LABEL_Y
      HP_LABEL_X HP_LABEL_Y HP_VALUE_X HP_VALUE_Y HP_IV_X HP_IV_Y HP_EV_X HP_EV_Y
      ATK_LABEL_X ATK_LABEL_Y ATK_VALUE_X ATK_VALUE_Y ATK_IV_X ATK_IV_Y ATK_EV_X ATK_EV_Y
      DEF_LABEL_X DEF_LABEL_Y DEF_VALUE_X DEF_VALUE_Y DEF_IV_X DEF_IV_Y DEF_EV_X DEF_EV_Y
      SPA_LABEL_X SPA_LABEL_Y SPA_VALUE_X SPA_VALUE_Y SPA_IV_X SPA_IV_Y SPA_EV_X SPA_EV_Y
      SPDEF_LABEL_X SPDEF_LABEL_Y SPDEF_VALUE_X SPDEF_VALUE_Y SPDEF_IV_X SPDEF_IV_Y SPDEF_EV_X SPDEF_EV_Y
      SPEED_LABEL_X SPEED_LABEL_Y SPEED_VALUE_X SPEED_VALUE_Y SPEED_IV_X SPEED_IV_Y SPEED_EV_X SPEED_EV_Y
      TOTAL_EVS_LABEL_X TOTAL_EVS_LABEL_Y TOTAL_EVS_VALUE_X TOTAL_EVS_VALUE_Y
      HIDDEN_POWER_LABEL_X HIDDEN_POWER_LABEL_Y HIDDEN_POWER_ICON_X HIDDEN_POWER_ICON_Y
    ]
    list.each { |c| scale_const(scene, c) }
    %i[CURSOR_BASE_X CURSOR_BASE_Y CURSOR_OFFSET_Y FIFTH_MOVE_OFFSET_Y FIFTH_MOVE_GAP].each do |c|
      scale_const(MoveSelectionSprite, c)
    end
    %i[CURSOR_BASE_X CURSOR_BASE_Y CURSOR_OFFSET_X CURSOR_OFFSET_Y].each do |c|
      scale_const(RibbonSelectionSprite, c)
    end
  end
end

#===============================================================================
# Parches sobre PokemonSummary_Scene
#===============================================================================
class PokemonSummary_Scene

  #-----------------------------------------------------------------------------
  # Escala el fondo actual al tamano de pantalla. setBitmap no resetea zoom,
  # asi que basta re-aplicarlo tras cada cambio de fondo.
  #-----------------------------------------------------------------------------
  def _zbox_summary640_scale_background
    bg = @sprites["background"]
    return if bg.nil? || bg.disposed?
    bm = bg.bitmap
    return if bm.nil?
    if bm.height == 384
      bg.zoom_x = Summary640::SCALE
      bg.zoom_y = Summary640::SCALE
    else
      # Fondos no estandar (p.ej. variantes 640x440): rellenan el alto sin crop.
      bg.zoom_x = 1.0
      bg.zoom_y = (Graphics.height.to_f / bm.height).round(3)
    end
  end

  #-----------------------------------------------------------------------------
  # Fondo tras cada repintado de pagina.
  #-----------------------------------------------------------------------------
  alias_method :_zbox_summary640_orig_drawPage, :drawPage
  def drawPage(page)
    _zbox_summary640_orig_drawPage(page)
    _zbox_summary640_scale_background
  end

  #-----------------------------------------------------------------------------
  # Fondos de pantallas alternas (aprender/olvidar movimiento).
  #-----------------------------------------------------------------------------
  alias_method :_zbox_summary640_orig_drawPageFourSelecting, :drawPageFourSelecting
  def drawPageFourSelecting(move_to_learn)
    _zbox_summary640_orig_drawPageFourSelecting(move_to_learn)
    _zbox_summary640_scale_background
  end

  #-----------------------------------------------------------------------------
  # Fondos de descripciones de habilidad / shadow.
  #-----------------------------------------------------------------------------
  alias_method :_zbox_summary640_orig_showAbilityDescription, :showAbilityDescription
  def showAbilityDescription(pokemon)
    _zbox_summary640_orig_showAbilityDescription(pokemon)
    _zbox_summary640_scale_background
  end

  alias_method :_zbox_summary640_orig_showShadowDescription, :showShadowDescription
  def showShadowDescription(pokemon)
    _zbox_summary640_orig_showShadowDescription(pokemon)
    _zbox_summary640_scale_background
  end

  #-----------------------------------------------------------------------------
  # Escala el panel de fondo de la pantalla de marcas al abrir la escena.
  #-----------------------------------------------------------------------------
  alias_method :_zbox_summary640_orig_pbStartScene, :pbStartScene
  def pbStartScene(*args)
    _zbox_summary640_orig_pbStartScene(*args)
    markbg = @sprites["markingbg"]
    if markbg && !markbg.disposed?
      markbg.zoom_x = Summary640::SCALE
      markbg.zoom_y = Summary640::SCALE
    end
  end

  #-----------------------------------------------------------------------------
  # Iconos de pagina reescritos: se estiran al tamano de celda escalada.
  # (pbDrawImagePositions no estira; por eso se usa stretch_blt).
  #-----------------------------------------------------------------------------
  def drawPageIcons
    setPages if !@page_list || @page_list.empty?
    iconPos    = 0
    xpos, ypos = PAGE_ICONS_POSITION
    w, h       = PAGE_ICON_SIZE
    frame_w    = Summary640::PAGE_ICON_FRAME_WIDTH
    frame_h    = Summary640::PAGE_ICON_FRAME_HEIGHT
    size       = MAX_PAGE_ICONS - 1
    range      = [@page_list.length, MAX_PAGE_ICONS]
    page       = @page_list.find_index(@page_id)
    startPage  = (page > size) ? page - size : 0
    endPage    = [startPage + size, @page_list.length - 1].min
    case PAGE_ICONS_ALIGNMENT
    when :left   then offset = 0
    when :right  then offset = (Graphics.width - xpos + RIGHT_ALIGNMENT_X_OFFSET) - (w * range.min)
    when :center then offset = (Graphics.width - xpos + CENTER_ALIGNMENT_X_OFFSET) / 2 - (range.min * (w / 2))
    end
    overlay = @sprites["overlay"].bitmap
    for i in startPage..endPage
      suffix = UIHandlers.get_info(:summary, @page_list[i], :suffix)
      path   = "Graphics/UI/Summary/page_#{suffix}"
      src_x  = (page == i) ? frame_w : 0
      Summary640.draw_image(overlay, path, xpos + offset + (iconPos * w) + PAGE_ICON_X_ADJUST, ypos,
                            src_x, 0, frame_w, frame_h)
      iconPos += 1
    end
    if PAGE_ICONS_SHOW_ARROWS
      path = "Graphics/UI/Summary/page_arrows"
      if page > size
        Summary640.draw_image(overlay, path, xpos + offset + LEFT_ARROW_X_OFFSET, ypos + LEFT_ARROW_Y_OFFSET,
                              PAGE_ARROWS_SRC_LEFT_X, PAGE_ARROWS_SRC_Y, PAGE_ARROWS_WIDTH, PAGE_ARROWS_HEIGHT)
      end
      if page <= size && size < @page_list.length
        Summary640.draw_image(overlay, path, xpos + offset + (iconPos * w) + PAGE_ARROW_RIGHT_X_ADJUST, ypos + LEFT_ARROW_Y_OFFSET,
                              PAGE_ARROWS_SRC_RIGHT_X, PAGE_ARROWS_SRC_Y, PAGE_ARROWS_WIDTH, PAGE_ARROWS_HEIGHT)
      end
    end
  end

  #-----------------------------------------------------------------------------
  # Pantalla de marcas: mismas coordenadas escaladas x1.25.
  #-----------------------------------------------------------------------------
  def pbMarking(pokemon)
    @sprites["markingbg"].visible      = true
    @sprites["markingoverlay"].visible = true
    @sprites["markingsel"].visible     = true
    base   = Color.new(248, 248, 248)
    shadow = Color.new(104, 104, 104)
    ret = pokemon.markings.clone
    markings = pokemon.markings.clone
    mark_variants = @markingbitmap.bitmap.height / MARK_HEIGHT
    index = 0
    redraw = true
    markrect = Rect.new(0, 0, MARK_WIDTH, MARK_HEIGHT)
    loop do
      if redraw
        @sprites["markingoverlay"].bitmap.clear
        (@markingbitmap.bitmap.width / MARK_WIDTH).times do |i|
          markrect.x = i * MARK_WIDTH
          markrect.y = [(markings[i] || 0), mark_variants - 1].min * MARK_HEIGHT
          @sprites["markingoverlay"].bitmap.blt(Summary640.scale(300) + (Summary640.scale(58) * (i % 3)),
                                                Summary640.scale(154) + (Summary640.scale(50) * (i / 3)),
                                                @markingbitmap.bitmap, markrect)
        end
        textpos = [
          [_INTL("Marcar a {1}", pokemon.name), Summary640.scale(366), Summary640.scale(102), :center, base, shadow],
          [_INTL("OK"), Summary640.scale(366), Summary640.scale(254), :center, base, shadow],
          [_INTL("Cancelar"), Summary640.scale(366), Summary640.scale(304), :center, base, shadow]
        ]
        pbDrawTextPositions(@sprites["markingoverlay"].bitmap, textpos)
        redraw = false
      end
      @sprites["markingsel"].x = Summary640.scale(284) + (Summary640.scale(58) * (index % 3))
      @sprites["markingsel"].y = Summary640.scale(144) + (Summary640.scale(50) * (index / 3))
      case index
      when 6   # OK
        @sprites["markingsel"].x = Summary640.scale(284)
        @sprites["markingsel"].y = Summary640.scale(244)
        @sprites["markingsel"].src_rect.y = @sprites["markingsel"].bitmap.height / 2
      when 7   # Cancel
        @sprites["markingsel"].x = Summary640.scale(284)
        @sprites["markingsel"].y = Summary640.scale(294)
        @sprites["markingsel"].src_rect.y = @sprites["markingsel"].bitmap.height / 2
      else
        @sprites["markingsel"].src_rect.y = 0
      end
      Graphics.update
      Input.update
      pbUpdate
      if Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      elsif Input.trigger?(Input::USE)
        pbPlayDecisionSE
        case index
        when 6   # OK
          ret = markings
          break
        when 7   # Cancel
          break
        else
          markings[index] = ((markings[index] || 0) + 1) % mark_variants
          redraw = true
        end
      elsif Input.trigger?(Input::ACTION)
        if index < 6 && markings && markings[index] && markings[index] > 0
          pbPlayDecisionSE
          markings[index] = 0
          redraw = true
        end
      elsif Input.trigger?(Input::UP)
        if index == 7
          index = 6
        elsif index == 6
          index = 4
        elsif index < 3
          index = 7
        else
          index -= 3
        end
        pbPlayCursorSE
      elsif Input.trigger?(Input::DOWN)
        if index == 7
          index = 1
        elsif index == 6
          index = 7
        elsif index >= 3
          index = 6
        else
          index += 3
        end
        pbPlayCursorSE
      elsif Input.trigger?(Input::LEFT)
        if index < 6
          index -= 1
          index += 3 if index % 3 == 2
          pbPlayCursorSE
        end
      elsif Input.trigger?(Input::RIGHT)
        if index < 6
          index += 1
          index -= 3 if index % 3 == 0
          pbPlayCursorSE
        end
      end
    end
    @sprites["markingbg"].visible      = false
    @sprites["markingoverlay"].visible = false
    @sprites["markingsel"].visible     = false
    if pokemon.markings != ret
      pokemon.markings = ret
      return true
    end
    return false
  end
end

#===============================================================================
# Aplica el escalado de constantes al cargar el plugin.
#===============================================================================
Summary640.scale_summary_constants

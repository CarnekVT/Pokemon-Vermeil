# encoding: utf-8
class ZBOX_UIEditor::Scene
  COLORS = {
    box:    Color.new(60, 120, 255, 80), grid:   Color.new(60, 255, 60, 80),
    name:   Color.new(255, 200, 60, 120), sprite: Color.new(255, 120, 60, 120),
    text:   Color.new(200, 200, 200, 120), level:  Color.new(255, 60, 200, 120),
    ability: Color.new(60, 255, 200, 120), item:   Color.new(200, 200, 60, 120),
    shiny:  Color.new(255, 255, 60, 120), type:   Color.new(200, 60, 255, 120),
    marks:  Color.new(255, 140, 140, 120), icon:   Color.new(60, 200, 255, 120),
    cursor: Color.new(255, 255, 255, 150), default: Color.new(140, 140, 140, 100),
  }
  SELECTED_COLOR = Color.new(255, 255, 255)
  SCREEN_KEYS = ::ZBOX_UIEditor::Settings::SCREENS.keys.freeze
  INFO_Y = 356
  PREVIEW_W = 640
  PREVIEW_H = 480
  BASE_COLOR = Color.new(248, 248, 248)
  SHADOW_COLOR = Color.new(80, 80, 80)

  def pbStartScene
    @viewport = Viewport.new(0, 0, ::Settings::SCREEN_WIDTH, ::Settings::SCREEN_HEIGHT)
    @viewport.z = 99999
    @sprites = {}
    @sprites["overlay"] = BitmapSprite.new(::Settings::SCREEN_WIDTH, ::Settings::SCREEN_HEIGHT, @viewport)
    @overlay = @sprites["overlay"].bitmap
    pbSetSystemFont(@overlay)
    @preview_bmp = Bitmap.new(PREVIEW_W, PREVIEW_H)
    @gfx_cache = {}
    @screen_idx = 0
    @elem_idx = 0
    redraw
  end

  def pbMain
    loop do
      Graphics.update
      Input.update
      pbUpdateSpriteHash(@sprites)
      return if handle_input
    end
  end

  def pbEndScene
    @gfx_cache.each_value { |b| b.dispose rescue nil }
    @preview_bmp.dispose
    pbDisposeSpriteHash(@sprites)
    @viewport&.dispose
  end

  private

  def gfx(path)
    @gfx_cache[path] ||= begin
      bmp = AnimatedBitmap.new(path)
      bmp.bitmap
    rescue
      nil
    end
  end

  def current_screen_key; SCREEN_KEYS[@screen_idx]; end
  def current_screen_data; ::ZBOX_UIEditor::Settings::SCREENS[current_screen_key]; end
  def current_elems; current_screen_data[:elements]; end
  def current_elem; current_elems[@elem_idx]; end

  def switch_screen(delta)
    @screen_idx = (@screen_idx + delta) % SCREEN_KEYS.length
    @elem_idx = 0; redraw
  end

  def gv(klass, const, default = 0)
    ::ZBOX_UIEditor.get_effective(klass, const) || default
  end

  def handle_input
    return true if Input.trigger?(Input::BACK)
    if Input.trigger?(Input::F5) || Input.triggerex?(:LETTER_S)
      ::ZBOX_UIEditor.save_file
      pbPlayDecisionSE
    end
    step = Input.press?(Input::SHIFT) ? 10 : 1
    changed = false
    elem = current_elem; vis = elem&.dig(:visual)
    if Input.repeat?(Input::L)
      switch_screen(-1)
    elsif Input.repeat?(Input::R)
      switch_screen(1)
    elsif Input.repeat?(Input::LEFT)
      if vis == :pos_x || vis == :size_w || vis == :val
        adjust(elem, -step); changed = true
      else
        switch_screen(-1)
      end
    elsif Input.repeat?(Input::RIGHT)
      if vis == :pos_x || vis == :size_w || vis == :val
        adjust(elem, step); changed = true
      else
        switch_screen(1)
      end
    elsif Input.repeat?(Input::UP)
      if vis == :pos_y || vis == :size_h
        adjust(elem, -step); changed = true
      else
        @elem_idx = (@elem_idx - 1) % current_elems.length; redraw
      end
    elsif Input.repeat?(Input::DOWN)
      if vis == :pos_y || vis == :size_h
        adjust(elem, step); changed = true
      else
        @elem_idx = (@elem_idx + 1) % current_elems.length; redraw
      end
    end
    redraw if changed
    false
  end

  def adjust(elem, delta)
    val = ::ZBOX_UIEditor.get_effective(elem[:klass], elem[:const]) || 0
    ::ZBOX_UIEditor.set_override(elem[:klass], elem[:const], val + delta)
  end

  def redraw
    @overlay.clear
    draw_title_bar
    draw_preview
    draw_info_bar
    draw_controls_hint
  end

  def draw_title_bar
    pbDrawShadowText(@overlay, 256, 2, 0, 0,
                     _INTL("UI Editor — {1}", current_screen_data[:label]),
                     Color.new(248, 248, 248), Color.new(80, 80, 80), 1)
    pbDrawShadowText(@overlay, 490, 2, 0, 0, "F5:save",
                     Color.new(180, 220, 255), Color.new(80, 80, 80), 1)
    @overlay.fill_rect(0, 22, ::Settings::SCREEN_WIDTH, 2, Color.new(128, 128, 128))
  end

  def draw_preview
    @preview_bmp.clear
    area_x = 4; area_y = 26
    area_w = ::Settings::SCREEN_WIDTH - 8
    area_h = INFO_Y - area_y - 2
    @overlay.fill_rect(area_x, area_y, area_w, area_h, Color.new(16, 16, 24))
    @overlay.fill_rect(area_x, area_y, area_w, 1, Color.new(80, 80, 100))
    @overlay.fill_rect(area_x, area_y + area_h - 1, area_w, 1, Color.new(80, 80, 100))
    @overlay.fill_rect(area_x, area_y, 1, area_h, Color.new(80, 80, 100))
    @overlay.fill_rect(area_x + area_w - 1, area_y, 1, area_h, Color.new(80, 80, 100))

    case current_screen_key
    when :pc_storage       then draw_pc_storage_gfx
    when :pc_storage_scene then draw_pc_scene_gfx
    when :summary          then draw_summary_gfx
    when :summary_cursor   then draw_summary_cursor_gfx
    when :party            then draw_party_gfx
    else draw_generic_preview
    end

    scale_x = (area_w - 8).to_f / PREVIEW_W
    scale_y = (area_h - 8).to_f / PREVIEW_H
    scale = [scale_x, scale_y].min
    dest_w = (PREVIEW_W * scale).to_i
    dest_h = (PREVIEW_H * scale).to_i
    dest_x = area_x + ((area_w - dest_w) / 2)
    dest_y = area_y + ((area_h - dest_h) / 2)

    @overlay.stretch_blt(Rect.new(dest_x, dest_y, dest_w, dest_h),
                         @preview_bmp, Rect.new(0, 0, PREVIEW_W, PREVIEW_H))
  end

  # ─── PC box grid with 42x42 icons ──────────────────────────

  def draw_pc_storage_gfx
    box_x = gv("PokemonBoxSprite", :BOX_X, 184)
    box_y = gv("PokemonBoxSprite", :BOX_Y, 18)
    box_w = gv("PokemonBoxSprite", :BOX_WIDTH, 324)
    box_h = gv("PokemonBoxSprite", :BOX_HEIGHT, 296)
    ox    = gv("PokemonBoxSprite", :POKEMON_BOX_SPRITE_X_OFFSET, 10)
    oy    = gv("PokemonBoxSprite", :POKEMON_BOX_SPRITE_Y_OFFSET, 30)
    xs    = gv("PokemonBoxSprite", :POKEMON_BOX_SPRITE_X_SPACING, 48)
    ys    = gv("PokemonBoxSprite", :POKEMON_BOX_SPRITE_Y_SPACING, 48)
    nx    = gv("PokemonBoxSprite", :BOX_NAME_X_OFFSET, 162)
    _ny   = gv("PokemonBoxSprite", :BOX_NAME_Y, 14)

    @preview_bmp.fill_rect(0, 0, PREVIEW_W, PREVIEW_H, Color.new(24, 28, 40))
    @preview_bmp.fill_rect(0, 0, 180, PREVIEW_H, Color.new(20, 22, 32))
    @preview_bmp.fill_rect(180, 0, 1, PREVIEW_H, Color.new(60, 60, 80))

    box_gfx = gfx("Graphics/UI/Storage/box_0")
    if box_gfx
      @preview_bmp.stretch_blt(Rect.new(box_x, box_y, box_w, box_h),
                                box_gfx, Rect.new(0, 0, box_gfx.width, box_gfx.height))
    else
      @preview_bmp.fill_rect(box_x, box_y, box_w, box_h, Color.new(40, 50, 70))
    end

    icon_ids = ["CHARIZARD", "GYARADOS", "CHARIZARD", "GYARADOS", "CHARIZARD", "GYARADOS",
                "GYARADOS", "CHARIZARD", "GYARADOS", "CHARIZARD"]
    5.times do |j|
      6.times do |k|
        icon = gfx("Graphics/Pokemon/Icons/#{icon_ids[(j * 6 + k) % icon_ids.length]}")
        next unless icon
        ix = box_x + ox + (k * xs)
        iy = box_y + oy + (j * ys)
        @preview_bmp.blt(ix, iy, icon, Rect.new(0, 0, icon.width, icon.height))
      end
    end

    boxname = gfx("Graphics/UI/Storage/overlay_box")
    if boxname
      @preview_bmp.blt(nx - (boxname.width / 2), _ny, boxname,
                       Rect.new(0, 0, boxname.width, boxname.height))
    else
      @preview_bmp.fill_rect(box_x + (box_w / 2) - 30, _ny, 60, 20, Color.new(60, 60, 100, 200))
    end
  end

  # ─── PC info panel with CHARIZARD 42x42 icon + front sprite ───

  def draw_pc_scene_gfx
    sp_x = gv("PokemonStorageScene", :POKEMON_SPRITE_X, 90)
    sp_y = gv("PokemonStorageScene", :POKEMON_SPRITE_Y, 134)
    pn_x = gv("PokemonStorageScene", :POKENAME_TEXT_X, 10)
    pn_y = gv("PokemonStorageScene", :POKENAME_TEXT_Y, 14)
    lv_x = gv("PokemonStorageScene", :LEVEL_ICON_X, 6)
    lv_y = gv("PokemonStorageScene", :LEVEL_ICON_Y, 246)
    ln_x = gv("PokemonStorageScene", :LEVEL_NUMBER_X, 28)
    ln_y = gv("PokemonStorageScene", :LEVEL_NUMBER_Y, 240)
    ab_x = gv("PokemonStorageScene", :ABILITY_NAME_X, 86)
    ab_y = gv("PokemonStorageScene", :ABILITY_NAME_Y, 312)
    it_x = gv("PokemonStorageScene", :ITEM_NAME_X, 86)
    it_y = gv("PokemonStorageScene", :ITEM_NAME_Y, 348)
    sh_x = gv("PokemonStorageScene", :SHINY_ICON_X, 156)
    sh_y = gv("PokemonStorageScene", :SHINY_ICON_Y, 198)
    t1_x = gv("PokemonStorageScene", :TYPE_ICON_X_1, 52)
    t2_x = gv("PokemonStorageScene", :TYPE_ICON_X_2, 18)
    ty   = gv("PokemonStorageScene", :TYPE_ICON_Y, 272)
    mk_x = gv("PokemonStorageScene", :MARKINGS_X, 70)
    mk_y = gv("PokemonStorageScene", :MARKINGS_Y, 240)
    gd_x = gv("PokemonStorageScene", :GENDER_ICON_TEXT_X, 148)
    gd_y = gv("PokemonStorageScene", :GENDER_ICON_TEXT_Y, 14)

    @preview_bmp.fill_rect(0, 0, PREVIEW_W, PREVIEW_H, Color.new(24, 28, 40))
    @preview_bmp.fill_rect(0, 0, 180, PREVIEW_H, Color.new(20, 22, 32))
    @preview_bmp.fill_rect(180, 0, 1, PREVIEW_H, Color.new(60, 60, 80))

    sprite = gfx("Graphics/Pokemon/Front/CHARIZARD")
    if sprite
      s_x = sp_x - (sprite.width / 2)
      s_y = sp_y - (sprite.height / 2)
      @preview_bmp.blt(s_x, s_y, sprite, Rect.new(0, 0, sprite.width, sprite.height))
    else
      @preview_bmp.fill_rect(sp_x - 20, sp_y - 20, 40, 40, Color.new(80, 80, 120))
    end

    lv_gfx = gfx("Graphics/UI/Storage/overlay_lv")
    @preview_bmp.blt(lv_x, lv_y, lv_gfx, Rect.new(0, 0, lv_gfx.width, lv_gfx.height)) if lv_gfx

    shiny_gfx = gfx("Graphics/UI/shiny")
    @preview_bmp.blt(sh_x, sh_y, shiny_gfx, Rect.new(0, 0, shiny_gfx.width, shiny_gfx.height)) if shiny_gfx

    types_sheet = gfx("Graphics/UI/types")
    if types_sheet
      type_h = 28; type_w = 64
      grass_pos = 4; poison_pos = 12
      @preview_bmp.blt(t1_x, ty, types_sheet, Rect.new(0, grass_pos * type_h, type_w, type_h))
      @preview_bmp.blt(t2_x, ty + 22, types_sheet, Rect.new(0, poison_pos * type_h, type_w, type_h))
    end

    item_icon = gfx("Graphics/Items/001")
    if item_icon
      @preview_bmp.blt(6, it_y - 4, item_icon, Rect.new(0, 0, item_icon.width, item_icon.height))
    end

    pbSetSmallFont(@preview_bmp) rescue nil
    @preview_bmp.font.size = 20 rescue nil

    pbDrawShadowText(@preview_bmp, pn_x, pn_y, 0, 0, "Charizard", BASE_COLOR, SHADOW_COLOR, 0)
    @preview_bmp.fill_rect(gd_x, gd_y + 2, 8, 8, Color.new(24, 112, 216))
    pbDrawShadowText(@preview_bmp, ln_x, ln_y, 0, 0, "50", BASE_COLOR, SHADOW_COLOR, 0)
    ab_base = Color.new(200, 200, 200); ab_shadow = Color.new(120, 120, 120)
    pbDrawShadowText(@preview_bmp, ab_x, ab_y, 0, 0, "Blaze", ab_base, ab_shadow, 1)
    pbDrawShadowText(@preview_bmp, it_x, it_y, 0, 0, "Charcoal", ab_base, ab_shadow, 1)

    @preview_bmp.fill_rect(mk_x, mk_y, 72, 16, Color.new(40, 44, 60))
    @preview_bmp.fill_rect(mk_x + 2, mk_y + 2, 12, 12, Color.new(200, 60, 60))
    @preview_bmp.fill_rect(mk_x + 20, mk_y + 2, 12, 12, Color.new(60, 200, 60))
    @preview_bmp.fill_rect(mk_x + 38, mk_y + 2, 12, 12, Color.new(60, 60, 200))

    @preview_bmp.fill_rect(4, 356, 168, 22, Color.new(60, 60, 80))
    pbDrawShadowText(@preview_bmp, 88, 358, 0, 0, "Equipo: 6", BASE_COLOR, SHADOW_COLOR, 1)
    @preview_bmp.fill_rect(4, 330, 168, 22, Color.new(60, 60, 80))
    pbDrawShadowText(@preview_bmp, 88, 332, 0, 0, "Salir", BASE_COLOR, SHADOW_COLOR, 1)
  end

  # ─── Summary with CHARIZARD ─────────────────────────────────

  def draw_summary_gfx
    sp_x = gv("PokemonSummary_Scene", :UI_POKEMON_SPRITE_X, 104)
    sp_y = gv("PokemonSummary_Scene", :UI_POKEMON_SPRITE_Y, 206)
    ic_x = gv("PokemonSummary_Scene", :UI_POKEICON_X, 46)
    ic_y = gv("PokemonSummary_Scene", :UI_POKEICON_Y, 92)
    nm_x = gv("PokemonSummary_Scene", :TEXT_NAME_X, 40)
    nm_y = gv("PokemonSummary_Scene", :TEXT_NAME_Y, 68)
    lv_x = gv("PokemonSummary_Scene", :TEXT_LEVEL_X, 46)
    lv_y = gv("PokemonSummary_Scene", :TEXT_LEVEL_Y, 98)
    ii_x = gv("PokemonSummary_Scene", :UI_ITEMICON_X, 30)
    ii_y = gv("PokemonSummary_Scene", :UI_ITEMICON_Y, 320)
    gd_x = gv("PokemonSummary_Scene", :TEXT_GENDER_X, 178)
    gd_y = gv("PokemonSummary_Scene", :TEXT_GENDER_Y, 68)
    sh_x = gv("PokemonSummary_Scene", :IMG_SHINY_X, 174)
    sh_y = gv("PokemonSummary_Scene", :IMG_SHINY_Y, 100)

    @preview_bmp.fill_rect(0, 0, PREVIEW_W, PREVIEW_H, Color.new(24, 28, 40))
    bg = gfx("Graphics/UI/Summary/bg")
    if bg
      @preview_bmp.stretch_blt(Rect.new(0, 0, PREVIEW_W, PREVIEW_H), bg,
                                Rect.new(0, 0, bg.width, bg.height))
    else
      @preview_bmp.fill_rect(4, 4, 220, 376, Color.new(32, 36, 52))
      @preview_bmp.fill_rect(228, 4, 280, 376, Color.new(32, 36, 52))
    end

    sprite = gfx("Graphics/Pokemon/Front/CHARIZARD")
    if sprite
      s_x = sp_x - (sprite.width / 2)
      s_y = sp_y - (sprite.height / 2)
      @preview_bmp.blt(s_x, s_y, sprite, Rect.new(0, 0, sprite.width, sprite.height))
    end

    icon = gfx("Graphics/Pokemon/Icons/CHARIZARD")
    if icon
      @preview_bmp.blt(ic_x, ic_y, icon, Rect.new(0, 0, icon.width, icon.height))
    end

    pbDrawShadowText(@preview_bmp, nm_x, nm_y, 0, 0, "Charizard", BASE_COLOR, SHADOW_COLOR, 0)
    pbDrawShadowText(@preview_bmp, lv_x, lv_y, 0, 0, "Lv. 50", BASE_COLOR, SHADOW_COLOR, 0)
    @preview_bmp.fill_rect(gd_x - 4, gd_y + 2, 8, 8, Color.new(248, 56, 32))

    shiny_gfx = gfx("Graphics/UI/shiny")
    @preview_bmp.blt(sh_x, sh_y, shiny_gfx, Rect.new(0, 0, shiny_gfx.width, shiny_gfx.height)) if shiny_gfx

    item_gfx = gfx("Graphics/Items/063")
    @preview_bmp.blt(ii_x, ii_y, item_gfx, Rect.new(0, 0, item_gfx.width, item_gfx.height)) if item_gfx
  end

  # ─── Cursor moves ──────────────────────────────────────────

  def draw_summary_cursor_gfx
    cx = gv("MoveSelectionSprite", :CURSOR_BASE_X, 240)
    cy = gv("MoveSelectionSprite", :CURSOR_BASE_Y, 92)
    co = gv("MoveSelectionSprite", :CURSOR_OFFSET_Y, 64)

    @preview_bmp.fill_rect(0, 0, PREVIEW_W, PREVIEW_H, Color.new(24, 28, 40))
    bg = gfx("Graphics/UI/Summary/bg")
    @preview_bmp.stretch_blt(Rect.new(0, 0, PREVIEW_W, PREVIEW_H), bg,
                              Rect.new(0, 0, bg.width, bg.height)) if bg

    moves = ["Scratch", "Growl", "Ember", "Leer"]
    moves.each_with_index do |m, i|
      my = cy + (i * co)
      @preview_bmp.fill_rect(cx, my, 100, 34, Color.new(40, 44, 60))
      if i == 1
        @preview_bmp.fill_rect(cx - 2, my - 2, 104, 38, Color.new(255, 180, 60, 60))
        pbDrawShadowText(@preview_bmp, cx + 50, my + 8, 0, 0, m,
                         Color.new(255, 255, 255), Color.new(40, 40, 40), 1)
      else
        pbDrawShadowText(@preview_bmp, cx + 50, my + 8, 0, 0, m,
                         Color.new(180, 180, 200), Color.new(40, 40, 40), 1)
      end
    end
  end

  # ─── Party with CHARIZARD/GYARADOS 42x42 icons ─────────────

  def draw_party_gfx
    px  = gv("PokemonBoxPartySprite", :PARTY_BOX_X, 182)
    py  = gv("PokemonBoxPartySprite", :PARTY_BOX_Y_OFFSET, -352)
    ixs = gv("PokemonBoxPartySprite", :PARTY_ICON_X_START, 18)
    iys = gv("PokemonBoxPartySprite", :PARTY_ICON_Y_START, 2)
    _ixp = gv("PokemonBoxPartySprite", :PARTY_ICON_X_SPACING, 72)
    iyp = gv("PokemonBoxPartySprite", :PARTY_ICON_Y_SPACING, 64)
    party_y = PREVIEW_H + py

    @preview_bmp.fill_rect(0, 0, PREVIEW_W, PREVIEW_H, Color.new(24, 28, 40))
    @preview_bmp.fill_rect(px, party_y, 172, 352, Color.new(32, 36, 52))
    @preview_bmp.fill_rect(px, party_y, 172, 1, Color.new(100, 120, 160))
    @preview_bmp.fill_rect(px, party_y + 351, 172, 1, Color.new(100, 120, 160))
    @preview_bmp.fill_rect(px, party_y, 1, 352, Color.new(100, 120, 160))
    @preview_bmp.fill_rect(px + 171, party_y, 1, 352, Color.new(100, 120, 160))

    species_list = ["CHARIZARD", "GYARADOS", "CHARIZARD", "GYARADOS", "CHARIZARD", "GYARADOS"]
    names = ["Charizard", "Gyarados", "Charizard", "Gyarados", "Charizard", "Gyarados"]
    levels = [50, 45, 48, 52, 55, 70]

    Settings::MAX_PARTY_SIZE.times do |i|
      break if i >= species_list.length
      ix = px + ixs
      iy = party_y + iys + (i * iyp)
      icon = gfx("Graphics/Pokemon/Icons/#{species_list[i]}")
      @preview_bmp.blt(ix, iy, icon, Rect.new(0, 0, icon.width, icon.height)) if icon
      pbDrawShadowText(@preview_bmp, ix + icon.width + 4, iy, 0, 0,
                       _INTL("{1} Lv.{2}", names[i], levels[i]),
                       BASE_COLOR, SHADOW_COLOR, 0)
      bar_x = ix + icon.width + 4; bar_y = iy + 28
      @preview_bmp.fill_rect(bar_x, bar_y, 80, 4, Color.new(40, 40, 60))
      hp = 30 + (i * 10); hp = [hp, 100].min
      hp_w = (hp * 78 / 100)
      hp_color = hp > 50 ? Color.new(80, 200, 80) : (hp > 20 ? Color.new(200, 200, 60) : Color.new(200, 60, 60))
      @preview_bmp.fill_rect(bar_x + 1, bar_y + 1, hp_w, 2, hp_color)
    end
  end

  # ─── Generic fallback ──────────────────────────────────────

  def draw_generic_preview
    groups = {}
    current_elems.each do |e|
      g = e[:group] || :default; groups[g] ||= []; groups[g] << e
    end
    groups.each do |gid, ge|
      color = COLORS[gid] || COLORS[:default]
      xes = ge.select { |e| e[:visual] == :pos_x }
      yes = ge.select { |e| e[:visual] == :pos_y }
      we = ge.find { |e| e[:visual] == :size_w }
      he = ge.find { |e| e[:visual] == :size_h }
      xes.each_with_index do |xe, xi|
        ye = yes[xi] || yes.first; next unless ye
        xv = gv(xe[:klass], xe[:const], 0); yv = gv(ye[:klass], ye[:const], 0)
        w = we ? (gv(we[:klass], we[:const], 10)) : 6
        h = he ? (gv(he[:klass], he[:const], 10)) : 6
        if we && he
          @preview_bmp.fill_rect(xv, yv, w, h, color)
        else
          @preview_bmp.fill_rect(xv - 2, yv - 2, 5, 5, color)
        end
      end
    end
  end

  def draw_info_bar
    @overlay.fill_rect(0, INFO_Y, ::Settings::SCREEN_WIDTH, 24, Color.new(40, 40, 56))
    elem = current_elem
    return unless elem
    val = ::ZBOX_UIEditor.get_effective(elem[:klass], elem[:const]) || 0
    label = elem[:label] || elem[:const].to_s
    pbDrawShadowText(@overlay, 8, INFO_Y + 2, 0, 0, _INTL("{1} = {2}", label, val),
                     Color.new(255, 255, 255), Color.new(40, 40, 40), 0)
    hints = case elem[:visual]
    when :pos_x then _INTL("←→ mover | SHIFT x10")
    when :pos_y then _INTL("↑↓ mover | SHIFT x10")
    else _INTL("←→ -1 | → +1 | SHIFT x10")
    end
    pbDrawShadowText(@overlay, 256, INFO_Y + 2, 0, 0, hints,
                     Color.new(180, 180, 200), Color.new(40, 40, 40), 1)
  end

  def draw_controls_hint
    y = INFO_Y + 24
    @overlay.fill_rect(0, y, ::Settings::SCREEN_WIDTH, ::Settings::SCREEN_HEIGHT - y, Color.new(24, 24, 36))
    pbDrawShadowText(@overlay, 256, y + 2, 0, 0,
                     _INTL("Q/W: pantalla | ↑↓: elemento | ←→: ajustar | F5: guardar | ESC: salir"),
                     Color.new(160, 160, 160), Color.new(24, 24, 24), 1)
  end
end

class ZBOX_UIEditor::Screen
  def initialize(scene); @scene = scene; end
  def pbStartScreen; @scene.pbStartScene; @scene.pbMain; @scene.pbEndScene; end
end

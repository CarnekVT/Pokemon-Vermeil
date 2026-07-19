# ==============================================================================
# FIX RESOLUCIÓN 640x480 PARA PC - CAJA 436x470 (5x5 PERFECTO + CURSOR AISLADO)
# ==============================================================================

# 1. Ajuste de datos a 5x5
class PokemonBox
  remove_const(:BOX_WIDTH) if defined?(BOX_WIDTH)
  BOX_WIDTH = 5
  remove_const(:BOX_SIZE) if defined?(BOX_SIZE)
  BOX_SIZE = BOX_WIDTH * BOX_HEIGHT
end

Settings.remove_const(:NUM_STORAGE_BOXES) if Settings.const_defined?(:NUM_STORAGE_BOXES)
Settings.const_set(:NUM_STORAGE_BOXES, 120)

class PokemonBox
  alias _carnek_orig_length length
  def length
    return PokemonBox::BOX_SIZE
  end
end

EventHandlers.add(:on_game_load, :truncate_box_arrays,
  proc {
    $PokemonStorage.boxes.each do |box|
      arr = box.instance_variable_get(:@pokemon)
      next if arr.length <= PokemonBox::BOX_SIZE
      box.instance_variable_set(:@pokemon, arr.first(PokemonBox::BOX_SIZE))
    end
  }
)

# 2. Dibujo manual de la Caja y los Iconos (Centrado milimétrico)
class PokemonBoxSprite < Sprite
  remove_const(:BOX_NAME_X_OFFSET) if defined?(BOX_NAME_X_OFFSET)
  
  BOX_X = 194  
  BOX_Y = 5   
  BOX_WIDTH = 436
  BOX_HEIGHT = 470
  
  BOX_NAME_X_OFFSET = 218 # Mitad de 436
  remove_const(:BOX_NAME_Y) if defined?(BOX_NAME_Y)
  BOX_NAME_Y = 10

  # Grid de iconos (centralizado para cursor)
  GRID_X_OFFSET = 4
  GRID_Y_OFFSET = 40
  GRID_X_SPACING = 86
  GRID_Y_SPACING = 86

  alias _res_fix_refresh refresh
  def refresh
    if @refreshBox
      boxname = @storage[@boxnumber].name
      getBoxBitmap
      @contents.blt(0, 0, @boxbitmap.bitmap, Rect.new(0, 0, BOX_WIDTH, BOX_HEIGHT))
      pbSetSystemFont(@contents)
      widthval = @contents.text_size(boxname).width
      xval = BOX_NAME_X_OFFSET - (widthval / 2)
      pbDrawShadowText(@contents, xval, BOX_NAME_Y, widthval, BOX_NAME_HEIGHT,
                       boxname, Color.new(248, 248, 248), Color.new(40, 48, 48))
      @refreshBox = false
    end
    x_start = self.x + GRID_X_OFFSET
    y_start = self.y + GRID_Y_OFFSET
    PokemonBox::BOX_HEIGHT.times do |row|
      PokemonBox::BOX_WIDTH.times do |col|
        idx = (row * PokemonBox::BOX_WIDTH) + col
        sprite = @pokemonsprites[idx]
        if sprite && !sprite.disposed?
          sprite.viewport = self.viewport
          sprite.x = x_start + (col * GRID_X_SPACING)
          sprite.y = y_start + (row * GRID_Y_SPACING)
          sprite.z = 1
        end
      end
    end
  end
end

# 3. Dibujo manual del Equipo (Party)
class PokemonBoxPartySprite < Sprite
  PARTY_BOX_X = 144
  
  alias _res_fix_init initialize
  def initialize(party, viewport = nil)
    _res_fix_init(party, viewport)
    self.y = 480 
  end

end

# 4. Cursores, Textos y Aislamiento de Navegación
class PokemonStorageScene
  remove_const(:SWITCH_BOX_X_OFFSET) if defined?(SWITCH_BOX_X_OFFSET)
  SWITCH_BOX_X_OFFSET = 450 # Evita que las cajas se superpongan al deslizarse

  # --- Ajuste Perfecto del Panel Izquierdo ---
  POKEMON_SPRITE_X = 84
  POKEMON_SPRITE_Y = 128
  MSG_WINDOW_X = 194
  MSG_WINDOW_Y = 48
  
  POKENAME_TEXT_X = 8
  POKENAME_TEXT_Y = 10
  GENDER_ICON_TEXT_X = 162
  GENDER_ICON_TEXT_Y = 10
  
  LEVEL_ICON_X = 8
  LEVEL_ICON_Y = 232
  LEVEL_NUMBER_X = 34
  LEVEL_NUMBER_Y = 226
  
  SHINY_ICON_X = 160
  SHINY_ICON_Y = 250
  SHINY_LEAF_X = 162
  SHINY_LEAF_Y = 98
  IV_RATING_X = 12
  IV_RATING_Y = 250
  
  MARKINGS_X = 80
  MARKINGS_Y = 228
  
  TYPE_ICON_Y = 262
  TYPE_ICON_X_1 = 60
  TYPE_ICON_X_2 = 26
  
  ABILITY_NAME_X = 88
  ABILITY_NAME_Y = 308
  ITEM_NAME_X = 88
  ITEM_NAME_Y = 350

  # Desterramos los textos viejos
  TEAM_TEXT_X = -1100
  TEAM_TEXT_Y = -1100
  EXIT_TEXT_X = -1100
  EXIT_TEXT_Y = -1100
  
  NEW_TEAM_TEXT_X = 88
  NEW_TEAM_TEXT_Y = 404
  NEW_EXIT_TEXT_X = 88
  NEW_EXIT_TEXT_Y = 446

  # --- Reemplazo total del overlay (colores box name) ---
  def pbUpdateOverlay(selection, party = nil)
    if !@sprites["plugin_overlay"]
      @sprites["plugin_overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @boxsidesviewport)
      pbSetSystemFont(@sprites["plugin_overlay"].bitmap)
    end
    plugin_overlay = @sprites["plugin_overlay"].bitmap
    plugin_overlay.clear
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    buttonbase = Color.new(248, 248, 248)
    buttonshadow = Color.new(80, 80, 80)
    special_k = KeybindingReader.key_name(Input::SPECIAL)
    back_k = KeybindingReader.key_name(Input::BACK)
    pbDrawTextPositions(
      plugin_overlay,
      [[_INTL("{1}: Equipo", special_k, (@storage.party.length rescue 0)), NEW_TEAM_TEXT_X, NEW_TEAM_TEXT_Y, :center, buttonbase, buttonshadow, :outline],
       [_INTL("{1}: Salir", back_k), NEW_EXIT_TEXT_X, NEW_EXIT_TEXT_Y, :center, buttonbase, buttonshadow, :outline]]
    )
    pokemon = nil
    if @screen.pbHeldPokemon
      pokemon = @screen.pbHeldPokemon
    elsif selection >= 0
      pokemon = (party) ? party[selection] : @storage[@storage.currentBox, selection]
    end
    if !pokemon
      @sprites["pokemon"].visible = false
      pbFadeInOverlay if @sprites["overlay"].opacity == 0
      return
    end
    @sprites["pokemon"].visible = true
    base   = Color.new(248, 248, 248)
    shadow = Color.new(40, 48, 48)
    pokename = pokemon.name
    textstrings = [
      [pokename, POKENAME_TEXT_X, POKENAME_TEXT_Y, :left, base, shadow]
    ]
    if !pokemon.egg?
      imagepos = []
      if pokemon.male?
        textstrings.push([_INTL("♂"), GENDER_ICON_TEXT_X, GENDER_ICON_TEXT_Y, :left, Color.new(24, 112, 216), Color.new(136, 168, 208)])
      elsif pokemon.female?
        textstrings.push([_INTL("♀"), GENDER_ICON_TEXT_X, GENDER_ICON_TEXT_Y, :left, Color.new(248, 56, 32), Color.new(224, 152, 144)])
      end
      imagepos.push([_INTL("Graphics/UI/Storage/overlay_lv"), LEVEL_ICON_X, LEVEL_ICON_Y])
      textstrings.push([pokemon.level.to_s, LEVEL_NUMBER_X, LEVEL_NUMBER_Y, :left, base, shadow])
      if pokemon.ability
        textstrings.push([pokemon.ability.name, ABILITY_NAME_X, ABILITY_NAME_Y, :center, base, shadow])
      else
        textstrings.push([_INTL("Sin habilidad"), ABILITY_NAME_X, ABILITY_NAME_Y, :center, base, shadow])
      end
      if pokemon.item
        textstrings.push([pokemon.item.name, ITEM_NAME_X, ITEM_NAME_Y, :center, base, shadow])
      else
        textstrings.push([_INTL("Sin objeto"), ITEM_NAME_X, ITEM_NAME_Y, :center, base, shadow])
      end
      if pokemon.shiny?
        pbDrawImagePositions(plugin_overlay, [["Graphics/UI/shiny", SHINY_ICON_X, SHINY_ICON_Y]])
      end
      pbDisplayShinyLeaf(pokemon, plugin_overlay, SHINY_LEAF_X, SHINY_LEAF_Y)      if Settings::STORAGE_SHINY_LEAF
      pbDisplayIVRatings(pokemon, plugin_overlay, IV_RATING_X, IV_RATING_Y, true) if Settings::STORAGE_IV_RATINGS
      typebitmap = AnimatedBitmap.new(_INTL("Graphics/UI/types"))
      pokemon.types.each_with_index do |type, i|
        type_number = GameData::Type.get(type).icon_position
        type_rect = Rect.new(0, type_number * TYPE_ICON_HEIGHT, TYPE_ICON_RECT_WIDTH, TYPE_ICON_HEIGHT)
        type_x = (pokemon.types.length == 1) ? TYPE_ICON_X_1 : TYPE_ICON_X_2 + (TYPE_ICON_X_SPACING * i)
        overlay.blt(type_x, TYPE_ICON_Y, typebitmap.bitmap, type_rect)
      end

      pbDrawImagePositions(overlay, imagepos)
    end
    pbDrawTextPositions(overlay, textstrings)
    @sprites["pokemon"].setPokemonBitmap(pokemon)
    @sprites["pokemon"].make_grey_if_fainted = pokemon.fainted? if pokemon
    pbFadeInOverlay if @sprites["overlay"].opacity == 0
  end

  # --- AISLAMIENTO DEL CURSOR A LA CUADRÍCULA 5x5 ---
  def pbChangeSelection(key, selection)
    skip = @multi && defined?(@grabber) && @grabber && @grabber.holding_anything? && !@grabber.carrying
    bw = PokemonBox::BOX_WIDTH
    bs = PokemonBox::BOX_SIZE
    case key
    when Input::UP
      if selection == -1
        selection = bs - bw
      elsif selection >= 0 && selection < bw
        if skip
          selection = selection - bw + bs
        else
          selection = -1
        end
      else
        selection -= bw
      end
    when Input::DOWN
      if selection == -1
        selection = bw / 2
      elsif selection >= bs - bw
        if skip
          selection = selection + bw - bs
        else
          selection = -1
        end
      else
        selection += bw
      end
    when Input::LEFT
      if selection == -1
        selection = -4
      elsif selection == -4 || selection == -5
      elsif (selection % bw) == 0
        selection += bw - 1
      else
        selection -= 1
      end
    when Input::RIGHT
      if selection == -1
        selection = -5
      elsif selection == -4 || selection == -5
      elsif (selection % bw) == bw - 1
        selection -= bw - 1
      else
        selection += 1
      end
    end
    return selection
  end

  # --- Coordenadas del Cursor (usa los mismos valores que el grid) ---
  ICON_CENTER_X = 11
  ICON_CENTER_Y = 7

  def pbSetArrow(arrow, selection)
    arrow.on_namebox = (selection == -1 || selection == -4 || selection == -5)
    arrow.party_grab = false
    arrow.box_offset = 18
    case selection
    when -1, -4, -5  
      tx = PokemonBoxSprite::BOX_X + PokemonBoxSprite::BOX_NAME_X_OFFSET - 24
      ty = PokemonBoxSprite::BOX_Y - 16
    else
      if selection >= 0
        col = selection % PokemonBox::BOX_WIDTH
        row = selection / PokemonBox::BOX_WIDTH
        base_x = PokemonBoxSprite::BOX_X + PokemonBoxSprite::GRID_X_OFFSET
        base_y = PokemonBoxSprite::BOX_Y + PokemonBoxSprite::GRID_Y_OFFSET
        tx = base_x + (col * PokemonBoxSprite::GRID_X_SPACING)
        ty = base_y - 32 + (row * PokemonBoxSprite::GRID_Y_SPACING)
      end
    end
    arrow.target_x = tx
    arrow.target_y = ty
    return unless selection >= 0
    return unless @multi && defined?(@grabber) && @grabber && @grabber.holding_anything? && !@grabber.carrying
    @grabber.do_with(selection)
    do_green
  end

  def pbPartySetArrow(arrow, selection)
    arrow.on_namebox = false
    arrow.box_offset = nil
    arrow.party_grab = true if arrow.holding?
    return if selection < 0
    if selection == Settings::MAX_PARTY_SIZE
      tx = -110
      ty = -110
    else
      col = selection % 2
      row = selection / 2
      tx = PokemonBoxPartySprite::PARTY_BOX_X + 80 + (col * 160)
      ty = @sprites["boxparty"].y + 66 + (row * 84) + (col * 24)
    end
    arrow.target_x = tx
    arrow.target_y = ty
  end

  # --- Controles Modificados (Tecla SPECIAL exclusiva para el equipo) ---
  def pbSelectBoxInternal(_party)
    selection = @selection
    pbSetArrow(@sprites["arrow"], selection)
    pbUpdateOverlay(selection)
    pbSetMosaic(selection)
    self.update
    loop do
      Graphics.update
      Input.update
      key = -1
      key = Input::DOWN if Input.repeat?(Input::DOWN)
      key = Input::RIGHT if Input.repeat?(Input::RIGHT)
      key = Input::LEFT if Input.repeat?(Input::LEFT)
      key = Input::UP if Input.repeat?(Input::UP)
      
      if key >= 0
        pbPlayCursorSE
        selection = pbChangeSelection(key, selection)
        pbSetArrow(@sprites["arrow"], selection)
        case selection
        when -4
          nextbox = (@storage.currentBox + @storage.maxBoxes - 1) % @storage.maxBoxes
          pbSwitchBoxToLeft(nextbox)
          @storage.currentBox = nextbox
        when -5
          nextbox = (@storage.currentBox + 1) % @storage.maxBoxes
          pbSwitchBoxToRight(nextbox)
          @storage.currentBox = nextbox
        end
        selection = -1 if [-4, -5].include?(selection)
        pbUpdateOverlay(selection)
        pbSetMosaic(selection)
      end
      self.update
      
      t = defined?(@grabber) && @grabber && (@grabber.holding_anything? || @grabber.carrying)
      
      if Input.trigger?(Input::JUMPUP)
        pbPlayCursorSE
        nextbox = (@storage.currentBox + @storage.maxBoxes - 1) % @storage.maxBoxes
        pbSwitchBoxToLeft(nextbox)
        @storage.currentBox = nextbox
        pbUpdateOverlay(selection)
        pbSetMosaic(selection)
      elsif Input.trigger?(Input::JUMPDOWN)
        pbPlayCursorSE
        nextbox = (@storage.currentBox + 1) % @storage.maxBoxes
        pbSwitchBoxToRight(nextbox)
        @storage.currentBox = nextbox
        pbUpdateOverlay(selection)
        pbSetMosaic(selection)
      elsif Input.trigger?(Input::SPECIAL)
        pbPlayDecisionSE
        @selection = selection
        return [-2, -1]
      
      elsif Input.trigger?(Input::AUX2)
        pbSearch
      elsif Input.trigger?(Input::ACTION) && @command == 0   
        if !t && (!defined?(@grabber) || !@grabber || !@grabber.carrying)
          pbPlayDecisionSE
          pbSetQuickSwap(!@quickswap)
        elsif defined?(@grabber) && @grabber && @grabber.carrying && CAN_MASS_RELEASE && @multi
          pbMassRelease
        end
      elsif Input.trigger?(Input::BACK)
        @selection = selection
        return nil
      elsif Input.trigger?(Input::USE)
        @selection = selection
        if selection >= 0
          return [@storage.currentBox, selection]
        elsif selection == -1   
          return [-4, -1]
        end
      end
    end
  end

  def pbSelectPartyInternal(party, depositing)
    selection = @selection
    pbPartySetArrow(@sprites["arrow"], selection)
    pbUpdateOverlay(selection, party)
    pbSetMosaic(selection)
    self.update
    lastsel = 1
    loop do
      Graphics.update
      Input.update
      key = -1
      key = Input::DOWN if Input.repeat?(Input::DOWN)
      key = Input::RIGHT if Input.repeat?(Input::RIGHT)
      key = Input::LEFT if Input.repeat?(Input::LEFT)
      key = Input::UP if Input.repeat?(Input::UP)
      if key >= 0
        pbPlayCursorSE
        newselection = pbPartyChangeSelection(key, selection)
        case newselection
        when -1
          return -1 if !depositing
        when -2
          selection = lastsel
        else
          selection = newselection
        end
        pbPartySetArrow(@sprites["arrow"], selection)
        lastsel = selection if selection > 0
        pbUpdateOverlay(selection, party)
        pbSetMosaic(selection)
      end
      self.update
      
      # ===== NUEVA FUNCIÓN DE LA TECLA SPECIAL EN EL EQUIPO =====
      if Input.trigger?(Input::SPECIAL)
        pbPlayDecisionSE
        @selection = selection
        return -1 
      # ==========================================================
      
      elsif Input.trigger?(Input::ACTION) && @command == 0   
        pbPlayDecisionSE
        pbSetQuickSwap(!@quickswap, true)
      elsif Input.trigger?(Input::BACK)
        @selection = selection
        return -1
      elsif Input.trigger?(Input::USE)
        if selection >= 0 && selection < Settings::MAX_PARTY_SIZE
          @selection = selection
          return selection
        elsif selection == Settings::MAX_PARTY_SIZE   
          @selection = selection
          return (depositing) ? -3 : -1
        end
      end
    end
  end

  # --- Arreglo de Animaciones y Ventanas de Comando ---
  alias res_fix_start_box pbStartBox
  def pbStartBox(screen, command)
    res_fix_start_box(screen, command)
    if command != 2
      @sprites["boxparty"].y = 480
    else
      @sprites["boxparty"].y = 110
    end
    @sprites["pokemon"].z = -1 if @sprites["pokemon"]
  end

  def pbShowPartyTab
    pbSEPlay("GUI storage show party panel")
    ts = System.uptime
    d = 0.4
    fd = 0.2
    loop do
      now = System.uptime
      el = now - ts
      break if el >= d
      @sprites["boxparty"].y = lerp(480, 110, d, ts, now)
      @sprites["pokemon"].opacity = lerp(255, 0, fd, ts, now).to_i
      @sprites["overlay"].opacity = lerp(255, 0, fd, ts, now).to_i
      self.update
      Graphics.update
    end
    @sprites["pokemon"].opacity = 0
    @sprites["overlay"].opacity = 0
    Input.update
  end

  def pbHidePartyTab
    pbSEPlay("GUI storage hide party panel")
    ts = System.uptime
    d = 0.4
    fd = 0.2
    loop do
      now = System.uptime
      el = now - ts
      break if el >= d
      @sprites["boxparty"].y = lerp(110, 480, d, ts, now)
      @sprites["pokemon"].opacity = lerp(255, 0, fd, ts, now).to_i
      @sprites["overlay"].opacity = lerp(255, 0, fd, ts, now).to_i
      self.update
      Graphics.update
    end
    @sprites["pokemon"].opacity = 0
    @sprites["overlay"].opacity = 0
    Input.update
  end

  # Recuperamos pbBottomRight para solucionar el bug de las ventanas de diálogo
  def pbDisplay(message)
    msgwindow = Window_UnformattedTextPokemon.newWithSize("", 194, 48, 446, 32)
    msgwindow.viewport       = @viewport
    msgwindow.visible        = true
    msgwindow.letterbyletter = false
    msgwindow.resizeHeightToFit(message, 446)
    msgwindow.text = message
    pbBottomRight(msgwindow)
    loop do
      Graphics.update
      Input.update
      break if Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
      msgwindow.update
      self.update
    end
    msgwindow.dispose
    Input.update
  end

  def pbShowCommands(message, commands, index = 0)
    ret = -1
    msgwindow = Window_UnformattedTextPokemon.newWithSize("", 194, 48, 446, 32)
    msgwindow.viewport       = @viewport
    msgwindow.visible        = true
    msgwindow.letterbyletter = false
    msgwindow.text           = message
    msgwindow.resizeHeightToFit(message, 446)
    pbBottomRight(msgwindow)
    
    cmdwindow = Window_CommandPokemon.new(commands)
    cmdwindow.viewport = @viewport
    cmdwindow.visible  = true
    cmdwindow.resizeToFit(cmdwindow.commands)
    cmdwindow.height = Graphics.height - msgwindow.height if cmdwindow.height > Graphics.height - msgwindow.height
    pbBottomRight(cmdwindow)
    cmdwindow.y -= msgwindow.height
    cmdwindow.index = index
    loop do
      Graphics.update
      Input.update
      msgwindow.update
      cmdwindow.update
      if Input.trigger?(Input::BACK)
        ret = -1
        break
      elsif Input.trigger?(Input::USE)
        ret = cmdwindow.index
        break
      end
      self.update
    end
    msgwindow.dispose
    cmdwindow.dispose
    Input.update
    return ret
  end
end

# Animación de agarre/suelta sin salto al grid
class PokemonBoxArrow
  remove_const(:HELD_POKEMON_Y_OFFSET) if const_defined?(:HELD_POKEMON_Y_OFFSET)
  HELD_POKEMON_Y_OFFSET = 16
  remove_const(:GRAB_TIME) if const_defined?(:GRAB_TIME)
  GRAB_TIME = 0.2
  attr_accessor :on_namebox, :party_grab, :box_offset

  def party_offset
    @party_grab ? -18 : 0
  end

  alias _res_fix_update update
  def update
    @updating = true
    supb = @multi ? "g" : (@quickswap ? "q" : "")
    super
    heldpkmn = heldPokemon
    heldpkmn&.update
    @handsprite.update
    if @handsprite && !@handsprite.disposed?
      @handsprite.update
    end
    @holding = false if !heldpkmn
    if @grabbing_timer_start
      gts = @grabbing_timer_start
      gsy = @grab_start_y || @spriteY
      t = System.uptime - gts
      if t <= GRAB_TIME / 2
        @handsprite.change_bitmap(:"grab#{supb}")
        self.y = gsy + lerp(0, 8, GRAB_TIME / 2, gts, System.uptime)
      else
        @handsprite.change_bitmap(:"fist#{supb}")
        delta_y = lerp(8, 0, GRAB_TIME / 2, gts + (GRAB_TIME / 2), System.uptime)
        self.y = gsy + delta_y
        if delta_y == 0
          @holding = true
          @grabbing_timer_start = nil
        end
      end
      heldpkmn.y = lerp(@held_start_y || gsy, (@held_start_y || gsy) - 18, GRAB_TIME, gts, System.uptime) if heldpkmn
      heldpkmn.x = @target_x if heldpkmn && @target_x
    elsif @placing_timer_start
      pts = @placing_timer_start
      psy = @place_start_y || @spriteY
      t = System.uptime - pts
      if t <= GRAB_TIME / 2
        @handsprite.change_bitmap(:"fist#{supb}")
        self.y = psy + lerp(0, 8, GRAB_TIME / 2, pts, System.uptime)
      else
        @handsprite.change_bitmap(:"grab#{supb}")
        delta_y = lerp(8, 0, GRAB_TIME / 2, pts + (GRAB_TIME / 2), System.uptime)
        self.y = psy + delta_y
        if delta_y == 0
          @holding = false
          @heldpkmn = nil
          @party_grab = false
          @placing_timer_start = nil
        end
      end
      if heldpkmn && @held_sprite_off
        slot_y = psy + @held_sprite_off
        heldpkmn.y = lerp(heldpkmn.y, slot_y, GRAB_TIME, pts, System.uptime)
      end
      heldpkmn.x = @target_x if heldpkmn && @target_x
    elsif holding?
      @handsprite.change_bitmap(:"fist#{supb}")
      if heldpkmn
        heldpkmn.x = @target_x if @target_x
        heldpkmn.y = self.y - 18 + (@held_sprite_off || 0)
      end
    else
      if @on_namebox
        @handsprite.change_bitmap(:"movebox#{supb}")
      elsif (System.uptime / 0.5).to_i.even?
        @handsprite.change_bitmap(:"point1#{supb}")
      else
        @handsprite.change_bitmap(:"point2#{supb}")
      end
    end
    @updating = false
  end
end

# Movimiento suave de la mano (lerp al target)
class PokemonBoxArrow
  attr_accessor :target_x, :target_y

  alias _carnek_arr_init initialize
  def initialize(viewport = nil)
    _carnek_arr_init(viewport)
    @target_x = self.x
    @target_y = self.y
    @on_namebox = false
    @party_grab = false
    @handsprite.add_bitmap(:movebox, "Graphics/UI/Storage/cursor_movebox")
    @handsprite.add_bitmap(:moveboxq, "Graphics/UI/Storage/cursor_movebox_q")
    @handsprite.add_bitmap(:moveboxg, "Graphics/UI/Storage/cursor_movebox_g")
  end

  alias _carnek_arr_yset y=
  def y=(value)
    _carnek_arr_yset(value)
    if holding?
      heldPokemon.y = self.y - 18 + (@held_sprite_off || 0)
    end
  end

  alias _carnek_arr_update21 update_21
  def update_21
    heldpkmn = heldPokemon
    heldpkmn&.update
    @handsprite.update
    @holding = false if !heldpkmn
  end

  alias _carnek_arr_grab grab
  def grab(sprite)
    self.x = @target_x
    self.y = @target_y
    _carnek_arr_grab(sprite)
    @heldpkmn.x = @target_x if @heldpkmn
    @grab_start_y = self.y
    @held_start_y = sprite.y
    @held_sprite_off = sprite.y - self.y
  end

  alias _carnek_arr_place place
  def place
    self.x = @target_x
    self.y = @target_y
    _carnek_arr_place
    @place_start_y = self.y
  end

  alias _carnek_arr_update update
  def update
    if @target_x && @target_y && !@grabbing_timer_start && !@placing_timer_start
      dx = @target_x - self.x
      dy = @target_y - self.y
      if dx.abs > 1 || dy.abs > 1
        self.x = self.x + dx * 0.4
        self.y = self.y + dy * 0.4
      elsif self.x != @target_x || self.y != @target_y
        self.x = @target_x
        self.y = @target_y
      end
    end
    _carnek_arr_update
  end
end

# --- Texto "[BACK] Atrás" con tecla dinámica, reposicionado ---
class PokemonBoxPartySprite
  remove_const(:PARTY_BOX_WIDTH) if defined?(PARTY_BOX_WIDTH)
  PARTY_BOX_WIDTH = 312
  remove_const(:PARTY_BOX_HEIGHT) if defined?(PARTY_BOX_HEIGHT)
  PARTY_BOX_HEIGHT = 370
  remove_const(:BACK_TEXT_X) if defined?(BACK_TEXT_X)
  BACK_TEXT_X = 110
  remove_const(:BACK_TEXT_Y) if defined?(BACK_TEXT_Y)
  BACK_TEXT_Y = 15
  def refresh
    @contents.blt(0, 0, @boxbitmap.bitmap, Rect.new(0, 0, PARTY_BOX_WIDTH, PARTY_BOX_HEIGHT))
    @pokemonsprites.delete_if { |sprite| sprite&.disposed? }
    @pokemonsprites.each { |sprite| sprite&.refresh }
    s_x = 80
    s_y = 66
    x_spacing = 160
    y_spacing = 84
    Settings::MAX_PARTY_SIZE.times do |i|
      col = i % 2
      row = i / 2
      sprite = @pokemonsprites[i]
      if sprite && !sprite.disposed?
        sprite.viewport = self.viewport
        sprite.x = PARTY_BOX_X + s_x + (col * x_spacing)
        sprite.y = self.y + s_y + (row * y_spacing) + (col * 24)
        sprite.z = 1
      end
    end
    back_k = KeybindingReader.key_name(Input::BACK)
    pbDrawTextPositions(
      self.bitmap,
      [[_INTL("{1}: Atrás", back_k), BACK_TEXT_X, BACK_TEXT_Y, :center, Color.new(248, 248, 248), Color.new(80, 80, 80), :outline]]
    )
  end

  alias _carnek_party_grab grabPokemon
  def grabPokemon(index, arrow)
    _carnek_party_grab(index, arrow)
    arrow.party_grab = true
    arrow.box_offset = nil
  end

end

class PokemonStorageScene
  def pbPartyChangeSelection(key, selection)
    case key
    when Input::LEFT
      selection -= 1
      selection = Settings::MAX_PARTY_SIZE - 1 if selection < 0
    when Input::RIGHT
      selection += 1
      selection = 0 if selection > Settings::MAX_PARTY_SIZE - 1
    when Input::UP
      selection -= 2
      selection = Settings::MAX_PARTY_SIZE - 1 if selection < 0
    when Input::DOWN
      selection += 2
      selection = 0 if selection > Settings::MAX_PARTY_SIZE - 1
    end
    return selection
  end

  alias _carnek_pbSelectBox pbSelectBox
  def pbSelectBox(party)
    return pbSelectBoxInternal(party) if @command == 1
    ret = nil
    loop do
      ret = pbSelectBoxInternal(party) if !@choseFromParty
      if @choseFromParty || (ret && ret[0] == -2)
        if !@choseFromParty
          pbShowPartyTab
          @selection = 0
        end
        ret = pbSelectPartyInternal(party, false)
        if ret < 0
          pbHidePartyTab
          @selection = 0
          @choseFromParty = false
        else
          @choseFromParty = true
          return [-1, ret]
        end
      else
        @choseFromParty = false
        return ret
      end
    end
  end

  def set_box_sprites_opacity(box, op)
    sprs = box.instance_variable_get(:@pokemonsprites)
    sprs&.each { |s| s.opacity = op if s && !s.disposed? }
  end

  alias _carnek_ps_box_right pbSwitchBoxToRight
  def pbSwitchBoxToRight(new_box_number)
    box = @sprites["box"]
    start_x = box.x
    newbox = PokemonBoxSprite.new(@storage, new_box_number, @boxviewport)
    newbox.x = start_x + SWITCH_BOX_X_OFFSET
    newbox.opacity = 0
    set_box_sprites_opacity(newbox, 0)
    ts = System.uptime
    d = 0.4
    fd = 0.2
    loop do
      now = System.uptime
      el = now - ts
      break if el >= d
      t = el / d
      st = (1 - Math.cos(t * Math::PI)) / 2
      box_op = (255 * (1 - st)).to_i
      @sprites["box"].x = start_x - SWITCH_BOX_X_OFFSET * st
      @sprites["box"].opacity = box_op
      set_box_sprites_opacity(@sprites["box"], box_op)
      box_op2 = (255 * st).to_i
      newbox.x = @sprites["box"].x + SWITCH_BOX_X_OFFSET
      newbox.opacity = box_op2
      set_box_sprites_opacity(newbox, box_op2)
      @sprites["pokemon"].opacity = lerp(255, 0, fd, ts, now).to_i
      @sprites["overlay"].opacity = lerp(255, 0, fd, ts, now).to_i
      self.update
      Graphics.update
    end
    @sprites["pokemon"].opacity = 0
    @sprites["overlay"].opacity = 0
    @sprites["box"].opacity = 255
    set_box_sprites_opacity(@sprites["box"], 255)
    newbox.x = PokemonBoxSprite::BOX_X
    @sprites["box"].dispose
    @sprites["box"] = newbox
    newbox.opacity = 255
    set_box_sprites_opacity(newbox, 255)
    Input.update
  end

  alias _carnek_ps_box_left pbSwitchBoxToLeft
  def pbSwitchBoxToLeft(new_box_number)
    box = @sprites["box"]
    start_x = box.x
    newbox = PokemonBoxSprite.new(@storage, new_box_number, @boxviewport)
    newbox.x = start_x - SWITCH_BOX_X_OFFSET
    newbox.opacity = 0
    set_box_sprites_opacity(newbox, 0)
    ts = System.uptime
    d = 0.4
    fd = 0.2
    loop do
      now = System.uptime
      el = now - ts
      break if el >= d
      t = el / d
      st = (1 - Math.cos(t * Math::PI)) / 2
      box_op = (255 * (1 - st)).to_i
      @sprites["box"].x = start_x + SWITCH_BOX_X_OFFSET * st
      @sprites["box"].opacity = box_op
      set_box_sprites_opacity(@sprites["box"], box_op)
      box_op2 = (255 * st).to_i
      newbox.x = @sprites["box"].x - SWITCH_BOX_X_OFFSET
      newbox.opacity = box_op2
      set_box_sprites_opacity(newbox, box_op2)
      @sprites["pokemon"].opacity = lerp(255, 0, fd, ts, now).to_i
      @sprites["overlay"].opacity = lerp(255, 0, fd, ts, now).to_i
      self.update
      Graphics.update
    end
    @sprites["pokemon"].opacity = 0
    @sprites["overlay"].opacity = 0
    @sprites["box"].opacity = 255
    set_box_sprites_opacity(@sprites["box"], 255)
    newbox.x = PokemonBoxSprite::BOX_X
    @sprites["box"].dispose
    @sprites["box"] = newbox
    newbox.opacity = 255
    set_box_sprites_opacity(newbox, 255)
    Input.update
  end

  alias _carnek_ps_pbSwap pbSwap
  def pbSwap(selected, _heldpoke)
    arrow = @sprites["arrow"]
    held_sprite = arrow.heldPokemon
    if selected[0] == -1
      box_sprite = @sprites["boxparty"]&.getPokemon(selected[1])
    else
      box_sprite = @sprites["box"]&.getPokemon(selected[1])
    end
    if held_sprite && box_sprite && !held_sprite.disposed? && !box_sprite.disposed?
      hx_orig, hy_orig = held_sprite.x, held_sprite.y
      bx_orig, by_orig = box_sprite.x, box_sprite.y
      mid_x = (hx_orig + bx_orig) / 2.0
      mid_y = (hy_orig + by_orig) / 2.0
      dhx, dhy = hx_orig - mid_x, hy_orig - mid_y
      dbx, dby = bx_orig - mid_x, by_orig - mid_y
      vis_min = 8.0
      s = Math.sqrt(dhx**2 + dhy**2)
      start_scale = (s > 0 && s < vis_min) ? vis_min / s : 1.0
      ts = System.uptime
      loop do
        el = System.uptime - ts
        break if el >= 0.3
        t = el / 0.3
        cur_scale = start_scale + (1.0 - start_scale) * t
        chx = dhx * cur_scale; chy = dhy * cur_scale
        cbx = dbx * cur_scale; cby = dby * cur_scale
        a = t * Math::PI
        ca, sa = Math.cos(a), Math.sin(a)
        held_sprite.x = mid_x + chx * ca - chy * sa
        held_sprite.y = mid_y + chx * sa + chy * ca
        box_sprite.x  = mid_x + cbx * ca + cby * sa
        box_sprite.y  = mid_y - cbx * sa + cby * ca
        Graphics.update
        Input.update
      end
      held_sprite.x, held_sprite.y = bx_orig, by_orig
      box_sprite.x,  box_sprite.y  = hx_orig, hy_orig
    end
    _carnek_ps_pbSwap(selected, _heldpoke)
  end

  alias _carnek_ps_place pbPlace
  def pbPlace(selected, _heldpoke)
    @sprites["arrow"].party_grab = false if selected[0] != -1
    _carnek_ps_place(selected, _heldpoke)
  end

  def pbFadeInOverlay
    ts = System.uptime
    loop do
      el = System.uptime - ts
      break if el >= 0.1
      op = lerp(0, 255, 0.1, ts, System.uptime).to_i
      @sprites["pokemon"].opacity = op
      @sprites["overlay"].opacity = op
      self.update
      Graphics.update
    end
    @sprites["pokemon"].opacity = 255
    @sprites["overlay"].opacity = 255
  end
end

# --- Quitar Marcas del menú de acciones del almacenamiento ---
class PokemonStorageScreen
  alias _carnek_organise_commands organise_commands
  def organise_commands(selected, pokemon)
    commands = []
    cmdMove     = -1
    cmdSummary  = -1
    cmdWithdraw = -1
    cmdItem     = -1
    cmdPokedex  = -1
    cmdRelease  = -1
    cmdDebug    = -1
    heldpoke = pbHeldPokemon
    if heldpoke
      helptext = _INTL("Has seleccionado a {1}.", heldpoke.name)
      commands[cmdMove = commands.length] = (pokemon) ? _INTL("Cambiar") : _INTL("Dejar")
    elsif pokemon
      helptext = _INTL("Has seleccionado a {1}.", pokemon.name)
      commands[cmdMove = commands.length] = _INTL("Mover")
    end
    commands[cmdSummary = commands.length]  = _INTL("Datos")
    commands[cmdWithdraw = commands.length] = (selected[0] == -1) ? _INTL("Guardar") : _INTL("Sacar")
    commands[cmdItem = commands.length]     = _INTL("Objeto")
    poke_for_dex = (pokemon) ? pokemon : @heldpkmn
    commands[cmdPokedex = commands.length]  = _INTL("Pokédex") if $player.has_pokedex && poke_for_dex && !poke_for_dex.egg? && $player.pokedex.species_in_unlocked_dex?(poke_for_dex.species)
    commands[cmdRelease = commands.length]  = _INTL("Liberar")
    commands[cmdDebug = commands.length]    = _INTL("Debug") if $DEBUG
    commands[commands.length]               = _INTL("Cancelar")
    command = pbShowCommands(helptext, commands)
    if cmdMove >= 0 && command == cmdMove
      if @heldpkmn
        (pokemon) ? pbSwap(selected) : pbPlace(selected)
      else
        pbHold(selected)
      end
    elsif cmdSummary >= 0 && command == cmdSummary
      pbSummary(selected, @heldpkmn)
    elsif cmdWithdraw >= 0 && command == cmdWithdraw
      (selected[0] == -1) ? pbStore(selected, @heldpkmn) : pbWithdraw(selected, @heldpkmn)
    elsif cmdItem >= 0 && command == cmdItem
      pbItem(selected, @heldpkmn)
    elsif cmdPokedex >= 0 && command == cmdPokedex
      openPokedexOnPokemon(pokemon.species, pokemon.gender, pokemon.form) if pokemon
      openPokedexOnPokemon(@heldpkmn.species, @heldpkmn.gender, @heldpkmn.form) if !pokemon && @heldpkmn
    elsif cmdRelease >= 0 && command == cmdRelease
      pbRelease(selected, @heldpkmn)
    elsif cmdDebug >= 0 && command == cmdDebug
      pbPokemonDebug((@heldpkmn) ? @heldpkmn : pokemon, selected, heldpoke)
    end
  end
end

# --- Quitar Marcas del resumen (visual + menú) ---
class PokemonSummary_Scene
  def drawMarkings(bitmap, x, y)
  end

  alias _carnek_pbOptions pbOptions
  def pbOptions
    dorefresh = false
    commands = []
    cmdGiveItem = -1
    cmdTakeItem = -1
    cmdPokedex  = -1
    if !@pokemon.egg?
      commands[cmdGiveItem = commands.length] = _INTL("Dar objeto")
      commands[cmdTakeItem = commands.length] = _INTL("Guardar objeto") if @pokemon.hasItem?
      commands[cmdPokedex = commands.length]  = _INTL("Ver Pokédex") if $player.has_pokedex
    end
    commands[commands.length]                 = _INTL("Cancelar")
    command = pbShowCommands(commands)
    if cmdGiveItem >= 0 && command == cmdGiveItem
      item = nil
      pbFadeOutIn do
        scene = PokemonBag_Scene.new
        screen = PokemonBagScreen.new(scene, $bag)
        item = screen.pbChooseItemScreen(proc { |itm| GameData::Item.get(itm).can_hold? })
      end
      dorefresh = pbGiveItemToPokemon(item, @pokemon, self, @partyindex) if item
    elsif cmdTakeItem >= 0 && command == cmdTakeItem
      dorefresh = pbTakeItemFromPokemon(@pokemon, self)
    elsif cmdPokedex >= 0 && command == cmdPokedex
      $player.pokedex.register_last_seen(@pokemon)
      pbFadeOutIn do
        scene = PokemonPokedexInfo_Scene.new
        screen = PokemonPokedexInfoScreen.new(scene)
        screen.pbStartSceneSingle(@pokemon.species, true)
      end
      dorefresh = true
    end
    return dorefresh
  end
end

# --- Quitar Marcas de las páginas del resumen MUI ---
if defined?(UIHandlers) && UIHandlers.respond_to?(:edit_hash)
  UIHandlers.edit_hash(:summary, :page_info, "options",
    [:item] + (Settings::ALLOW_RENAMING_POKEMON_IN_SUMMARY_SCREEN ? [:nickname] : []) + [:pokedex, :legacy])
  UIHandlers.edit_hash(:summary, :page_memo, "options",
    [:item] + (Settings::ALLOW_RENAMING_POKEMON_IN_SUMMARY_SCREEN ? [:nickname] : []) + [:pokedex, :legacy])
  UIHandlers.edit_hash(:summary, :page_skills, "options",
    [:item] + (Settings::ALLOW_RENAMING_POKEMON_IN_SUMMARY_SCREEN ? [:nickname] : []) + [:pokedex, :legacy])
  UIHandlers.edit_hash(:summary, :page_egg, "options", [])
end
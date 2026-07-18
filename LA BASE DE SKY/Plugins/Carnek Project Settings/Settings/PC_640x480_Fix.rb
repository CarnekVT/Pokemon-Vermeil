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
  BOX_NAME_Y = 6

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
        sprite = @pokemonsprites[(row * PokemonBox::BOX_WIDTH) + col]
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
  
  POKENAME_TEXT_X = 14
  POKENAME_TEXT_Y = 10
  GENDER_ICON_TEXT_X = 174
  GENDER_ICON_TEXT_Y = 10
  
  LEVEL_ICON_X = 12
  LEVEL_ICON_Y = 254
  LEVEL_NUMBER_X = 34
  LEVEL_NUMBER_Y = 248
  
  SHINY_ICON_X = 160
  SHINY_ICON_Y = 254
  SHINY_LEAF_X = 162
  SHINY_LEAF_Y = 98
  IV_RATING_X = 12
  IV_RATING_Y = 254
  
  MARKINGS_X = 66
  MARKINGS_Y = 248
  
  TYPE_ICON_Y = 286
  TYPE_ICON_X_1 = 64
  TYPE_ICON_X_2 = 30
  
  ABILITY_NAME_X = 96
  ABILITY_NAME_Y = 340
  ITEM_NAME_X = 96
  ITEM_NAME_Y = 376

  # Desterramos los textos viejos
  TEAM_TEXT_X = -1100
  TEAM_TEXT_Y = -1100
  EXIT_TEXT_X = -1100
  EXIT_TEXT_Y = -1100
  
  NEW_TEAM_TEXT_X = 96
  NEW_TEAM_TEXT_Y = 422
  NEW_EXIT_TEXT_X = 96
  NEW_EXIT_TEXT_Y = 456

  # --- Sin recorte del sprite battler ---
  alias _res_fix_pbUpdateOverlay pbUpdateOverlay
  def pbUpdateOverlay(selection, party = nil)
    _res_fix_pbUpdateOverlay(selection, party)
    overlay = @sprites["overlay"].bitmap
    buttonbase = Color.new(248, 248, 248)
    buttonshadow = Color.new(80, 80, 80)
    
    overlay.fill_rect(194, 430, 436, 50, Color.new(0,0,0,0))
    overlay.fill_rect(10, 410, 180, 70, Color.new(0,0,0,0))
    
    sprite = @sprites["pokemon"]
    if sprite && sprite.bitmap && !sprite.bitmap.disposed?
      sprite.src_rect.set(0, 0, sprite.bitmap.width, sprite.bitmap.height)
    end
    
    special_k = KeybindingReader.key_name(Input::SPECIAL)
    back_k = KeybindingReader.key_name(Input::BACK)
    pbDrawTextPositions(
      overlay,
      [[_INTL("[{1}] Equipo: {2}", special_k, (@storage.party.length rescue 0)), NEW_TEAM_TEXT_X, NEW_TEAM_TEXT_Y, :center, buttonbase, buttonshadow, :outline],
       [_INTL("[{1}] Salir", back_k), NEW_EXIT_TEXT_X, NEW_EXIT_TEXT_Y, :center, buttonbase, buttonshadow, :outline]]
    )
  end

  # --- AISLAMIENTO DEL CURSOR A LA CUADRÍCULA 5x5 ---
  def pbChangeSelection(key, selection)
    case key
    when Input::UP
      if selection == -1   
        selection = 22     
      elsif selection < 5 && selection >= 0
        selection = -1
      else
        selection -= 5
        selection = -1 if selection < 0 && selection != -4 && selection != -5
      end
    when Input::DOWN
      if selection == -1   
        selection = 2      
      elsif selection >= 20
        selection = -1     
      else
        selection += 5
      end
    when Input::LEFT
      if selection == -1
        selection = -4
      elsif selection == -4 || selection == -5
        # Mantiene estado
      elsif (selection % 5) == 0
        selection += 4     
      else
        selection -= 1
      end
    when Input::RIGHT
      if selection == -1
        selection = -5
      elsif selection == -4 || selection == -5
        # Mantiene estado
      elsif (selection % 5) == 4
        selection -= 4     
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
    case selection
    when -1, -4, -5  
      arrow.x = PokemonBoxSprite::BOX_X + PokemonBoxSprite::BOX_NAME_X_OFFSET - 24
      arrow.y = PokemonBoxSprite::BOX_Y - 16
    else
      if selection >= 0
        col = selection % PokemonBox::BOX_WIDTH
        row = selection / PokemonBox::BOX_WIDTH
        base_x = PokemonBoxSprite::BOX_X + PokemonBoxSprite::GRID_X_OFFSET
        base_y = PokemonBoxSprite::BOX_Y + PokemonBoxSprite::GRID_Y_OFFSET
        arrow.x = base_x + (col * PokemonBoxSprite::GRID_X_SPACING)
        arrow.y = base_y - 32 + (row * PokemonBoxSprite::GRID_Y_SPACING)
      end
    end
  end

  def pbPartySetArrow(arrow, selection)
    return if selection < 0
    if selection == Settings::MAX_PARTY_SIZE
      arrow.x = -110
      arrow.y = -110
    else
      col = selection % 2
      row = selection / 2
      arrow.x = PokemonBoxPartySprite::PARTY_BOX_X + 80 + (col * 160)
      arrow.y = 110 + 66 - 32 + (row * 84) + (col * 24)
    end
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
      
      t = defined?(@grabber) && @grabber && @grabber.holding_anything? && !@grabber.carrying
      
      if Input.trigger?(Input::JUMPUP) && !t
        pbPlayCursorSE
        nextbox = (@storage.currentBox + @storage.maxBoxes - 1) % @storage.maxBoxes
        pbSwitchBoxToLeft(nextbox)
        @storage.currentBox = nextbox
        pbUpdateOverlay(selection)
        pbSetMosaic(selection)
      elsif Input.trigger?(Input::JUMPDOWN) && !t
        pbPlayCursorSE
        nextbox = (@storage.currentBox + 1) % @storage.maxBoxes
        pbSwitchBoxToRight(nextbox)
        @storage.currentBox = nextbox
        pbUpdateOverlay(selection)
        pbSetMosaic(selection)
        
      # ===== NUEVA FUNCIÓN DE LA TECLA SPECIAL =====
      elsif Input.trigger?(Input::SPECIAL) && !t   
        pbPlayDecisionSE
        @selection = selection
        return [-2, -1] 
      # =============================================
      
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
  end

  def pbShowPartyTab
    if !@screen.pbHeldPokemon
      pbUpdateOverlay(-1)
      pbSetMosaic(-1)
    end
    pbSEPlay("GUI storage show party panel")
    start_y = 480
    timer_start = System.uptime
    loop do
      @sprites["boxparty"].y = lerp(start_y, 110, 0.4, timer_start, System.uptime)
      self.update
      Graphics.update
      break if @sprites["boxparty"].y == 110
    end
    Input.update
  end

  def pbHidePartyTab
    if !@screen.pbHeldPokemon
      pbUpdateOverlay(-1)
      pbSetMosaic(-1)
    end
    pbSEPlay("GUI storage hide party panel")
    start_y = 110
    timer_start = System.uptime
    loop do
      @sprites["boxparty"].y = lerp(start_y, 480, 0.4, timer_start, System.uptime)
      self.update
      Graphics.update
      break if @sprites["boxparty"].y == 480
    end
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

  alias _res_fix_update update
  def update
    @updating = true
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
      t = System.uptime - gts
      if t <= GRAB_TIME / 2
        @handsprite.change_bitmap((@quickswap) ? :grabq : :grab)
        self.y = @spriteY + lerp(0, 8, GRAB_TIME / 2, gts, System.uptime)
      else
        @handsprite.change_bitmap((@quickswap) ? :fistq : :fist)
        delta_y = lerp(8, 0, GRAB_TIME / 2, gts + (GRAB_TIME / 2), System.uptime)
        self.y = @spriteY + delta_y
        if delta_y == 0
          @holding = true
          @grabbing_timer_start = nil
        end
      end
      heldpkmn.y = @spriteY + 32 - lerp(0, 16, GRAB_TIME, gts, System.uptime) if heldpkmn
    elsif @placing_timer_start
      pts = @placing_timer_start
      t = System.uptime - pts
      if t <= GRAB_TIME / 2
        @handsprite.change_bitmap((@quickswap) ? :fistq : :fist)
        self.y = @spriteY + lerp(0, 8, GRAB_TIME / 2, pts, System.uptime)
      else
        @handsprite.change_bitmap((@quickswap) ? :grabq : :grab)
        delta_y = lerp(8, 0, GRAB_TIME / 2, pts + (GRAB_TIME / 2), System.uptime)
        self.y = @spriteY + delta_y
        if delta_y == 0
          @holding = false
          @heldpkmn = nil
          @placing_timer_start = nil
        end
      end
      heldpkmn.y = @spriteY + 16 + lerp(0, 16, GRAB_TIME, pts, System.uptime) if heldpkmn && @holding
    elsif holding?
      @handsprite.change_bitmap((@quickswap) ? :fistq : :fist)
    else
      self.x = @spriteX
      self.y = @spriteY
      if (System.uptime / 0.5).to_i.even?
        @handsprite.change_bitmap((@quickswap) ? :point1q : :point1)
      else
        @handsprite.change_bitmap((@quickswap) ? :point2q : :point2)
      end
    end
    @updating = false
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
    x_start = PARTY_BOX_X + 80
    y_start = 66
    x_spacing = 160
    y_spacing = 84
    Settings::MAX_PARTY_SIZE.times do |i|
      sprite = @pokemonsprites[i]
      if sprite && !sprite.disposed?
        col = i % 2
        row = i / 2
        sprite.viewport = self.viewport
        sprite.x = x_start + (col * x_spacing)
        sprite.y = self.y + y_start + (row * y_spacing) + (col * 24)
        sprite.z = 1
      end
    end
    back_k = KeybindingReader.key_name(Input::BACK)
    pbDrawTextPositions(
      self.bitmap,
      [[_INTL("{1}: Atrás", back_k), BACK_TEXT_X, BACK_TEXT_Y, :center, Color.new(248, 248, 248), Color.new(80, 80, 80), :outline]]
    )
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
end

# Movimiento suave de la mano (lerp al target)
class PokemonBoxArrow
  attr_accessor :target_x, :target_y

  alias _carnek_arr_init initialize
  def initialize(viewport = nil)
    _carnek_arr_init(viewport)
    @target_x = self.x
    @target_y = self.y
  end

  alias _carnek_arr_grab grab
  def grab(sprite)
    self.x = @target_x
    self.y = @target_y
    _carnek_arr_grab(sprite)
    @heldpkmn.x = @target_x if @heldpkmn
  end

  alias _carnek_arr_place place
  def place
    self.x = @target_x
    self.y = @target_y
    _carnek_arr_place
  end

  alias _carnek_arr_update update
  def update
    if @target_x && @target_y
      dx = @target_x - self.x
      dy = @target_y - self.y
      if dx.abs > 1 || dy.abs > 1
        self.x = self.x + dx * 0.4
        self.y = self.y + dy * 0.4
      else
        self.x = @target_x
        self.y = @target_y
      end
    end
    _carnek_arr_update
  end
end

class PokemonStorageScene
  def pbSetArrow(arrow, selection)
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
      else
        tx = arrow.x
        ty = arrow.y
      end
    end
    arrow.target_x = tx
    arrow.target_y = ty
  end

  def pbPartySetArrow(arrow, selection)
    return if selection < 0
    if selection == Settings::MAX_PARTY_SIZE
      tx = -110
      ty = -110
    else
      col = selection % 2
      row = selection / 2
      tx = PokemonBoxPartySprite::PARTY_BOX_X + 80 + (col * 160)
      ty = 110 + 66 - 32 + (row * 84) + (col * 24)
    end
    arrow.target_x = tx
    arrow.target_y = ty
  end

  def reset_icon_zoom(idx, party = false)
    sprites = party ? @sprites["boxparty"] : @sprites["box"]
    s = sprites&.getPokemon(idx)
    if s
      s.zoom_x = 1.0
      s.zoom_y = 1.0
    end
  end

  def set_icon_zoom(idx, zoom, party = false)
    sprites = party ? @sprites["boxparty"] : @sprites["box"]
    s = sprites&.getPokemon(idx)
    if s
      s.zoom_x = zoom
      s.zoom_y = zoom
    end
  end

  alias _carnek_ps_update update
  def update
    _carnek_ps_update
    if @_hover_anim
      elapsed = System.uptime - @_hover_anim[:start]
      if elapsed >= 0.3
        set_icon_zoom(@_hover_anim[:idx], 1.0, @_hover_anim[:party])
        @_hover_anim = nil
      else
        t = elapsed / 0.3
        set_icon_zoom(@_hover_anim[:idx], 1.0 + Math.sin(t * Math::PI) * 0.2, @_hover_anim[:party])
      end
    end
  end
end

class PokemonStorageScene
  alias _carnek_ps_pbSetArrow pbSetArrow
  def pbSetArrow(arrow, selection)
    if selection >= 0 && selection != @_last_box_hover
      reset_icon_zoom(@_last_box_hover, false) if @_last_box_hover
      @_hover_anim = { start: System.uptime, idx: selection, party: false }
      @_last_box_hover = selection
    elsif selection < 0
      reset_icon_zoom(@_last_box_hover, false) if @_last_box_hover
      @_last_box_hover = nil
    end
    _carnek_ps_pbSetArrow(arrow, selection)
  end

  alias _carnek_ps_pbPartySetArrow pbPartySetArrow
  def pbPartySetArrow(arrow, selection)
    if selection >= 0 && selection < Settings::MAX_PARTY_SIZE && selection != @_last_party_hover
      reset_icon_zoom(@_last_party_hover, true) if @_last_party_hover
      @_hover_anim = { start: System.uptime, idx: selection, party: true }
      @_last_party_hover = selection
    elsif selection < 0 || selection >= Settings::MAX_PARTY_SIZE
      reset_icon_zoom(@_last_party_hover, true) if @_last_party_hover
      @_last_party_hover = nil
    end
    _carnek_ps_pbPartySetArrow(arrow, selection)
  end
end

class PokemonStorageScene
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
      slot_x = selected[0] == -1 \
        ? PokemonBoxPartySprite::PARTY_BOX_X + 80 + (selected[1] % 2) * 160 \
        : PokemonBoxSprite::BOX_X + PokemonBoxSprite::GRID_X_OFFSET + (selected[1] % PokemonBox::BOX_WIDTH) * PokemonBoxSprite::GRID_X_SPACING
      slot_y = selected[0] == -1 \
        ? 110 + 66 + (selected[1] / 2) * 84 + (selected[1] % 2) * 24 \
        : PokemonBoxSprite::BOX_Y + PokemonBoxSprite::GRID_Y_OFFSET + (selected[1] / PokemonBox::BOX_WIDTH) * PokemonBoxSprite::GRID_Y_SPACING
      hx, hy = held_sprite.x, held_sprite.y
      bx, by = box_sprite.x, box_sprite.y
      mid_x = (hx + bx) / 2.0
      mid_y = (hy + by) / 2.0
      dhx, dhy = hx - mid_x, hy - mid_y
      dbx, dby = bx - mid_x, by - mid_y
      ts = System.uptime
      loop do
        el = System.uptime - ts
        break if el >= 0.3
        a = el / 0.3 * Math::PI
        ca, sa = Math.cos(a), Math.sin(a)
        held_sprite.x = mid_x + dhx * ca - dhy * sa
        held_sprite.y = mid_y + dhx * sa + dhy * ca
        box_sprite.x  = mid_x + dbx * ca + dby * sa
        box_sprite.y  = mid_y - dbx * sa + dby * ca
        Graphics.update
        Input.update
      end
      held_sprite.x, held_sprite.y = bx, by
      box_sprite.x,  box_sprite.y  = hx, hy
    end
    _carnek_ps_pbSwap(selected, _heldpoke)
  end
end
class DeluxeBitmapWrapper
  alias _res_fix_refresh refresh
  def refresh(bitmaps = nil)
    _res_fix_refresh(bitmaps)
    if @temp_bmp && !@bitmaps.empty?
      bmp = @bitmaps[0]
      if @temp_bmp.width != bmp.width || @temp_bmp.height != bmp.height
        @temp_bmp.dispose
        @temp_bmp = Bitmap.new(bmp.width, bmp.height)
      end
    end
  end
end
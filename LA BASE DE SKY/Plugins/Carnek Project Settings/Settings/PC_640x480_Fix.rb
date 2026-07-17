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

# 2. Dibujo manual de la Caja y los Iconos (Centrado milimétrico)
class PokemonBoxSprite < Sprite
  remove_const(:BOX_NAME_X_OFFSET) if defined?(BOX_NAME_X_OFFSET)
  
  BOX_X = 194  
  BOX_Y = 5   
  BOX_WIDTH = 436
  BOX_HEIGHT = 470
  
  BOX_NAME_X_OFFSET = 218 # Mitad de 436

  alias _res_fix_refresh refresh
  def refresh
    _res_fix_refresh
    
    # Centro matemático para icono 42x42 en celda de 87x84
    x_start = self.x + 22 
    y_start = self.y + 71 
    
    x_spacing = 87 
    y_spacing = 84 
    
    PokemonBox::BOX_HEIGHT.times do |row|
      PokemonBox::BOX_WIDTH.times do |col|
        sprite = @pokemonsprites[(row * PokemonBox::BOX_WIDTH) + col]
        if sprite && !sprite.disposed?
          sprite.x = x_start + (col * x_spacing)
          sprite.y = y_start + (row * y_spacing)
        end
      end
    end
  end
end

# 3. Dibujo manual del Equipo (Party)
class PokemonBoxPartySprite < Sprite
  PARTY_BOX_X = 194
  
  alias _res_fix_init initialize
  def initialize(party, viewport = nil)
    _res_fix_init(party, viewport)
    self.y = 480 
  end

  alias _res_fix_refresh refresh
  def refresh
    _res_fix_refresh
    
    x_start = PARTY_BOX_X + 80
    y_start = 50
    x_spacing = 160
    y_spacing = 84
    
    Settings::MAX_PARTY_SIZE.times do |i|
      sprite = @pokemonsprites[i]
      if sprite && !sprite.disposed?
        col = i % 2
        row = i / 2
        sprite.x = x_start + (col * x_spacing)
        sprite.y = self.y + y_start + (row * y_spacing) + (col * 24)
      end
    end
  end
end

# 4. Cursores, Textos y Aislamiento de Navegación
class PokemonStorageScene
  remove_const(:SWITCH_BOX_X_OFFSET) if defined?(SWITCH_BOX_X_OFFSET)
  SWITCH_BOX_X_OFFSET = 450 # Evita que las cajas se superpongan al deslizarse

  # --- Ajuste Perfecto del Panel Izquierdo ---
  POKEMON_SPRITE_X = 96
  POKEMON_SPRITE_Y = 136
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
  TEAM_TEXT_X = -1000
  TEAM_TEXT_Y = -1000
  EXIT_TEXT_X = -1000
  EXIT_TEXT_Y = -1000
  
  NEW_TEAM_TEXT_X = 96
  NEW_TEAM_TEXT_Y = 422
  NEW_EXIT_TEXT_X = 96
  NEW_EXIT_TEXT_Y = 456

  # --- Textos Inferiores (Solo lectura) ---
  alias _res_fix_pbUpdateOverlay pbUpdateOverlay
  def pbUpdateOverlay(selection, party = nil)
    _res_fix_pbUpdateOverlay(selection, party)
    overlay = @sprites["overlay"].bitmap
    buttonbase = Color.new(248, 248, 248)
    buttonshadow = Color.new(80, 80, 80)
    
    overlay.fill_rect(194, 430, 436, 50, Color.new(0,0,0,0))
    overlay.fill_rect(10, 410, 180, 70, Color.new(0,0,0,0))
    
    pbDrawTextPositions(
      overlay,
      [[_INTL("[SPECIAL] Equipo: {1}", (@storage.party.length rescue 0)), NEW_TEAM_TEXT_X, NEW_TEAM_TEXT_Y, :center, buttonbase, buttonshadow, :outline],
       [_INTL("[X] Salir"), NEW_EXIT_TEXT_X, NEW_EXIT_TEXT_Y, :center, buttonbase, buttonshadow, :outline]]
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

  # --- Coordenadas del Cursor (-32px de compensación en Y) ---
  def pbSetArrow(arrow, selection)
    case selection
    when -1, -4, -5  
      arrow.x = 194 + 218 - 24
      arrow.y = 10
    else
      if selection >= 0
        col = selection % 5
        row = selection / 5
        arrow.x = (194 + 22) + (col * 87)
        arrow.y = (5 + 71 - 32) + (row * 84) # -32 para que el dedo apunte al centro
      end
    end
  end

  def pbPartySetArrow(arrow, selection)
    return if selection < 0
    if selection == Settings::MAX_PARTY_SIZE
      arrow.x = -100
      arrow.y = -100
    else
      col = selection % 2
      row = selection / 2
      arrow.x = 194 + 80 + (col * 160)
      arrow.y = 128 + 50 - 32 + (row * 84) + (col * 24) # -32 para el dedo
    end
  end

  # --- Controles Modificados (Tecla SPECIAL exclusiva para el equipo) ---
  def pbSelectBoxInternal(_party)
    selection = @selection
    pbSetArrow(@sprites["arrow"], selection)
    pbUpdateOverlay(selection)
    pbSetMosaic(selection)
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
      @sprites["boxparty"].y = 128
    end
  end

  def pbShowPartyTab
    @sprites["arrow"].visible = false
    if !@screen.pbHeldPokemon
      pbUpdateOverlay(-1)
      pbSetMosaic(-1)
    end
    pbSEPlay("GUI storage show party panel")
    start_y = 480
    timer_start = System.uptime
    loop do
      @sprites["boxparty"].y = lerp(start_y, 128, 0.4, timer_start, System.uptime)
      self.update
      Graphics.update
      break if @sprites["boxparty"].y == 128
    end
    Input.update
    @sprites["arrow"].visible = true
  end

  def pbHidePartyTab
    @sprites["arrow"].visible = false
    if !@screen.pbHeldPokemon
      pbUpdateOverlay(-1)
      pbSetMosaic(-1)
    end
    pbSEPlay("GUI storage hide party panel")
    start_y = 128
    timer_start = System.uptime
    loop do
      @sprites["boxparty"].y = lerp(start_y, 480, 0.4, timer_start, System.uptime)
      self.update
      Graphics.update
      break if @sprites["boxparty"].y == 480
    end
    Input.update
    @sprites["arrow"].visible = true
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
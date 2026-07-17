# ==============================================================================
# FIX RESOLUCIÓN 640x480 PARA PC - CAJA 436x470 (5x5 PERFECTO + ANIMACIONES)
# ==============================================================================

# 1. Ajuste de datos a 5x5
class PokemonBox
  remove_const(:BOX_WIDTH) if defined?(BOX_WIDTH)
  BOX_WIDTH = 5
  remove_const(:BOX_SIZE) if defined?(BOX_SIZE)
  BOX_SIZE = BOX_WIDTH * BOX_HEIGHT
end

# 2. Dibujo manual de la Caja y los Iconos (Con deslizamiento animado)
class PokemonBoxSprite < Sprite
  BOX_X = 194  
  BOX_Y = 5   
  BOX_WIDTH = 436
  BOX_HEIGHT = 470

  alias _res_fix_refresh refresh
  def refresh
    _res_fix_refresh
    
    # Al usar self.x y self.y, recuperamos la animación de deslizamiento natural
    x_start = self.x + 46 
    y_start = self.y + 86 
    
    x_spacing = 74 
    y_spacing = 72 
    
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
    
    # Animación fluida atada a self.y
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

# 4. Cursores y Textos del Panel Izquierdo
class PokemonStorageScene
  # --- Ajuste Perfecto del Panel Izquierdo (Basado en la Imagen 2) ---
  POKEMON_SPRITE_X = 96
  POKEMON_SPRITE_Y = 136
  MSG_WINDOW_X = 190
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

  # Desterramos los textos viejos fuera de la pantalla para que no se superpongan
  TEAM_TEXT_X = -1000
  TEAM_TEXT_Y = -1000
  EXIT_TEXT_X = -1000
  EXIT_TEXT_Y = -1000
  
  # Nuevas Coordenadas para los textos en el panel izquierdo
  NEW_TEAM_TEXT_X = 96
  NEW_TEAM_TEXT_Y = 422
  NEW_EXIT_TEXT_X = 96
  NEW_EXIT_TEXT_Y = 456

  # --- Textos Inferiores ---
  alias _res_fix_pbUpdateOverlay pbUpdateOverlay
  def pbUpdateOverlay(selection, party = nil)
    _res_fix_pbUpdateOverlay(selection, party)
    overlay = @sprites["overlay"].bitmap
    buttonbase = Color.new(248, 248, 248)
    buttonshadow = Color.new(80, 80, 80)
    
    # Dibujamos nuestros textos personalizados limpios en el panel izquierdo
    pbDrawTextPositions(
      overlay,
      [[_INTL("[↓] Equipo: {1}", (@storage.party.length rescue 0)), NEW_TEAM_TEXT_X, NEW_TEAM_TEXT_Y, :center, buttonbase, buttonshadow, :outline],
       [_INTL("[X] Salir"), NEW_EXIT_TEXT_X, NEW_EXIT_TEXT_Y, :center, buttonbase, buttonshadow, :outline]]
    )
  end

  # --- Coordendas Exactas del Cursor ---
  def pbSetArrow(arrow, selection)
    case selection
    when -1, -4, -5  # Nombre de la Caja
      arrow.x = 194 + 218 - 24
      arrow.y = 5 + 22
    when -2          # Botón Equipo (Panel Izquierdo)
      arrow.x = NEW_TEAM_TEXT_X - 60
      arrow.y = NEW_TEAM_TEXT_Y - 16
    when -3          # Botón Salir (Panel Izquierdo)
      arrow.x = NEW_EXIT_TEXT_X - 60
      arrow.y = NEW_EXIT_TEXT_Y - 16
    else
      if selection >= 0
        col = selection % 5
        row = selection / 5
        arrow.x = (194 + 46) + (col * 74)
        arrow.y = (5 + 86) + (row * 72)
      end
    end
  end

  def pbPartySetArrow(arrow, selection)
    return if selection < 0
    if selection == Settings::MAX_PARTY_SIZE
      arrow.x = NEW_EXIT_TEXT_X - 60
      arrow.y = NEW_EXIT_TEXT_Y - 16
    else
      col = selection % 2
      row = selection / 2
      # Coordenadas exactas para cuando la PartyBox sube a Y=128
      arrow.x = 194 + 80 + (col * 160)
      arrow.y = 128 + 50 + (row * 84) + (col * 24)
    end
  end

  # --- Arreglo de Animaciones y Ventanas Inferiores ---
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

  def pbDisplay(message)
    msgwindow = Window_UnformattedTextPokemon.newWithSize("", 190, 48, 450, 32)
    msgwindow.viewport       = @viewport
    msgwindow.visible        = true
    msgwindow.letterbyletter = false
    msgwindow.resizeHeightToFit(message, 450)
    msgwindow.text = message
    msgwindow.x = 190
    msgwindow.y = 480 - msgwindow.height
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
    msgwindow = Window_UnformattedTextPokemon.newWithSize("", 190, 48, 450, 32)
    msgwindow.viewport       = @viewport
    msgwindow.visible        = true
    msgwindow.letterbyletter = false
    msgwindow.text           = message
    msgwindow.resizeHeightToFit(message, 450)
    msgwindow.x = 190
    msgwindow.y = 480 - msgwindow.height
    
    cmdwindow = Window_CommandPokemon.new(commands)
    cmdwindow.viewport = @viewport
    cmdwindow.visible  = true
    cmdwindow.resizeToFit(cmdwindow.commands)
    cmdwindow.height = Graphics.height - msgwindow.height if cmdwindow.height > Graphics.height - msgwindow.height
    cmdwindow.x = 640 - cmdwindow.width
    cmdwindow.y = 480 - msgwindow.height - cmdwindow.height
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
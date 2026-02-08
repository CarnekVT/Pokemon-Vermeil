#===============================================================================
# Better Move Relearner
# Clase que maneja el cursor visual del selector de movimientos
#===============================================================================
class UI::MoveReminderCursor < IconSprite
  # Índice del primer movimiento visible en la lista
  attr_accessor :top_index

  # Dimensiones y propiedades visuales del cursor
  CURSOR_WIDTH     = 258  # Ancho del cursor en píxeles
  CURSOR_HEIGHT    = 72   # Altura del cursor en píxeles
  CURSOR_THICKNESS = 6    # Grosor del borde del cursor

  # Inicializa el cursor visual
  def initialize(viewport = nil)
    super(0, 0, viewport)
    # Carga la imagen del cursor
    setBitmap("Graphics/UI/Move Reminder/cursor")
    self.src_rect = Rect.new(0, 0, CURSOR_WIDTH, CURSOR_HEIGHT)
    self.z = 1600
    # Crea un sprite de fondo para el cursor (parte inferior de la imagen)
    @bg_sprite = IconSprite.new(x, y, viewport)
    @bg_sprite.setBitmap("Graphics/UI/Move Reminder/cursor")
    @bg_sprite.src_rect = Rect.new(0, CURSOR_HEIGHT, CURSOR_WIDTH, CURSOR_HEIGHT)
    @top_index = 0
    self.index = 0
  end

  # Libera los recursos del cursor y su fondo
  def dispose
    @bg_sprite.dispose
    @bg_sprite = nil
    super
  end

  # Establece el índice del movimiento seleccionado y actualiza su posición
  def index=(value)
    @index = value
    refresh_position
  end

  # Establece la visibilidad del cursor y su fondo
  def visible=(value)
    super
    @bg_sprite.visible = value
  end

  # Recalcula la posición Y del cursor basándose en el índice y el índice superior
  def refresh_position
    return if @index < 0
    # Posición X basada en la constante de la clase visual
    self.x = UI::MoveReminderVisuals::MOVE_LIST_X
    # Posición Y base menos el grosor
    self.y = UI::MoveReminderVisuals::MOVE_LIST_Y - CURSOR_THICKNESS
    # Ajusta la posición Y según el desplazamiento desde el índice superior
    self.y += (@index - @top_index) * UI::MoveReminderVisuals::MOVE_LIST_SPACING
    # Actualiza la posición del fondo
    @bg_sprite.x = self.x
    @bg_sprite.y = self.y
  end
end

#===============================================================================
# Clase visual del Move Reminder - Maneja toda la presentación gráfica
#===============================================================================
class UI::MoveReminderVisuals < UI::BaseVisuals
  # Índice actualmente seleccionado
  attr_reader :index

  # Carpeta donde se encuentran los gráficos
  GRAPHICS_FOLDER   = "Move Reminder/"   # Subcarpeta en Graphics/UI
  
  # Temas de color para diferentes elementos de texto
  TEXT_COLOR_THEMES = {   # Estos temas de color se agregan al overlay
    :default => [Color.new(248, 248, 248), Color.new(0, 0, 0)],   # Color base y sombra
    :white   => [Color.new(248, 248, 248), Color.new(0, 0, 0)],
    :black   => [Color.new(64, 64, 64), Color.new(176, 176, 176)],
    :header  => [Color.new(88, 88, 80), Color.new(168, 184, 184)]
  }
  
  # POSICIONES Y DIMENSIONES DE ELEMENTOS VISUALES
  MOVE_LIST_X        = 0        # Posición X de la lista de movimientos
  MOVE_LIST_Y        = 84       # Posición Y de la lista de movimientos
  MOVE_LIST_SPACING  = 64       # Distancia Y entre dos áreas de movimiento adyacentes
  VISIBLE_MOVES      = 4        # Número de movimientos visibles en la pantalla
  TYPE_ICONS_X       = 396      # Posición X de los íconos de tipo
  TYPE_ICONS_Y       = 70       # Posición Y de los íconos de tipo
  TYPE_ICONS_SPACING = 6        # Espaciado entre íconos de tipo
  POKEMON_ICON_X     = 314      # Posición X del ícono del Pokémon
  POKEMON_ICON_Y     = 84       # Posición Y del ícono del Pokémon
  HEADER_X           = 16       # Posición X del encabezado
  HEADER_Y           = 14       # Posición Y del encabezado
  BUTTON_DOWN_WIDTH  = 76       # Ancho del botón "Abajo"
  BUTTON_DOWN_HEIGHT = 32       # Alto del botón "Abajo"
  BUTTON_DOWN_X      = 47       # Posición X del botón "Abajo"
  BUTTON_DOWN_Y      = 350      # Posición Y del botón "Abajo"
  BUTTON_UP_WIDTH    = 76       # Ancho del botón "Arriba"
  BUTTON_UP_HEIGHT   = 32       # Alto del botón "Arriba"
  BUTTON_UP_X        = 135      # Posición X del botón "Arriba"
  BUTTON_UP_Y        = 350      # Posición Y del botón "Arriba"
  MOVE_NAME_X_OFFSET = 76       # Desplazamiento X del nombre del movimiento
  MOVE_NAME_Y_OFFSET = 6        # Desplazamiento Y del nombre del movimiento
  LEVEL_OR_TM_X_OFFSET = 12     # Desplazamiento X del nivel o TM/HM
  LEVEL_OR_TM_Y_OFFSET = 36     # Desplazamiento Y del nivel o TM/HM
  PP_LABEL_X_OFFSET   = 150     # Desplazamiento X de la etiqueta PP
  PP_LABEL_Y_OFFSET   = 38      # Desplazamiento Y de la etiqueta PP
  PP_VALUE_X_OFFSET   = 240     # Desplazamiento X del valor PP
  PP_VALUE_Y_OFFSET   = 38      # Desplazamiento Y del valor PP
  POWER_LABEL_X       = 278     # Posición X de la etiqueta de Poder
  POWER_LABEL_Y       = 120     # Posición Y de la etiqueta de Poder
  POWER_VALUE_X       = 480     # Posición X del valor de Poder
  POWER_VALUE_Y       = 120     # Posición Y del valor de Poder
  ACCURACY_LABEL_X    = 278     # Posición X de la etiqueta de Precisión
  ACCURACY_LABEL_Y    = 152     # Posición Y de la etiqueta de Precisión
  ACCURACY_VALUE_X    = 480     # Posición X del valor de Precisión
  ACCURACY_VALUE_Y    = 152     # Posición Y del valor de Precisión
  CATEGORY_LABEL_X    = 278     # Posición X de la etiqueta de Categoría
  CATEGORY_LABEL_Y    = 184     # Posición Y de la etiqueta de Categoría
  CATEGORY_ICON_X     = 436     # Posición X del ícono de Categoría
  CATEGORY_ICON_Y     = 178     # Posición Y del ícono de Categoría
  DESCRIPTION_X       = 275     # Posición X de la descripción
  DESCRIPTION_Y       = 215     # Posición Y de la descripción
  DESCRIPTION_WIDTH   = 235     # Ancho de la descripción
  DESCRIPTION_LINES   = 5       # Número máximo de líneas de descripción
  TYPE_ICON_X_OFFSET  = 8       # Desplazamiento X del ícono de tipo en la lista
  TYPE_ICON_Y_OFFSET  = 1       # Desplazamiento Y del ícono de tipo en la lista
  MOVE_NAME_WIDTH     = 230     # Ancho máximo del nombre del movimiento

  # Inicializa la clase con el Pokémon y lista de movimientos
  def initialize(pokemon, moves)
    @pokemon   = pokemon   # Pokémon a quien enseñar movimientos
    @moves     = moves     # Lista de movimientos disponibles
    @top_index = 0         # Índice del primer movimiento visible
    @index     = 0         # Índice del movimiento actualmente seleccionado
    super()
    refresh_cursor
  end

  # Inicializa los bitmaps necesarios (tipos e imágenes de botones)
  def initialize_bitmaps
    @bitmaps[:types]   = AnimatedBitmap.new(UI_FOLDER + _INTL("types"))
    @bitmaps[:buttons] = AnimatedBitmap.new(graphics_folder + "buttons")
  end

  # Inicializa los sprites (ícono del Pokémon y cursor)
  def initialize_sprites
    # Sprite del ícono del Pokémon
    @sprites[:pokemon_icon] = PokemonIconSprite.new(@pokemon, @viewport)
    @sprites[:pokemon_icon].setOffset(PictureOrigin::CENTER)
    @sprites[:pokemon_icon].x = POKEMON_ICON_X
    @sprites[:pokemon_icon].y = POKEMON_ICON_Y
    @sprites[:pokemon_icon].z = 200
    # Sprite del cursor
    @sprites[:cursor] = UI::MoveReminderCursor.new(@viewport)
  end

  #-----------------------------------------------------------------------------
  # Establecedor de la lista de movimientos
  #-----------------------------------------------------------------------------

  # Establece una nueva lista de movimientos y actualiza la interfaz
  def moves=(move_list)
    @moves = move_list
    # Si el índice actual está fuera de rango, ajustarlo al último movimiento
    @index = @moves.length - 1 if @index >= @moves.length
    refresh_on_index_changed(@index)
    # Ocultar cursor si no hay movimientos
    @cursor.visible = false if @moves.empty?
    refresh
  end

  #-----------------------------------------------------------------------------
  # Métodos de renderizado del overlay
  #-----------------------------------------------------------------------------

  # Redibuja todo el contenido del overlay
  def refresh_overlay
    super
    draw_header              # Dibuja el encabezado "Teach move?"
    draw_pokemon_type_icons(TYPE_ICONS_X, TYPE_ICONS_Y, TYPE_ICONS_SPACING)  # Dibuja tipos del Pokémon
    draw_moves_list          # Dibuja la lista de movimientos
    draw_move_properties     # Dibuja las propiedades del movimiento seleccionado
    draw_buttons             # Dibuja los botones de navegación
  end

  # Dibuja el encabezado "Teach which move?"
  def draw_header
    draw_text(_INTL("Teach move?"), HEADER_X, HEADER_Y, theme: :header)
  end

  # Dibuja los íconos de tipo del Pokémon
  # x y y son la esquina superior izquierda del ícono de tipo si hay solo uno.
  def draw_pokemon_type_icons(x, y, spacing)
    @pokemon.types.each_with_index do |type, i|
      # Obtiene el número de posición del ícono de tipo
      type_number = GameData::Type.get(type).icon_position
      # Calcula el desplazamiento para centrar los íconos
      offset = ((@pokemon.types.length - 1) * (64 + spacing) / 2)
      offset = (offset / 2) * 2
      # Calcula la posición X del ícono
      type_x = x - offset + ((64 + spacing) * i)
      # Dibuja el ícono de tipo
      draw_image(@bitmaps[:types], type_x, y,
                 0, type_number * 28, 64, 28)
    end
  end

  # Dibuja la lista de movimientos visibles (hasta VISIBLE_MOVES)
  def draw_moves_list
    VISIBLE_MOVES.times do |i|
      # Obtiene el movimiento en la posición i + top_index
      move = @moves[@top_index + i]
      next if move.nil?
      # Dibuja el movimiento en su posición
      draw_move_in_list(move, MOVE_LIST_X, MOVE_LIST_Y + (i * MOVE_LIST_SPACING))
    end
  end

  # Dibuja un movimiento individual en la lista
  def draw_move_in_list(move, x, y)
    # Obtiene los datos del movimiento
    move_data = GameData::Move.get(move[0])

    # Dibuja el ícono de tipo del movimiento
    type_number = GameData::Type.get(move_data.display_type(@pokemon)).icon_position
    draw_image(@bitmaps[:types], x + TYPE_ICON_X_OFFSET, y + TYPE_ICON_Y_OFFSET,
                0, type_number * 28, 64, 28)

    # Dibuja el nombre del movimiento
    move_name = move_data.name
    move_name = crop_text(move_name, MOVE_NAME_WIDTH)
    draw_text(move_name, x + MOVE_NAME_X_OFFSET, y + MOVE_NAME_Y_OFFSET, theme: :black)

    # Dibuja el nivel de aprendizaje o TM/HM
    if move[1]
      tm_hm = move[1] == :TM ? _INTL("TM") : move[1] == :HM ? _INTL("HM") : move[1]
      draw_text(tm_hm, x + LEVEL_OR_TM_X_OFFSET, y + LEVEL_OR_TM_Y_OFFSET, theme: :black)
    end

    # Dibuja el texto PP (Poder de Ponzoña)
    if move_data.total_pp > 0
      draw_text(_INTL("PP"), x + PP_LABEL_X_OFFSET, y + PP_LABEL_Y_OFFSET, theme: :black)
      draw_text(sprintf("%d/%d", move_data.total_pp, move_data.total_pp), x + PP_VALUE_X_OFFSET, y + PP_VALUE_Y_OFFSET, align: :right, theme: :black)
    end
  end

  # Dibuja las propiedades (Poder, Precisión, Categoría, Descripción) del movimiento seleccionado
  def draw_move_properties
    # Obtiene el movimiento seleccionado
    move = @moves[@index]
    move_data = GameData::Move.get(move[0])
    
    # Dibuja Poder
    draw_text(_INTL("POWER"), POWER_LABEL_X, POWER_LABEL_Y)
    power_text = move_data.display_damage(@pokemon)
    power_text = "---" if power_text == 0   # Movimiento de estado
    power_text = "???" if power_text == 1   # Movimiento de poder variable
    draw_text(power_text, POWER_VALUE_X, POWER_VALUE_Y, align: :right, theme: :black)
    
    # Dibuja Precisión
    draw_text(_INTL("ACCURACY"), ACCURACY_LABEL_X, ACCURACY_LABEL_Y)
    accuracy = move_data.display_accuracy(@pokemon)
    if accuracy == 0
      draw_text("---", ACCURACY_VALUE_X, ACCURACY_VALUE_Y, align: :right, theme: :black)
    else
      draw_text(accuracy, ACCURACY_VALUE_X, ACCURACY_VALUE_Y, align: :right, theme: :black)
      draw_text("%", ACCURACY_VALUE_X, ACCURACY_VALUE_Y, theme: :black)
    end

    # Dibuja la categoría del movimiento
    draw_text(_INTL("CATEGORY"), CATEGORY_LABEL_X, CATEGORY_LABEL_Y)
    draw_image(UI_FOLDER + "category", CATEGORY_ICON_X, CATEGORY_ICON_Y,
               0, move_data.display_category(@pokemon) * 28, 64, 28)

    # Dibuja la descripción del movimiento
    draw_paragraph_text(move_data.description, DESCRIPTION_X, DESCRIPTION_Y, DESCRIPTION_WIDTH, DESCRIPTION_LINES, theme: :black)
  end

  # Dibuja los botones de navegación (Arriba/Abajo)
  def draw_buttons
    # Dibuja botón para bajar si no estamos en el último movimiento
    draw_image(@bitmaps[:buttons], BUTTON_DOWN_X, BUTTON_DOWN_Y, 0, 0, BUTTON_DOWN_WIDTH, BUTTON_DOWN_HEIGHT) if @index < @moves.length - 1 
    # Dibuja botón para subir si no estamos en el primer movimiento
    draw_image(@bitmaps[:buttons], BUTTON_UP_X, BUTTON_UP_Y, BUTTON_DOWN_WIDTH, 0, BUTTON_UP_WIDTH, BUTTON_UP_HEIGHT) if @top_index > 0
  end

  #-----------------------------------------------------------------------------
  # Métodos de actualización del cursor y manejo de índice
  #-----------------------------------------------------------------------------

  # Actualiza la posición visual del cursor
  def refresh_cursor
    @sprites[:cursor].top_index = @top_index
    @sprites[:cursor].index = @index
  end

  # Se ejecuta cuando el índice seleccionado cambia
  def refresh_on_index_changed(old_index)
    # Reproduce efecto de sonido si el índice cambió
    pbPlayCursorSE if old_index != @index && defined?(old_index)
    # Cambia @top_index para mantener @index en el medio de la lista visible
    # (o lo más cercano posible)
    middle_range_top = (VISIBLE_MOVES / 2) - ((VISIBLE_MOVES + 1) % 2)
    middle_range_bottom = VISIBLE_MOVES / 2
    if @index < @top_index + middle_range_top
      @top_index = @index - middle_range_top
    elsif @index > @top_index + middle_range_bottom
      @top_index = @index - middle_range_bottom
    end
    # Asegura que top_index esté dentro del rango válido
    @top_index = @top_index.clamp(0, [@moves.length - VISIBLE_MOVES, 0].max)
    refresh_cursor
    refresh
  end

  #-----------------------------------------------------------------------------
  # Métodos de entrada de usuario
  #-----------------------------------------------------------------------------

  # Procesa la entrada del usuario (navegación e interacción)
  def update_input
    # Comprueba el movimiento del cursor
    update_cursor_movement
    # Comprueba la interacción (confirmación, cancelación, etc.)
    if Input.trigger?(Input::USE)
      return update_interaction(Input::USE)
    elsif Input.trigger?(Input::BACK)
      return update_interaction(Input::BACK)
    elsif Input.trigger?(Input::ACTION)
      return update_interaction(Input::ACTION)
    end
    return nil
  end

  # Actualiza el índice basándose en la entrada del usuario (arriba/abajo/salto)
  def update_cursor_movement
    old_index = @index
    # Comprueba el movimiento hacia arriba
    if Input.repeat?(Input::UP)
      @index -= 1
      if Input.trigger?(Input::UP)
        @index = @moves.length - 1 if @index < 0   # Envuelve al final
      else
        @index = 0 if @index < 0
      end
    # Comprueba el movimiento hacia abajo
    elsif Input.repeat?(Input::DOWN)
      @index += 1
      if Input.trigger?(Input::DOWN)
        @index = 0 if @index >= @moves.length   # Envuelve al inicio
      else
        @index = @moves.length - 1 if @index >= @moves.length
      end
    # Comprueba salto hacia arriba (Page Up)
    elsif Input.repeat?(Input::JUMPUP)
      @index -= VISIBLE_MOVES
      @index = 0 if @index < 0
    # Comprueba salto hacia abajo (Page Down)
    elsif Input.repeat?(Input::JUMPDOWN)
      @index += VISIBLE_MOVES
      @index = @moves.length - 1 if @index >= @moves.length
    end
    # Si el índice cambió, actualiza la pantalla
    if old_index != @index
      refresh_on_index_changed(old_index)
    end
    
    return old_index != @index
  end

  # Procesa la interacción del usuario (qué hacer cuando presiona botones)
  def update_interaction(input)
    case input
    when Input::USE
      pbPlayDecisionSE
      return :learn    # Retorna :learn para enseñar el movimiento seleccionado
    when Input::BACK
      pbPlayCloseMenuSE
      return :quit     # Retorna :quit para salir de la pantalla
    end
    return nil
  end
end

#===============================================================================
# Clase de pantalla para el Move Reminder - Maneja la lógica del juego
#===============================================================================
class UI::MoveReminder < UI::BaseScreen
  # Referencia al Pokémon a quien se enseñan movimientos
  attr_reader :pokemon
  
  # Hash de acciones que pueden ser disparadas en la pantalla
  ACTIONS = HandlerHash.new

  # ID único de la pantalla
  SCREEN_ID = :move_reminder_screen

  # mode es :normal (continuar después de enseñar) o :single (cerrar después de enseñar)
  def initialize(pokemon, mode: :normal, required_item: nil)
    @pokemon = pokemon              # Pokémon al que enseñar movimientos
    @mode = mode                    # Modo de operación (:normal o :single)
    @required_item = required_item  # Artículo requerido para enseñar (si aplica)
    @moves = []                     # Lista de movimientos disponibles
    @result = nil                   # Resultado de la operación
    @consumed_items = 0             # Contador de artículos consumidos
    generate_move_list              # Genera la lista inicial de movimientos
    super()
  end

  # Inicializa los elementos visuales
  def initialize_visuals
    @visuals = UI::MoveReminderVisuals.new(@pokemon, @moves)
  end

  # Obtiene el artículo requerido
  def required_item
    return @required_item
  end

  # Obtiene el número de artículos consumidos
  def consumed_items
    return @consumed_items
  end

  # Establece el número de artículos consumidos
  def consumed_items=(value)
    @consumed_items = value
  end

  # Muestra un mensaje sobre los artículos consumidos
  def show_consumed_items_message
    return if @required_item.nil? || @consumed_items <= 0
    item_name = GameData::Item.get(@required_item).name_plural
    pbMessage(_INTL("\\PN delivered {1} {2} in exchange.", @consumed_items, item_name))
  end

  #-----------------------------------------------------------------------------
  # Generación de la lista de movimientos disponibles
  #-----------------------------------------------------------------------------

  # Genera la lista de movimientos que el Pokémon puede aprender
  def generate_move_list
    @moves = []
    # No puede aprender si es un huevo o un Pokémon sombra
    return if !@pokemon || @pokemon.egg? || @pokemon.shadowPokemon?
    
    # Obtiene los movimientos de la lista de aprendizaje del Pokémon
    @pokemon.getMoveList.each do |move|
      next if move[0] > @pokemon.level || @pokemon.hasMove?(move[1])
      # Convierte el movimiento a ID si es necesario
      move_to_add = move.is_a?(GameData::Move) ? move.id : move[1]
      # Añade el movimiento con su nivel (Lv. X)
      @moves << [move_to_add, _INTL("Lv. #{move[0].to_i.abs}")] if !@moves.include?(move_to_add)
    end
    
    # Añade movimientos iniciales si la configuración lo permite
    if Settings::MOVE_RELEARNER_CAN_TEACH_MORE_MOVES && @pokemon.first_moves
      first_moves = []
      @pokemon.first_moves.each do |move|
        # Añade movimientos iniciales que aún no conoce
        first_moves.push([move, _INTL("Lv. 1")]) if !@moves.any? { |m| m[0] == move } && !@pokemon.hasMove?(move)
      end
      @moves = first_moves + @moves   # Los movimientos iniciales van primero
    end
    
    # Elimina duplicados basándose en el ID del movimiento
    @moves = @moves.uniq { |move| move[0] }

    # Añade movimientos de TM/HM si la configuración lo permite
    if Settings::SHOW_MTS_MOS_IN_MOVE_RELEARNER
      tms = pbGetTMMoves(@pokemon)
      for tm in tms
        # Añade TM si no existe ya en la lista
        if !@moves.any? { |m| m[0] == tm[0] }
            @moves.push([tm[0], tm[1]])
        end
      end
    end
  end

  # Actualiza la lista de movimientos generando una nueva
  def refresh_move_list
    generate_move_list
    @visuals.moves = @moves
  end

  #-----------------------------------------------------------------------------
  # Accesores y consultores
  #-----------------------------------------------------------------------------

  # Obtiene el movimiento actualmente seleccionado
  def move
    return @moves[self.index]
  end

  #-----------------------------------------------------------------------------
  # ACCIONES que pueden ser disparadas en la pantalla del Move Reminder
  #===============================================================================
  
  # Acción :learn - Enseña el movimiento seleccionado
  ACTIONS.add(:learn, {
    :effect => proc { |screen|
      # El movimiento es un array de 2 elementos:
      # Posibles valores:
      # [:MOVE_ID, "Lv X."]   - Movimiento aprendible por nivel
      # [:MOVE_ID, "TM"]       - Movimiento de TM
      # [:MOVE_ID, "HM"]       - Movimiento de HM
      move = screen.move
      next if !screen.show_confirm_message(_INTL("Teach {1}?", GameData::Move.get(move[0]).name))

      # Determina si es un movimiento de máquina (TM/HM)
      is_machine = [:TM, :HM].include?(move[1]) ? true : false
      
      # Comprueba si el jugador tiene el artículo requerido (solo para movimientos que no son de máquina)
      if !is_machine && screen.required_item && !$bag.has?(screen.required_item)
        screen.show_message(_INTL("You don't have any more {1}.", GameData::Item.get(screen.required_item).name_plural))
        screen.end_screen
        next
      end
      
      # Flag para indicar que es un reaprendizaje
      relearn = is_machine ? false : true
      # Intenta enseñar el movimiento
      next if !pbLearnMove(screen.pokemon, move[0], false, is_machine)
      
      # Elimina el artículo requerido si se especificó (solo para movimientos que no son de máquina)
      if !is_machine && screen.required_item
        $bag.remove(screen.required_item)
        screen.consumed_items = screen.consumed_items + 1
      end
      
      # Actualiza las estadísticas
      $stats.moves_taught_by_reminder += 1 if !is_machine
      $stats.moves_taught_by_item     += 1 if is_machine
      
      # Comportamiento basado en el modo
      if screen.mode == :normal
        # En modo normal, permite enseñar más movimientos
        screen.refresh_move_list
        # Comprueba si el jugador aún tiene artículos (solo para movimientos que no son de máquina)
        if !is_machine && screen.required_item && !$bag.has?(screen.required_item)
          screen.show_message(_INTL("You don't have any more {1}.", GameData::Item.get(screen.required_item).name_plural))
          screen.end_screen
        end
      else
        # En modo single, cierra la pantalla después de enseñar
        screen.end_screen
      end
    }
  })

  #-----------------------------------------------------------------------------
  # Bucle principal de la pantalla
  #-----------------------------------------------------------------------------

  # Ejecuta el bucle principal de la pantalla
  def main
    return if @disposed
    start_screen
    @visuals.refresh if @visuals
    Graphics.update
    loop do
      on_start_main_loop
      # Navega por los movimientos y obtiene el comando
      command = @visuals.navigate
      # Comprueba si debe salir de la pantalla
      break if command == :quit && (@mode == :normal ||
               show_confirm_message(_INTL("Do you prefer {1} not to learn a new move?", @pokemon.name)))
      # Ejecuta la acción correspondiente al comando
      perform_action(command)
      # Comprueba si no hay más movimientos disponibles
      if @moves.empty?
        show_message(_INTL("There are no more moves for {1} to learn.", @pokemon.name))
        break
      end
      # Comprueba si la pantalla fue cerrada
      if @disposed
        @result = true
        break
      end
    end
    end_screen
    return @result
  end
end

#===============================================================================
# Función global para acceder a la pantalla del Move Reminder
#===============================================================================

# Abre la pantalla del Move Reminder y permite al Pokémon aprender movimientos
# pkmn: El Pokémon que aprenderá movimientos
# required_item: Artículo requerido (opcional) para enseñar movimientos
def pbRelearnMoveScreen(pkmn, required_item = nil)
  ret = true
  pbFadeOutIn do
    # Determina el modo basándose en la configuración
    mode = Settings::CLOSE_MOVE_RELEARNER_AFTER_TEACHING_MOVE ? :single : :normal
    # Crea la pantalla del Move Reminder
    move_reminder = UI::MoveReminder.new(pkmn, mode: mode, required_item: required_item)
    # Ejecuta la pantalla principal
    ret = move_reminder.main
    # Muestra un mensaje sobre los artículos consumidos (si aplica)
    move_reminder.show_consumed_items_message
  end
  return ret
end

# Obtiene la lista de movimientos de TM/HM que el Pokémon puede aprender
# pokemon: El Pokémon del que se obtendrán los movimientos compatibles
def pbGetTMMoves(pokemon)
  tmmoves = []
  # Itera sobre los artículos en la bolsa (bolsillo de TM/HM)
  for item_aux in $bag.pockets[4]
    item = GameData::Item.get(item_aux[0])
    # Comprueba si el artículo es una máquina (TM/HM)
    if item.is_machine?
      machine = item.move
      # Determina si es TM o HM
      tmorhm = item.is_HM? ? :HM : :TM
      # Comprueba si el Pokémon puede aprender este movimiento y no lo conoce ya
      if pokemon.compatible_with_move?(machine) && !pokemon.hasMove?(machine)
        tmmoves.push([machine, tmorhm])
      end
    end
  end
  return tmmoves
end

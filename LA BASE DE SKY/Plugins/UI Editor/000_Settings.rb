
class Settings_UI_Editor
  
  #--- UI EDITABLE --- 
  # Clases de las UI Editables. Por defecto vienen las de la base. Si quieres Añadir una nueva UI
  # hazlo aquí.
  UI_EDITABLE_CLASS = [
  "UI::MoveReminderVisuals","UI::BaseVisuals",
  "PokemonParty_Scene", "PokemonPokedex_Scene", "PokemonBag_Scene",
  "PokemonSummary_Scene", "PokemonLoad_Scene", "PokemonPokedexMenu_Scene",
  "PokemonPokedexInfo_Scene", "PokemonTrainerCard_Scene", "PokemonRegionMap_Scene",
  "Battle::Scene::MenuBase", "ItemStorage_Scene", "PokemonStorageScene", "PurifyChamberScene",
  "PokemonReadyMenu_Scene", "MoveRelearner_Scene"
]




  KEYS = {
    :NEXT_OBJ    => :Q, # AvPág (salto 5)
    :PREV_OBJ    => :E,  #RePág (salto 5):R, #R
    :EXIT        => Input::BACK, 
    :TOGGLE_SUB  => :F, # F
    :ACTION_MENU => :K,
    :FAST_STEP   => Input::CTRL,
    :RESET       => :BACKSPACE, #Backspace
    :ZOOM_UP     => :W, #W  
    :ZOOM_DOWN   => :S, #S
    :Z_LAYER_TAB => :TAB, #TAB
    :OPACITY_UP  => :D, #D
    :OPACITY_DOWN=> :A, #A
    :PLUS_Z      => :EQUALS , # +/= (La tecla al lado de backspace)
    :MIN_Z       => :MINUS,  # - (La tecla al lado del 0)
    :ROTATE_L    => :R, #
    :ROTATE_R    => :T, #Q
    :MIRROR      => :M, #M
    :HIDE_TOGGLE => :H, # Tecla H
    :TOGGLE_HELP => :F5, #F5
    :TOGGLE_HUD  => :F4,
    :ADJUST_HUD  => :F7, 
    :LIST_HUD    => :L,
    :SNAP_EDGE    => :I, # G
    :TOGGLE_GUIDES => :G,
    :AV_PAG       => :PAGEUP, # Pasar a la siguiente pagina
    :REV_PAG      => :PAGEDOWN
  }
  
=begin
    Estas son Todas las KEYS Disponibles:
    
      Letras:

      :A :B :C :D :E :F :G :H :I :J :K :L :M
      :N :O :P :Q :R :S :T :U :V :W :X :Y :Z


      Números fila (superior):

      :N0 :N1 :N2 :N3 :N4 :N5 :N6 :N7 :N8 :N9

      Numpad:

      :KP0 :KP1 :KP2 :KP3 :KP4 :KP5 :KP6 :KP7 :KP8 :KP9
      :KP_DIVIDE :KP_MULTIPLY :KP_SUBTRACT :KP_ADD :KP_ENTER :KP_PERIOD


      Función

      :F1 :F2 :F3 :F4 :F5 :F6 :F7 :F8 :F9 :F10 :F11 :F12

      Modificadores:

      :SHIFT :LSHIFT :RSHIFT
      :CTRL  :LCTRL  :RCTRL
      :ALT   :LALT   :RALT


      Especiales:

      :RETURN :ESCAPE :BACKSPACE :TAB :SPACE :CAPS
      :INSERT :DELETE :HOME :END :PAGEUP :PAGEDOWN
      :LEFT :RIGHT :UP :DOWN

      Puntuación (teclado normal):

      :MINUS      # -
      :EQUALS     # = / +
      :LBRACKET   # [
      :RBRACKET   # ]
      :SEMICOLON  # ;
      :APOSTROPHE # '
      :COMMA      # ,
      :PERIOD     # .
      :SLASH      # /
      :BACKSLASH  # \
      :GRAVE      # ` / ~


        

=end

  #--- VALID CLASSES ---
  # Estas son las clases que el editor sabe que son 100% bienvenidas a pasar y ser editable.

  VALID_CLASSES = [Sprite, BitmapSprite, IconSprite, Window, SpriteWindow, 
  PokemonIconSprite, ChangelingSprite, IconWindow, HeldItemIconSprite, Window_AdvancedTextPokemon,
    Window_UnformattedTextPokemon, Plane, Window_CommandPokemon]


  #---BLACK LIST ---
  #aquí puedes poner aquellos objetos que no quieres que aparezcan en el editor.
  # tales como complementos de otros etc.
  
  BLACK_LIST = [:@viewport, :@viewport2, :@viewport3, :@msgwindow, :@unused_sprites, :@disposed,
                        :@event_handlers, :@disposed_at_start, :@hover_image, :@scroll_bar, :@corner]

  # --- PREFERENCIAS VISUALES ---

  ACTIVE_SELECTION_THEME = :RADIACTIVE 



  VISUAL_SETTINGS = {
    :active_theme => :RADIACTIVE,
    :bg_dim_opacity => 130,
    # El tono personalizado: [R, G, B, Gris]
    :custom_tone => [100, 100, 100, 0] 
  }



  SELECTION_THEMES_UI = {
    # Efecto "Radiactivo" un verde que resalta (Ideal para UIs oscuras)
    :RADIACTIVE => [50, 180, 50, 0], 
    # Efecto de iluminación estándar
    :NORMAL     => [100, 100, 100, 0],    
    # Tu configuración personalizada
    :CUSTOM     => [100, 100, 100, 0],     
  }
  

  # Cuánto se oscurece el fondo (R, G, B, Gris)
  BACKGROUND_DIM = [-80, -80, -80, 130] 


  

  FORMAT_ARCHIVE_HISTORY = {:txt => "txt", :md => "md"}


  EXPERIMENTAL_FUNCTIONS = false

  attr_accessor :report_format    
  attr_accessor :active_theme     
  attr_accessor :custom_tone     
  attr_accessor :bg_dim_opacity 

  attr_accessor :grid_size
  def initialize
    @report_format    = :txt
    @active_theme     = :RADIACTIVE
    @custom_tone      = [100, 100, 100, 0]
    @bg_dim_opacity   = 130
    @grid_size        = 0
  end
  def grid_size
    
    if @grid_size.nil?
      val =  0
      @grid_size = val
      
    end
    return @grid_size || 0
  end
  def report_format
  val = @report_format
    
    if val.is_a?(Integer)
      val = Settings_UI_Editor::FORMAT_ARCHIVE_HISTORY.keys[val] || :txt
      @report_format = val
    end
    return val || :txt
  end
  
end

  #Prueba de saludo al usurario 
  def pbGetGreeting
    hora   = Time.now.hour
    saludo = "Buenas noches"
    saludo = "Buenos días" if hora >= 6 && hora < 12
    saludo = "Buenas tardes" if hora >= 12 && hora < 20
    return "#{saludo}, #{pbGetUserName}"
  end


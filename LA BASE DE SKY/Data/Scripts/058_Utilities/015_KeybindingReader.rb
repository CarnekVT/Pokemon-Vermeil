#===============================================================================
# KeybindingReader - Módulo para leer teclas asignadas dinámicamente
#===============================================================================
# Este módulo permite obtener el nombre de la tecla asignada a cada botón
# del juego, leyendo el archivo keybindings si existe (cuando el usuario
# modifica los controles con F1) o usando los valores por defecto.
#
# Uso:
#   KeybindingReader.key_name(:SPECIAL)  # => "D" (o la tecla modificada)
#   KeybindingReader.key_name(:USE)      # => "C"
#   KeybindingReader.key_name(:ACTION)   # => "Z"
#
# Puedes usar los símbolos de Input directamente:
#   KeybindingReader.key_name(Input::SPECIAL) # funciona igual
#
# @author La Base de Sky
# @version 2.0.0
#===============================================================================
module KeybindingReader
  # Ruta al archivo keybindings binario generado por MKXP-Z (%APPDATA%/...)
  KEYBINDINGS_FILE = RTP.getSaveFileName("keybindings.mkxp1")

  # Debug: muestra información detallada al parsear el archivo binario
  DEBUG = false

  # Índices de botón usados por MKXP-Z en el archivo binario
  # Derivados del análisis del archivo keybindings.mkxp1 real
  BUTTON_INDEX = {
    "A"     => 11,  # Action  (Z por defecto)
    "B"     => 12,  # Back    (X por defecto)
    "C"     => 13,  # Use     (C por defecto)
    "X"     => 14,  # JumpUp  (A por defecto)
    "Y"     => 15,  # JumpDown(S por defecto)
    "Z"     => 16,  # Special (D por defecto)
    "L"     => 17,  # AUX1   (Q por defecto)
    "R"     => 18,  # AUX2   (W por defecto)
    "Up"    => 8,
    "Down"  => 2,
    "Left"  => 4,
    "Right" => 6
  }
  # Invertido para parsear: índice → nombre de botón
  INDEX_TO_BUTTON = BUTTON_INDEX.invert

  # Mapeo de constantes Input a nombres internos de MKXP-Z
  INPUT_TO_MKXP_NAME = {
    Input::B        => "B",
    Input::C        => "C",
    Input::X        => "X",
    Input::Y        => "Y",
    Input::Z        => "Z",
    Input::L        => "L",
    Input::R        => "R",
    Input::UP       => "Up",
    Input::DOWN     => "Down",
    Input::LEFT     => "Left",
    Input::RIGHT    => "Right",
    Input::USE      => "C",
    Input::BACK     => "B",
    Input::ACTION   => "A",
    Input::JUMPUP   => "X",
    Input::JUMPDOWN => "Y",
    Input::SPECIAL  => "Z",
    Input::AUX1     => "L",
    Input::AUX2     => "R"
  }

  # Teclas por defecto (sin archivo keybindings o botón no modificado)
  DEFAULT_KEYS = {
    "A"     => "Z",
    "B"     => "X",
    "C"     => "C",
    "X"     => "A",
    "Y"     => "S",
    "Z"     => "D",
    "L"     => "Q",
    "R"     => "W",
    "Up"    => "↑",
    "Down"  => "↓",
    "Left"  => "←",
    "Right" => "→"
  }

  # SDL Scancodes → nombre legible
  # Referencia: https://wiki.libsdl.org/SDL2/SDL_Scancode
  SDL_SCANCODE_NAMES = {
    4  => "A",  5  => "B",  6  => "C",  7  => "D",  8  => "E",
    9  => "F",  10 => "G",  11 => "H",  12 => "I",  13 => "J",
    14 => "K",  15 => "L",  16 => "M",  17 => "N",  18 => "O",
    19 => "P",  20 => "Q",  21 => "R",  22 => "S",  23 => "T",
    24 => "U",  25 => "V",  26 => "W",  27 => "X",  28 => "Y",
    29 => "Z",
    30 => "1",  31 => "2",  32 => "3",  33 => "4",  34 => "5",
    35 => "6",  36 => "7",  37 => "8",  38 => "9",  39 => "0",
    40 => "Enter", 41 => "Esc", 42 => "Backspace", 43 => "Tab",
    44 => "Espacio", 45 => "-",  46 => "=",
    47 => "[",  48 => "]",  49 => "\\", 51 => ";",  52 => "'",
    54 => ",",  55 => ".",  56 => "/",
    57 => "BloqMay",
    58 => "F1",  59 => "F2",  60 => "F3",  61 => "F4",
    62 => "F5",  63 => "F6",  64 => "F7",  65 => "F8",
    66 => "F9",  67 => "F10", 68 => "F11", 69 => "F12",
    73 => "Ins",  74 => "Inicio", 75 => "RePág",
    76 => "Supr", 77 => "Fin",   78 => "AvPág",
    79 => "→",   80 => "←",   81 => "↓",   82 => "↑",
    224 => "Ctrl", 225 => "Shift", 226 => "Alt",
    228 => "Ctrl", 229 => "Shift", 230 => "Alt",
    89 => "Num1", 90 => "Num2", 91 => "Num3", 92 => "Num4",
    93 => "Num5", 94 => "Num6", 95 => "Num7", 96 => "Num8",
    97 => "Num9", 98 => "Num0"
  }

  # Scancodes de modificadores (Ctrl, Shift, Alt) — se usan como tecla secundaria
  MODIFIER_SCANCODES = [224, 225, 226, 227, 228, 229, 230, 231]

  # Cache
  @keybindings_cache = nil
  @cache_time = nil
  CACHE_DURATION = 5

  module_function

  #-----------------------------------------------------------------------------
  # Obtiene el nombre de la tecla asignada a un botón de Input
  #-----------------------------------------------------------------------------
  def key_name(input, prefer_letter: true)
    if input.is_a?(Symbol)
      input = get_input_constant(input)
      return "?" if input.nil?
    end
    mkxp_name = INPUT_TO_MKXP_NAME[input]
    return "?" unless mkxp_name

    keybindings = load_keybindings
    if keybindings && keybindings[mkxp_name]
      return keybindings[mkxp_name]
    end

    DEFAULT_KEYS[mkxp_name] || "?"
  end

  def key_for(symbol)
    key_name(symbol)
  end

  def format_text(text, input)
    text.gsub("{KEY}", key_name(input))
  end

  def format_keys(text)
    result = text.dup
    result.gsub!(/\{KEY:(\w+)\}/) { key_name($1.to_sym) }
    result
  end

  def clear_cache
    @keybindings_cache = nil
    @cache_time = nil
  end

  def all_keybindings
    result = {}
    INPUT_TO_MKXP_NAME.each do |input, mkxp_name|
      result[mkxp_name] = key_name(input) unless result[mkxp_name]
    end
    result
  end

  #=============================================================================
  # Métodos privados
  #=============================================================================

  def load_keybindings
    if @keybindings_cache && @cache_time && (Time.now - @cache_time < CACHE_DURATION)
      return @keybindings_cache
    end

    unless File.exist?(KEYBINDINGS_FILE)
      echoln("[KeybindingReader] Archivo no encontrado: #{KEYBINDINGS_FILE}") if DEBUG
      return nil
    end

    begin
      data = File.binread(KEYBINDINGS_FILE)
      echoln("[KeybindingReader] Archivo leído: #{data.bytesize} bytes") if DEBUG
      echoln("[KeybindingReader] Hex: #{data.bytes.first(64).map { |b| b.to_s(16).rjust(2,"0") }.join(" ")}") if DEBUG
      @keybindings_cache = parse_binary(data)
      echoln("[KeybindingReader] Resultado parsed: #{@keybindings_cache.inspect}") if DEBUG
      @cache_time = Time.now
      return @keybindings_cache
    rescue StandardError => e
      echoln("[KeybindingReader] Error: #{e.message}") if DEBUG
      return nil
    end
  end

  #-----------------------------------------------------------------------------
  # Parsea el formato binario de MKXP-Z.
  #
  # Estructura observada (little-endian, uint32):
  # Formato binario real de MKXP-Z (.mkxp1):
  #   Header (3x uint32): [magic, version, total_entries]
  #   Luego total_entries registros de 4x uint32 cada uno:
  #     [input_type: u32]  1=teclado, 2=botón gamepad, 3=eje gamepad
  #     [input_code: u32]  SDL scancode (si type==1) o índice de botón/eje
  #     [extra:      u32]  dirección para ejes, ignorado para teclado
  #     [button_idx: u32]  índice del botón del juego (0=A, 1=B, ..., 8=Up...)
  #-----------------------------------------------------------------------------
  def parse_binary(data)
    return nil if data.bytesize < 12

    values = data.unpack("V*")
    total_entries = values[2]
    echoln("[KeybindingReader] Header: magic=#{values[0]}, v=#{values[1]}, total_entries=#{total_entries}") if DEBUG
    return nil if values.size < 3 + total_entries * 4

    # Recopilar todos los scancodes de teclado por botón
    kbd = {}
    total_entries.times do |i|
      pos        = 3 + i * 4
      input_type = values[pos]
      input_code = values[pos + 1]
      # extra    = values[pos + 2]  # ignorado
      button_idx = values[pos + 3]
      next unless input_type == 1  # solo teclado
      btn_name = INDEX_TO_BUTTON[button_idx]
      next unless btn_name
      kbd[btn_name] ||= []
      kbd[btn_name] << input_code
    end

    # Elegir la mejor tecla por botón: primero no-modificador, luego la primera
    result = {}
    kbd.each do |btn_name, scancodes|
      sc  = scancodes.find { |c| !MODIFIER_SCANCODES.include?(c) } || scancodes.first
      key = SDL_SCANCODE_NAMES[sc]
      result[btn_name] = key if key
      echoln("[KeybindingReader] #{btn_name} => #{key.inspect} (scancodes: #{scancodes.inspect})") if DEBUG
    end

    result.empty? ? nil : result
  end

  def get_input_constant(symbol)
    case symbol
    when :A, :JUMPUP   then Input::JUMPUP
    when :B, :BACK     then Input::BACK
    when :C, :USE      then Input::USE
    when :X            then Input::X
    when :Y, :JUMPDOWN then Input::JUMPDOWN
    when :Z, :SPECIAL  then Input::SPECIAL
    when :L, :AUX1     then Input::AUX1
    when :R, :AUX2     then Input::AUX2
    when :UP           then Input::UP
    when :DOWN         then Input::DOWN
    when :LEFT         then Input::LEFT
    when :RIGHT        then Input::RIGHT
    when :ACTION       then Input::ACTION
    else nil
    end
  end
end

#===============================================================================
# Alias conveniente para uso más corto
#===============================================================================
def pbGetKeyName(input)
  KeybindingReader.key_name(input)
end

def pbFormatKeyText(text, input)
  KeybindingReader.format_text(text, input)
end

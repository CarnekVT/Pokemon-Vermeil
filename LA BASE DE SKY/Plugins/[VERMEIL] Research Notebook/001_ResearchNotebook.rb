#===============================================================================
# [VERMEIL] Research Notebook - Vinculación con Nueva Pokédex y Optimización
#===============================================================================
module VermeilResearchNotebook
  @species_cache = nil
  @last_unlocked_signature = nil

  # Obtiene la lista de especies filtrada ESTRICTAMENTE por las Dexes habilitadas
  def self.valid_species_list
    current_sig = current_dex_signature

    # Si la caché está viva y no han cambiado las dexes habilitadas, reutilizar al instante (O(1))
    if @species_cache && @last_unlocked_signature == current_sig
      return @species_cache
    end

    # La dex real del juego la decide el JSON editable (Data/SpeciesDex/config.json), con
    # sus slots tal cual (una forma propia ES su slot, no se colapsa a especie base).
    # Si NuevaPokedex no está cargado, fallback: todas las especies base del PBS.
    if defined?(NuevaPokedex) && NuevaPokedex.respond_to?(:enabled_dexes) &&
       NuevaPokedex.respond_to?(:regional_species)
      dex_species = []
      NuevaPokedex.enabled_dexes.each do |reg|
        dex_species.concat(NuevaPokedex.regional_species(reg))
      end
      @species_cache = dex_species.uniq
    else
      list = []
      GameData::Species.each do |s|
        next if s.form > 0
        list << s.species
      end
      @species_cache = list
    end

    @last_unlocked_signature = current_sig
    return @species_cache
  end

  # Firma de invalidez de la caché: las dexes habilitadas + el mtime del JSON que
  # las define. No depende del estado de la partida ni de APIs del motor.
  def self.current_dex_signature
    stamp = (File.mtime("Data/SpeciesDex/config.json") rescue nil)
    if defined?(NuevaPokedex) && NuevaPokedex.respond_to?(:enabled_dexes)
      enabled = NuevaPokedex.enabled_dexes
    else
      enabled = []
    end
    return [enabled, stamp].to_s
  end

  def self.clear_cache!
    @species_cache = nil
    @last_unlocked_signature = nil
  end

  class Scene
    PAGE_SIZE = 6

    def pbStartScene
      VermeilResearchNotebook.clear_cache!
      @species_pool = VermeilResearchNotebook.valid_species_list
      @index = 0
      @top_index = 0
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99999
      @sprites = {}

      # Fondo de libreta
      @sprites["bg"] = Sprite.new(@viewport)
      @sprites["bg"].bitmap = Bitmap.new(Graphics.width, Graphics.height)
      draw_notebook_background

      # Overlay de texto
      @sprites["overlay"] = Sprite.new(@viewport)
      @sprites["overlay"].bitmap = Bitmap.new(Graphics.width, Graphics.height)
      pbSetSystemFont(@sprites["overlay"].bitmap)

      # Icono de especie seleccionada
      @sprites["species_icon"] = PokemonSpeciesIconSprite.new(nil, @viewport)
      @sprites["species_icon"].x = Graphics.width - 130
      @sprites["species_icon"].y = 110
      @sprites["species_icon"].z = 20

      # Cursor de libreta
      @sprites["cursor"] = Sprite.new(@viewport)
      @sprites["cursor"].bitmap = Bitmap.new(Graphics.width - 240, 48)
      @sprites["cursor"].bitmap.fill_rect(0, 0, Graphics.width - 240, 48, Color.new(210, 180, 120, 70))
      @sprites["cursor"].bitmap.fill_rect(0, 0, 4, 48, Color.new(180, 120, 60))
      @sprites["cursor"].x = 24
      @sprites["cursor"].y = 70
      @sprites["cursor"].z = 10

      refresh_page
      pbPlayDecisionSE
    end

    def draw_notebook_background
      bmp = @sprites["bg"].bitmap
      # Estilo pergamino / libreta de investigación
      bmp.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(242, 235, 218))
      # Margen lateral izquierdo de libreta
      bmp.fill_rect(0, 0, 16, Graphics.height, Color.new(160, 130, 95))
      # Encabezado
      bmp.fill_rect(16, 0, Graphics.width - 16, 52, Color.new(225, 214, 190))
      bmp.fill_rect(16, 50, Graphics.width - 16, 2, Color.new(190, 175, 145))
      # Pie de página
      bmp.fill_rect(16, Graphics.height - 36, Graphics.width - 16, 36, Color.new(225, 214, 190))
      bmp.fill_rect(16, Graphics.height - 38, Graphics.width - 16, 2, Color.new(190, 175, 145))
      # Panel de notas
      bmp.fill_rect(Graphics.width - 220, 52, 220, Graphics.height - 88, Color.new(232, 222, 200, 160))
    end

    def refresh_page
      overlay = @sprites["overlay"].bitmap
      overlay.clear

      title = "LIBRETA DE INVESTIGACIÓN  (Especies activas: #{@species_pool.length})"
      pbDrawTextPositions(overlay, [
        [title, 32, 16, :left, Color.new(70, 50, 30), Color.new(220, 210, 190)],
        ["X: Cerrar  C: Ver Tareas de Campo", Graphics.width - 24, Graphics.height - 26, :right, Color.new(120, 100, 80), Color.new(240, 235, 220)]
      ])

      y = 72
      PAGE_SIZE.times do |i|
        idx = @top_index + i
        break if idx >= @species_pool.length
        sp = @species_pool[idx]
        s_data = GameData::Species.try_get(sp)
        next if !s_data

        seen = $player && $player.pokedex ? ($player.pokedex.seen?(sp) rescue true) : true
        owned = $player && $player.pokedex ? ($player.pokedex.owned?(sp) rescue false) : false

        name = seen ? s_data.name : "??? (No avistado)"
        status = owned ? "Investigado [✓]" : (seen ? "Avistado [-]" : "Sin datos")
        col = owned ? Color.new(40, 140, 50) : (seen ? Color.new(60, 60, 70) : Color.new(150, 140, 130))

        pbDrawTextPositions(overlay, [
          [sprintf("#%03d", idx + 1), 32, y + 12, :left, Color.new(130, 110, 90)],
          [name, 96, y + 12, :left, col],
          [status, Graphics.width - 240, y + 12, :right, col]
        ])
        y += 48
      end

      curr_sp = @species_pool[@index]
      if curr_sp && ($player && $player.pokedex ? ($player.pokedex.seen?(curr_sp) rescue true) : true)
        @sprites["species_icon"].pbSetParams(curr_sp, 0, 0)
        @sprites["species_icon"].visible = true
      else
        @sprites["species_icon"].visible = false
      end
    end

    def update_cursor
      rel = @index - @top_index
      target_y = 70 + (rel * 48)
      @sprites["cursor"].y += (target_y - @sprites["cursor"].y) * 0.4
    end

    def pbMain
      loop do
        Graphics.update
        Input.update
        update_cursor

        if Input.repeat?(Input::DOWN)
          if @index < @species_pool.length - 1
            @index += 1
            if @index >= @top_index + PAGE_SIZE
              @top_index += 1
            end
            pbPlayCursorSE
            refresh_page
          end
        elsif Input.repeat?(Input::UP)
          if @index > 0
            @index -= 1
            if @index < @top_index
              @top_index = @index
            end
            pbPlayCursorSE
            refresh_page
          end
        elsif Input.trigger?(Input::USE)
          pbPlayDecisionSE
          inspect_species
        elsif Input.trigger?(Input::BACK)
          pbPlayCancelSE
          break
        end
      end
    end

    def inspect_species
      sp = @species_pool[@index]
      return if !sp
      s_data = GameData::Species.try_get(sp)
      return if !s_data
      if !($player && $player.pokedex ? ($player.pokedex.seen?(sp) rescue true) : true)
        pbMessage("No posees información ni avistamientos registrados de este Pokémon en la región activa.")
        return
      end
      # Resumen de investigación
      pbMessage("\c[2]Notas de Campo: #{s_data.name}\c[0]\nTipo: #{s_data.types.join('/')}\nBioma / Hábitat registrado en la región habilitada.")
    end

    def pbEndScene
      pbDisposeSpriteHash(@sprites)
      @viewport.dispose
    end
  end

  class Screen
    def initialize(scene)
      @scene = scene
    end
    def pbStartScreen
      @scene.pbStartScene
      @scene.pbMain
      @scene.pbEndScene
    end
  end
end

def pbOpenResearchNotebook
  scene = VermeilResearchNotebook::Scene.new
  screen = VermeilResearchNotebook::Screen.new(scene)
  screen.pbStartScreen
end

#===============================================================================
# [ZBOX] Nueva Pokédex - Escena y Renderizado (Gamefeel Alto)
#===============================================================================
class NewPokedex_Scene
  PAGE_SIZE = 7

  def pbStartScene(dex_id = 0)
    NewPokedex.load_data
    @dex_id = dex_id
    @species_list = NewPokedex.species_in_dex(@dex_id)
    @index = 0
    @top_index = 0
    @mode = :list
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999

    # Fondo base
    @sprites["bg"] = Sprite.new(@viewport)
    @sprites["bg"].bitmap = Bitmap.new(Graphics.width, Graphics.height)
    draw_background

    # Lista overlay
    @sprites["overlay"] = Sprite.new(@viewport)
    @sprites["overlay"].bitmap = Bitmap.new(Graphics.width, Graphics.height)
    pbSetSystemFont(@sprites["overlay"].bitmap)

    # Cursor de selección con animación
    @sprites["cursor"] = Sprite.new(@viewport)
    @sprites["cursor"].bitmap = Bitmap.new(Graphics.width - 240, 44)
    @sprites["cursor"].bitmap.fill_rect(0, 0, Graphics.width - 240, 44, Color.new(235, 75, 75, 90))
    @sprites["cursor"].bitmap.fill_rect(0, 0, 4, 44, Color.new(255, 120, 120))
    @sprites["cursor"].x = 16
    @sprites["cursor"].y = 64
    @sprites["cursor"].z = 10

    # Icono del Pokémon seleccionado
    @sprites["pokemon_icon"] = PokemonSpeciesIconSprite.new(nil, @viewport)
    @sprites["pokemon_icon"].x = Graphics.width - 110
    @sprites["pokemon_icon"].y = 120
    @sprites["pokemon_icon"].z = 20

    refresh_list
    pbPlayDecisionSE if NewPokedexConfig::PLAY_DECISION_SE
  end

  def draw_background
    bmp = @sprites["bg"].bitmap
    bmp.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(20, 24, 34))
    # Encabezado
    bmp.fill_rect(0, 0, Graphics.width, 50, Color.new(28, 36, 50))
    bmp.fill_rect(0, 48, Graphics.width, 2, Color.new(50, 65, 88))
    # Pie de página
    bmp.fill_rect(0, Graphics.height - 36, Graphics.width, 36, Color.new(28, 36, 50))
    bmp.fill_rect(0, Graphics.height - 38, Graphics.width, 2, Color.new(50, 65, 88))
    # Panel lateral de vista previa
    panel_x = Graphics.width - 210
    bmp.fill_rect(panel_x, 50, 210, Graphics.height - 86, Color.new(25, 32, 44, 200))
    bmp.fill_rect(panel_x - 2, 50, 2, Graphics.height - 86, Color.new(45, 58, 78))
  end

  def refresh_list
    overlay = @sprites["overlay"].bitmap
    overlay.clear

    # Título y conteos
    dex_name = NewPokedex.dex_name(@dex_id)
    seen = $player && $player.pokedex ? ($player.pokedex.seen_count(@dex_id) rescue 0) : 0
    owned = $player && $player.pokedex ? ($player.pokedex.owned_count(@dex_id) rescue 0) : 0
    title_text = "#{dex_name}   Vistos: #{seen}  Atrapados: #{owned}"
    pbDrawTextPositions(overlay, [
      [title_text, 16, 14, :left, NewPokedexConfig::COLOR_TEXT_MAIN, Color.new(0, 0, 0, 140)],
      ["X: Salir  C: Ver Detalle  Z: Buscar", Graphics.width - 16, Graphics.height - 26, :right, NewPokedexConfig::COLOR_TEXT_MUTED, Color.new(0, 0, 0, 140)]
    ])

    # Elementos de la lista
    y = 64
    PAGE_SIZE.times do |i|
      idx = @top_index + i
      break if idx >= @species_list.length
      species = @species_list[idx]
      s_data = GameData::Species.try_get(species)
      next if !s_data

      is_seen = $player && $player.pokedex ? ($player.pokedex.seen?(species) rescue true) : true
      is_owned = $player && $player.pokedex ? ($player.pokedex.owned?(species) rescue false) : false

      num_str = sprintf("%03d", idx + 1)
      ball_mark = is_owned ? "[PKMN]" : (is_seen ? "  -  " : "     ")
      name_str = is_seen ? s_data.name : "----------"
      text_color = is_owned ? NewPokedexConfig::COLOR_OWNED : (is_seen ? NewPokedexConfig::COLOR_TEXT_MAIN : NewPokedexConfig::COLOR_TEXT_MUTED)

      pbDrawTextPositions(overlay, [
        [num_str, 24, y + 10, :left, NewPokedexConfig::COLOR_TEXT_MUTED, Color.new(0, 0, 0, 120)],
        [name_str, 90, y + 10, :left, text_color, Color.new(0, 0, 0, 120)],
        [ball_mark, Graphics.width - 270, y + 10, :right, text_color, Color.new(0, 0, 0, 120)]
      ])
      y += 44
    end

    # Actualizar icono lateral
    current_species = @species_list[@index]
    if current_species && ($player && $player.pokedex ? ($player.pokedex.seen?(current_species) rescue true) : true)
      @sprites["pokemon_icon"].pbSetParams(current_species, 0, 0)
      @sprites["pokemon_icon"].visible = true
    else
      @sprites["pokemon_icon"].visible = false
    end
  end

  def update_cursor
    relative_index = @index - @top_index
    target_y = 64 + (relative_index * 44)
    # Movimiento suavizado del cursor
    @sprites["cursor"].y += (target_y - @sprites["cursor"].y) * 0.5
    # Pulso visual de gamefeel
    time = (Graphics.frame_count * 0.16) rescue 0
    @sprites["cursor"].opacity = (200 + Math.sin(time) * 45).round
  end

  def pbMain
    loop do
      Graphics.update
      Input.update
      update_cursor

      if Input.repeat?(Input::DOWN)
        if @index < @species_list.length - 1
          @index += 1
          if @index >= @top_index + PAGE_SIZE
            @top_index += 1
          end
          pbPlayCursorSE if NewPokedexConfig::PLAY_CURSOR_SE
          refresh_list
        end
      elsif Input.repeat?(Input::UP)
        if @index > 0
          @index -= 1
          if @index < @top_index
            @top_index = @index
          end
          pbPlayCursorSE if NewPokedexConfig::PLAY_CURSOR_SE
          refresh_list
        end
      elsif Input.repeat?(Input::JUMPUP) # L Trigger
        if @index > 0
          @index = [@index - PAGE_SIZE, 0].max
          @top_index = [@top_index - PAGE_SIZE, 0].max
          pbPlayCursorSE if NewPokedexConfig::PLAY_CURSOR_SE
          refresh_list
        end
      elsif Input.repeat?(Input::JUMPDOWN) # R Trigger
        if @index < @species_list.length - 1
          @index = [@index + PAGE_SIZE, @species_list.length - 1].min
          @top_index = [@top_index + PAGE_SIZE, [@species_list.length - PAGE_SIZE, 0].max].min
          pbPlayCursorSE if NewPokedexConfig::PLAY_CURSOR_SE
          refresh_list
        end
      elsif Input.trigger?(Input::ACTION) # Z
        current_species = @species_list[@index]
        if current_species && ($player && $player.pokedex ? ($player.pokedex.seen?(current_species) rescue true) : true)
          GameData::Species.play_cry_from_species(current_species) rescue nil
        end
      elsif Input.trigger?(Input::USE) # C
        pbPlayDecisionSE if NewPokedexConfig::PLAY_DECISION_SE
        show_detail
      elsif Input.trigger?(Input::BACK) # X
        pbPlayCancelSE if NewPokedexConfig::PLAY_CANCEL_SE
        break
      end
    end
  end

  def show_detail
    current_species = @species_list[@index]
    return if !current_species
    return if !($player && $player.pokedex ? ($player.pokedex.seen?(current_species) rescue true) : true)
    s_data = GameData::Species.try_get(current_species)
    return if !s_data

    # Pantalla modal con datos completos y audio
    pbMessage("\c[1]#{s_data.name}\c[0] - #{s_data.category}\n#{s_data.pokedex_entry}")
  end

  def pbEndScene
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

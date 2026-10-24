# encoding: UTF-8
#===============================================================================
# Libreta de Investigación - UI 640x480 v1.2.2
# Inspiración funcional: MegaDex de Z-A (foco grande + cuadrícula rápida).
# Interfaz propia. NO modifica Summary.
#===============================================================================
module ResearchNotebook
  class Scene
    WIDTH  = 640
    HEIGHT = 480

    HEADER_H = 55
    FOOTER_Y = 442

    FOCUS_X = 14
    FOCUS_Y = 62
    FOCUS_W = 294
    FOCUS_H = 368

    GRID_X = 320
    GRID_Y = 76
    GRID_W = 306
    GRID_H = 348
    COLS   = ResearchNotebook::Settings::GRID_COLUMNS
    ROWS   = ResearchNotebook::Settings::GRID_ROWS
    PAGE_SIZE = COLS * ROWS
    CELL_W = 58
    CELL_H = 63
    GRID_GAP_X = 3
    GRID_GAP_Y = 3

    BOOK_X = 6
    BOOK_Y = HEADER_H
    BOOK_W = WIDTH - (BOOK_X * 2)
    BOOK_H = FOOTER_Y - HEADER_H

    PAPER      = Color.new(246, 239, 217)
    PAPER_2    = Color.new(237, 227, 201)
    PAPER_3    = Color.new(225, 211, 180)
    PAPER_DARK = Color.new(198, 179, 139)
    INK        = Color.new(53, 44, 39)
    MUTED      = Color.new(123, 108, 91)
    LINE       = Color.new(205, 190, 157)
    COVER      = Color.new(42, 31, 27)
    COVER_2    = Color.new(76, 55, 39)
    WHITE      = Color.new(250, 248, 240)
    BLACK      = Color.new(0, 0, 0)
    ARCANE     = Color.new(177, 145, 216)
    ARCANE_2   = Color.new(100, 72, 136)
    GOLDEN     = Color.new(231, 182, 63)
    GOLDEN_2   = Color.new(148, 103, 24)
    GREEN      = Color.new(112, 166, 110)
    RED        = Color.new(172, 82, 75)

    SORT_LABELS = {
      :DEX    => "Número",
      :NAME   => "Nombre",
      :STATUS => "Estado"
    }

    def initialize
      @sprites = {}
      @skin = ResearchNotebook::Skin.new(ResearchNotebook::Settings::USE_CUSTOM_UI)
      @viewport = nil
      @sections = []
      @section_index = 0
      @species = []
      @index = 0
      @sort_mode = ResearchNotebook::Settings::DEFAULT_SORT
      @admission_set = nil
      @detail_open = false
      @detail_page = 0
      @frame_count = 0
      @order_map = {}
      @display_number = {}
      @grid_signature = nil
      @pending_grid_icons = []
      @species_generation = 0
      @focus_signature = nil
      @icon_base_zoom = {}
      @pokemon_base_zoom_x = 1.0
      @pokemon_base_zoom_y = 1.0
      @type_sheet = nil
      @type_sheet_path = nil
      @type_frame_h = nil
      @type_icon_count = nil
      @golden_custom_bitmap = nil
      @golden_custom_path = nil
    end

    def main
      start
      loop do
        Graphics.update
        Input.update
        # Solo el Pokémon focal necesita update continuo. Los 25 iconos de la
        # cuadrícula quedan estáticos para evitar una caída de FPS innecesaria.
        focus = @sprites["pokemon"]
        focus.update if focus && focus.visible && focus.respond_to?(:update)
        update_gamefeel
        render_next_grid_icons(2)
        break if update_input
      end
      close_animation if ResearchNotebook::Settings::ENABLE_OPEN_ANIMATION
      dispose
    end

    def start
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99_999

      @sprites["shade"] = BitmapSprite.new(WIDTH, HEIGHT, @viewport)
      @sprites["shade"].z = 0
      @sprites["shade"].bitmap.fill_rect(0, 0, WIDTH, HEIGHT, Color.new(0, 0, 0, 170))

      @sprites["paper"] = BitmapSprite.new(WIDTH, HEIGHT, @viewport)
      @sprites["paper"].z = 1
      @sprites["overlay"] = BitmapSprite.new(WIDTH, HEIGHT, @viewport)
      @sprites["overlay"].z = 2

      # Toda la cuadrícula se rasteriza en un único bitmap. Mantener 25
      # PokemonIconSprite vivos a la vez era la principal caída de FPS de la UI.
      @sprites["grid_icons"] = BitmapSprite.new(WIDTH, HEIGHT, @viewport)
      @sprites["grid_icons"].z = 4

      @sprites["cursor"] = BitmapSprite.new(CELL_W, CELL_H, @viewport)
      @sprites["cursor"].z = 6
      build_cursor_bitmap

      if defined?(PokemonSprite)
        @sprites["pokemon"] = PokemonSprite.new(@viewport)
        @sprites["pokemon"].z = 4
        @sprites["pokemon"].visible = false
      end

      @sprites["pageblank"] = BitmapSprite.new(GRID_W, BOOK_H, @viewport)
      @sprites["pageblank"].x = GRID_X
      @sprites["pageblank"].y = BOOK_Y
      @sprites["pageblank"].z = 69
      @sprites["pageblank"].visible = false

      @sprites["pagefx"] = BitmapSprite.new(GRID_W, BOOK_H, @viewport)
      @sprites["pagefx"].x = GRID_X
      @sprites["pagefx"].y = BOOK_Y
      @sprites["pagefx"].z = 70
      @sprites["pagefx"].visible = false

      ["paper", "overlay", "grid_icons", "cursor", "pageblank", "pagefx"].each do |key|
        sprite = @sprites[key]
        pbSetSystemFont(sprite.bitmap) if sprite && sprite.respond_to?(:bitmap) && sprite.bitmap
      end

      # La tapa aparece inmediatamente; la sincronización se hace detrás de ella.
      # Así no hay un fundido negro seguido de otra animación ni una pausa vacía.
      create_cover_sprites
      set_notebook_content_visible(false)
      Graphics.update

      # Abrir la Libreta nunca recorre las cajas. Solo sincroniza el equipo
      # actual (máximo 6 Pokémon); el escaneo completo queda para Debug.
      ResearchNotebook::Repository.golden_data
      ResearchNotebook::Repository.arcane_data
      ResearchNotebook.progress.sync_party_unlocks!

      # Los badges de tipos se dibujan como texto legible; no abrir
      # spritesheets enormes antes de mostrar la Libreta.
      build_order_maps
      rebuild_sections
      rebuild_species
      set_notebook_content_visible(true)
      refresh
      remember_content_visibility
      set_notebook_content_visible(false)
      if ResearchNotebook::Settings::ENABLE_OPEN_ANIMATION
        open_animation
      else
        restore_content_visibility
      end
    end

    def dispose
      @skin.dispose if @skin
      dispose_grid_icons
      begin
        @type_sheet.dispose if @type_sheet && @type_sheet.respond_to?(:dispose)
      rescue
      end
      begin
        @golden_custom_bitmap.dispose if @golden_custom_bitmap && @golden_custom_bitmap.respond_to?(:dispose)
      rescue
      end
      pbDisposeSpriteHash(@sprites) if defined?(pbDisposeSpriteHash)
      @viewport.dispose if @viewport && !@viewport.disposed?
    end

    #===========================================================================
    # Navegación
    #===========================================================================
    def update_input
      if Input.trigger?(Input::BACK)
        pbPlayCancelSE if defined?(pbPlayCancelSE)
        if @detail_open
          @detail_open = false
          @detail_page = 0
          page_wipe(-1) { refresh }
          return false
        end
        return true
      end

      if @detail_open
        if Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
          move_detail_species(Input.repeat?(Input::UP) ? -1 : 1)
        elsif current_section == :golden
          if Input.trigger?(Input::LEFT)
            change_detail_page(-1)
          elsif Input.trigger?(Input::RIGHT)
            change_detail_page(1)
          end
        end
        if defined?(Input::USE) && Input.trigger?(Input::USE)
          @detail_open = false
          pbPlayCancelSE if defined?(pbPlayCancelSE)
          page_wipe(-1) { refresh }
        end
        return false
      end

      if Input.repeat?(Input::UP)
        move_grid(0, -1)
      elsif Input.repeat?(Input::DOWN)
        move_grid(0, 1)
      elsif Input.repeat?(Input::LEFT)
        move_grid(-1, 0)
      elsif Input.repeat?(Input::RIGHT)
        move_grid(1, 0)
      elsif defined?(Input::USE) && Input.trigger?(Input::USE)
        open_detail
      elsif defined?(Input::ACTION) && Input.trigger?(Input::ACTION)
        change_section(1)
      elsif defined?(Input::SPECIAL) && Input.trigger?(Input::SPECIAL)
        cycle_sort
      end
      return false
    end

    def move_detail_species(direction)
      return if @species.empty?
      next_index = @index + direction
      return unless next_index.between?(0, @species.length - 1)
      @index = next_index
      @detail_page = 0
      pbPlayCursorSE if defined?(pbPlayCursorSE)
      # No cerrar la ficha para cambiar de especie.
      refresh
    end

    def current_section
      return @sections[@section_index] ? @sections[@section_index][0] : nil
    end

    def rebuild_sections
      @sections = []
      if ResearchNotebook.progress.arcane_section_unlocked
        @sections << [:arcane, _INTL("Habilidades Arcanas")]
      end
      if ResearchNotebook.progress.golden_section_unlocked
        @sections << [:golden, _INTL("Áureo")]
      end
      @section_index = [[@section_index, 0].max, [@sections.length - 1, 0].max].min
    end

    def change_section(delta)
      return if @sections.length <= 1
      old = selected_species
      @section_index = (@section_index + delta) % @sections.length
      @detail_page = 0
      rebuild_species(old)
      pbPlayCursorSE if defined?(pbPlayCursorSE)
      page_wipe(delta) { refresh }
    end

    def cycle_sort
      modes = [:DEX, :NAME, :STATUS]
      pos = modes.index(@sort_mode) || 0
      @sort_mode = modes[(pos + 1) % modes.length]
      old = selected_species
      rebuild_species(old)
      pbPlayDecisionSE if defined?(pbPlayDecisionSE)
      flash_sort_label
      refresh
    end

    def change_detail_page(delta)
      count = detail_page_count
      return if count <= 1
      @detail_page = (@detail_page + delta) % count
      pbPlayCursorSE if defined?(pbPlayCursorSE)
      page_wipe(delta) { refresh }
    end

    def detail_page_count
      return 1 unless current_section == :golden
      return 1 unless ResearchNotebook::Repository.golden_form_configured?(selected_species)
      moves = golden_move_records(selected_species)
      moves.empty? ? 2 : 2 + (moves.length.to_f / 4).ceil
    end

    def golden_move_records(entry)
      return [] unless defined?(GoldenSystem::GoldenMoves)
      base, source_form = ResearchNotebook::Repository.species_base_and_form(entry)
      target = ResearchNotebook::Repository.golden_form_index(entry)
      return [] unless target
      GoldenSystem::GoldenMoves.all.values.select do |item|
        item[:species] == base && item[:form].to_i == target &&
          (item[:source_form].nil? || item[:source_form].to_i == source_form)
      end.sort_by { |item| item[:name].to_s }
    end

    def open_detail
      return if !selected_species
      @detail_open = true
      @detail_page = 0
      pbPlayDecisionSE if defined?(pbPlayDecisionSE)
      page_wipe(1) { refresh }
    end

    def move_grid(dx, dy)
      return if @species.empty?
      old = @index
      col = @index % COLS
      row = (@index / COLS) % ROWS
      page = @index / PAGE_SIZE
      page_start = page * PAGE_SIZE
      page_count = [@species.length - page_start, PAGE_SIZE].min
      page_rows = [(page_count.to_f / COLS).ceil, 1].max

      if dx != 0
        new_col = col + dx
        if new_col < 0
          target = @index - 1
          target = [page_start + page_count - 1, @species.length - 1].min if target < page_start
          @index = target
        elsif new_col >= COLS || page_start + row * COLS + new_col >= page_start + page_count
          target = page_start + row * COLS
          target = page_start if target >= page_start + page_count
          @index = target
        else
          @index = page_start + row * COLS + new_col
        end
      elsif dy != 0
        new_row = row + dy
        if new_row < 0
          previous_page = page - 1
          if previous_page >= 0
            prev_start = previous_page * PAGE_SIZE
            prev_count = [@species.length - prev_start, PAGE_SIZE].min
            prev_rows = [(prev_count.to_f / COLS).ceil, 1].max
            target_row = prev_rows - 1
            target = prev_start + target_row * COLS + col
            target = prev_start + prev_count - 1 if target >= prev_start + prev_count
            @index = target
          else
            target_row = page_rows - 1
            target = page_start + target_row * COLS + col
            target = page_start + page_count - 1 if target >= page_start + page_count
            @index = target
          end
        elsif new_row >= page_rows || page_start + new_row * COLS + col >= page_start + page_count
          next_page = page + 1
          next_start = next_page * PAGE_SIZE
          if next_start < @species.length
            @index = [next_start + col, @species.length - 1].min
          else
            @index = [page_start + col, page_start + page_count - 1].min
          end
        else
          @index = page_start + new_row * COLS + col
        end
      end
      return if old == @index
      pbPlayCursorSE if defined?(pbPlayCursorSE)
      refresh
    end

    def selected_species
      return nil if @species.empty?
      return @species[@index]
    end

    def current_page_start
      return 0 if @species.empty?
      return (@index / PAGE_SIZE) * PAGE_SIZE
    end

    def current_page_number
      return 1 if @species.empty?
      return (@index / PAGE_SIZE) + 1
    end

    def total_pages
      return 1 if @species.empty?
      return (@species.length.to_f / PAGE_SIZE).ceil
    end

    #===========================================================================
    # Catálogo / orden
    #===========================================================================
    def build_order_maps
      @order_map.clear
      @display_number.clear
      if ResearchNotebook::Settings::DEX_ORDER == :GAME
        # La Pokédex activa la define el JSON editable (Data/SpeciesDex/config.json),
        # no un índice fijo del motor.
        if defined?(NuevaPokedex) && NuevaPokedex.respond_to?(:enabled_dexes) &&
           NuevaPokedex.respond_to?(:regional_species)
          dex_list = []
          NuevaPokedex.enabled_dexes.each do |region|
            dex_list.concat(NuevaPokedex.regional_species(region))
          end
          dex_list.uniq.each_with_index do |slot, i|
            id = catalog_slot_id(slot)
            @order_map[id] = i
            @display_number[id] = i + 1
            base = base_species(slot)
            @order_map[base] ||= i
            @display_number[base] ||= i + 1
          end
        end
      end
      ResearchNotebook::Repository.relevant_species.each do |species|
        next if @order_map.key?(species)
        n = national_number(species)
        @order_map[species] = 100_000 + n
        @display_number[species] ||= n
      end
    end

    def national_number(species)
      data = GameData::Species.try_get(species) rescue nil
      return data.id_number.to_i if data && data.respond_to?(:id_number)
      return 0
    end

    def dex_number(entry)
      base = ResearchNotebook::Repository.species_base_and_form(entry)[0]
      return (@display_number[catalog_slot_id(entry)] || @display_number[base] || national_number(base)).to_i
    end

    def source_species
      # El catálogo de la región habilitada ES la lista completa de la Libreta.
      # Las habilidades y formas especiales son atributos del slot, no filtros
      # que hagan desaparecer Pokémon del libro.
      catalog_admission_set.keys
    end

    # Admisiones de la Pokédex activa: slots del Data/SpeciesDex/config.json de
    # las dexes habilitadas. Misma lógica que la Libreta (regional_species +
    # form_shown?). Se construye una vez por escena: las dexes no cambian con la
    # Libreta abierta.
    def catalog_admission_set
      return @admission_set if @admission_set
      @admission_set = {}
      if defined?(NuevaPokedex) && NuevaPokedex.respond_to?(:enabled_dexes) &&
         NuevaPokedex.respond_to?(:regional_species)
        NuevaPokedex.enabled_dexes.each do |region|
          NuevaPokedex.regional_species(region).each { |slot| @admission_set[slot] = true }
        end
      end
      return @admission_set
    end

    def catalog_slot_id(entry)
      base, form = ResearchNotebook::Repository.species_base_and_form(entry)
      return form.to_i > 0 ? "#{base}_#{form}".to_sym : base.to_sym
    end

    def rebuild_species(preferred = nil)
      list = source_species
      if !ResearchNotebook::Settings::SHOW_UNOWNED_ENTRIES
        list.select! { |sp| species_identity_known?(sp) }
      end
      list.sort_by! { |sp| sort_key(sp) }
      @species = list
      if preferred && @species.include?(preferred)
        @index = @species.index(preferred)
      else
        @index = [[@index, 0].max, [@species.length - 1, 0].max].min
      end
      @species_generation += 1
      @grid_signature = nil
    end

    def sort_key(entry)
      # entry puede ser "ESPECIE" o "ESPECIE,FORMA"
      base, form = ResearchNotebook::Repository.species_base_and_form(entry)
      case @sort_mode
      when :NAME
        known = species_identity_known?(base)
        name = known ? ResearchNotebook::Repository.species_name(entry).downcase : "zzz"
        # Las formas van después de la especie base
        form_sort = form.to_i
        return [known ? 0 : 1, name, dex_number(entry), form_sort]
      when :STATUS
        return [-entry_completion(entry), @order_map[catalog_slot_id(entry)] || 999_999, base.to_s, form.to_i]
      else
        # :DEX - ordenar por número de Pokédex, luego por forma
        return [@order_map[catalog_slot_id(entry)] || @order_map[base] || 999_999, national_number(base), base.to_s, form.to_i]
      end
    end

    def base_species(entry)
      ResearchNotebook::Repository.species_base_and_form(entry)[0]
    end

    def entry_known?(entry)
      base = base_species(entry)
      return arcane_known?(base) if current_section == :arcane
      return golden_known?(base) if current_section == :golden
      return false
    end

    def species_identity_known?(entry)
      base, form = ResearchNotebook::Repository.species_base_and_form(entry)
      if defined?(NuevaPokedex) && NuevaPokedex.respond_to?(:slot_seen?)
        return true if NuevaPokedex.slot_seen?(catalog_slot_id(entry))
        return false if form.to_i > 0
      end
      return entry_known?(entry)
    end

    def arcane_known?(base)
      p = ResearchNotebook.progress
      return p.arcane_potential_known?(base) || p.arcane_seen?(base) || p.arcane_used?(base)
    end

    def golden_known?(base)
      p = ResearchNotebook.progress
      return p.golden_potential_known?(base) || p.golden_form_seen?(base) ||
             p.golden_form_used?(base) || p.golden_power_used?(base)
    end

    def entry_completion(entry)
      base = base_species(entry)
      if current_section == :arcane
        return 3 if ResearchNotebook.progress.arcane_used?(base)
        return 2 if ResearchNotebook.progress.arcane_seen?(base)
        return 1 if ResearchNotebook.progress.arcane_potential_known?(base)
        return 0
      end
      score = 0
      score += 1 if ResearchNotebook.progress.golden_potential_known?(base)
      score += 1 if ResearchNotebook.progress.golden_power_used?(base)
      score += 1 if ResearchNotebook.progress.golden_form_seen?(base)
      score += 1 if ResearchNotebook.progress.golden_form_used?(base)
      return score
    end

    #===========================================================================
    # Dibujo general
    #===========================================================================
    def draw_static
      bmp = @sprites["paper"].bitmap
      bmp.clear
      bmp.fill_rect(0, 0, WIDTH, HEIGHT, COVER)
      # El bloque visible de páginas coincide con el bloque usado por la tapa.
      # Así la animación revela la libreta que ya está debajo, no otra pantalla.
      bmp.fill_rect(BOOK_X - 2, BOOK_Y - 2, BOOK_W + 4, BOOK_H + 4, Color.new(18, 13, 11, 110))
      bmp.fill_rect(BOOK_X, BOOK_Y, BOOK_W, BOOK_H, PAPER)
      bmp.fill_rect(BOOK_X + 3, BOOK_Y + 3, BOOK_W - 6, BOOK_H - 6, PAPER_2)
      bmp.fill_rect(308, BOOK_Y, 2, BOOK_H, Color.new(156, 135, 100))
      bmp.fill_rect(310, BOOK_Y, 3, BOOK_H, Color.new(90, 72, 55, 65))
      bmp.fill_rect(313, BOOK_Y + 5, 1, BOOK_H - 10, Color.new(255, 255, 255, 70))
      y = 83
      while y < 420
        bmp.fill_rect(20, y, 278, 1, Color.new(214, 201, 171, 70))
        y += 31
      end
      bmp.fill_rect(0, 0, WIDTH, HEADER_H, COVER)
      bmp.fill_rect(0, FOOTER_Y, WIDTH, HEIGHT - FOOTER_Y, COVER)
      # Arte de cuaderno editable: 640x480, detrás de todos los datos.
      @skin.draw(bmp, :background, 0, 0) if @skin
      draw_text(bmp, 18, 10, 286, 30, _INTL("LIBRETA DE INVESTIGACIÓN"), 19, WHITE, 0, true)
    end

    def refresh
      rebuild_sections
      if @sections.empty?
        draw_empty_state
        return
      end
      rebuild_species if current_section && @species.empty? && !source_species.empty?
      draw_static
      bmp = @sprites["overlay"].bitmap
      bmp.clear
      draw_header(bmp)
      if @species.empty?
        hide_pokemon_sprite
        dispose_grid_icons
        draw_no_entries(bmp)
      else
        draw_focus_panel(bmp)
        if @detail_open
          set_grid_visible(false)
          draw_detail_panel(bmp)
        else
          draw_grid_panel(bmp)
          refresh_grid_icons
          set_grid_visible(true)
          sync_cursor
        end
      end
      draw_footer(bmp)
    end

    def draw_header(bmp)
      return if @sections.empty?
      x = 318
      @sections.each_with_index do |entry, i|
        label = entry[1]
        w = (306 / @sections.length.to_f).floor
        xx = x + i * w
        active = (i == @section_index)
        color = entry[0] == :arcane ? ARCANE : GOLDEN
        tab_key = entry[0] == :arcane ? :tab_arcane : :tab_golden
        tab_drawn = (@sections.length == 2 && @skin && @skin.draw(bmp, tab_key, xx, 8))
        bmp.fill_rect(xx, 8, w - 4, 37, active ? color : Color.new(87, 70, 55)) if !tab_drawn
        bmp.fill_rect(xx, 42, w - 4, 3, color) if active
        draw_text(bmp, xx + 4, 24, w - 12, 17, label, 12, WHITE, 1, true)
      end
      subtitle = current_section == :arcane ? _INTL("Notas sobre energía arcana") : _INTL("Notas sobre energía áurea")
      draw_text(bmp, 20, 38, 132, 15, subtitle, 10, Color.new(218, 205, 184), 0, false)
    end

    def draw_empty_state
      draw_static
      bmp = @sprites["overlay"].bitmap
      bmp.clear
      hide_pokemon_sprite
      dispose_grid_icons
      draw_text(bmp, 60, 180, WIDTH - 120, 30, _INTL("Estas páginas todavía están cerradas."), 19, INK, 1, true)
      draw_wrapped(bmp, 100, 220, WIDTH - 200,
        _INTL("Cuando descubras algo relacionado con estas energías, habrá un lugar para anotarlo aquí."),
        14, MUTED, 20, 4)
      draw_footer(bmp)
      @sprites["cursor"].visible = false
    end

    def draw_no_entries(bmp)
      @sprites["cursor"].visible = false
      color = section_color
      title = current_section == :arcane ? _INTL("Sin apuntes arcanos") : _INTL("Sin apuntes áureos")
      draw_text(bmp, 34, 142, 245, 28, title, 20, INK, 1, true)
      draw_wrapped(bmp, 42, 188, 228,
        _INTL("Aún no hay observaciones suficientes para llenar estas páginas."), 14, MUTED, 21, 4)
      bmp.fill_rect(GRID_X + 14, GRID_Y + 50, GRID_W - 28, 118, PAPER_2)
      draw_text(bmp, GRID_X + 24, GRID_Y + 78, GRID_W - 48, 25, _INTL("Quedan páginas por llenar…"), 16, color, 1, true)
    end

    def draw_focus_panel(bmp)
      entry = selected_species
      base, form = ResearchNotebook::Repository.species_base_and_form(entry)
      known = species_identity_known?(entry)
      color = section_color
      draw_card(bmp, FOCUS_X, FOCUS_Y, FOCUS_W, FOCUS_H, PAPER_2)
      @skin.draw(bmp, :focus_panel, FOCUS_X, FOCUS_Y) if @skin

      num = dex_number(entry)
      number = num > 0 ? format("#%03d", num) : "#---"
      name = known ? ResearchNotebook::Repository.species_name(entry) : "???"
      draw_text(bmp, FOCUS_X + 14, FOCUS_Y + 10, 62, 20, number, 12, MUTED, 0, true)
      draw_text(bmp, FOCUS_X + 72, FOCUS_Y + 7, FOCUS_W - 88, 28, name, 21, INK, 0, true)

      # Determinar la forma a mostrar
      display_form = form
      silhouette = !known
      if current_section == :golden && ResearchNotebook::Repository.golden_form_configured?(entry)
        golden_form_idx = ResearchNotebook::Repository.golden_form_index(entry)
        if golden_form_idx
          display_form = golden_form_idx
          # Las formas descubiertas se revelan; no las formas secretas.
          revealed = ResearchNotebook.progress.golden_form_seen?(base) ||
                     ResearchNotebook.progress.golden_form_used?(base)
          silhouette = !revealed
        end
      end
      # Una forma áurea pendiente debe mostrar su propia silueta, nunca la forma base.
      custom_golden = current_section == :golden &&
                      ResearchNotebook::Repository.golden_form_sprite_path(entry)
      if custom_golden
        show_custom_golden_silhouette(base, custom_golden, FOCUS_X + FOCUS_W / 2, FOCUS_Y + 161, 214, 200, silhouette)
      else
        show_pokemon(base, display_form, silhouette, FOCUS_X + FOCUS_W / 2, FOCUS_Y + 161, 214, 200)
      end
      if current_section == :golden && display_form.to_i > 0 &&
         ResearchNotebook::Repository.golden_form_index(entry) == display_form.to_i &&
         !custom_golden && !silhouette
        asset = "Graphics/Pokemon/Front/#{base}_#{display_form}"
        found = (pbResolveBitmap(asset) rescue nil) if defined?(pbResolveBitmap)
        if !found
          @sprites["pokemon"].color = Color.new(215, 172, 52, 70) if @sprites["pokemon"]
          draw_text(bmp, FOCUS_X + 16, FOCUS_Y + 222, FOCUS_W - 32, 16,
                    _INTL("Arte de forma pendiente"), 10, RED, 1, true)
        end
      end

      # Suelo/halo bajo el Pokémon, más cercano al tratamiento de MegaDex.
      bmp.fill_rect(FOCUS_X + 54, FOCUS_Y + 247, FOCUS_W - 108, 2, Color.new(color.red, color.green, color.blue, 100))
      draw_ring(bmp, FOCUS_X + FOCUS_W / 2, FOCUS_Y + 248, 67, Color.new(color.red, color.green, color.blue, 95))
      draw_ring(bmp, FOCUS_X + FOCUS_W / 2, FOCUS_Y + 248, 49, Color.new(color.red, color.green, color.blue, 65))

      if current_section == :arcane
        draw_arcane_focus_info(bmp, base)
      else
        draw_golden_focus_info(bmp, entry)
        if ResearchNotebook::Repository.golden_form_configured?(entry) &&
           ResearchNotebook::Repository.golden_form_index(entry).nil? &&
           species_identity_known?(entry)
          draw_text(bmp, FOCUS_X + 50, FOCUS_Y + 228, FOCUS_W - 100, 17,
                    _INTL("FORMA SIN DESTINO"), 10, RED, 1, true)
        end
      end
    end

    def draw_arcane_focus_info(bmp, base)
      y = FOCUS_Y + 268
      unlocked = ResearchNotebook.progress.arcane_seen?(base)
      used = ResearchNotebook.progress.arcane_used?(base)
      potential = ResearchNotebook.progress.arcane_potential_known?(base)
      ability = notebook_arcane_ability(base)
      draw_text(bmp, FOCUS_X + 18, y, FOCUS_W - 36, 16, _INTL("HABILIDAD ARCANA"), 10, ARCANE_2, 0, true)
      name = unlocked ? ResearchNotebook::Repository.ability_name(ability) : "????"
      draw_text(bmp, FOCUS_X + 18, y + 17, FOCUS_W - 36, 26, name, 17, INK, 0, true)
      draw_text(bmp, FOCUS_X + 18, y + 54, 70, 15, _INTL("TIPOS"), 9, MUTED, 0, true)
      draw_type_icons(bmp, ResearchNotebook::Repository.normal_types(base), FOCUS_X + 18, y + 71, 68, 23)
      status = used ? _INTL("PROBADA") : (unlocked ? _INTL("DESPERTADA") : (potential ? _INTL("POR DESPERTAR") : _INTL("SIN OBSERVAR")))
      draw_text(bmp, FOCUS_X + 166, y + 54, 104, 15, _INTL("ESTADO"), 9, MUTED, 0, true)
      draw_status_chip(bmp, FOCUS_X + 166, y + 71, 104, 23, status, ARCANE)
    end

    def draw_golden_focus_info(bmp, entry)
      base = base_species(entry)
      y = FOCUS_Y + 268
      potential = ResearchNotebook.progress.golden_potential_known?(base)
      form_seen = ResearchNotebook.progress.golden_form_seen?(base)
      form_used = ResearchNotebook.progress.golden_form_used?(base)
      form_known = form_seen || form_used
      # Primera fila: los tipos REALES de la forma, no el tipo de su Poder Dorado.
      draw_text(bmp, FOCUS_X + 18, y, FOCUS_W - 36, 16,
                _INTL("TIPOS · FORMA DORADA"), 10, GOLDEN_2, 0, true)
      if form_known && ResearchNotebook::Repository.golden_form_configured?(entry)
        draw_type_icons(bmp, ResearchNotebook::Repository.golden_form_types(entry),
                        FOCUS_X + 18, y + 19, 77, 23)
      else
        draw_text(bmp, FOCUS_X + 18, y + 19, 145, 23, "????", 14, MUTED, 0, true)
      end
      # Segunda fila: la afinidad es una propiedad distinta de la forma.
      draw_text(bmp, FOCUS_X + 18, y + 55, 140, 15, _INTL("AFINIDAD ÁUREA"), 9, MUTED, 0, true)
      gtype = ResearchNotebook::Repository.golden_type(entry)
      if potential && ResearchNotebook.progress.golden_type_known?(base) && gtype
        draw_type_icons(bmp, [gtype], FOCUS_X + 18, y + 72, 78, 23)
      else
        draw_text(bmp, FOCUS_X + 18, y + 72, 74, 23, "????", 13, MUTED, 0, true)
      end
      draw_text(bmp, FOCUS_X + 170, y + 55, 104, 15, _INTL("ESTADO FORMA"), 9, MUTED, 0, true)
      status = if !ResearchNotebook::Repository.golden_form_configured?(entry)
                 _INTL("NO POSEE")
               elsif form_used
                 _INTL("UTILIZADA")
               elsif form_seen
                 _INTL("OBSERVADA")
               elsif potential
                 _INTL("POR VER")
               else
                 _INTL("SIN OBSERVAR")
               end
      draw_status_chip(bmp, FOCUS_X + 166, y + 72, 104, 23, status, GOLDEN)
    end

    def draw_grid_panel(bmp)
      color = section_color
      @skin.draw(bmp, :grid_panel, GRID_X, GRID_Y) if @skin
      bmp.fill_rect(GRID_X, 59, GRID_W, 1, Color.new(255, 255, 255, 45))
      draw_text(bmp, GRID_X + 3, 59, 134, 18, _INTL("Especies: {1}", @species.length), 11, MUTED, 0, false)
      draw_text(bmp, GRID_X + 138, 59, 103, 18, _INTL("Orden: {1}", _INTL(SORT_LABELS[@sort_mode] || @sort_mode.to_s)), 11, INK, 1, true)
      draw_text(bmp, GRID_X + 242, 59, 62, 18, _INTL("{1}/{2}", current_page_number, total_pages), 11, color, 2, true)

      page_start = current_page_start
      PAGE_SIZE.times do |slot|
        idx = page_start + slot
        col = slot % COLS
        row = slot / COLS
        x = GRID_X + 5 + col * (CELL_W + GRID_GAP_X)
        y = GRID_Y + row * (CELL_H + GRID_GAP_Y)
        draw_grid_cell(bmp, x, y, idx, idx == @index)
      end
      @sprites["cursor"].visible = true
    end

    def draw_grid_cell(bmp, x, y, idx, selected)
      if idx >= @species.length
        bmp.fill_rect(x, y, CELL_W, CELL_H, Color.new(218, 206, 180, 90))
        bmp.fill_rect(x + 4, y + 4, CELL_W - 8, CELL_H - 8, Color.new(244, 238, 220, 80))
        return
      end
      species = @species[idx]
      known = species_identity_known?(species)
      fill = selected ? Color.new(section_color.red, section_color.green, section_color.blue, 70) : PAPER_2
      asset = selected ? :grid_cell_selected : :grid_cell
      unless @skin && @skin.draw(bmp, asset, x, y)
        bmp.fill_rect(x, y, CELL_W, CELL_H, Color.new(154, 135, 103, 110))
        bmp.fill_rect(x + 1, y + 1, CELL_W - 2, CELL_H - 2, fill)
      end
      num = dex_number(species)
      label = known ? (num > 0 ? format("%03d", num) : "---") : "???"
      draw_text(bmp, x + 3, y + 2, CELL_W - 6, 14, label, 8, known ? MUTED : Color.new(150, 142, 127), 0, true)
      state_color = entry_completion(species) > 0 ? section_color : Color.new(170, 158, 134)
      bmp.fill_rect(x + 5, y + CELL_H - 8, CELL_W - 10, 3, state_color)
      if entry_completion(species) > 0
        bmp.fill_rect(x + CELL_W - 11, y + 5, 5, 5, state_color)
      end
    end

    #===========================================================================
    # Fichas
    #===========================================================================
    def draw_detail_panel(bmp)
      @sprites["cursor"].visible = false
      x = GRID_X
      y = 61
      w = GRID_W
      h = 365
      draw_card(bmp, x, y, w, h, PAPER_2)
      @skin.draw(bmp, :detail_panel, x, y) if @skin
      color = section_color
      bmp.fill_rect(x, y, 4, h, color)
      entry = selected_species
      base, form = ResearchNotebook::Repository.species_base_and_form(entry)
      if current_section == :arcane
        draw_arcane_detail(bmp, base, x + 14, y + 12, w - 28, h - 24)
      else
        draw_golden_detail(bmp, base, x + 14, y + 12, w - 28, h - 24)
      end
    end

    def draw_arcane_detail(bmp, base, x, y, w, h)
      unlocked = ResearchNotebook.progress.arcane_seen?(base)
      used = ResearchNotebook.progress.arcane_used?(base)
      potential = ResearchNotebook.progress.arcane_potential_known?(base)
      ability = notebook_arcane_ability(base)
      draw_text(bmp, x, y, w, 25, _INTL("Habilidad Arcana"), 18, ARCANE_2, 0, true)
      state = used ? _INTL("PROBADA") : (unlocked ? _INTL("DESPERTADA") : _INTL("BLOQUEADA"))
      draw_status_chip(bmp, x + w - 106, y + 2, 106, 21, state, ARCANE)
      draw_text(bmp, x, y + 34, w, 17, _INTL("HABILIDAD"), 10, MUTED, 0, true)
      name = unlocked ? ResearchNotebook::Repository.ability_name(ability) : "????"
      draw_text(bmp, x, y + 50, w, 27, name, 18, INK, 0, true)
      draw_text(bmp, x, y + 84, w, 16, _INTL("APUNTE"), 10, ARCANE_2, 0, true)
      draw_card(bmp, x, y + 101, w, 104, PAPER)
      if unlocked
        desc = ResearchNotebook::Repository.ability_description(ability).to_s
        desc = _INTL("Aún me falta describir con precisión cómo se manifiesta esta habilidad.") if desc.empty?
      elsif potential
        desc = _INTL("He detectado una resonancia arcana en esta especie, pero todavía no he logrado despertar ni identificar su habilidad.")
      else
        desc = _INTL("No he observado todavía ninguna manifestación arcana en esta especie.")
      end
      draw_wrapped(bmp, x + 10, y + 113, w - 20, desc, 13, unlocked ? INK : MUTED, 18, 4)
      draw_text(bmp, x, y + 218, w, 16, _INTL("DESPERTAR"), 10, ARCANE_2, 0, true)
      half = (w - 7) / 2
      draw_card(bmp, x, y + 236, half, 33, PAPER)
      draw_card(bmp, x + half + 7, y + 236, half, 33, PAPER)
      draw_text(bmp, x + 5, y + 243, half - 10, 19, unlocked ? _INTL("Identificada") : _INTL("Pendiente"), 10, unlocked ? INK : MUTED, 1, true)
      draw_text(bmp, x + half + 12, y + 243, half - 10, 19, used ? _INTL("Probada") : _INTL("Sin probar"), 10, used ? INK : MUTED, 1, true)
      draw_text(bmp, x, y + 281, w, 16, _INTL("CATALIZADOR"), 10, ARCANE_2, 0, true)
      draw_item_card(bmp, x, y + 299, w, 40, ResearchNotebook::Settings::ARCANE_TEA_ITEM, ARCANE, _INTL("Té Arcano"))
      draw_changedex_note(bmp, base, x, y + 348, w)
    end

    def draw_golden_detail(bmp, base, x, y, w, h)
      entry = selected_species
      if @detail_page == 0 || !ResearchNotebook::Repository.golden_form_configured?(entry)
        draw_golden_power_detail(bmp, base, x, y, w, h)
      elsif @detail_page == 1
        draw_golden_form_detail(bmp, entry, x, y, w, h)
      else
        draw_golden_moves_detail(bmp, entry, x, y, w, h)
      end
    end

    def draw_golden_moves_detail(bmp, entry, x, y, w, h)
      base = base_species(entry)
      used = ResearchNotebook.progress.golden_form_used?(base)
      moves = golden_move_records(entry)
      page = [@detail_page - 2, 0].max
      total = [(moves.length.to_f / 4).ceil, 1].max
      draw_text(bmp, x, y, w - 72, 24, _INTL("Técnicas doradas"), 17, GOLDEN_2, 0, true)
      draw_text(bmp, x + w - 66, y + 3, 66, 18,
                _INTL("{1}/{2}", page + 1, total), 11, MUTED, 2, true)
      unless used
        draw_wrapped(bmp, x + 3, y + 43, w - 6,
          _INTL("Registra la Forma Dorada en combate para identificar los movimientos requeridos y sus versiones resultantes."),
          12, MUTED, 20, 6)
        return
      end
      moves[page * 4, 4].to_a.each_with_index do |move, i|
        yy = y + 40 + i * 72
        draw_card(bmp, x, yy, w, 68, PAPER)
        move_data = nil
        begin
          move_data = GameData::Move.try_get(move[:move]) if defined?(GameData::Move)
        rescue StandardError
        end
        required = move_data && move_data.respond_to?(:name) ? move_data.name : move[:move].to_s
        result = move[:name].to_s.empty? ? required : move[:name]
        draw_text(bmp, x + 8, yy + 4, w - 16, 17,
                  _INTL("MOVIMIENTO BASE: {1}", required), 11, MUTED, 0, false)
        draw_text(bmp, x + 8, yy + 22, w - 16, 23,
                  _INTL("RESULTANTE: {1}", result), 14, INK, 0, true)
        type = move[:type] && (GameData::Type.get(move[:type]).name rescue move[:type].to_s)
        info = [type, move[:power] ? _INTL("Pot. {1}", move[:power]) : nil,
                move[:accuracy] ? _INTL("Prec. {1}", move[:accuracy]) : nil].compact.join("  ·  ")
        draw_text(bmp, x + 8, yy + 46, w - 16, 16, info, 10, GOLDEN_2, 0, false)
      end
    end

    def draw_golden_power_detail(bmp, base, x, y, w, h)
      potential = ResearchNotebook.progress.golden_potential_known?(base)
      power_used = ResearchNotebook.progress.golden_power_used?(base)
      draw_text(bmp, x, y, w, 25, _INTL("Poder Dorado"), 18, GOLDEN_2, 0, true)
      state = power_used ? _INTL("UTILIZADO") : (potential ? _INTL("IDENTIFICADO") : _INTL("SIN OBSERVAR"))
      draw_status_chip(bmp, x + w - 108, y + 2, 108, 21, state, GOLDEN)
      draw_text(bmp, x, y + 34, w, 16, _INTL("TIPOS NATURALES"), 10, MUTED, 0, true)
      draw_type_icons(bmp, ResearchNotebook::Repository.normal_types(base), x, y + 51, 68, 23)
      draw_text(bmp, x, y + 81, w, 16, _INTL("AFINIDAD ÁUREA"), 10, GOLDEN_2, 0, true)
      gtype = ResearchNotebook::Repository.golden_type(base)
      if potential && ResearchNotebook.progress.golden_type_known?(base) && gtype
        draw_type_icons(bmp, [gtype], x, y + 98, 68, 23)
      else
        draw_text(bmp, x, y + 98, 74, 23, "????", 16, MUTED, 0, true)
      end
      draw_text(bmp, x, y + 132, w, 16, _INTL("APUNTE"), 10, GOLDEN_2, 0, true)
      draw_card(bmp, x, y + 149, w, 92, PAPER)
      desc = ResearchNotebook::Repository.golden_power_description(base).to_s
      if desc.empty?
        desc = potential ? _INTL("El Fragmento Dorado reacciona con esta afinidad y permite manifestarla durante el combate sin alterar la forma del Pokémon.") : _INTL("Todavía no he logrado identificar la afinidad áurea de esta especie.")
      end
      draw_wrapped(bmp, x + 10, y + 160, w - 20, desc, 13, potential ? INK : MUTED, 18, 4)
      draw_text(bmp, x, y + 252, w, 16, _INTL("CATALIZADOR"), 10, GOLDEN_2, 0, true)
      draw_item_card(bmp, x, y + 270, w, 43, ResearchNotebook::Settings::GOLDEN_FRAGMENT_ITEM, GOLDEN, _INTL("Fragmento Dorado"))
      if ResearchNotebook::Repository.golden_form_configured?(selected_species)
        draw_text(bmp, x, y + 321, w, 17, _INTL("← Poder        Forma →"), 10, GOLDEN_2, 1, true)
      end
    end

    def draw_golden_form_detail(bmp, entry, x, y, w, h)
      base = base_species(entry)
      seen = ResearchNotebook.progress.golden_form_seen?(base)
      used = ResearchNotebook.progress.golden_form_used?(base)
      reveal_details = used || !ResearchNotebook::Settings::GOLDEN_DETAILS_REQUIRE_USE
      draw_text(bmp, x, y, w, 25, _INTL("Forma Dorada"), 18, GOLDEN_2, 0, true)
      state = used ? _INTL("UTILIZADA") : (seen ? _INTL("OBSERVADA") : _INTL("POR VER"))
      draw_status_chip(bmp, x + w - 104, y + 2, 104, 21, state, GOLDEN)
      draw_text(bmp, x, y + 34, w, 16, _INTL("TIPOS DE LA FORMA DORADA"), 10, MUTED, 0, true)
      if reveal_details
        draw_type_icons(bmp, ResearchNotebook::Repository.golden_form_types(entry), x, y + 51, 68, 23)
      else
        draw_text(bmp, x, y + 51, 138, 23, "????", 16, MUTED, 0, true)
      end
      draw_text(bmp, x, y + 81, w, 16, _INTL("HABILIDAD"), 10, MUTED, 0, true)
      ability = reveal_details ? ResearchNotebook::Repository.golden_ability(entry) : nil
      draw_text(bmp, x, y + 97, w, 25, reveal_details ? ResearchNotebook::Repository.ability_name(ability) : "????", 16, INK, 0, true)
      draw_text(bmp, x, y + 128, w, 16, _INTL("ESTADÍSTICAS · BASE / DORADA"), 10, GOLDEN_2, 0, true)
      if reveal_details
        stats = ResearchNotebook::Repository.golden_stats(entry)
        form_index = ResearchNotebook::Repository.golden_form_index(entry) || 0
        stats ||= ResearchNotebook::Repository.base_stats(base, form_index)
        base_stats = ResearchNotebook::Repository.base_stats(base, 0)
        draw_stat_panel(bmp, x, y + 145, w, 92, stats, base_stats, GOLDEN)
      else
        draw_card(bmp, x, y + 145, w, 92, PAPER)
        draw_text(bmp, x + 10, y + 154, w - 20, 15, _INTL("APUNTE"), 9, GOLDEN_2, 0, true)
        text = seen ? _INTL("He observado esta Forma Dorada, pero aún necesito verla en acción para completar sus características.") : _INTL("Sé que esta forma puede manifestarse, pero todavía no he logrado observarla directamente.")
        draw_wrapped(bmp, x + 10, y + 174, w - 20, text, 13, MUTED, 18, 3)
      end
      draw_text(bmp, x, y + 247, w, 15, _INTL("COSTE"), 10, RED, 0, true)
      draw_wrapped(bmp, x, y + 264, w, ResearchNotebook::Repository.golden_form_drain_text, 10, RED, 16, 2)
      draw_text(bmp, x, y + 300, w, 15, _INTL("CATALIZADORES"), 10, GOLDEN_2, 0, true)
      draw_item_pair(bmp, x, y + 317, w, ResearchNotebook::Settings::GOLDEN_STONE_ITEM, ResearchNotebook::Settings::GOLDEN_RING_ITEM)
    end

    #===========================================================================
    # Sprites de Pokémon / cuadrícula
    #===========================================================================
    def split_species_form(value, fallback_form = 0)
      # Compartir el mismo parser de slots con la Pokédex y el repositorio:
      # RATTATA_1, RATTATA,1 y formas base deben producir el mismo par.
      base, form = ResearchNotebook::Repository.species_base_and_form(value)
      return [base, (form.to_i > 0 ? form.to_i : fallback_form.to_i)]
    rescue StandardError
      return [value, fallback_form.to_i]
    end

    def show_pokemon(species, form = 0, silhouette = false, x = 160, y = 210, max_w = 214, max_h = 200)
      sprite = @sprites["pokemon"]
      return if !sprite
      species, embedded_form = split_species_form(species, form)
      form = embedded_form if form.to_i == 0 && embedded_form.to_i != 0
      signature = [species, form.to_i, silhouette, x, y, max_w, max_h]
      if @focus_signature == signature && sprite.visible
        return
      end
      begin
        pkmn = Pokemon.new(species, 5)
        if pkmn.respond_to?(:form_simple=)
          pkmn.form_simple = form.to_i
        elsif pkmn.respond_to?(:form=)
          pkmn.form = form.to_i
        end
        sprite.setPokemonBitmap(pkmn)
        sprite.visible = true
        sprite.x = x
        sprite.y = y
        if sprite.bitmap && !sprite.bitmap.disposed?
          sprite.ox = sprite.bitmap.width / 2
          sprite.oy = sprite.bitmap.height / 2
          scale = [max_w.to_f / sprite.bitmap.width, max_h.to_f / sprite.bitmap.height, 1.0].min
          sprite.zoom_x = scale
          sprite.zoom_y = scale
          @pokemon_base_zoom_x = scale
          @pokemon_base_zoom_y = scale
        end
        sprite.color = silhouette ? Color.new(0, 0, 0, 255) : Color.new(0, 0, 0, 0)
        @focus_signature = signature
      rescue => e
        sprite.visible = false
        @focus_signature = nil
        ResearchNotebook::Repository.log("Sprite focal #{species}/#{form}: #{e.message}")
      end
    end

    def show_custom_golden_silhouette(species, path, x, y, max_w, max_h, silhouette = true)
      sprite = @sprites["pokemon"]
      return show_pokemon(species, ResearchNotebook::Repository.golden_form_index(species) || 0, true, x, y, max_w, max_h) if !sprite
      begin
        if @golden_custom_path != path || !@golden_custom_bitmap || @golden_custom_bitmap.disposed?
          @golden_custom_bitmap.dispose if @golden_custom_bitmap && @golden_custom_bitmap.respond_to?(:dispose)
          @golden_custom_bitmap = AnimatedBitmap.new(path)
          @golden_custom_path = path
        end
        bitmap = @golden_custom_bitmap.bitmap
        raise "bitmap vacío" if !bitmap || bitmap.width <= 0 || bitmap.height <= 0
        sprite.bitmap = bitmap if sprite.respond_to?(:bitmap=)
        sprite.visible = true
        sprite.x = x
        sprite.y = y
        sprite.ox = bitmap.width / 2
        sprite.oy = bitmap.height / 2
        frame_h = bitmap.height
        frame_w = bitmap.width >= frame_h * 2 ? frame_h : bitmap.width
        sprite.src_rect = Rect.new(0, 0, frame_w, frame_h) if sprite.respond_to?(:src_rect=)
        scale = [max_w.to_f / frame_w, max_h.to_f / frame_h, 1.0].min
        sprite.zoom_x = scale
        sprite.zoom_y = scale
        sprite.color = silhouette ? Color.new(0, 0, 0, 255) : Color.new(0, 0, 0, 0)
        @pokemon_base_zoom_x = scale
        @pokemon_base_zoom_y = scale
        @focus_signature = [species, :custom_golden, path, silhouette, x, y, max_w, max_h]
      rescue => e
        ResearchNotebook::Repository.log("Silueta áurea custom #{species}: #{e.message}")
        show_pokemon(species, ResearchNotebook::Repository.golden_form_index(species) || 0, true, x, y, max_w, max_h)
      end
    end

    def hide_pokemon_sprite
      if @sprites["pokemon"]
        @sprites["pokemon"].visible = false
        @focus_signature = nil
      end
    end

    def dispose_grid_icons
      canvas = @sprites["grid_icons"]
      canvas.bitmap.clear if canvas && canvas.respond_to?(:bitmap) && canvas.bitmap
      @grid_signature = nil
      @pending_grid_icons = []
    end

    # Las variantes tienen iconos individuales, p. ej. RATTATA_1.png.
    # Evitamos la resolución de Essentials que a veces retorna la forma base
    # incluso si el icono alterno es distinto.
    def grid_icon_filename(_pkmn, species, form = 0)
      paths = []
      if form.to_i > 0
        paths << "Graphics/Pokemon/Icons/#{species}_#{form.to_i}"
        paths << "Graphics/Pokemon/Icons/#{species.to_s.downcase}_#{form.to_i}"
      else
        paths << "Graphics/Pokemon/Icons/#{species}"
        paths << "Graphics/Pokemon/Icons/#{species.to_s.downcase}"
      end
      paths.each do |path|
        resolved = (pbResolveBitmap(path) rescue nil) if defined?(pbResolveBitmap)
        return resolved if resolved
      end
      return nil if form.to_i > 0   # Jamás sustituir forma regional por icono base
      return GameData::Species.icon_filename(species, 0, 0, false, false) if
        defined?(GameData::Species) && GameData::Species.respond_to?(:icon_filename)
      nil
    end

    def draw_species_icon_to_grid(canvas, species, slot)
      col = slot % COLS
      row = slot / COLS
      cell_x = GRID_X + 5 + col * (CELL_W + GRID_GAP_X)
      cell_y = GRID_Y + row * (CELL_H + GRID_GAP_Y)
      unless species_identity_known?(species)
        draw_text(canvas, cell_x + 9, cell_y + 19, CELL_W - 18, 30, "?", 20, MUTED, 1, true)
        return
      end
      base, form = split_species_form(species, 0)
      if current_section == :golden && form.to_i <= 0 &&
         (ResearchNotebook.progress.golden_form_seen?(base) ||
          ResearchNotebook.progress.golden_form_used?(base))
        form = ResearchNotebook::Repository.golden_form_index(species) || form
      end
      filename = grid_icon_filename(nil, base, form)
      unless filename
        draw_text(canvas, cell_x + 9, cell_y + 20, CELL_W - 18, 27, "?", 18, MUTED, 1, true)
        return
      end
      icon = nil
      begin
        icon = Bitmap.new(filename)
        if icon && icon.width > 0 && icon.height > 0
          # Los iconos de Essentials son spritesheets horizontales de 2 frames.
          frame_w = (icon.width >= icon.height * 2) ? icon.width / 2 : icon.width
          frame_h = icon.height
          scale = [48.0 / frame_w, 43.0 / frame_h, 1.0].min
          dw = [(frame_w * scale).round, 1].max
          dh = [(frame_h * scale).round, 1].max
          dest = Rect.new(cell_x + (CELL_W - dw) / 2,
                          cell_y + 15 + (43 - dh) / 2, dw, dh)
          canvas.stretch_blt(dest, icon, Rect.new(0, 0, frame_w, frame_h))
        end
      rescue StandardError => e
        ResearchNotebook::Repository.log("Icono #{species}: #{e.message}")
      ensure
        icon.dispose if icon && !icon.disposed?
      end
    end

    def refresh_grid_icons
      return if @detail_open
      signature = [current_section, @sort_mode, current_page_start, @species_generation]
      return if @grid_signature == signature
      canvas_sprite = @sprites["grid_icons"]
      return unless canvas_sprite && canvas_sprite.bitmap
      canvas_sprite.bitmap.clear
      @grid_signature = signature
      @pending_grid_icons = []
      page_start = current_page_start
      PAGE_SIZE.times do |slot|
        index = page_start + slot
        @pending_grid_icons << [@species[index], slot] if index < @species.length
      end
    end

    def render_next_grid_icons(count = 2)
      return if @detail_open || !@pending_grid_icons || @pending_grid_icons.empty?
      canvas_sprite = @sprites["grid_icons"]
      return unless canvas_sprite && canvas_sprite.bitmap
      count.times do
        item = @pending_grid_icons.shift
        break unless item
        draw_species_icon_to_grid(canvas_sprite.bitmap, item[0], item[1])
      end
    end

    def set_grid_visible(value)
      @sprites["grid_icons"].visible = value if @sprites["grid_icons"]
      @sprites["cursor"].visible = value && !@species.empty?
    end

    def sync_cursor
      return if @species.empty?
      slot = @index - current_page_start
      col = slot % COLS
      row = slot / COLS
      @sprites["cursor"].x = GRID_X + 5 + col * (CELL_W + GRID_GAP_X)
      @sprites["cursor"].y = GRID_Y + row * (CELL_H + GRID_GAP_Y)
      @sprites["cursor"].visible = !@detail_open
    end

    def build_cursor_bitmap
      bmp = @sprites["cursor"].bitmap
      bmp.clear
      color = Color.new(255, 255, 255, 210)
      bmp.fill_rect(0, 0, CELL_W, 2, color)
      bmp.fill_rect(0, CELL_H - 2, CELL_W, 2, color)
      bmp.fill_rect(0, 0, 2, CELL_H, color)
      bmp.fill_rect(CELL_W - 2, 0, 2, CELL_H, color)
      bmp.fill_rect(3, 3, CELL_W - 6, CELL_H - 6, Color.new(255, 255, 255, 22))
    end

    #===========================================================================
    # Tipos: usa Graphics/UI/types del proyecto
    #===========================================================================
    def resolve_type_sheet
      return if @type_sheet
      ResearchNotebook::Settings::TYPE_SHEET_CANDIDATES.each do |candidate|
        path = nil
        begin
          path = pbResolveBitmap(candidate) if defined?(pbResolveBitmap)
        rescue
        end
        next if !path
        begin
          @type_sheet = AnimatedBitmap.new(candidate)
          @type_sheet_path = candidate
          break
        rescue
          @type_sheet = nil
        end
      end
      calculate_type_sheet_metrics
    end

    def calculate_type_sheet_metrics
      return if !@type_sheet || !@type_sheet.bitmap
      max_pos = -1
      begin
        GameData::Type.each do |type|
          next if !type.respond_to?(:icon_position)
          max_pos = [max_pos, type.icon_position.to_i].max
        end
      rescue
      end
      @type_icon_count = [max_pos + 1, 1].max
      h = @type_sheet.bitmap.height
      @type_frame_h = h / @type_icon_count
      @type_frame_h = 28 if @type_frame_h <= 0
    end

    def draw_type_icons(bmp, types, x, y, target_w = 68, target_h = 25)
      values = Array(types).compact.first(2)
      if values.empty?
        draw_text(bmp, x, y, target_w, target_h, "—", 12, MUTED, 1, false)
        return
      end
      values.each_with_index do |type, i|
        xx = x + i * (target_w + 5)
        # No reducir un spritesheet de pictogramas 96x32 a símbolos minúsculos:
        # el nombre del tipo debe ser comprensible a resolución 640x480.
        bg = Color.new(96, 80, 55)
        bmp.fill_rect(xx, y, target_w, target_h, bg)
        bmp.fill_rect(xx, y + target_h - 2, target_w, 2, section_color)
        name = ResearchNotebook::Repository.type_name(type).to_s.upcase
        draw_text(bmp, xx + 3, y + 2, target_w - 6, target_h - 4, name, 11, WHITE, 1, true)
      end
    end

    #===========================================================================
    # Gamefeel / transiciones
    #===========================================================================
    def notebook_content_keys
      return ["paper", "overlay", "grid_icons", "cursor", "pokemon"]
    end

    def remember_content_visibility
      @content_visibility = {}
      notebook_content_keys.each do |key|
        sprite = @sprites[key]
        @content_visibility[key] = sprite ? sprite.visible : false
      end
    end

    def set_notebook_content_visible(value)
      notebook_content_keys.each do |key|
        sprite = @sprites[key]
        sprite.visible = value if sprite
      end
    end

    def restore_content_visibility
      notebook_content_keys.each do |key|
        sprite = @sprites[key]
        next if !sprite
        sprite.visible = @content_visibility ? !!@content_visibility[key] : true
      end
    end

    def create_cover_sprites
      @sprites["book_shadow"] = BitmapSprite.new(BOOK_W + 10, BOOK_H + 10, @viewport)
      shadow = @sprites["book_shadow"]
      shadow.z = 87
      shadow.x = BOOK_X + 5
      shadow.y = BOOK_Y + 6
      shadow.bitmap.fill_rect(0, 0, BOOK_W + 10, BOOK_H + 10, Color.new(0, 0, 0, 135))

      @sprites["book_pages"] = BitmapSprite.new(BOOK_W, BOOK_H, @viewport)
      pages = @sprites["book_pages"]
      pages.z = 88
      pages.x = BOOK_X
      pages.y = BOOK_Y
      pages.bitmap.fill_rect(0, 0, BOOK_W, BOOK_H, PAPER_DARK)
      pages.bitmap.fill_rect(4, 4, BOOK_W - 8, BOOK_H - 8, PAPER_2)
      spine = 307
      pages.bitmap.fill_rect(spine, 4, 2, BOOK_H - 8, Color.new(145, 124, 92, 150))
      pages.bitmap.fill_rect(spine + 2, 5, 2, BOOK_H - 10, Color.new(255, 255, 255, 60))
      @skin.draw(pages.bitmap, :pages, 0, 0) if @skin
      4.times { |i| pages.bitmap.fill_rect(BOOK_W - 10 + i * 2, 8, 1, BOOK_H - 16, Color.new(170, 150, 118, 100)) }

      @sprites["front_cover"] = BitmapSprite.new(BOOK_W, BOOK_H, @viewport)
      cover = @sprites["front_cover"]
      cover.z = 90
      cover.x = BOOK_X
      cover.y = BOOK_Y
      cover.ox = 0
      cover.zoom_x = 1.0
      pbSetSystemFont(cover.bitmap) if defined?(pbSetSystemFont)
      bmp = cover.bitmap
      bmp.fill_rect(0, 0, BOOK_W, BOOK_H, COVER)
      bmp.fill_rect(7, 7, BOOK_W - 14, BOOK_H - 14, COVER_2)
      bmp.fill_rect(13, 13, 22, BOOK_H - 26, Color.new(35, 24, 21))
      bmp.fill_rect(39, 18, 2, BOOK_H - 36, Color.new(132, 96, 60, 150))
      label_w = 270
      label_x = (BOOK_W - label_w) / 2
      bmp.fill_rect(label_x, 94, label_w, 122, Color.new(50, 36, 28))
      bmp.fill_rect(label_x + 6, 100, label_w - 12, 110, Color.new(91, 66, 43))
      @skin.draw(bmp, :cover, 0, 0) if @skin
      draw_text(bmp, label_x + 16, 118, label_w - 32, 34, _INTL("LIBRETA"), 25, WHITE, 1, true)
      draw_text(bmp, label_x + 16, 153, label_w - 32, 28, _INTL("DE INVESTIGACIÓN"), 15, WHITE, 1, true)
      draw_ring(bmp, BOOK_W / 2, 265, 54, Color.new(216, 190, 126, 125))
      draw_ring(bmp, BOOK_W / 2, 265, 36, Color.new(216, 190, 126, 80))
      draw_text(bmp, label_x + 16, BOOK_H - 56, label_w - 32, 20, _INTL("VERMEIL"), 10, Color.new(213, 194, 158), 1, true)
      pages.visible = false
      cover.visible = true
      shadow.visible = true
    end

    def set_content_opacity(value)
      notebook_content_keys.each do |key|
        sprite = @sprites[key]
        sprite.opacity = value if sprite && sprite.respond_to?(:opacity=)
      end
    end

    def open_animation
      cover = @sprites["front_cover"]
      pages = @sprites["book_pages"]
      shadow = @sprites["book_shadow"]
      return restore_content_visibility if !cover || !pages
      frames = [ResearchNotebook::Settings::OPEN_ANIMATION_FRAMES.to_i, 6].max
      pages.visible = true
      pages.opacity = 255
      cover.visible = true
      cover.opacity = 255
      cover.zoom_x = 1.0
      cover.x = BOOK_X
      shadow.visible = true if shadow
      shadow.opacity = 135 if shadow
      frames.times do |i|
        t = (i + 1).to_f / frames
        eased = 0.5 - Math.cos(Math::PI * t) * 0.5
        cover.zoom_x = [1.0 - 0.96 * eased, 0.04].max
        shadow.opacity = (135 - 65 * eased).round if shadow
        Graphics.update
      end
      cover.visible = false
      restore_content_visibility
      set_content_opacity(0)
      fade_frames = [ResearchNotebook::Settings::CONTENT_FADE_FRAMES.to_i, 1].max
      fade_frames.times do |i|
        t = (i + 1).to_f / fade_frames
        pages.opacity = (255 * (1.0 - t)).round
        set_content_opacity((255 * t).round)
        Graphics.update
      end
      set_content_opacity(255)
      pages.visible = false
      pages.opacity = 255
      shadow.visible = false if shadow
      cover.zoom_x = 1.0
    end

    def close_animation
      cover = @sprites["front_cover"]
      pages = @sprites["book_pages"]
      shadow = @sprites["book_shadow"]
      return if !cover || !pages
      remember_content_visibility
      frames = [ResearchNotebook::Settings::OPEN_ANIMATION_FRAMES.to_i, 6].max
      pages.visible = true
      pages.opacity = 0
      shadow.visible = true if shadow
      shadow.opacity = 70 if shadow
      3.times do |i|
        t = (i + 1).to_f / 3.0
        pages.opacity = (255 * t).round
        set_content_opacity((255 * (1.0 - t)).round)
        Graphics.update
      end
      set_notebook_content_visible(false)
      set_content_opacity(255)
      cover.visible = true
      cover.opacity = 255
      cover.x = BOOK_X
      cover.zoom_x = 0.04
      frames.times do |i|
        t = (i + 1).to_f / frames
        eased = 0.5 - Math.cos(Math::PI * t) * 0.5
        cover.zoom_x = 0.04 + 0.96 * eased
        shadow.opacity = (70 + 65 * eased).round if shadow
        Graphics.update
      end
      cover.zoom_x = 1.0
      pages.visible = false
    end

    def capture_right_page(target)
      return if !target
      target.clear
      rect = Rect.new(GRID_X, BOOK_Y, GRID_W, BOOK_H)
      paper = @sprites["paper"]
      overlay = @sprites["overlay"]
      icons = @sprites["grid_icons"]
      target.blt(0, 0, paper.bitmap, rect) if paper && paper.bitmap
      target.blt(0, 0, overlay.bitmap, rect) if overlay && overlay.bitmap
      target.blt(0, 0, icons.bitmap, rect) if icons && icons.visible && icons.bitmap
    end

    def prepare_page_blank
      blank = @sprites["pageblank"]
      return if !blank || !blank.bitmap
      bmp = blank.bitmap
      bmp.clear
      bmp.fill_rect(0, 0, GRID_W, BOOK_H, PAPER_2)
      bmp.fill_rect(0, 0, 3, BOOK_H, Color.new(146, 124, 92, 120))
      bmp.fill_rect(4, 3, GRID_W - 8, BOOK_H - 6, PAPER)
      blank.visible = true
    end

    def page_wipe(direction = 1)
      if !ResearchNotebook::Settings::ENABLE_PAGE_TURN_ANIMATION
        yield if block_given?
        return
      end
      fx = @sprites["pagefx"]
      blank = @sprites["pageblank"]
      if !fx || !blank
        yield if block_given?
        return
      end
      cursor_was_visible = @sprites["cursor"] && @sprites["cursor"].visible
      @sprites["cursor"].visible = false if @sprites["cursor"]
      prepare_page_blank
      capture_right_page(fx.bitmap)
      fx.visible = true
      fx.opacity = 255
      if direction >= 0
        fx.ox = 0
        fx.x = GRID_X
      else
        fx.ox = GRID_W
        fx.x = GRID_X + GRID_W
      end
      fx.zoom_x = 1.0
      frames = [ResearchNotebook::Settings::PAGE_TURN_FRAMES.to_i,
                ResearchNotebook::Settings::PAGE_TURN_MIN_FRAMES.to_i, 6].max
      half = [frames / 2, 3].max
      half.times do |i|
        t = (i + 1).to_f / half
        eased = Math.sin(t * Math::PI / 2.0)
        fx.zoom_x = [1.0 - 0.95 * eased, 0.05].max
        Graphics.update
      end
      yield if block_given?
      capture_right_page(fx.bitmap)
      fx.zoom_x = 0.05
      half.times do |i|
        t = (i + 1).to_f / half
        eased = 1.0 - Math.cos(t * Math::PI / 2.0)
        fx.zoom_x = 0.05 + 0.95 * eased
        Graphics.update
      end
      fx.visible = false
      fx.zoom_x = 1.0
      fx.ox = 0
      fx.x = GRID_X
      blank.visible = false
      @sprites["cursor"].visible = !@detail_open && !@species.empty? if @sprites["cursor"]
    end

    def flash_sort_label
      # Sin frames de espera: el SFX y el cambio de encabezado bastan para
      # comunicar el nuevo orden sin frenar la navegación.
    end

    def update_gamefeel
      @frame_count += 1
      return if @sections.empty?
      if !@detail_open && @sprites["cursor"] && @sprites["cursor"].visible && ResearchNotebook::Settings::ENABLE_CURSOR_PULSE
        @sprites["cursor"].opacity = 195 + ((Math.sin(@frame_count / 8.0) + 1.0) * 24).round
      end
      # El Pokémon y los iconos ya no cambian de escala cada frame por defecto.
      # Ese micro-pulso era el origen de varios "tics" visuales y además hacía
      # trabajar a 25 sprites sin aportar información.
      if ResearchNotebook::Settings::ENABLE_FOCUS_BREATH && @sprites["pokemon"] && @sprites["pokemon"].visible
        pulse = 1.0 + Math.sin(@frame_count / 20.0) * 0.008
        @sprites["pokemon"].zoom_x = @pokemon_base_zoom_x * pulse
        @sprites["pokemon"].zoom_y = @pokemon_base_zoom_y * pulse
      end
    end

    #===========================================================================
    # Helpers visuales
    #===========================================================================
    def section_color
      return current_section == :arcane ? ARCANE : GOLDEN
    end

    def notebook_arcane_ability(species)
      return nil if !ResearchNotebook.progress.arcane_seen?(species)
      return ResearchNotebook.progress.arcane_ability_id(species)
    end

    def draw_card(bmp, x, y, w, h, fill = PAPER_2)
      bmp.fill_rect(x, y, w, h, Color.new(168, 147, 111, 110))
      bmp.fill_rect(x + 1, y + 1, w - 2, h - 2, fill)
    end

    def draw_status_chip(bmp, x, y, w, h, text, color)
      bmp.fill_rect(x, y, w, h, color)
      draw_text(bmp, x + 3, y + 12, w - 6, h - 13, text, 10, INK, 1, true)
    end

    def draw_progress_dots(bmp, x, y, total, active, color)
      total.times do |i|
        xx = x + i * 28
        bmp.fill_rect(xx, y, 18, 6, i < active ? color : Color.new(184, 170, 141))
      end
      draw_text(bmp, x + total * 28 + 2, y - 6, 120, 18, _INTL("{1}/{2} registrado", active, total), 9, MUTED, 0, false)
    end

    def draw_progress_track(bmp, x, y, w, steps, color)
      gap = 7
      each_w = ((w - gap * (steps.length - 1)) / steps.length.to_f).floor
      steps.each_with_index do |step, i|
        xx = x + i * (each_w + gap)
        fill = step[1] ? color : PAPER_3
        bmp.fill_rect(xx, y, each_w, 30, Color.new(163, 144, 109, 90))
        bmp.fill_rect(xx + 1, y + 1, each_w - 2, 28, fill)
        draw_text(bmp, xx + 3, y + 5, each_w - 6, 18, step[0], 9, step[1] ? INK : MUTED, 1, true)
      end
    end

    def draw_item_card(bmp, x, y, w, h, item_id, color, label)
      draw_card(bmp, x, y, w, h, PAPER)
      bmp.fill_rect(x, y, 5, h, color)
      draw_text(bmp, x + 11, y + 5, w - 22, 15, label, 9, MUTED, 0, true)
      draw_text(bmp, x + 11, y + 20, w - 22, 22, ResearchNotebook::Repository.item_name(item_id), 13, INK, 0, true)
    end

    def draw_item_pair(bmp, x, y, w, first_id, second_id)
      half = (w - 6) / 2
      draw_card(bmp, x, y, half, 31, PAPER)
      draw_card(bmp, x + half + 6, y, half, 31, PAPER)
      draw_text(bmp, x + 5, y + 12, half - 10, 17, ResearchNotebook::Repository.item_name(first_id), 10, INK, 1, true)
      draw_text(bmp, x + half + 11, y + 12, half - 10, 17, ResearchNotebook::Repository.item_name(second_id), 10, INK, 1, true)
    end

    def draw_stat_panel(bmp, x, y, w, h, stats, base, color)
      draw_card(bmp, x, y, w, h, PAPER)
      if !stats || stats.empty?
        draw_text(bmp, x + 8, y + 45, w - 16, 22, _INTL("Estadísticas sin registrar"), 12, MUTED, 1, false)
        return
      end
      rows = [[:HP, "PS"], [:ATTACK, "ATQ"], [:DEFENSE, "DEF"], [:SPECIAL_ATTACK, "A.E"], [:SPECIAL_DEFENSE, "D.E"], [:SPEED, "VEL"]]
      rows.each_with_index do |row, i|
        col = i / 3
        line = i % 3
        xx = x + 8 + col * (w / 2)
        yy = y + 2 + line * 24
        value = stats[row[0]].to_i
        old = base && base[row[0]] ? base[row[0]].to_i : nil
        delta = old ? value - old : 0
        draw_text(bmp, xx, yy, 28, 17, row[1], 9, MUTED, 0, true)
        draw_text(bmp, xx + 30, yy, 34, 17, value.to_s, 10, INK, 2, true)
        bar_x = xx + 68
        bar_w = [w / 2 - 84, 42].max
        bmp.fill_rect(bar_x, yy + 6, bar_w, 6, PAPER_3)
        fill = ((bar_w * [value, 200].min) / 200.0).round
        bmp.fill_rect(bar_x, yy + 6, fill, 6, color) if fill > 0
        if old && delta != 0
          sign = delta > 0 ? "+" : ""
          draw_text(bmp, xx + 30, yy + 12, 34, 10, "#{sign}#{delta}", 7, delta > 0 ? GREEN : RED, 2, true)
        end
      end
      bst = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].inject(0) { |sum, k| sum + stats[k].to_i }
      draw_text(bmp, x + w - 98, y + h - 17, 88, 14, _INTL("BST {1}", bst), 9, INK, 2, true)
    end

    def draw_ring(bmp, cx, cy, radius, color)
      steps = 72
      last_x = cx + radius
      last_y = cy
      (1..steps).each do |i|
        angle = Math::PI * 2 * i / steps
        nx = (cx + Math.cos(angle) * radius).round
        ny = (cy + Math.sin(angle) * radius * 0.28).round
        draw_line(bmp, last_x, last_y, nx, ny, color)
        last_x = nx
        last_y = ny
      end
    end

    def draw_changedex_note(bmp, base, x, y, w)
      return if !ResearchNotebook::Settings::USE_CHANGEDEX_HIDDEN_FORMS
      # Verificar si la especie base tiene formas ocultas en ChangeDex
      hidden_keys = ResearchNotebook::Repository.changedex_hidden_keys
      species_key = base.to_s.upcase
      has_hidden = hidden_keys.key?(species_key) ||
                   hidden_keys.keys.any? { |k| k.start_with?(species_key + ",") }
      return if !has_hidden
      
      draw_text(bmp, x, y, w, 16, _INTL("NOTA: ChangeDex oculta formas de esta especie."), 10, MUTED, 0, true)
    end

    def draw_line(bmp, x0, y0, x1, y1, color)
      dx = (x1 - x0).abs
      sx = x0 < x1 ? 1 : -1
      dy = -(y1 - y0).abs
      sy = y0 < y1 ? 1 : -1
      err = dx + dy
      loop do
        bmp.set_pixel(x0, y0, color)
        break if x0 == x1 && y0 == y1
        e2 = 2 * err
        if e2 >= dy
          err += dy
          x0 += sx
        end
        if e2 <= dx
          err += dx
          y0 += sy
        end
      end
    end

    def draw_footer(bmp)
      if @sections.empty?
        text = _INTL("Atrás · Cerrar")
      elsif @detail_open
        text = current_section == :golden && detail_page_count > 1 ? _INTL("Arr/Abj: Pokémon    Izq/Der: Página    C/X: Volver") : _INTL("Arr/Abj: Pokémon    C/X: Volver")
      else
        text = _INTL("Flechas Mover   C Ficha   Z Sección   D Ordenar   X Cerrar")
      end
      draw_text(bmp, 12, FOOTER_Y + 13, WIDTH - 24, 18, text, 12, WHITE, 1, false)
    end

    def draw_text(bmp, x, y, w, h, string, size = 18, color = INK, align = 0, bold = false)
      return if string.nil? || w.to_i <= 0 || h.to_i <= 0
      old_size = bmp.font.size
      old_color = bmp.font.color
      old_bold = bmp.font.bold
      bmp.font.size = size
      bmp.font.color = color
      bmp.font.bold = bold
      # Las especies y traducciones tienen longitudes distintas. Adaptar el
      # texto al ancho de su componente evita invadir iconos o fichas vecinas.
      while bmp.font.size > 9 && bmp.text_size(string.to_s).width > w - 3
        bmp.font.size -= 1
      end
      bmp.draw_text(x, y, w, h, string.to_s, align)
    ensure
      if bmp && bmp.respond_to?(:font) && bmp.font && old_size
        bmp.font.size = old_size
        bmp.font.color = old_color
        bmp.font.bold = old_bold
      end
    end

    def draw_wrapped(bmp, x, y, width, string, size = 17, color = INK, line_h = 23, max_lines = 5)
      return if string.nil?
      old_size = bmp.font.size
      old_color = bmp.font.color
      old_bold = bmp.font.bold
      bmp.font.size = size
      bmp.font.color = color
      bmp.font.bold = false
      lines = []
      string.to_s.split(/\n/).each do |paragraph|
        words = paragraph.split(/\s+/)
        line = ""
        words.each do |word|
          test = line.empty? ? word : "#{line} #{word}"
          if !line.empty? && bmp.text_size(test).width > width
            lines << line
            line = word
          else
            line = test
          end
        end
        lines << line if !line.empty?
      end
      truncated = lines.length > max_lines
      lines = lines[0, max_lines]
      if truncated && !lines.empty?
        while !lines[-1].empty? && bmp.text_size(lines[-1] + "…").width > width
          lines[-1] = lines[-1][0...-1]
        end
        lines[-1] += "…"
      end
      lines.each_with_index { |line, i| bmp.draw_text(x, y + i * line_h, width, line_h, line, 0) }
      bmp.font.size = old_size
      bmp.font.color = old_color
      bmp.font.bold = old_bold
    end
  end

  module_function
  def open
    Scene.new.main
  end
end

def pbOpenResearchNotebook
  ResearchNotebook.open
end

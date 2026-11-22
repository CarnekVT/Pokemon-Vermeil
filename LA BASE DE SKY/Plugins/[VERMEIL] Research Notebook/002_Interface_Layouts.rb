# frozen_string_literal: true
# Bridge between MakerStudio > Editor de Interfaces and Vermeil's native scenes.
# The game logic remains native; authored graphic slots and EXTRA elements use
# the very same UI/*.json that the MakerStudio editor writes.
module VermeilInterfaceLayout
  # Native screen profiles live in real folders. Flat filenames remain as
  # compatibility aliases; the most recently edited file wins per page.
  FILES = {
    :notebook => ["Libreta/Catalogo", "Libreta/Ficha"],
    :pokedex  => ["Pokedex/Lista", "Pokedex/Ficha",
                  "Pokedex/Area", "Pokedex/Formas"]
  }.freeze

  LEGACY = {
    "Libreta/Catalogo" => "vermeil_libreta",
    "Libreta/Ficha" => "vermeil_libreta_detalle",
    "Pokedex/Lista" => "vermeil_pokedex_lista",
    "Pokedex/Ficha" => "vermeil_pokedex_ficha",
    "Pokedex/Area" => "vermeil_pokedex_area",
    "Pokedex/Formas" => "vermeil_pokedex_formas"
  }.freeze

  NATIVE_IDS = {
    "Libreta/Catalogo" => %w[background cover pages focus_panel grid_panel
                            focus_sprite tab_arcane tab_golden
                            notebook_title focus_number focus_name header_bar
                            footer_bar book_spine grid_cell grid_cell_selected
                            grid_cursor cover_label cover_title cover_subtitle
                            cover_brand tab_arcane_label tab_golden_label
                            footer_hint],
    "Libreta/Ficha" => %w[detail_panel card_template
                         detail_arcane_title detail_ability_name detail_arcane_note
                         detail_power_title detail_power_note detail_form_title
                         detail_form_ability detail_moves_title detail_form_note],
    "Pokedex/Lista" => %w[background header list_panel portrait_panel
                         portrait_pokemon counter_panel scrollbar_track
                         list_row list_row_selected
                         pokedex_title seen_counter caught_counter],
    "Pokedex/Ficha" => %w[entry_page entry_sprite entry_description
                         detail_name detail_category detail_height detail_weight],
    "Pokedex/Area" => %w[area_page],
    "Pokedex/Formas" => %w[forms_page]
  }.freeze

  EXTRA_TYPES = %w[imagen panel texto animado barra].freeze
  module_function

  def report(message)
    echoln("[Vermeil Interface Studio] #{message}") if defined?(echoln)
  rescue StandardError
  end

  def load(kind)
    result={}
    loaded=0
    (FILES[kind] || []).each do |page|
      # The file visible in MakerStudio's UI/<Interface>/<Page> library is
      # ALWAYS the source of truth. mtime comparisons previously made edits
      # appear ignored when a legacy flat JSON had a newer timestamp.
      canonical="UI/#{page}.json"
      legacy=LEGACY[page] ? "UI/#{LEGACY[page]}.json" : nil
      filename=File.file?(canonical) ? canonical :
               (legacy && File.file?(legacy) ? legacy : nil)
      next unless filename
      begin
        source=File.open(filename,"rb") { |file| file.read.force_encoding("UTF-8") }
        data=if defined?(Interfaces::AnalizadorJSON)
               Interfaces::AnalizadorJSON.analizar(source,filename)
             elsif defined?(JSON) && JSON.respond_to?(:parse)
               JSON.parse(source)
             end
        unless data.is_a?(Hash) && data["elementos"].is_a?(Array)
          report("#{filename}: no se pudo leer una lista de elementos")
          next
        end
        loaded+=1
        data["elementos"].each do |element|
          next unless element.is_a?(Hash)
          id=element["id"].to_s
          next if id.empty?
          result[id]=element.merge("__page"=>page)
        end
      rescue StandardError=>error
        report("#{filename}: #{error.class}: #{error.message}")
      end
    end
    report("#{kind}: #{loaded} perfiles leidos / #{result.length} elementos") if $DEBUG
    result
  end

  def element(layout, id)
    layout.is_a?(Hash) ? layout[id.to_s] : nil
  end

  def number(layout, id, property, fallback)
    data = element(layout, id)
    value = data.is_a?(Hash) ? data[property.to_s] : nil
    return fallback unless value.is_a?(Numeric) && value.finite?
    value
  end

  def position(layout, id, axis, fallback)
    number(layout, id, axis, fallback).round
  end

  def layer(layout, id, fallback)
    number(layout, id, "capa", fallback).to_i
  end

  def entrance(layout, id)
    data = element(layout, id)
    entry = data.is_a?(Hash) ? data["entrada"] : nil
    entry.is_a?(Hash) ? entry : {}
  end

  def frames(layout, id, fallback, minimum = 3, maximum = 75)
    duration = entrance(layout, id)["duracion"]
    return fallback unless duration.is_a?(Numeric) && duration.finite? && duration > 0
    [[(duration * 60).round, minimum].max, maximum].min
  end

  def color(value, default = nil)
    text=value.to_s.delete_prefix("#")
    return default unless text.match?(/\A(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\z/)
    Color.new(text[0,2].to_i(16),text[2,2].to_i(16),text[4,2].to_i(16),
              text.length==8 ? text[6,2].to_i(16) : 255)
  rescue StandardError
    default
  end

  def bitmap_for(path)
    name=path.to_s.strip.tr("\\","/")
    return nil if name.empty?
    @images ||= {}
    return @images[name] if @images.key?(name)
    resolved = (pbResolveBitmap(name) rescue nil) if defined?(pbResolveBitmap)
    resolved ||= [name,name+".png",name+".jpg"].find { |candidate| File.file?(candidate) }
    @images[name] = resolved ? Bitmap.new(resolved) : nil
  rescue StandardError => error
    report("Imagen #{path.inspect}: #{error.class}: #{error.message}")
    @images[name] = nil
  end

  # Graphic slots: a changed PNG, size, panel fill, opacity or position
  # in MakerStudio now modifies the REAL native panel (not a fake preview).
  # Return true only when there is actual authored artwork/panel paint.
  def paint_native(canvas, layout, id, x, y, target_width=nil, target_height=nil)
    data=element(layout,id)
    return false unless data.is_a?(Hash)
    return true if data["visible"] == false
    width=target_width ? target_width.to_i : data["ancho"].to_i
    height=target_height ? target_height.to_i : data["alto"].to_i
    if data["tipo"]=="imagen"
      bmp=bitmap_for(data["imagen"])
      return false unless bmp && !(bmp.disposed? rescue true)
      width=bmp.width if width<=0
      height=bmp.height if height<=0
      return false if width<=0 || height<=0
      opacity=[[number(layout,id,"opacidad",255).to_i,0].max,255].min
      canvas.stretch_blt(Rect.new(x.to_i,y.to_i,width,height),bmp,bmp.rect,opacity)
      return true
    elsif data["tipo"]=="panel"
      return false if width<=0 || height<=0
      fill=color(data["color"],Color.new(22,29,43,255))
      alpha=[[number(layout,id,"opacidad",255).to_i,0].max,255].min
      fill=Color.new(fill.red,fill.green,fill.blue,(fill.alpha*alpha/255.0).round)
      canvas.fill_rect(x.to_i,y.to_i,width,height,fill)
      border=color(data["borde"])
      if border
        border=Color.new(border.red,border.green,border.blue,
                         (border.alpha*alpha/255.0).round)
        thick=[[data["borde_grosor"].to_i,1].max,10].min
        canvas.fill_rect(x.to_i,y.to_i,width,thick,border)
        canvas.fill_rect(x.to_i,y.to_i+height-thick,width,thick,border)
        canvas.fill_rect(x.to_i,y.to_i,thick,height,border)
        canvas.fill_rect(x.to_i+width-thick,y.to_i,thick,height,border)
      end
      return true
    end
    false
  rescue StandardError => error
    report("Panel #{id}: #{error.class}: #{error.message}")
    false
  end

  # -----------------------------------------------------------------------
  # ONE declarative compositor for BOTH scenes.
  # The JSON created in MakerStudio defines order, geometry, typography,
  # color, artwork and visibility. Ruby supplies ONLY values/state.
  # All native visual layers are rasterized through the same method.
  # -----------------------------------------------------------------------
  def render_document(canvas,layout,page,ids,values={},origin_x=0,origin_y=0)
    return [] unless canvas && layout && ids && !ids.empty?
    allowed=ids.map(&:to_s)
    layers=layout.map do |id,data|
      next unless allowed.include?(id) && data.is_a?(Hash) &&
                  data["__page"]==page && data["visible"]!=false
      [id,data]
    end.compact
    layers.sort_by! { |id,data| [data["capa"].to_i,allowed.index(id)||0] }
    painted=[]
    layers.each do |id,data|
      x=data["x"].to_i-origin_x.to_i
      y=data["y"].to_i-origin_y.to_i
      case data["tipo"]
      when "panel","imagen"
        painted << id if paint_native(canvas,layout,id,x,y)
      when "texto"
        override=values[id]
        if override.is_a?(Hash)
          # Repeated native rows bind a live datum and a row offset without
          # changing the author-defined font/colors/original template.
          local=data.merge(override)
          dx=local["x"].to_i-origin_x.to_i
          dy=local["y"].to_i-origin_y.to_i
          paint_text(canvas,local,dx,dy,local["texto"])
        else
          value=values.key?(id) ? override : data["texto"].to_s
          paint_text(canvas,data,x,y,value)
        end
        painted << id
      end
    end
    painted
  end

  def paint_text(canvas,data,x,y,value)
    return unless canvas && canvas.respond_to?(:font) && canvas.font
    prev_size=canvas.font.size
    prev_bold=(canvas.font.bold rescue nil)
    size=data["tamano"].to_i
    canvas.font.size=[[size,8].max,54].min if size>0
    canvas.font.bold=(data["negrita"]==true) if canvas.font.respond_to?(:bold=)
    w=[data["ancho"].to_i,1].max
    h=[data["alto"].to_i,1].max
    align=case data["alineacion"]
          when "centro" then 1
          when "derecha" then 2
          else 0
          end
    primary=color(data["color"],Color.new(240,240,240,255))
    shadow=color(data["sombra"],Color.new(20,20,25,180))
    if defined?(pbDrawShadowText)
      pbDrawShadowText(canvas,x,y,w,h,value.to_s,primary,shadow,align)
    else
      canvas.font.color=primary
      canvas.draw_text(x,y,w,h,value.to_s,align)
    end
  ensure
    canvas.font.size=prev_size if prev_size && canvas && canvas.font
    canvas.font.bold=prev_bold if !prev_bold.nil? && canvas && canvas.font &&
                                   canvas.font.respond_to?(:bold=)
  end

  def render_component(canvas,layout,id,x,y,width=nil,height=nil)
    paint_native(canvas,layout,id,x,y,width,height)
  end

  # Draw an authored full page while preserving the actual transparent
  # Pokemon window. The rect is scene state, the *page art* comes from JSON.
  def render_masked_page(canvas,layout,page,id,hole_x,hole_y,hole_w,hole_h)
    data=element(layout,id)
    return false unless data && data["__page"]==page && data["visible"]!=false
    fill=color(data["color"],Color.new(20,28,42,255))
    fill=Color.new(fill.red,fill.green,fill.blue,255)
    w=canvas.width;h=canvas.height
    canvas.fill_rect(0,0,w,hole_y,fill)
    canvas.fill_rect(0,hole_y+hole_h,w,h-hole_y-hole_h,fill)
    canvas.fill_rect(0,hole_y,hole_x,hole_h,fill)
    canvas.fill_rect(hole_x+hole_w,hole_y,w-hole_x-hole_w,hole_h,fill)
    # A custom background image may be used only when it explicitly asks for
    # full coverage; do not stretch it across the Pokemon sprite hole.
    if data["tipo"]=="imagen"
      bmp=bitmap_for(data["imagen"])
      if bmp
        pieces=[[0,0,w,hole_y],[0,hole_y+hole_h,w,h-hole_y-hole_h],
                [0,hole_y,hole_x,hole_h],
                [hole_x+hole_w,hole_y,w-hole_x-hole_w,hole_h]]
        pieces.each do |x,y,pw,ph|
          next if pw<=0 || ph<=0
          canvas.blt(x,y,bmp,Rect.new(x,y,pw,ph))
        end
      end
    end
    true
  end

  def release_images
    (@images || {}).each_value do |bitmap|
      bitmap.dispose if bitmap && !(bitmap.disposed? rescue true)
    end
    @images = {}
  end

  # The native game owns data boxes, grid selection, Pokemon state and commands.
  # Additional author-created decorative text, art, panels and animations are
  # rendered by Interfaces::Elemento itself, on the native scene viewport.
  # Never create decorative clones of the reserved/native scene anchors.
  def make_extras(layout, viewport, page, animate_entry=true)
    return [] unless defined?(Interfaces::Elemento)
    native=NATIVE_IDS[page] || []
    result=[]
    notes=[]
    layout.each do |id, data|
      next unless data.is_a?(Hash) && data["__page"] == page
      next if native.include?(id)
      next unless EXTRA_TYPES.include?(data["tipo"].to_s)
      begin
        copy=data.dup
        copy.delete("__page")
        # On first opening the native screen itself fades in. Do not replay
        # another independent editor entrance on those same first frames.
        copy.delete("entrada") unless animate_entry
        copy["capa"] = [[data["capa"].to_i+8,8].max,65].min
        obj=Interfaces::Elemento.construir(copy,viewport,notes)
        next unless obj
        obj.crear(Time.now.to_f)
        result << obj
      rescue StandardError => error
        report("#{page}.#{id}: #{error.class}: #{error.message}")
      end
    end
    notes.each { |note| report("#{page}: #{note}") }
    result
  end

  def update_extras(items)
    return unless items
    now=Time.now.to_f
    items.each do |item|
      item.actualizar(now)
      # The original Interfaces engine uses zoom_x/zoom_y but its Imagen
      # implementation does not apply the editor's explicit image W/H.
      # Apply them from the ORIGINAL bitmap every frame (non-accumulating).
      data=item.datos
      next unless ["imagen","animado"].include?(data["tipo"].to_s)
      sprite=item.sprite
      next unless sprite && sprite.bitmap && !(sprite.disposed? rescue true)
      source=sprite.bitmap
      src=(sprite.src_rect rescue nil)
      bitmap_w=(src && src.width.to_f>0 ? src.width.to_f : source.width.to_f)
      bitmap_h=(src && src.height.to_f>0 ? src.height.to_f : source.height.to_f)
      desired_w=data["ancho"].to_f
      desired_h=data["alto"].to_f
      if desired_w>0 && bitmap_w>0
        # Elemento#actualizar resets the authored "zoom" every update, but
        # applying any multiplier to a previous frame invites compounding if
        # another runtime updates the sprite in between.
        sprite.zoom_x=item.valor_de("zoom",now).to_f*(desired_w/bitmap_w)
      end
      if desired_h>0 && bitmap_h>0
        sprite.zoom_y=item.valor_de("zoom",now).to_f*(desired_h/bitmap_h)
      end
    end
  rescue StandardError => error
    report("Elemento visual: #{error.class}: #{error.message}")
  end

  def dispose_extras(items)
    (items || []).each do |item|
      item.soltar if item.respond_to?(:soltar)
    rescue StandardError
    end
  end
end

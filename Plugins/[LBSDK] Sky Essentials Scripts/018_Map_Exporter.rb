#==============================================================================#
#                              Map Exporter                                    #
#                                by Marin                                      #
#==============================================================================#
# Manually export a map using `pbExportMap(id)`, or go into the Debug menu and #
#            choose the `Export a Map` option that is now in there.            #
#                                                                              #
#  `pbExportMap(id, options)`, where `options` is an array that can contain:   #
#       - :events  ->  This will also export all events present on the map     #
#       - :player  ->  This will also export the player if they're on that map #
#  `id` can be nil, which case it will use the current map the player is on.   #
#==============================================================================#
#                    Please give credit when using this.                       #
#==============================================================================#

# This is where the map will be exported to once it has been created.
# If this file already exists, it is overwritten.
EXPORTEDMAPBASENAME = "MapExporter/MAP_EXPORTED_"

unless 0.respond_to?(:to_digits)
  class Integer
    def to_digits
      format("%03d", self)
    end
  end
end

unless defined?(pbGetActiveEventPage)
  def pbGetActiveEventPage(event, map_id)
    return nil if !event || !event.pages
    event.pages.reverse_each do |page|
      c = page.condition
      next if c.switch1_valid && !pbMapExporterSwitchIsOn?(c.switch1_id)
      next if c.switch2_valid && !pbMapExporterSwitchIsOn?(c.switch2_id)
      next if c.variable_valid && $game_variables[c.variable_id] < c.variable_value
      if c.self_switch_valid
        key = [map_id, event.id, c.self_switch_ch]
        next if $game_self_switches[key] != true
      end
      return page
    end
    return nil
  end
end

unless defined?(pbMapExporterSwitchIsOn?)
  def pbMapExporterSwitchIsOn?(id)
    switchname = $data_system.switches[id]
    return false if !switchname
    if switchname[/^s\:/]
      return eval($~.post_match)
    end
    return $game_switches[id]
  end
end

unless defined?(pbMapExporterSavePng)
  def pbMapExporterSavePng(bitmap, filename)
    if bitmap.respond_to?(:save_to_png)
      bitmap.save_to_png(filename)
    elsif bitmap.respond_to?(:save_png)
      bitmap.save_png(filename)
    elsif bitmap.respond_to?(:save_to_file)
      bitmap.save_to_file(filename)
    elsif bitmap.respond_to?(:get_pixel)
      pbMapExporterWritePng(bitmap, filename)
    else
      raise NoMethodError, "Bitmap missing save_to_png/save_png/save_to_file"
    end
  end
end

unless defined?(pbMapExporterWritePng)
  def pbMapExporterWritePng(bitmap, filename)
    require "zlib"
    width = bitmap.width
    height = bitmap.height
    raw = String.new.b
    height.times do |y|
      raw << 0.chr
      width.times do |x|
        c = bitmap.get_pixel(x, y)
        r = [[c.red.to_i, 0].max, 255].min
        g = [[c.green.to_i, 0].max, 255].min
        b = [[c.blue.to_i, 0].max, 255].min
        a = [[c.alpha.to_i, 0].max, 255].min
        raw << r.chr << g.chr << b.chr << a.chr
      end
    end
    compressed = Zlib::Deflate.deflate(raw)
    File.open(filename, "wb") do |f|
      f.write "\x89PNG\r\n\x1a\n"
      ihdr = [width, height, 8, 6, 0, 0, 0].pack("NNCCCCC")
      pbMapExporterWriteChunk(f, "IHDR", ihdr)
      pbMapExporterWriteChunk(f, "IDAT", compressed)
      pbMapExporterWriteChunk(f, "IEND", "")
    end
  end
end

unless defined?(pbMapExporterWriteChunk)
  def pbMapExporterWriteChunk(io, type, data)
    io.write [data.bytesize].pack("N")
    io.write type
    io.write data
    io.write [Zlib.crc32(type + data)].pack("N")
  end
end


def pbExportMap(id = nil, options = [])
  mapExporter = MarinMapExporter.new(id, options)
  return mapExporter.exported_file
end

def pbExportAMap
  vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
  vp.z = 99999
  s = Sprite.new(vp)
  s.bitmap = Bitmap.new(Graphics.width, Graphics.height)
  s.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0,0,0))
  mapid = pbListScreen(_INTL("Export Map"),MapLister.new(pbDefaultMap))
  if mapid > 0
    player = $game_map.map_id == mapid
    if player
      cmds = ["Export", "[  ] Events", "[  ] Player", "Cancel"]
    else
      cmds = ["Export", "[  ] Events", "Cancel"]
    end
    cmd = 0
    loop do
      cmd = pbShowCommands(nil,cmds,-1,cmd)
      if cmd == 0
        Graphics.update
        options = []
        options << :events if cmds[1].split("")[1] == "X"
        options << :player if player && cmds[2].split("")[1] == "X"
        msgwindow = Window_AdvancedTextPokemon.newWithSize(
            _INTL("Saving... Please wait."),
            0, Graphics.height - 96, Graphics.width, 96, vp
        )
        msgwindow.setSkin(MessageConfig.pbGetSpeechFrame)
        Graphics.update
        exported_file = pbExportMap(mapid, options)
        msgwindow.setText(_INTL("The map has been exported as #{exported_file}"))
        60.times { Graphics.update; Input.update }
        #pbDisposeMessageWindow(msgwindow)
        break
      elsif cmd == 1
        if cmds[1].split("")[1] == " "
          cmds[1] = "[X] Events"
        else
          cmds[1] = "[  ] Events"
        end
      elsif cmd == 2 && player
        if cmds[2].split("")[1] == " "
          cmds[2] = "[X] Player"
        else
          cmds[2] = "[  ] Player"
        end
      elsif cmd == 3 || cmd == 2 && !player || cmd == -1
        break
      end
    end
  end
  s.bitmap.dispose
  s.dispose
  vp.dispose
end

MenuHandlers.add(:debug_menu,:exportmap, {
  "parent"      => :field_menu,
  "name"        => _INTL("Export a Map"),
  "description" => _INTL("Choose a map to export as a PNG image."),
  "effect"      => proc { |sprites, viewport|
    pbExportAMap
  }
})

class MarinMapExporter
  attr_accessor :exported_file
  def initialize(id = nil, options = [])
    @exported_file = nil
    @id = id || $game_map.map_id
    @options = options
    @data = load_data("Data/Map#{@id.to_digits}.rxdata")
    @tiles = @data.data
    @result = Bitmap.new(32 * @tiles.xsize, 32 * @tiles.ysize)
    @tilesetdata = load_data("Data/Tilesets.rxdata")
    tilesetname = @tilesetdata[@data.tileset_id].tileset_name
    @tileset = Bitmap.new("Graphics/Tilesets/#{tilesetname}")
    @autotiles = @tilesetdata[@data.tileset_id].autotile_names
        .filter { |e| e && e.size > 0 }
        .map { |e| Bitmap.new("Graphics/Autotiles/#{e}") }
    for z in 0..2
      for y in 0...@tiles.ysize
        for x in 0...@tiles.xsize
          id = @tiles[x, y, z]
          next if id == 0
          if id < 384 # Autotile
            build_autotile(@result, x * 32, y * 32, id)
          else # Normal tile
            @result.blt(x * 32, y * 32, @tileset,
                Rect.new(32 * ((id - 384) % 8),32 * ((id - 384) / 8).floor,32,32))
          end
        end
      end
    end
    if @options.include?(:events)
      keys = @data.events.keys.sort { |a, b| @data.events[a].y <=> @data.events[b].y }
      keys.each do |id|
        event = @data.events[id]
        page = pbGetActiveEventPage(event, @id)
        if page && page.graphic && page.graphic.character_name && page.graphic.character_name.size > 0
          bmp = Bitmap.new("Graphics/Characters/#{page.graphic.character_name}")
          if bmp
            bmp = bmp.clone
            bmp.hue_change(page.graphic.character_hue) unless page.graphic.character_hue == 0
            ex = bmp.width / 4 * page.graphic.pattern
            ey = bmp.height / 4 * (page.graphic.direction / 2 - 1)
            @result.blt(event.x * 32 + 16 - bmp.width / 8, (event.y + 1) * 32 - bmp.height / 4, bmp,
                Rect.new(ex, ey, bmp.width / 4, bmp.height / 4))
          end
          bmp = nil
        end
      end
    end
    if @options.include?(:player) && $game_map.map_id == @id && $game_player.character_name &&
       $game_player.character_name.size > 0
      bmp = Bitmap.new("Graphics/Characters/#{$game_player.character_name}")
      dir = $game_player.direction
      @result.blt($game_player.x * 32 + 16 - bmp.width / 8, ($game_player.y + 1) * 32 - bmp.height / 4,
          bmp, Rect.new(0, bmp.height / 4 * (dir / 2 - 1), bmp.width / 4, bmp.height / 4))
    end
    @exported_file = "#{EXPORTEDMAPBASENAME}#{Time.now.strftime('%d_%m_%YT%H_%M_%S')}.png"  
    Dir.mkdir("MapExporter") if !Dir.exists?("MapExporter")
    pbMapExporterSavePng(@result, @exported_file)
    Input.update
  end
  
  def build_autotile(bitmap, x, y, id)
    autotile = @autotiles[id / 48 - 1]
    return unless autotile
    if autotile.height == 32
      bitmap.blt(x,y,autotile,Rect.new(0,0,32,32))
    else
      id %= 48
      tiles = TileDrawingHelper::AUTOTILE_PATTERNS[id >> 3][id & 7]
      src = Rect.new(0,0,0,0)
      halfTileWidth = halfTileHeight = halfTileSrcWidth = halfTileSrcHeight = 32 >> 1
      for i in 0...4
        tile_position = tiles[i] - 1
        src.set((tile_position % 6) * halfTileSrcWidth,
           (tile_position / 6) * halfTileSrcHeight, halfTileSrcWidth, halfTileSrcHeight)
        bitmap.blt(i % 2 * halfTileWidth + x, i / 2 * halfTileHeight + y,
            autotile, src)
      end
    end
  end
end

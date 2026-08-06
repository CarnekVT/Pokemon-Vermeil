#===============================================================================
# [VERMEIL] Visual 2.5D - 013_Heightmap.rb
# CAMARA 3D / RELIEVE REAL DEL TERRENO (nuevo, distinto al render plano previo)
# Referencia: H-Mode7.update_camera (V.1.4.2) y Neo Mode 7 cam altitude.
#
# Un PNG de relieve (Graphics/Heightmaps/Heightmap_XXX.png, XXX = id del mapa)
# guarda la altura del terreno por pixel (0=negro, 255=blanco). Este modulo:
#   1) Carga y cachea el heightmap por mapa.
#   2) Eleva el suelo: las filas de pantalla se desplazan en Y segun el relieve
#      que atraviesan (proyeccion en picada mas alta si el terreno sube).
#   3) Mueve la camara (altura del ojo) siguiendo la elevacion bajo el jugador,
#      interpolada con Config::ALTITUDE_SMOOTH.
#
# Es OPT-IN: solo actua en mapas que tengan un heightmap. Sin PNG, no cambia
# nada del render anterior.
#===============================================================================
module Mode7
  module Heightmap
    module_function

    # Obtiene (o carga y cachea) la tabla de alturas del mapa actual.
    # Devuelve un Array[Array[Float]] [x][y] con la altura en px de mundo,
    # o nil si no hay heightmap para el mapa.
    def data
      return @data if @data && @map_id == $game_map.map_id
      load_current
    end

    def dispose
      @bitmap&.dispose
      @bitmap = nil
      @data = nil
      @map_id = nil
    end

    # Altura (px de mundo) en el tile (tx, ty) del mapa actual.
    def altitude_at(x, y)
      d = data
      return 0 if !d
      d[[x, 0].max, [y, 0].max]
    end

    # Altura bajo el jugador (px de mundo).
    def player_altitude
      return 0 if !$game_player
      tx = $game_player.x
      ty = $game_player.y
      return altitude_at(tx, ty)
    end

    # La altura actual aplicada a la camara (px de mundo), suavizado.
    def camera_altitude
      return @camera_altitude || 0
    end

    # Avanza el seguimiento suave de la camara hacia la altura del jugador.
    # Llamar cada frame desde Scene_Map cuando el heightmap este activo.
    def update_camera
      d = data
      return if !d
      target = player_altitude
      return if @camera_altitude.nil?
      @camera_altitude += (target - @camera_altitude) * Config::ALTITUDE_SMOOTH
      @camera_altitude = target if (target - @camera_altitude).abs < 0.5
    end

    # ------- carga y cache -------
    def load_current
      @bitmap&.dispose
      @data = nil
      @map_id = $game_map.map_id
      @camera_altitude = 0
      filename = sprintf("Graphics/%s/Heightmap_%03d.png",
        Config::HEIGHTMAP_FOLDER, @map_id)
      return nil if !safe_exist?(filename)
      bmp = Bitmap.new(filename)
      @bitmap = bmp
      build_data(bmp)
      @data
    rescue
      @data = nil
      nil
    end

    def safe_exist?(path)
      return FileTest.exist?(path)
    end

    # Reduce el PNG a una tabla de tierra. Re-muestrea a px por tile (nueva
    # altura en horizonte por pixel de mapa => altura por tile).
    def build_data(bmp)
      w = $game_map.width
      h = $game_map.height
      max = Config::HEIGHT_RANGE_PX
      scale = Config::HEIGHT_SCALE
      @data = Array.new(w) { Array.new(h, 0) }
      w.times do |tx|
        h.times do |ty|
          sx = ((tx + 0.5) * bmp.width / w.to_f).floor.clamp(0, bmp.width - 1)
          sy = ((ty + 0.5) * bmp.height / h.to_f).floor.clamp(0, bmp.height - 1)
          c = bmp.get_pixel(sx, sy)
          lum = (c.red + c.green + c.blue) / 3.0
          @data[tx][ty] = (lum / 255.0 * max * scale).round
        end
      end
    end
  end
end
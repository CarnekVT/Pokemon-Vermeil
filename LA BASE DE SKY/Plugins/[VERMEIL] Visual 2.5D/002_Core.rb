#===============================================================================
# [VERMEIL] Visual 2.5D - 002_Core.rb
#===============================================================================
module Mode7
  class << self
    attr_reader :zoom, :camera_zoom, :zoom_effect_override, :current_alpha,
                :sin, :distance_h, :cylindrical_radius, :projection_revision,
                :projection_override
    # Proyeccion forzada por mapa (nil = usar Config::PROJECTION).
    attr_accessor :map_projection
    # map_id del mapa al que el renderer resolvio indoor SOLO por terrain tags.
    # Permite que indoor_map?/contexto de angulo escuchen esa deteccion sin
    # depender de que un plugin de metadata exponga Outside/Outdoor.
    attr_accessor :tag_indoor_map_id

    def screen_w; return Settings::SCREEN_WIDTH; end
    def screen_h; return Settings::SCREEN_HEIGHT; end
    def center_x; return screen_w / 2; end

    def pivot_ratio
      return @pivot_override if !@pivot_override.nil?
      return Config::AFFINE_PIVOT_RATIO if affine_mode?
      Config::CYLINDRICAL_PIVOT_RATIO
    end

    def pivot_y; return (screen_h * pivot_ratio).round; end

    # Metadata del mapa actual. Acepta GameData, hashes de plugins y datos
    # expuestos por Game_Map.
    def map_metadata_candidates_for(map_id = nil)
      id = map_id
      id = $game_map.map_id if id.nil? && $game_map
      return [] if id.nil?

      candidates = []
      if defined?(GameData::MapMetadata)
        begin
          meta = GameData::MapMetadata.try_get(id)
          candidates << meta if meta
        rescue Exception
        end
        begin
          meta = GameData::MapMetadata.get(id)
          candidates << meta if meta && !candidates.include?(meta)
        rescue Exception
        end
      end

      if $game_map
        [:metadata, :map_metadata].each do |reader|
          next if !$game_map.respond_to?(reader)
          begin
            meta = $game_map.public_send(reader)
            candidates << meta if meta && !candidates.include?(meta)
          rescue Exception
          end
        end
        candidates << $game_map if !candidates.include?($game_map)
        begin
          raw_map = $game_map.instance_variable_get(:@map)
          candidates << raw_map if raw_map && !candidates.include?(raw_map)
        rescue Exception
        end
      end
      candidates
    end

    def map_metadata_for(map_id = nil)
      map_metadata_candidates_for(map_id).first
    end

    def metadata_bool(value)
      return value if value == true || value == false
      return true if value.is_a?(Numeric) && value.to_i != 0
      return false if value.is_a?(Numeric) && value.to_i == 0
      if value.is_a?(String) || value.is_a?(Symbol)
        text = value.to_s.strip.downcase
        return true if ["true", "yes", "1", "on"].include?(text)
        return false if ["false", "no", "0", "off"].include?(text)
      end
      nil
    end

    def metadata_outdoor_state(meta)
      return nil if !meta

      [:outdoor_map, :outdoor, :outside,
       :outdoor_map?, :outdoor?, :outside?].each do |reader|
        next if !meta.respond_to?(reader)
        begin
          value = metadata_bool(meta.public_send(reader))
          return value unless value.nil?
        rescue Exception
        end
      end

      if meta.respond_to?(:[])
        [
          :outdoor_map, :outdoor, :outside,
          "outdoor_map", "outdoor", "outside",
          "Outdoor", "Outside", "OutdoorMap"
        ].each do |key|
          begin
            value = metadata_bool(meta[key])
            return value unless value.nil?
          rescue Exception
          end
        end
      end

      [:@outdoor_map, :@outdoor, :@outside].each do |ivar|
        next if !meta.instance_variable_defined?(ivar)
        value = metadata_bool(meta.instance_variable_get(ivar))
        return value unless value.nil?
      end
      nil
    rescue Exception
      nil
    end

    def metadata_has_flag?(meta, flag)
      return false if !meta || !flag
      if meta.respond_to?(:has_flag?)
        begin
          return true if meta.has_flag?(flag)
        rescue Exception
        end
      end
      if meta.respond_to?(:flags)
        begin
          flags = meta.flags
          return flags.any? { |value| value.to_s.downcase == flag.to_s.downcase } if flags
        rescue Exception
        end
      end
      false
    end

    def indoor_map?(map_id = nil)
      id = map_id
      id = $game_map.map_id if id.nil? && $game_map
      if id && defined?(Config::INDOOR_MAP_IDS) &&
         Config::INDOOR_MAP_IDS.include?(id.to_i)
        return true
      end
      # Deteccion por terrain tags exclusivos de interior (IndoorWall/Border/
      # Prop). La resuelve el renderer al construir el mapa; sin esto un mapa
      # indoor solo-por-tags usaba el angulo outdoor y raster_affine = false.
      return true if @tag_indoor_map_id == id

      candidates = map_metadata_candidates_for(id)
      return true if candidates.any? { |meta| metadata_has_flag?(meta, Config::MAP_FLAG_INDOOR) }

      states = candidates.filter_map { |meta| metadata_outdoor_state(meta) }
      return true if states.include?(false)
      return false if states.include?(true)
      false
    end

    # Override manual de Debug. :auto devuelve el control a metadata/tags.
    def set_projection_mode(mode)
      normalized = mode.nil? ? nil : mode.to_sym
      normalized = nil if normalized == :auto
      return map_mode if normalized && ![:affine, :cylindrical].include?(normalized)

      @projection_override = normalized
      reset_caches
      renderer = $scene.instance_variable_get(:@map_renderer) if $scene.is_a?(Scene_Map)
      renderer.refresh if renderer && renderer.respond_to?(:refresh)
      map_mode
    end

    # Unicamente Affine o Cylindrical.
    def map_mode
      return @projection_override if [:affine, :cylindrical].include?(@projection_override)
      return :affine if indoor_map?
      return @map_projection if [:affine, :cylindrical].include?(@map_projection)
      mode = Config::PROJECTION
      [:affine, :cylindrical].include?(mode) ? mode : :cylindrical
    end

    def affine_mode?; map_mode == :affine; end
    def cylindrical_mode?; map_mode == :cylindrical; end

    def raster_tiles_map?(map_id = nil)
      return true if indoor_map?(map_id)
      map_metadata_candidates_for(map_id).any? do |meta|
        metadata_has_flag?(meta, Config::MAP_FLAG_RASTER_AFFINE)
      end
    end

    def raster_affine_mode?
      affine_mode? && raster_tiles_map?
    end

    def detect_map_projection(map_id)
      return :affine if indoor_map?(map_id)
      candidates = map_metadata_candidates_for(map_id)

      return :affine if candidates.any? { |meta| metadata_has_flag?(meta, Config::MAP_FLAG_RASTER_AFFINE) }
      return :affine if candidates.any? do |meta|
        metadata_has_flag?(meta, Config::MAP_FLAG_AFFINE) ||
          metadata_has_flag?(meta, Config::MAP_FLAG_AFFINE_LEGACY)
      end
      return :cylindrical if candidates.any? { |meta| metadata_has_flag?(meta, Config::MAP_FLAG_CYLINDRICAL) }
      nil
    end

    # Cantidad de curvatura activa. Se deriva directamente del angulo real de
    # camara, en vez de escalar DEFAULT_ALPHA. Esto evita que 30°/45° hagan
    # explotar la curva por multiplicadores 2x/3x.
    def cylindrical_angle_scale
      return 0.0 if !@current_alpha
      Math.sin(@current_alpha.to_f * Math::PI / 180.0).clamp(0.0, 1.0)
    end

    # Pitch global de la camara. A 0° el mapa es top-down; al aumentar el
    # angulo se comprime TODO el eje Y, no solo la perspectiva interna de tiles.
    def camera_pitch_scale
      # La escala global debe permanecer 1.0. El angulo modifica la forma de
      # la proyeccion Cylindrical, no funciona como un segundo zoom oculto.
      1.0
    end

    # Escala uniforme de billboards/bloques al cambiar el angulo.
    # Esto hace que la camara afecte tambien personajes, walls y P2+ sin
    # aplastar el bitmap en X/Y por separado.
    def camera_billboard_pitch_scale
      # Walls/personajes no cambian de tamano solo por variar el angulo.
      1.0
    end

    # Media circunferencia top-down SIN punto de inflexion visible.
    #
    # Se usa una sola rama de la circunferencia:
    #   raw(phi) = -cos(phi)
    #   phi      = CYLINDRICAL_PHASE + theta
    #
    # La curva se normaliza para que g(0)=0 y g'(0)=1. Durante todo el viewport
    # phi permanece entre CYLINDRICAL_MIN y CYLINDRICAL_MAX, ambos dentro de (0, PI/2).
    # Por tanto la derivada es siempre positiva y la curvatura siempre convexa.
    def cylindrical_curve(theta)
      phase = Config::CYLINDRICAL_PHASE.to_f
      min_phi = Config::CYLINDRICAL_MIN.to_f.clamp(0.02, Math::PI / 2.0 - 0.04)
      max_phi = Config::CYLINDRICAL_MAX.to_f.clamp(min_phi + 0.02, Math::PI / 2.0 - 0.02)
      norm = Math.sin(phase)
      norm = 1.0 if norm.abs < 1.0e-6

      phi = phase + theta.to_f
      base = -Math.cos(phase)

      if phi < min_phi
        edge = -Math.cos(min_phi) - base
        return (edge + (phi - min_phi) * Math.sin(min_phi)) / norm
      elsif phi > max_phi
        edge = -Math.cos(max_phi) - base
        return (edge + (phi - max_phi) * Math.sin(max_phi)) / norm
      end

      (-Math.cos(phi) - base) / norm
    end

    # Derivada exacta de cylindrical_curve. Se usa para invertir la proyeccion durante
    # transiciones suaves de angulo/zoom.
    def cylindrical_curve_derivative(theta)
      phase = Config::CYLINDRICAL_PHASE.to_f
      min_phi = Config::CYLINDRICAL_MIN.to_f.clamp(0.02, Math::PI / 2.0 - 0.04)
      max_phi = Config::CYLINDRICAL_MAX.to_f.clamp(min_phi + 0.02, Math::PI / 2.0 - 0.02)
      norm = Math.sin(phase)
      norm = 1.0 if norm.abs < 1.0e-6
      phi = phase + theta.to_f
      return Math.sin(min_phi) / norm if phi < min_phi
      return Math.sin(max_phi) / norm if phi > max_phi
      Math.sin(phi) / norm
    end

    def cylindrical_directional_scale(theta, strength)
      strength = strength.to_f
      return 1.0 if strength.abs < 1.0e-9
      den = 1.0 - strength * theta.to_f
      den = 0.25 if den < 0.25
      k = 1.0 / den
      return 0.60 if k < 0.60
      return 1.50 if k > 1.50
      k
    end

    # Escala horizontal del plano. Con 0 mantiene habitaciones rectangulares.
    # La curvatura Cylindrical afecta profundidad Y; no forzar derivada X evita que las
    # filas del borde se cierren y dejen huecos fuera del mapa.
    def cylindrical_width_scale(theta)
      cylindrical_directional_scale(theta.to_f * cylindrical_angle_scale,
                            Config::CYLINDRICAL_WIDTH_PERSPECTIVE)
    end

    # Escala de personajes/eventos por profundidad. Puede variar suavemente
    # sin afectar la proporcion interna de los tiles del mapa.
    def cylindrical_sprite_scale(theta)
      cylindrical_directional_scale(theta.to_f * cylindrical_angle_scale,
                            Config::CYLINDRICAL_SPRITE_SCALE)
    end

    # Escala UNIFORME de objetos verticales. Terrain usa curvatura propia, pero
    # walls/priorities usan este canal separado para no encoger piezas altas por
    # celda. zoom_x == zoom_y siempre conserva pixel art y silueta.
    def tile_billboard_scale_for_world_y(wy)
      return @zoom if !cylindrical_mode?
      strength = Config::CYLINDRICAL_BILLBOARD_PERSPECTIVE
      @zoom * camera_billboard_pitch_scale *
        cylindrical_directional_scale(cylindrical_theta_for_world_y(wy), strength)
    end

    def cylindrical_ground_y_scale
      v = Config::CYLINDRICAL_GROUND_Y_SCALE.to_f
      v <= 0.01 ? 0.01 : v
    end

    # Angulo de profundidad a partir de una coordenada Y del mundo, sin mezclar
    # elevacion. Este theta representa exclusivamente distancia sobre el suelo.
    def cylindrical_theta_for_world_y(wy)
      ry = (wy.to_f - projection_cam_y - pivot_y)
      (ry * @zoom * cylindrical_ground_y_scale) / @cylindrical_radius
    end

    # Escala visual de un billboard situado en la Y indicada.
    def object_scale_for_world_y(wy)
      return @zoom if !cylindrical_mode?
      @zoom * camera_billboard_pitch_scale *
        cylindrical_sprite_scale(cylindrical_theta_for_world_y(wy))
    end

    # Escala del eje vertical Z. IMPORTANTE: no usa CYLINDRICAL_SPRITE_SCALE.
    # El error de Phase 4 era ancho~=1.0 pero alto<1.0, aplastando muros.
    # Un tile vertical siempre conserva su aspect ratio; la perspectiva del
    # terreno viene de Y, no de deformar la cara del objeto.
    def vertical_scale_for_world_y(wy)
      return object_scale_for_world_y(wy) if !cylindrical_mode?
      tile_billboard_scale_for_world_y(wy) * Config::CYLINDRICAL_VERTICAL_SCALE.to_f
    end

    # Affine aporta inclinacion/convergencia; el residuo circular conserva la
    # curvatura propia de Cylindrical sin volverlo casi plano cerca del pivot.
    def cylindrical_ground_offset_for_ry(ry)
      ground_ry = ry.to_f * cylindrical_ground_y_scale
      flat = ground_ry * @zoom
      return flat if @cylindrical_radius.to_f.abs < 1.0e-6

      theta = flat / @cylindrical_radius
      mix = cylindrical_angle_scale * Config::CYLINDRICAL_CURVE_MIX.to_f
      affine = affine_depth_scale(ground_ry)
      curved = @cylindrical_radius * cylindrical_curve(theta)
      affine * (1.0 - mix) + curved * mix
    end

    # Theta correspondiente a una fila de pantalla. Se resuelve por Newton
    # sobre la MISMA mezcla usada por cylindrical_ground_offset_for_ry, de modo que
    # ground/hscale/prioridades siguen sincronizados durante una transición.
    def cylindrical_theta_for_row(sy)
      radius = @cylindrical_radius.to_f
      return 0.0 if radius.abs < 1.0e-6

      mix = cylindrical_angle_scale * Config::CYLINDRICAL_CURVE_MIX.to_f
      target = sy.to_f - pivot_y
      zoom = @zoom.to_f
      return 0.0 if zoom.abs < 1.0e-9

      theta = affine_depth_unscale(target) * zoom / radius
      10.times do
        ground_ry = theta * radius / zoom
        curve = cylindrical_curve(theta)
        f = affine_depth_scale(ground_ry) * (1.0 - mix) +
            radius * curve * mix - target
        d = affine_depth_derivative(ground_ry) * radius / zoom * (1.0 - mix) +
            radius * cylindrical_curve_derivative(theta) * mix
        break if d.abs < 1.0e-8
        step = f / d
        theta -= step
        break if step.abs < 1.0e-7
      end
      theta
    end
    # El renderer 2.5D permanece activo incluso en estado OFF.
    # OFF significa camara a 0 grados/zoom 1 (look vanilla), no volver al
    # TilemapRenderer. Esto evita reconstrucciones y mantiene transiciones de
    # angulo realmente suaves.
    def effective_mode_blend; 1.0; end
    def rendering_now?; true; end


    def terrain_camera_lift
      @terrain_camera_lift || 0.0
    end

    # Valor cuantizado usado por toda la proyeccion. Ground, walls y prioridad
    # cambian juntos; usar aqui el interpolado crudo movia walls cada frame
    # mientras el bitmap del suelo esperaba su siguiente repintado.
    def terrain_camera_render_lift
      return @terrain_camera_render_lift if !@terrain_camera_render_lift.nil?
      terrain_camera_lift
    end

    # Intensidad visual de profundidad. No modifica display_y, cam_y ni las
    # coordenadas logicas del mapa.
    def projection_cam_y
      cam_y
    end

    def terrain_camera_lift_for_tag(tag)
      return 0.0 if !tag || !tag.respond_to?(:id)
      (Config::TERRAIN_TAG_CAMERA_LIFT[tag.id] || 0).to_f
    end

    def terrain_tag_at(x, y)
      return nil if !$game_map
      return $map_factory.getTerrainTagFromCoords($game_map.map_id, x, y) if $map_factory
      $game_map.terrain_tag(x, y)
    rescue
      nil
    end

    # ElevatedWall es la excepcion al tag logico del jugador: un suelo puede
    # conservar Grass para mecanicas y llevar Mountains en otra capa visual.
    # Solo se acepta si ese tag fue declarado explicitamente ElevatedWall.
    def terrain_camera_elevated_wall_lift_at(x, y)
      renderer = $scene.instance_variable_get(:@map_renderer) if $scene
      return nil if !renderer || !renderer.is_a?(Mode7Renderer) || renderer.disposed?
      entries = renderer.instance_variable_get(:@entry_cache)
      cell = entries && entries[[x, y]]
      return nil if !cell
      cell.filter_map do |entry|
        tag = renderer.send(:terrain_tag_for_entry, entry)
        next if !tag || !Config::ELEVATED_WALL_TERRAIN_TAG_HEIGHT.key?(tag.id)
        terrain_camera_lift_for_tag(tag)
      end.max || 0.0
    rescue
      nil
    end

    def terrain_camera_elevated_wall_tags_at(x, y)
      renderer = $scene.instance_variable_get(:@map_renderer) if $scene
      return [] if !renderer || !renderer.is_a?(Mode7Renderer) || renderer.disposed?
      entries = renderer.instance_variable_get(:@entry_cache)
      cell = entries && entries[[x, y]]
      return [] if !cell
      cell.filter_map do |entry|
        tag = renderer.send(:terrain_tag_for_entry, entry)
        tag.id if tag && Config::ELEVATED_WALL_TERRAIN_TAG_HEIGHT.key?(tag.id)
      end.uniq
    rescue
      []
    end

    def terrain_camera_lift_at(x, y)
      logical_lift = terrain_camera_lift_for_tag(terrain_tag_at(x, y))
      elevated_lift = terrain_camera_elevated_wall_lift_at(x, y)
      [logical_lift, elevated_lift || 0.0].max
    end

    def terrain_camera_lift_target
      return 0.0 if Config::TERRAIN_TAG_CAMERA_LIFT.empty? || !$game_player || !$game_map
      player = $game_player
      target_x = player.x
      target_y = player.y
      target_lift = terrain_camera_lift_at(target_x, target_y)
      return target_lift if !player.moving?

      start_x = player.instance_variable_get(:@move_initial_x)
      start_y = player.instance_variable_get(:@move_initial_y)
      return target_lift if start_x.nil? || start_y.nil?
      progress = []
      if target_x != start_x
        real_x = player.real_x.to_f / Game_Map::REAL_RES_X
        progress.push((real_x - start_x).abs / (target_x - start_x).abs.to_f)
      end
      if target_y != start_y
        real_y = player.real_y.to_f / Game_Map::REAL_RES_Y
        progress.push((real_y - start_y).abs / (target_y - start_y).abs.to_f)
      end
      return target_lift if progress.empty?
      t = (progress.sum / progress.length.to_f).clamp(0.0, 1.0)
      start_lift = terrain_camera_lift_at(start_x, start_y)
      start_lift + (target_lift - start_lift) * t
    rescue
      @terrain_camera_target = 0.0
    end

    # Al crear el renderer del mapa, la partida ya tiene coordenada y terrain
    # tag definitivos. Arrancar desde ese target evita una animacion falsa
    # 0 -> Mountains al cargar/transferir mapa.
    def snap_terrain_camera_lift_to_target
      target = active_now? ? terrain_camera_lift_target : 0.0
      render_step = Config::TERRAIN_TAG_CAMERA_LIFT_RENDER_STEP.to_f
      render_step = 1.0 if render_step <= 0.0
      @terrain_camera_lift_render_key = (target / render_step).round
      @terrain_camera_render_lift = target
      @terrain_camera_lift_update_time = System.uptime
      return if (terrain_camera_lift - target).abs < 0.01
      @terrain_camera_lift = target
      @projection_revision = (@projection_revision || 0) + 1
      reset_caches
    end

    def terrain_camera_lift_debug_text
      return _INTL("Sin jugador/mapa.") if !$game_player || !$game_map
      tag = $game_player.pbTerrainTag
      logical = tag ? tag.id.to_s : "None"
      elevated = terrain_camera_elevated_wall_tags_at($game_player.x, $game_player.y)
      elevated_text = elevated.empty? ? "ninguno" : elevated.join(", ")
      target = terrain_camera_lift_target.round(2)
      current = terrain_camera_lift.round(2)
      _INTL("Logico: {1}\nElevatedWall: {2}\nLift target: {3}\nLift actual: {4}",
            logical, elevated_text, target, current)
    rescue
      _INTL("No se pudo leer el lift 2.5D.")
    end

    def update_terrain_camera_lift
      target = active_now? ? terrain_camera_lift_target : 0.0
      current = terrain_camera_lift
      now = System.uptime
      last_time = @terrain_camera_lift_update_time || (now - 1.0 / 60.0)
      @terrain_camera_lift_update_time = now
      frame_scale = ((now - last_time) * 60.0).clamp(0.25, 6.0)
      smooth = Config::TERRAIN_TAG_CAMERA_LIFT_SMOOTH.to_f.clamp(0.01, 1.0)
      frame_smooth = 1.0 - ((1.0 - smooth)**frame_scale)
      step = (target - current) * frame_smooth
      # Paso dependiente de tiempo: una caida de FPS ya no alarga la bajada.
      max_step = Config::TERRAIN_TAG_CAMERA_LIFT_MAX_STEP.to_f
      max_step = 0.75 if max_step <= 0.0
      step = step.clamp(-max_step * frame_scale, max_step * frame_scale)
      value = current + step
      value = target if (target - value).abs < 0.05
      return if (value - current).abs < 0.01
      @terrain_camera_lift = value

      render_step = Config::TERRAIN_TAG_CAMERA_LIFT_RENDER_STEP.to_f
      render_step = 1.0 if render_step <= 0.0
      render_key = (value / render_step).round
      final_value = (value - target).abs < 0.01
      return if !final_value && render_key == @terrain_camera_lift_render_key
      @terrain_camera_lift_render_key = render_key
      @terrain_camera_render_lift = value
      @projection_revision = (@projection_revision || 0) + 1
      reset_caches
      invalidate_renderer_ground
    end


    def configure(alpha = nil, zoom = nil, distance_h = nil, cylindrical_radius = nil)
      @current_alpha = (alpha || @current_alpha || context_default_alpha).to_f
      @camera_zoom = (zoom || @camera_zoom || Config::DEFAULT_ZOOM).to_f
      @zoom = (@zoom_effect_override || @camera_zoom).to_f
      @distance_h = (distance_h || @distance_h || Config::DISTANCE_H).to_f
      @cylindrical_radius = (
        cylindrical_radius || @cylindrical_radius || Config::CYLINDRICAL_RADIUS
      ).to_f
      @projection_revision = (@projection_revision || 0) + 1

      @a = @current_alpha * Math::PI / 180.0
      @cos = Math.cos(@a)
      @sin = Math.sin(@a)
      @dh = @distance_h
      reset_caches
    end

    # Reinicia las caches de proyeccion (al cambiar mapa/camara/zoom/pivot).
    def reset_caches
      @hscale_cache ||= {}
      @hscale_cache.clear
      @world_y_cache ||= {}
      @world_y_cache.clear
      @affine_row_world_offset_cache ||= {}
      @affine_row_world_offset_cache.clear
      @cylindrical_row_world_offset_cache ||= {}
      @cylindrical_row_world_offset_cache.clear
      @project_y_cache ||= {}
      @project_y_cache.clear
      @projection_cache_cam_y = nil
    end

    # project_y/world_y dependen de la posicion exacta de camara. Usar floor
    # los hacia saltar al cruzar cada pixel durante scroll suave vertical.
    def refresh_camera_projection_cache
      current_cam_y = projection_cam_y
      return if @projection_cache_cam_y == current_cam_y
      @projection_cache_cam_y = current_cam_y
      # project_y depende de cam_y. La inversa por fila no: cacheamos solo el
      # offset relativo y sumamos cam_y al final.
      @project_y_cache.clear if @project_y_cache
    end





    # Parametros Affine del ZIP pre-curve.
    def affine_depth_value; Config::AFFINE_DEPTH.to_f; end
    def affine_slope_value; Config::AFFINE_SLOPE.to_f; end
    def affine_zoom_value; Config::AFFINE_ZOOM.to_f; end
    def affine_convergence_value; Config::AFFINE_CONVERGENCE.to_f; end

    def hscale(sy)
      @hscale_cache ||= {}
      return @hscale_cache[sy] if @hscale_cache.key?(sy)
      result = _hscale_uncached(sy)
      @hscale_cache[sy] = result
      result
    end

    def base_hscale(sy)
      hscale(sy)
    end

    def _hscale_uncached(sy)
      if cylindrical_mode?
        theta = cylindrical_theta_for_row(sy)
        ground_ry = theta * @cylindrical_radius / @zoom
        return affine_depth_derivative(ground_ry) * cylindrical_width_scale(theta)
      end

      # Copia de la rama Affine del ZIP pre-curve.
      t = affine_depth_value
      if t > 0
        heff = @dh / t
        ry = affine_depth_unscale((sy - pivot_y).to_f)
        zi = @zoom * ry
        d = heff - zi * @sin
        return 0.0 if d.abs < 1.0e-9
        return @zoom * heff * heff * @cos / (d * d)
      end

      screen_t = (sy / screen_h.to_f) - 0.5
      affine_zoom_value *
        (1.0 + affine_convergence_value * 2.0 * screen_t)
    end

    def horizon_row
      return 0.0 if cylindrical_mode?
      t = affine_depth_value
      return 0 if t <= 0 || @sin.abs < 1.0e-9
      heff = @dh / t
      pivot_y - heff * @cos / @sin
    end

    # Niebla de profundidad: 0 en el pivot del jugador, FOG_MAX_ALPHA en el
    # horizonte. Interpola por fila de pantalla (screen_y). Consultada por
    # suelo/muros/personajes para difuminar lo lejano.
    def fog_alpha(screen_y)
      return 0 if !Config::FOG_ENABLED
      delta = pivot_y - horizon_row
      return 0 if delta <= 0
      t = (pivot_y - screen_y.to_f) / delta
      t = 0.0 if t < 0.0
      t = 1.0 if t > 1.0
      (t * Config::FOG_MAX_ALPHA).round
    end

    def cam_x
      return 0 if !$game_map
      ($game_map.display_x.to_f / Game_Map::X_SUBPIXELS) + center_x
    end

    def cam_y
      return 0 if !$game_map
      base = $game_map.display_y.to_f / Game_Map::Y_SUBPIXELS
      return base - camera_elevation if Config::HEIGHTMAP_ENABLED
      base
    end

    def camera_elevation
      return 0 if !Config::HEIGHTMAP_ENABLED
      Mode7::Heightmap.camera_altitude
    rescue
      0
    end

    # Matematica Affine exacta del ZIP pre-curve.
    def affine_depth_scale(ry)
      t = affine_depth_value
      slope = affine_slope_value
      return slope * ry.to_f if t <= 0

      heff = @dh / t
      yi = @zoom * ry.to_f
      d = heff - yi * @sin
      return slope * ry.to_f if d <= 0.0
      (heff * yi * @cos) / d
    end

    def affine_depth_unscale(so)
      t = affine_depth_value
      slope = affine_slope_value
      return so.to_f / slope if t <= 0

      heff = @dh / t
      den = so.to_f * @sin + heff * @cos
      return so.to_f / slope if den.abs < 1.0e-9
      yi = so.to_f * heff / den
      yi / @zoom
    end

    def affine_depth_derivative(ry)
      t = affine_depth_value
      slope = affine_slope_value
      return slope if t <= 0

      heff = @dh / t
      yi = @zoom * ry.to_f
      d = heff - yi * @sin
      return slope if d <= 0.0
      @zoom * heff * heff * @cos / (d * d)
    end

    def _cylindrical_project(wx, wy, elevation = 0)
      rx = wx.to_f - cam_x
      ry = wy.to_f - projection_cam_y - pivot_y
      theta = cylindrical_theta_for_world_y(wy)
      sy_ground = pivot_y + cylindrical_ground_offset_for_ry(ry)

      scale_x = affine_depth_derivative(ry * cylindrical_ground_y_scale) *
                cylindrical_width_scale(theta)
      sx = center_x + rx * scale_x
      sy = sy_ground - elevation.to_f * vertical_scale_for_world_y(wy)
      [sx, sy]
    end

    def project(wx, wy, elevation = 0)
      return _cylindrical_project(wx, wy, elevation) if cylindrical_mode?

      rx = wx.to_f - cam_x
      ry = (wy.to_f - projection_cam_y - elevation.to_f) - pivot_y
      sy = pivot_y + affine_depth_scale(ry)
      sx = center_x + hscale(sy) * rx
      [sx, sy]
    end

    def project_y(wy, elevation = 0)
      @project_y_cache ||= {}
      refresh_camera_projection_cache
      key = [wy, elevation]
      return @project_y_cache[key] if @project_y_cache.key?(key)
      result = _project_y_uncached(wy, elevation)
      @project_y_cache[key] = result
      @project_y_cache.clear if @project_y_cache.size > 2000
      result
    end

    def overworld_project_y(wy, elevation = 0)
      project_y(wy, elevation)
    end

    def overworld_depth_z(wy, height = 0)
      depth_z(wy, 0, height)
    end

    def _cylindrical_project_y(wy, elevation = 0)
      ry = wy.to_f - projection_cam_y - pivot_y
      sy_ground = pivot_y + cylindrical_ground_offset_for_ry(ry)
      sy_ground - elevation.to_f * vertical_scale_for_world_y(wy)
    end

    def _project_y_uncached(wy, elevation = 0)
      return _cylindrical_project_y(wy, elevation) if cylindrical_mode?
      pivot_y + affine_depth_scale(
        (wy.to_f - projection_cam_y - elevation.to_f) - pivot_y
      )
    end

    # Unidad Z de prioridad.
    #
    # Geometricamente sigue el alto de la fila proyectada para responder a
    # cambios de angulo/zoom, pero NUNCA baja de PRIORITY_Z_MIN_STEP cuando
    # zoom <= 1.0. De ese modo P1/P2/P4 conserva la precedencia RPG Maker a
    # zoom 0.9, 0.8, etc. y no queda por debajo del personaje por redondeo.
    def priority_screen_step(wy)
      # La prioridad de RPG Maker es logica, no perspectiva. Pero si el paso Z
      # NO reacciona al angulo, al inclinarlo las filas se comprimen y los
      # paredones de un lado llegan a pisar las prioridades de otro: un P1 del
      # mismo objeto pasa delante/atras segun la fila en la que caiga.
      min_step = Config::PRIORITY_Z_MIN_STEP.to_f
      floor = project_y(wy.to_f, 0)
      ceil = project_y(wy.to_f - Game_Map::TILE_HEIGHT, 0)
      return min_step if !floor || !ceil
      step = (floor - ceil).abs
      return min_step if step < min_step
      step
    end

    # Solape de raster/sprite para prioridad. Crece con zoom y con la cantidad
    # de inclinacion activa, pero queda limitado para no emborronar pixel art.
    def priority_edge_overlap
      base = Config::PRIORITY_EDGE_OVERLAP.to_f
      maxv = Config::PRIORITY_EDGE_OVERLAP_MAX.to_f
      z = [(@zoom || 1.0).to_f, 0.25].max
      angle = cylindrical_mode? ? cylindrical_angle_scale.abs : (@sin || 0.0).abs
      factor = 0.75 + [angle, 1.5].min * 0.50
      [[base * z * factor, 0.5].max, maxv].min
    end

    # Clave de profundidad compatible con RPG Maker, pero adaptada a la
    # proyeccion ACTUAL. Priority N avanza N altos-de-fila proyectados desde
    # su base. Al interpolar angulo/zoom, el Z cambia en el mismo frame que
    # cambia la geometria y no hay saltos de orden ni prioridad "encogida".
    def depth_z(wy, priority = 0, bias = 0)
      sy = project_y(wy.to_f, 0)
      return bias.to_i if sy.nil?
      p = priority.to_i
      sy += priority_screen_step(wy) * p if p > 0
      sy.round + bias.to_i
    end
    def world_y_for_row(sy)
      return _cylindrical_world_y_for_row(sy) if cylindrical_mode?

      @affine_row_world_offset_cache ||= {}
      offset = @affine_row_world_offset_cache[sy]
      if offset.nil?
        offset = pivot_y + affine_depth_unscale(sy - pivot_y)
        @affine_row_world_offset_cache[sy] = offset
      end
      projection_cam_y + offset
    end

    def _cylindrical_world_y_for_row(sy)
      ground_scale = cylindrical_ground_y_scale
      denom = @zoom * ground_scale
      return projection_cam_y + pivot_y if denom.abs < 1.0e-9

      @cylindrical_row_world_offset_cache ||= {}
      key = [
        sy, cylindrical_angle_scale, @zoom,
        ground_scale, @cylindrical_radius
      ]
      offset = @cylindrical_row_world_offset_cache[key]
      if offset.nil?
        theta = cylindrical_theta_for_row(sy)
        flat = theta * @cylindrical_radius
        ry = flat / denom
        offset = pivot_y + ry
        @cylindrical_row_world_offset_cache[key] = offset
      end
      projection_cam_y + offset
    end

    def override; return @override; end
    def override=(value); @override = value; end

    def active_now?
      return @override if !@override.nil?
      return false if !$game_switches
      return $game_switches[Config::SWITCH_ID] if Config::SWITCH_ID > 0
      return $game_switches[Config::PLAYER_SWITCH] if Config::PLAYER_SWITCH > 0
      Config::DEFAULT_ENABLED
    end

    def toggle_debug
      # Toggle manual binario. No volver a Auto: F3/debug siempre deja estado
      # explicito para probar el mismo mapa con 2.5D ON u OFF.
      @override = @override == true ? false : true
    end

    def override_state
      return _INTL("ON") if @override
      return _INTL("OFF")
    end

    def indoor_alpha
      @indoor_alpha = Config::INDOOR_DEFAULT_ALPHA.to_f if @indoor_alpha.nil?
      @indoor_alpha
    end

    def outdoor_alpha
      @outdoor_alpha = Config::OUTDOOR_DEFAULT_ALPHA.to_f if @outdoor_alpha.nil?
      @outdoor_alpha
    end

    def context_default_alpha
      indoor_map? ? indoor_alpha : outdoor_alpha
    end

    def set_context_angle(context, value, frames = Config::CAMERA_ANGLE_SMOOTH_FRAMES)
      angle = value.to_f.clamp(0.0, 89.0)
      case context.to_sym
      when :indoor
        @indoor_alpha = angle
        set_camera(angle, camera_zoom, frames, distance_h, cylindrical_radius) if indoor_map?
      when :outdoor
        @outdoor_alpha = angle
        set_camera(angle, camera_zoom, frames, distance_h, cylindrical_radius) if !indoor_map?
      end
      angle
    end

    def set_camera(target_alpha, target_zoom, frames = 60, target_distance_h = nil, target_cylindrical_radius = nil)
      @target_alpha = target_alpha.to_f
      @target_zoom = target_zoom.to_f
      @target_distance_h = (target_distance_h || @distance_h || Config::DISTANCE_H).to_f
      @target_cylindrical_radius = (target_cylindrical_radius || @cylindrical_radius || Config::CYLINDRICAL_RADIUS).to_f
      @transition_frames = frames.to_i

      if @transition_frames <= 0
        configure(@target_alpha, @target_zoom, @target_distance_h, @target_cylindrical_radius)
      else
        @step_alpha = (@target_alpha - @current_alpha) / @transition_frames
        @step_zoom = (@target_zoom - @camera_zoom) / @transition_frames
        @step_distance_h = (@target_distance_h - @distance_h) / @transition_frames
        @step_cylindrical_radius = (@target_cylindrical_radius - @cylindrical_radius) / @transition_frames
      end
    end

    # Cambia el angulo con la misma interpolacion usada por zoom/radio.
    # Todas las prioridades consultan la proyeccion actual cada frame, por lo
    # que pueden acompañar esta transicion sin reconstruir el mapa.
    def set_angle(target_alpha, frames = Config::CAMERA_ANGLE_SMOOTH_FRAMES)
      value = target_alpha.to_f.clamp(0.0, 89.0)
      if indoor_map?
        @indoor_alpha = value
      else
        @outdoor_alpha = value
      end
      set_camera(value, camera_zoom, frames, distance_h, cylindrical_radius)
      value
    end

    # Comando para la terminal F3: Mode7.set_zoom(1.50)
    # ponytail: un unico setter cubre terminal y menu; exponer presets solo si
    # el ajuste manual deja de ser suficiente.
    def set_zoom(target_zoom, frames = Config::CAMERA_ZOOM_SMOOTH_FRAMES)
      min_zoom = Config::CAMERA_ZOOM_MIN.to_f
      max_zoom = Config::CAMERA_ZOOM_MAX.to_f
      zoom_value = target_zoom.to_f.clamp(min_zoom, max_zoom)
      set_camera(current_alpha, zoom_value, frames, distance_h, cylindrical_radius)
      return zoom_value
    end

    def zoom_effect_override=(value)
      value = value.to_f.clamp(Config::CAMERA_ZOOM_MIN.to_f,
                               Config::CAMERA_ZOOM_MAX.to_f) if !value.nil?
      current = @zoom_effect_override
      return if current.nil? && value.nil?
      return if current && value && (current - value).abs < 0.001
      @zoom_effect_override = value
      configure(@current_alpha, @camera_zoom, @distance_h, @cylindrical_radius)
      invalidate_renderer_ground
    end

    def update_transition
      if @transition_frames && @transition_frames > 0
        @transition_frames -= 1
        if @transition_frames == 0
          configure(@target_alpha, @target_zoom, @target_distance_h, @target_cylindrical_radius)
        else
          configure(@current_alpha + @step_alpha,
                    @camera_zoom + @step_zoom,
                    @distance_h + @step_distance_h,
                    @cylindrical_radius + @step_cylindrical_radius)
        end
        invalidate_renderer_ground
      end
    end

    def invalidate_renderer_ground
      return if !$scene.is_a?(Scene_Map)
      renderer = $scene.instance_variable_get(:@map_renderer)
      renderer.invalidate_ground if renderer.respond_to?(:invalidate_ground)
    end
  end

  configure(Config::OUTDOOR_DEFAULT_ALPHA, Config::DEFAULT_ZOOM)
end

class Scene_Map
  alias_method :_VERMEIL_25D_core_update, :update unless method_defined?(:_VERMEIL_25D_core_update)
  def update
    _VERMEIL_25D_core_update
    # 005_ModeTransition.rb actualiza la interpolacion de camara una sola vez
    # por frame, tanto al encender como al ir a angulo 0.
    Mode7.update_terrain_camera_lift if !Mode7::Config::TERRAIN_TAG_CAMERA_LIFT.empty?
  end
end

# Deteccion de interiores: al cargar un mapa se resuelve :affine/:cylindrical.
# Mode7RasterAffine conserva compatibilidad, pero ahora significa :affine +
# politica raster de tiles, no una proyeccion distinta.
class Game_Map
  alias_method :_VERMEIL_25D_core_setup, :setup unless method_defined?(:_VERMEIL_25D_core_setup)

  def setup(map_id)
    old_mode = Mode7.map_projection
    _VERMEIL_25D_core_setup(map_id)
    # El flag indoor-por-tags pertenece al mapa que se acaba de cargar; el
    # renderer lo pondra en su build si detecta tags indoor. Aqui solo se evita
    # que un valor viejo de otro mapa contamine esta resolucion.
    Mode7.tag_indoor_map_id = nil
    # Resolver DESPUES del setup: aqui ya existen $game_map y cualquier
    # metadata adicional inyectada por Maker Studio/plugins.
    Mode7.map_projection = Mode7.detect_map_projection(map_id)

    # Cada contexto conserva su propio angulo.
    target_alpha = Mode7.active_now? ? Mode7.context_default_alpha : 0.0
    Mode7.set_camera(
      target_alpha, Mode7.camera_zoom, 0,
      Mode7.distance_h, Mode7.cylindrical_radius
    )

    if Mode7.map_projection != old_mode
      Mode7.reset_caches
      Mode7.invalidate_renderer_ground rescue nil
    end
  end
end

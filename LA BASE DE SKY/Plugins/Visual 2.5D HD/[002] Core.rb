#===============================================================================
# Visual 2.5D HD - Nucleo
#-------------------------------------------------------------------------------
# La proyeccion. Todo el escenario pasa por las mismas dos funciones, que es lo
# que garantiza que no aparezcan cortes entre tiles vecinos:
#
#   scale_at(y)   Cuanto se agranda lo que hay en la fila de pantalla "y". Vale 1
#                 arriba del todo (lo mas lejano) y crece hacia abajo.
#   project_y(y)  Donde acaba dibujandose esa fila. Es la integral de scale_at,
#                 asi que dos filas contiguas comparten exactamente su borde.
#
# El punto de fuga sale solo: al aplicar scale_at en horizontal alrededor del
# centro de la pantalla, las filas lejanas se estrechan y las cercanas se abren.
#
# La proyeccion se recentra en el jugador para que siga apareciendo en mitad de
# la pantalla.
#===============================================================================
module Visual25D
  # Hueco que se le deja al personaje por encima del tile con prioridad que se
  # apoya en su misma casilla. Tiene que quedar por debajo de una casilla entera,
  # para que el tile apoyado en la fila de abajo le siga tapando.
  TILE_CLEARANCE = TilemapRenderer::DISPLAY_TILE_HEIGHT / 2
  # El suelo del mapa, y lo que otros plugins dibujan pegado a el (sombras del
  # mapa, capas extra de MakerStudio), ocupan la franja baja de Z. Todo lo que
  # esta de pie sobre el suelo se sube en bloque por encima de ella con esto: asi
  # ni la fila mas alejada de la rejilla ampliada, que da Z negativa, puede caer
  # dentro y quedar tapada por el propio suelo.
  Z_LIFT = (Config::MAX_MARGIN_ROWS + Config::MAX_PRIORITY + 2) *
           TilemapRenderer::DISPLAY_TILE_HEIGHT
  # Vanilla always_on_top = 999. En 2.5D un tile raised es Z_LIFT + fila y
  # supera 999, asi que el flag se ignoraba al dibujar. Esta cota queda por
  # encima de cualquier columna/personaje de la rejilla ampliada.
  ALWAYS_ON_TOP_Z = Z_LIFT +
                    ((Config::MAX_MARGIN_ROWS * 2 + Config::MAX_PRIORITY + 24) *
                     TilemapRenderer::DISPLAY_TILE_HEIGHT) + 1

  class << self
    attr_reader :tile_lift
    attr_reader :tilt
    attr_reader :camera_zoom
    attr_reader :perspective
    attr_reader :row_offset
    attr_accessor :haze_opacity
    attr_accessor :near_haze_opacity
    attr_accessor :vignette_opacity

    #---------------------------------------------------------------------------
    # Estado
    #---------------------------------------------------------------------------

    # Estado deseado por el jugador/desarrollador.
    def enabled
      return @wanted
    end

    def enabled=(value)
      cancel_blend!
      @wanted = value
      @blend = value ? 1.0 : 0.0
      $PokemonSystem.visual25d_enabled = value if $PokemonSystem&.respond_to?(:visual25d_enabled=)
      rebuild_render_params!
      refresh_active
    end

    # Estado real de este frame, ya teniendo en cuenta DISABLE_SWITCH.
    def enabled?
      return @active
    end

    # 0 = plano (2D), 1 = tilt/zoom/niebla a tope. Durante fundido interpola.
    def blend
      return @blend unless @blend.nil?
      return @active ? 1.0 : 0.0
    end

    def blending?
      return !@blend_dur.nil?
    end

    # ¿Hay que forzar reproyección este frame? (fundido sin scroll).
    def take_force_reproject!
      return false if !@force_reproject
      @force_reproject = false
      return true
    end

    # Peek sin consumir (Bridge idle-skip MS).
    def force_reproject_pending?
      return !!@force_reproject
    end

    # Toggle con fundido. duration en segundos (nil = Config::TRANSITION_SECONDS).
    def toggle_smooth(duration = nil)
      going_on = if blending?
                   @blend_to < 0.5
                 else
                   !(@wanted && @active && blend > 0.5)
                 end
      set_smooth(going_on, duration)
    end

    # Encender/apagar con fundido progresivo (tilt + zoom + niebla).
    def set_smooth(to_on, duration = nil)
      duration = (duration.nil? ? Config::TRANSITION_SECONDS : duration).to_f
      if duration <= 0 || !$scene.is_a?(Scene_Map)
        self.enabled = to_on
        return
      end
      from = blend
      target = to_on ? 1.0 : 0.0
      if (from - target).abs < 0.001 && !blending?
        self.enabled = to_on
        return
      end
      # Invertir mid-fundido: partir del blend actual.
      @blend_from = from
      @blend_to = target
      @blend_dur = duration
      @blend_t0 = nil
      # Esperar a pie quieto: scroll a mitad de paso + márgenes creciendo = huecos negros.
      @blend_wait_idle = true
      if to_on
        @wanted = true
        $PokemonSystem.visual25d_enabled = true if $PokemonSystem&.respond_to?(:visual25d_enabled=)
      end
      update_blend_progress!
    end

    def cancel_blend!
      @blend_dur = nil
      @blend_t0 = nil
      @blend_wait_idle = false
      @force_reproject = false
      clear_blend_margin_floor!
    end

    def clear_blend_margin_floor!
      @blend_margin_min_cols = nil
      @blend_margin_min_rows = nil
    end

    # Rejilla al tamaño del pico del fundido (no crecer frame a frame).
    # Sin redraw_map: clear_wall_field + refresh a destiempo (tras spritesets)
    # hacía desaparecer capas un frame.
    def prepare_blend_start!
      peak = [@blend_from, @blend_to].max
      peak = 1.0 if peak < 0.001
      saved = @blend_from
      @blend = peak
      @active = true
      rebuild_render_params!
      refresh_margins
      @blend_margin_min_cols = @margin_columns
      @blend_margin_min_rows = @margin_rows
      @blend = saved
      rebuild_render_params!
      refresh_margins
      @projection_dirty = true
      @force_reproject = true
      @blend_t0 = System.uptime
      @blend_wait_idle = false
    end

    # Apagar sin tirar WallField (evita parpadeo al terminar fundido → 2D).
    def soft_disable_after_blend!
      @wanted = false
      @active = false
      @blend = 0.0
      $PokemonSystem.visual25d_enabled = false if $PokemonSystem&.respond_to?(:visual25d_enabled=)
      rebuild_render_params!
      @projection_dirty = true
      @refresh_pending = true
      # flush en el mismo updateSpritesets → sync grid 2D + coords sin hueco
      flush_refresh
    end

    def update_blend_progress!
      return if !@blend_dur
      if @blend_wait_idle
        if $game_player && ($game_player.moving? || $game_player.jumping?)
          return
        end
        prepare_blend_start!
      end
      return if !@blend_t0
      t = ((System.uptime - @blend_t0) / @blend_dur).clamp(0.0, 1.0)
      # smoothstep: arranque/parada suaves
      s = t * t * (3.0 - (2.0 * t))
      @blend = @blend_from + ((@blend_to - @blend_from) * s)
      rebuild_render_params!
      @force_reproject = true
      return if t < 1.0
      @blend_dur = nil
      @blend_t0 = nil
      clear_blend_margin_floor!
      @blend = @blend_to
      if @blend_to <= 0.0
        soft_disable_after_blend!
      else
        @wanted = true
        @active = true
        @blend = 1.0
        $PokemonSystem.visual25d_enabled = true if $PokemonSystem&.respond_to?(:visual25d_enabled=)
        rebuild_render_params!
        @projection_dirty = true
        @force_reproject = true
      end
    end

    # Texto HUD: modo al que va (durante fundido) o el activo real.
    def mode_label_25d?
      return @blend_to > 0.5 if blending?
      return enabled?
    end

    # Perspectiva/zoom vivos a partir del tilt/zoom guardados * blend.
    def rebuild_render_params!
      b = blend
      degrees = (@tilt || 0) * b
      @perspective = Math.tan(degrees * Math::PI / 180.0)
      target_z = (@camera_zoom || 100) / 100.0
      @zoom = 1.0 + ((target_z - 1.0) * b)
      @projection_dirty = true
      @margin_columns = nil
      @margin_rows = nil
      clear_proj_hot_cache
    end

    def tile_lift=(value)
      @tile_lift = value
      redraw_map
    end

    # Inclinacion de la camara en grados. La perspectiva es su tangente: a 0
    # grados no hay punto de fuga y el mapa se ve totalmente desde arriba.
    def tilt=(degrees)
      value = degrees.clamp(0, Config::MAX_TILT_DEGREES)
      $PokemonSystem.visual25d_tilt = value if $PokemonSystem.respond_to?(:visual25d_tilt=)
      apply_tilt(value)
    end

    def camera_zoom=(percent)
      value = percent.clamp(Config::MIN_CAMERA_ZOOM, Config::MAX_CAMERA_ZOOM)
      $PokemonSystem.visual25d_zoom = value if $PokemonSystem.respond_to?(:visual25d_zoom=)
      apply_camera_zoom(value)
    end

    def apply_tilt(value)
      return if @tilt == value
      @tilt = value
      rebuild_render_params!
      if blending?
        @force_reproject = true
      else
        redraw_map
      end
    end

    def apply_camera_zoom(value)
      return if @camera_zoom == value
      @camera_zoom = value
      rebuild_render_params!
      if blending?
        @force_reproject = true
      else
        redraw_map
      end
    end

    # Sesión (no PokemonSystem). Nil = Config::PROJECTION_MODEL / CAMERA_FOV.
    def projection_model
      return @projection_model if @projection_model
      return Config::PROJECTION_MODEL
    end

    def projection_model=(value)
      value = [:gen5, :camera, :classic].include?(value) ? value : :gen5
      $PokemonSystem.visual25d_model = value if $PokemonSystem&.respond_to?(:visual25d_model=)
      return if projection_model == value
      @projection_model = value
      clear_proj_hot_cache
      rebuild_render_params!
      if blending?
        @force_reproject = true
      else
        redraw_map
      end
    end

    def camera_fov
      return @camera_fov if @camera_fov
      return Config::CAMERA_FOV
    end

    def camera_fov=(value)
      value = value.to_f.clamp(20.0, 90.0)
      $PokemonSystem.visual25d_fov = value if $PokemonSystem&.respond_to?(:visual25d_fov=)
      return if @camera_fov && (@camera_fov - value).abs < 0.01
      @camera_fov = value
      clear_proj_hot_cache
      rebuild_render_params!
      if blending?
        @force_reproject = true
      else
        redraw_map
      end
    end

    # Vermeil: suelo ESTRICTAMENTE plano. No se ofrece modo circular.
    # Mantener las firmas originales para no romper los otros proyectores.
    def horizon_curve_px
      return 0.0
    end

    def horizon_curve=(value)
      @horizon_curve = 0.0
    end

    def horizon_curve(y)
      return 0.0
    end

    # Lee partida solo si dirty (carga, F12, opciones). No cada frame.
    def mark_save_sync_dirty!
      @save_sync_dirty = true
    end

    def sync_with_save
      return if !@save_sync_dirty
      @save_sync_dirty = false
      cancel_blend!
      @wanted = $PokemonSystem.visual25d_enabled if $PokemonSystem.respond_to?(:visual25d_enabled)
      @blend = @wanted ? 1.0 : 0.0
      if $PokemonSystem.respond_to?(:visual25d_round)
        curve = $PokemonSystem.visual25d_round ? Config::HORIZON_CURVE.to_f : 0.0
        if (horizon_curve_px - curve).abs >= 0.01
          @horizon_curve = curve
          clear_proj_hot_cache
          @projection_dirty = true
          @refresh_pending = true
        elsif @horizon_curve.nil?
          @horizon_curve = curve
        end
      end
      $PokemonSystem.visual25d_upgrade_legacy_profile! if $PokemonSystem.respond_to?(:visual25d_upgrade_legacy_profile!)
      return if !$PokemonSystem.respond_to?(:visual25d_tilt)
      @tilt = $PokemonSystem.visual25d_tilt
      @camera_zoom = $PokemonSystem.visual25d_zoom
      @projection_model = $PokemonSystem.visual25d_model if $PokemonSystem.respond_to?(:visual25d_model)
      @camera_fov = $PokemonSystem.visual25d_fov if $PokemonSystem.respond_to?(:visual25d_fov)
      rebuild_render_params!
      # refresh_active aplica @active / redraw
    end

    # Se llama una vez por frame desde Scene_Map#updateSpritesets.
    def refresh_active
      sync_perf_for_map!
      sync_with_save
      update_blend_progress! if @blend_dur
      value = @wanted
      if value && Config::DISABLE_SWITCH > 0 && $game_switches
        value = false if $game_switches[Config::DISABLE_SWITCH]
      end
      # Interruptor fuerza OFF a mitad de fundido → corte limpio a 2D.
      # Si el fundido era para encender, @wanted se queda y al soltar el
      # interruptor el modo vuelve. Si el jugador lo estaba apagando, se queda off.
      if !value && blending?
        turning_off = @blend_to && @blend_to <= 0.0
        cancel_blend!
        @blend = 0.0
        if turning_off
          @wanted = false
          $PokemonSystem.visual25d_enabled = false if $PokemonSystem&.respond_to?(:visual25d_enabled=)
        end
        rebuild_render_params!
      end
      # Durante fundido el pipeline 2.5D sigue activo.
      # En wait_idle aún no: prepare_blend_start! expande rejilla al pico.
      if blending?
        if @blend_wait_idle
          flush_refresh
          return
        end
        if !@active
          @active = true
          redraw_map
        else
          flush_refresh
        end
        return
      end
      # @active ANTES del flush: si no, el refresh corre aun en modo 2.5D y deja
      # Z_LIFT / columna en tiles que luego el 2D interpreta mal (orden de capas).
      if value != @active
        @active = value
        @blend = value ? 1.0 : 0.0
        rebuild_render_params!
        redraw_map
      else
        flush_refresh
      end
    end

    def reset_to_defaults
      cancel_blend!
      @wanted            = Config::ENABLED
      @active            = Config::ENABLED
      @blend             = Config::ENABLED ? 1.0 : 0.0
      @tile_lift         = Config::TILE_LIFT
      @haze_opacity      = Config::HAZE_OPACITY
      @near_haze_opacity = Config::NEAR_HAZE_OPACITY
      @vignette_opacity  = Config::VIGNETTE_OPACITY
      @tilt              = Config::TILT_DEGREES
      @camera_zoom       = Config::CAMERA_ZOOM
      @projection_model  = nil
      @camera_fov        = nil
      @horizon_curve     = nil
      @band_blur         = nil
      @row_batch         = nil
      if $PokemonSystem
        $PokemonSystem.visual25d_round   = false if $PokemonSystem.respond_to?(:visual25d_round=)
        $PokemonSystem.visual25d_tilt    = Config::TILT_DEGREES if $PokemonSystem.respond_to?(:visual25d_tilt=)
        $PokemonSystem.visual25d_zoom    = Config::CAMERA_ZOOM if $PokemonSystem.respond_to?(:visual25d_zoom=)
        $PokemonSystem.visual25d_enabled = Config::ENABLED if $PokemonSystem.respond_to?(:visual25d_enabled=)
        $PokemonSystem.visual25d_model = Config::PROJECTION_MODEL if $PokemonSystem.respond_to?(:visual25d_model=)
        $PokemonSystem.visual25d_fov = Config::CAMERA_FOV if $PokemonSystem.respond_to?(:visual25d_fov=)
      end
      rebuild_render_params!
      mark_save_sync_dirty!
      redraw_map
    end

    # El modulo sobrevive a un reinicio con F12, y con el sobreviven sus
    # variables. La que hace dano es @shifted_maps: si queda apuntando a los
    # mapas de la partida anterior, el encuadre de la nueva no se corre nunca y
    # todo se dibuja desplazado el margen de la rejilla. Se llama al crear los
    # spritesets, que es justo cuando empieza un mapa.
    def reset_render_state
      # F12 / nuevo mapa: cortar fundido a medias (estado viene del save).
      cancel_blend!
      @shift_depth = 0
      restore_shifted_maps!
      @tile_offsets = nil
      clear_map_offset_cache
      clear_wall_field if respond_to?(:clear_wall_field)
      clear_interior_faces if respond_to?(:clear_interior_faces)
      dispose_ground_rows if respond_to?(:dispose_ground_rows)
      mark_save_sync_dirty!
      redraw_map
    end

    # Fuerza a recalcular la proyeccion y a recolocar todos los tiles.
    def redraw_map
      @projection_dirty = true
      @refresh_pending = true
      @margin_columns = nil
      @margin_rows = nil
      clear_proj_hot_cache
      clear_map_offset_cache
      # Recalcular WallField (suavizado / rampa) al reactivar o F12.
      clear_wall_field if respond_to?(:clear_wall_field)
      flush_refresh
    end

    # Stamp de tabla de filas (InteriorWalls dirty, etc.).
    def projection_stamp
      return @projection_stamp || 0
    end

    # Durante refresh_tile con MS: coords no proyecta; el bridge proyecta una vez.
    def defer_tile_project?
      return @defer_tile_project
    end

    def defer_tile_project=(value)
      @defer_tile_project = value
    end

    # refresh_tile siempre llama refresh_tile_z despues de coords: no proyectar Z dos veces.
    def skip_coords_z?
      return @skip_coords_z
    end

    def skip_coords_z=(value)
      @skip_coords_z = value
    end

    #-------------------------------------------------------------------------
    # Probe de rendimiento (1 linea/seg). Solo echoln — nunca puts.
    # Activar: pbVisual25DPerfProbe / menu / PERF_PROBE_AUTO / PERF_PROBE_MAPS
    # Snapshot: pbVisual25DPerfDump
    #-------------------------------------------------------------------------
    def perf_enabled?
      return @perf_enabled
    end

    def perf_now
      return System.uptime if defined?(System) && System.respond_to?(:uptime)
      return Time.now.to_f
    end

    def perf_enabled=(value)
      @perf_enabled = value ? true : false
      @perf_manual = true
      perf_reset_counters
      @perf_last_dump = perf_now
      echoln("[V25D perf] #{@perf_enabled ? 'ON' : 'OFF'} (1 linea/seg, echoln)")
    end

    # Arranque automatico global o por mapa (PERF_PROBE_MAPS).
    def ensure_perf_auto!
      if Config::PERF_PROBE_AUTO && !@perf_auto_started
        @perf_auto_started = true
        @perf_manual = false
        @perf_enabled = true
        perf_reset_counters
        @perf_last_dump = perf_now
        echoln("[V25D perf] AUTO ON (PERF_PROBE_AUTO)")
      end
      sync_perf_for_map!
    end

    # Enciende probe al entrar en PERF_PROBE_MAPS; apaga al salir (si no manual).
    def sync_perf_for_map!
      maps = Config::PERF_PROBE_MAPS
      return if !maps.is_a?(Array) || maps.empty?
      mid = $game_map&.map_id
      want = mid && maps.include?(mid)
      if want
        # Usuario apago a proposito en este mapa → no re-encender hasta salir.
        return if @perf_manual && !@perf_enabled
        if !@perf_enabled
          @perf_enabled = true
          @perf_map_auto = true
          @perf_manual = false
          perf_reset_counters
          @perf_last_dump = perf_now
          echoln("[V25D perf] AUTO ON map=#{mid} (PERF_PROBE_MAPS)")
          perf_dump_map_profile!
        elsif @perf_profile_map != mid
          perf_dump_map_profile!
        end
      else
        if @perf_map_auto && @perf_enabled && !@perf_manual
          @perf_enabled = false
          echoln("[V25D perf] AUTO OFF (saliste de PERF_PROBE_MAPS)")
        end
        @perf_map_auto = false
        @perf_profile_map = nil
        @perf_manual = false if !@perf_enabled
      end
    end

    def perf_reset_counters
      @perf_full = 0
      @perf_yflat = 0
      @perf_xhit = 0
      @perf_xmiss = 0
      @perf_z = 0
      @perf_z_raised = 0
      @perf_blank = 0
      @perf_cull = 0
      @perf_proj_rebuild = 0
      @perf_ext_reapply = 0
      @perf_ext_proj = 0
      @perf_ext_idle = 0
      @perf_ext_fast = 0
      @perf_frames = 0
    end

    def perf_tick(key)
      return if !@perf_enabled
      case key
      when :full then @perf_full += 1
      when :yflat then @perf_yflat += 1
      when :xhit then @perf_xhit += 1
      when :xmiss then @perf_xmiss += 1
      when :z then @perf_z += 1
      when :z_raised then @perf_z_raised += 1
      when :blank then @perf_blank += 1
      when :cull then @perf_cull += 1
      when :proj_rebuild then @perf_proj_rebuild += 1
      when :ext_reapply then @perf_ext_reapply += 1
      when :ext_proj then @perf_ext_proj += 1
      when :ext_idle then @perf_ext_idle += 1
      when :ext_fast then @perf_ext_fast += 1
      end
    end

    # Perfil del mapa actual (MS layers). Solo echoln.
    def perf_dump_map_profile!
      mid = $game_map&.map_id
      @perf_profile_map = mid
      w = $game_map&.width.to_i
      h = $game_map&.height.to_i
      echoln(format(
        "[V25D perf] PROFILE map=%s %dx%d 25d=%s tilt=%d zoom=%d model=%s",
        mid.inspect, w, h, enabled? ? "ON" : "OFF",
        tilt.to_i, camera_zoom.to_i, Config::PROJECTION_MODEL.inspect
      ))
      return if !defined?(MakerStudio)
      return if !$game_map || mid.nil?
      ext = nil
      begin
        ext = MakerStudio::DataStore.get_extended_data(mid, w, h, $game_map)
      rescue StandardError => e
        echoln("[V25D perf] PROFILE MS load error: #{e.class}: #{e.message}")
        return
      end
      return echoln("[V25D perf] PROFILE MS=none") if !ext.is_a?(Hash)
      layers = ext["layers"]
      return echoln("[V25D perf] PROFILE MS layers=nil") if !layers.is_a?(Array)
      total = 0
      layers.each_with_index do |layer, i|
        next if !layer.is_a?(Hash)
        tiles = layer["tiles"]
        n = tiles.is_a?(Hash) ? tiles.size : 0
        total += n
        next if n <= 0
        echoln(format(
          "[V25D perf] PROFILE   MSlayer%d id=%s name=%s tiles=%d vis=%s",
          i, layer["id"].inspect, layer["name"].to_s, n, layer["visible"].inspect
        ))
      end
      echoln("[V25D perf] PROFILE   MSpainted_total=#{total}")
    end

    # Llamar 1× por frame tras el tilemap. Dump como mucho 1/seg.
    def perf_frame_end(renderer = nil)
      sync_perf_for_map!
      return if !@perf_enabled
      @perf_frames += 1
      now = perf_now
      @perf_last_dump ||= now
      return if (now - @perf_last_dump) < 1.0
      elapsed = now - @perf_last_dump
      @perf_last_dump = now
      f = @perf_frames
      return if f <= 0
      cols = rows = 0
      ext_n = 0
      if renderer && !renderer.disposed?
        cols = renderer.instance_variable_get(:@tiles_horizontal_count).to_i
        rows = renderer.instance_variable_get(:@tiles_vertical_count).to_i
        vis = renderer.instance_variable_get(:@ext_visible)
        ext_n = vis.length if vis.is_a?(Array)
      end
      slots = cols * rows * 3
      mid = $game_map&.map_id
      echoln(format(
        "[V25D perf] map=%s %.0ffps~ frames=%d grid=%dx%dx3(%d) marg=%dx%d extN=%d " \
        "full/f=%.0f yFlat/f=%.0f xHit/f=%.0f xMiss/f=%.0f z/f=%.0f zRaised/f=%.0f " \
        "blank/f=%.0f cull/f=%.0f rebuild/f=%.1f extRe/f=%.0f extPr/f=%.0f extIdle/f=%.0f extFast/f=%.0f tilt=%d zoom=%d",
        mid.inspect, f / elapsed, f, cols, rows, slots, margin_columns, margin_rows, ext_n,
        @perf_full.to_f / f, @perf_yflat.to_f / f,
        @perf_xhit.to_f / f, @perf_xmiss.to_f / f,
        @perf_z.to_f / f, @perf_z_raised.to_f / f, @perf_blank.to_f / f,
        @perf_cull.to_f / f,
        @perf_proj_rebuild.to_f / f,
        @perf_ext_reapply.to_f / f, @perf_ext_proj.to_f / f,
        @perf_ext_idle.to_f / f, @perf_ext_fast.to_f / f,
        tilt.to_i, camera_zoom.to_i
      ))
      perf_reset_counters
    end

    # ponytail: caches de frame/proyeccion. Sin cambiar geometria.
    def clear_proj_hot_cache
      @proj_tilt_normal = nil
      @proj_y_shift = nil
      @proj_min_width = nil
      @proj_center_x = nil
      @proj_vertical_gain = nil
      @cam_d0 = nil
      @cam_slope = nil
      @cam_half = nil
      @cam_d_min = nil
      @cam_s = nil
      @cam_y_lo = nil
      @cam_i_lo = nil
      @cam_shape_floor = nil
      @shelf_lift_cache = nil
      @shelf_lift_stamp = nil
    end

    # :gen5 = plano proyectado SIN escala variable por fila (billboards rectos).
    # Los modos :camera/:classic son legados experimentales.
    def gen5_projection?
      return projection_model == :gen5
    end

    # :camera = escala 1/profundidad (FOV); :classic = perfil lineal.
    def camera_projection?
      return projection_model == :camera
    end

    # Params FOV/pitch para :camera.
    # Bug viejo: slope = tan(tilt)*d0/half → a 50° tan>1 y depth se vuelve
    # negativa bajo el centro → clamp SHAPE_FLOOR → shape ~6.7x (look roto).
    # Ahora s = soft(tilt,FOV) ∈ (0, CAM_S_MAX) para depth>0 en pantalla.
    CAM_S_MAX = 0.72

    def ensure_camera_params!
      return if @cam_d0
      fov = camera_fov.to_f
      fov = 20.0 if fov < 20.0
      fov = 90.0 if fov > 90.0
      # d0 focal (FOV). Shape = 1/(1+s*ny) — d0 cancela; FOV suaviza s.
      @cam_d0 = 1.0 / Math.tan(fov * Math::PI / 360.0)
      @cam_half = Graphics.height / 2.0
      p = @perspective.to_f
      p = 0.0 if p < 0.0
      # Soft pitch: s→1 cuando p→∞, nunca ≥1.
      s = p / (1.0 + p)
      # FOV ancho → menos drama; FOV estrecho → un poco mas.
      fov_t = (fov - 20.0) / 70.0
      s *= (1.12 - (0.32 * fov_t))
      s = CAM_S_MAX if s > CAM_S_MAX
      @cam_s = s
      @cam_slope = (s * @cam_d0) / @cam_half
      @cam_d_min = @cam_d0 * SHAPE_FLOOR
      @cam_shape_floor = 1.0 / SHAPE_FLOOR
      # y donde depth toca el suelo (primer plano extremo / margenes).
      if @cam_slope.abs < 1.0e-9
        @cam_y_lo = 1.0e12
        @cam_i_lo = 0.0
      else
        @cam_y_lo = @cam_half + ((@cam_d0 - @cam_d_min) / @cam_slope)
        # I(y_lo) con formula log (depth justo en d_min).
        d_a = camera_depth_unclamped(0.0)
        @cam_i_lo = -(@cam_d0 / @cam_slope) * Math.log(@cam_d_min / d_a)
      end
    end

    def camera_depth_unclamped(y)
      ensure_camera_params!
      return @cam_d0 + (@cam_slope * (@cam_half - y))
    end

    def camera_depth_at(y)
      d = camera_depth_unclamped(y)
      return (d < @cam_d_min) ? @cam_d_min : d
    end

    def clear_map_offset_cache
      @map_offset_cache = nil
      @map_offset_sig = nil
    end

    # Una vez por fase de render (nativos con shift / extended sin shift).
    # Rebuild solo si display/mapas cambiaron (idle reutiliza cache).
    # ponytail: comparar in-place sin Array nuevo; solo rewrite @map_offset_sig al miss.
    def prime_map_offsets!
      maps = $map_factory ? $map_factory.maps : nil
      if @map_offset_cache && map_offsets_match_sig?(maps)
        return
      end
      cache = {}
      if maps
        maps.each do |map|
          next unless map
          cache[map.map_id] = compute_map_tile_offset(map)
        end
      end
      @map_offset_cache = cache
      store_map_offset_signature(maps)
    end

    def map_offsets_match_sig?(maps)
      sig = @map_offset_sig
      return false if !sig
      i = 0
      if maps
        maps.each do |map|
          next unless map
          return false if sig[i] != map.map_id ||
                          sig[i + 1] != map.display_x ||
                          sig[i + 2] != map.display_y
          i += 3
        end
      end
      return i == sig.length
    end

    def store_map_offset_signature(maps)
      sig = @map_offset_sig
      if sig
        sig.clear
      else
        sig = []
        @map_offset_sig = sig
      end
      return if !maps
      maps.each do |map|
        next unless map
        sig.push(map.map_id, map.display_x, map.display_y)
      end
    end

    # El cambio puede venir del menu de opciones, con el mapa parado detras: en
    # ese caso queda pendiente y se aplica en cuanto se vuelve a el.
    def flush_refresh
      return if !@refresh_pending
      return if !$scene.is_a?(Scene_Map) || !$scene.respond_to?(:map_renderer)
      renderer = $scene.map_renderer
      return if !renderer || renderer.disposed?
      renderer.refresh
      @refresh_pending = false
    end

    #---------------------------------------------------------------------------
    # Encuadre ampliado
    #-------------------------------------------------------------------------
    # Alejar o inclinar la camara obliga a dibujar mas mapa del que cabe en
    # pantalla, y el motor solo reserva las casillas justas. Se le amplia la
    # rejilla y se le corre el encuadre estas casillas mientras dibuja, de modo
    # que cargue tambien las que quedan fuera por arriba y por la izquierda.
    #
    # El margen se recalcula con los valores de camara en uso, no con los topes,
    # para no pagar tiles de mas cuando la camara esta cerca.
    #---------------------------------------------------------------------------

    def margin_columns
      return 0 if !enabled?
      refresh_margins if !@margin_columns
      return @margin_columns
    end

    def margin_rows
      return 0 if !enabled?
      refresh_margins if !@margin_rows
      return @margin_rows
    end

    def margin_offset_x
      return 0 if !enabled?
      return margin_columns * TilemapRenderer::DISPLAY_TILE_WIDTH
    end

    def margin_offset_y
      return 0 if !enabled?
      return margin_rows * TilemapRenderer::DISPLAY_TILE_HEIGHT
    end

    def refresh_margins
      # 2D puro: sin margen ni shift. Si no, @pixel_offset lleva margen y la Z
      # de MakerStudio (ms_overhead_tile_z) se desfasa del jugador.
      if !enabled?
        @margin_rows = 0
        @margin_columns = 0
        @y_shift = 0
        return
      end
      tile_w = TilemapRenderer::DISPLAY_TILE_WIDTH
      tile_h = TilemapRenderer::DISPLAY_TILE_HEIGHT
      @y_shift = centred_shift
      top    = unprojected_edge(0)
      bottom = unprojected_edge(Graphics.height)
      # Filas que hacen falta por encima de la primera y por debajo de la ultima.
      above = (top < 0) ? (-top.to_f / tile_h).ceil : 0
      base_rows = (Graphics.height.to_f / tile_h).ceil + 1
      below = ((bottom.to_f / tile_h).ceil + 1) - base_rows
      @margin_rows = [[above, below].max + 1, 1].max
      @margin_rows = Config::MAX_MARGIN_ROWS if @margin_rows > Config::MAX_MARGIN_ROWS
      # Si la rejilla no llega a donde pide la proyeccion, se corre hacia abajo
      # para que el borde de arriba siga cubierto: el jugador deja de estar
      # exactamente centrado, pero no aparece vacio.
      @y_shift = [centred_shift, raw_project_y(-@margin_rows * tile_h)].max
      # Columnas: la fila mas estrecha visible tiene que seguir llegando a los
      # dos bordes de la pantalla.
      half = Graphics.width / 2.0
      extra = (half / width_scale_at(unprojected_edge(0))) - half
      @margin_columns = (extra <= 0) ? 1 : (extra / tile_w).ceil + 1
      @margin_columns = Config::MAX_MARGIN_COLUMNS if @margin_columns > Config::MAX_MARGIN_COLUMNS
      # Fundido: no encoger bajo el pico (rejilla ya expandida al arrancar).
      if @blend_margin_min_cols
        @margin_columns = @blend_margin_min_cols if @margin_columns < @blend_margin_min_cols
        @margin_rows = @blend_margin_min_rows if @margin_rows < @blend_margin_min_rows
        @y_shift = [centred_shift, raw_project_y(-@margin_rows * tile_h)].max
      end
    end

    # Coordenada sin proyectar que acaba dibujada a esa altura de pantalla.
    # Es la inversa exacta de project_y: se resuelve la cuadratica en vez de
    # buscarla a tientas, asi que no depende de @margin_rows y puede usarse
    # desde refresh_margins sin recursion.
    def unprojected_edge(screen_y)
      return raw_unproject(screen_y + @y_shift.to_f)
    end

    # Inversa de raw_project_y (classic cuadrática / camera log-depth).
    def raw_unproject(raw_value)
      if gen5_projection?
        return raw_value / gen5_ground_scale
      end
      return raw_value / @zoom if @perspective == 0
      if camera_projection?
        return camera_raw_unproject(raw_value)
      end
      target = raw_value * tilt_normal / @zoom
      limit = (SHAPE_FLOOR - 1.0) * Graphics.height / @perspective
      base  = limit + (@perspective * limit * limit / (2.0 * Graphics.height))
      # Por debajo del horizonte la integral es lineal.
      return limit + ((target - base) / SHAPE_FLOOR) if target < base
      disc = 1.0 + (2.0 * @perspective * target / Graphics.height)
      return limit if disc < 0
      return (Math.sqrt(disc) - 1.0) * Graphics.height / @perspective
    end

    # Inversa de zoom * camera_shape_integral(y). Dual: log + tramo lineal.
    def camera_raw_unproject(raw_value)
      ensure_camera_params!
      s = @cam_slope
      return raw_value / @zoom if s.abs < 1.0e-9
      integral = raw_value / @zoom
      d0 = @cam_d0
      d_a = camera_depth_unclamped(0.0)
      return 0.0 if d_a <= 0.0
      i_lo = @cam_i_lo
      if integral > i_lo
        # Tramo clamp: I = i_lo + shape_floor*(y - y_lo)
        return @cam_y_lo + ((integral - i_lo) / @cam_shape_floor)
      end
      d_y = d_a * Math.exp(-integral * s / d0)
      d_y = @cam_d_min if d_y < @cam_d_min
      return @cam_half - ((d_y - d0) / s)
    end

    # El motor descarga un mapa conectado en cuanto se aleja 6 casillas de la
    # pantalla; con la camara alejada se sigue viendo bastante mas alla, asi que
    # se le suman las casillas de mas que hay a la vista.
    def map_in_range?(display_x, display_y, width, height)
      # +4: al correr el factory llegaba tarde y el mapa conectado se veía
      # un instante con tiles/eventos del encuadre anterior.
      range_x = 6 + margin_columns + 4
      range_y = 6 + margin_rows + 4
      return false if display_x >= (width + range_x) * Game_Map::REAL_RES_X
      return false if display_y >= (height + range_y) * Game_Map::REAL_RES_Y
      return false if display_x <= -(Graphics.width + (range_x * Game_Map::TILE_WIDTH)) * Game_Map::X_SUBPIXELS
      return false if display_y <= -(Graphics.height + (range_y * Game_Map::TILE_HEIGHT)) * Game_Map::Y_SUBPIXELS
      return true
    end

    def shift_maps_for_render
      @shift_depth = (@shift_depth || 0) + 1
      # Update anidado (carrera / turbo / hitch): no volver a correr el
      # encuadre. Si se restaura a medias, el mapa queda desplazado el margen
      # hasta que un refresh lento lo realinea.
      return if @shift_depth > 1
      restore_shifted_maps!
      return if margin_columns == 0 && margin_rows == 0
      return if !$map_factory
      @shift_x = margin_columns * Game_Map::REAL_RES_X
      @shift_y = margin_rows * Game_Map::REAL_RES_Y
      @shifted_maps = $map_factory.maps
      # Se escribe el ivar y no display_x=, porque el setter recorta el encuadre
      # a los bordes del mapa y anularia el corrimiento.
      @shifted_maps.each do |map|
        map.instance_variable_set(:@display_x, map.display_x - @shift_x)
        map.instance_variable_set(:@display_y, map.display_y - @shift_y)
      end
      # sync_projection_from_map! cachea offsets SIN shift. Si se reutilizan
      # aqui, grid_row suma margen otra vez y los pri>0 cogen unit del primer
      # plano: al correr N se arrastran.
      clear_map_offset_cache
    end

    def restore_maps_after_render
      return if !@shift_depth || @shift_depth <= 0
      @shift_depth -= 1
      return if @shift_depth > 0
      restore_shifted_maps!
    end

    def restore_shifted_maps!
      return if !@shifted_maps
      @shifted_maps.each do |map|
        map.instance_variable_set(:@display_x, map.display_x + @shift_x)
        map.instance_variable_set(:@display_y, map.display_y + @shift_y)
      end
      @shifted_maps = nil
      # Pool MS corre DESPUES: sin esto reusa offsets corridos + margen.
      clear_map_offset_cache
    end

    def shifted_for_render?
      return @shift_depth.to_i > 0 && @shifted_maps
    end

    #---------------------------------------------------------------------------
    # Proyeccion
    #---------------------------------------------------------------------------

    # Por debajo de esta escala la perspectiva se aplana. Es el horizonte: si se
    # dejara seguir, la escala llegaria a cero y luego se volveria negativa.
    SHAPE_FLOOR = 0.15

    def center_x
      return @proj_center_x if @proj_center_x
      return Graphics.width / 2
    end

    def tilt_normal
      return @proj_tilt_normal if @proj_tilt_normal
      return 1.0 + (@perspective / 2.0)
    end

    # Perfil de la perspectiva: lo que mide una fila respecto a la del centro de
    # la pantalla, que es donde esta el jugador. Normalizado para que inclinar la
    # camara reparta tamano entre el fondo y el primer plano en vez de acercar.
    def shape_at(y)
      return 1.0 if gen5_projection? || @perspective == 0
      if camera_projection?
        # shape = d0/depth → 1 en el centro; fondo mas pequeño, primer plano mayor.
        d = camera_depth_at(y)
        return @cam_d0 / d
      end
      raw = 1.0 + (@perspective * y / Graphics.height)
      raw = SHAPE_FLOOR if raw < SHAPE_FLOOR
      return raw / tilt_normal
    end

    # Escala en profundidad: gobierna el alto de las filas y el tamano de lo que
    # esta de pie sobre ellas.
    def scale_at(y)
      return gen5_ground_scale if gen5_projection?
      return @zoom * shape_at(y)
    end

    # Una transformacion afin del suelo: todo el mapa comparte el MISMO plano.
    # Sin deformaciones laterales segun distancia, bandas curvas ni efecto
    # miniatura. El angulo comprime la profundidad de modo uniforme.
    def gen5_ground_scale
      return @zoom * (1.0 - ((1.0 - Math.cos(tilt.to_f * blend * Math::PI / 180.0)) * 0.65))
    end

    # Escala en anchura. Converge menos que la de profundidad, como en una camara
    # inclinada de verdad, donde la distancia se acorta mas que la anchura. Ese
    # freno es ademas lo que evita que un elemento alto se despegue lateralmente
    # de la casilla que ocupa.
    def width_scale_at(y)
      return @zoom if gen5_projection?
      value = @zoom * (1.0 + ((shape_at(y) - 1.0) * Config::VANISHING_STRENGTH))
      floor = min_width_scale
      return (value < floor) ? floor : value
    end

    # Por debajo de esto una fila ya no cabria en la rejilla ampliada, asi que la
    # convergencia se planta ahi antes que dejar los laterales sin dibujar.
    def min_width_scale
      return @proj_min_width if @proj_min_width
      half = Graphics.width / 2.0
      return half / (half + ((Config::MAX_MARGIN_COLUMNS - 1) * TilemapRenderer::DISPLAY_TILE_WIDTH))
    end

    # Integral de scale_at: dos filas contiguas comparten borde exactamente.
    def raw_project_y(y)
      return gen5_ground_scale * y if gen5_projection?
      return @zoom * y if @perspective == 0
      if camera_projection?
        return @zoom * camera_shape_integral(y)
      end
      return @zoom * shape_integral(y) / tilt_normal
    end

    # ∫ shape_at dy. shape = d0/depth, depth = d0 + slope*(half-y).
    # Tramo y > y_lo (depth clampeado): integral lineal con shape = 1/SHAPE_FLOOR.
    def camera_shape_integral(y)
      ensure_camera_params!
      s = @cam_slope
      return y if s.abs < 1.0e-9
      d0 = @cam_d0
      d_a = camera_depth_unclamped(0.0)
      y_lo = @cam_y_lo
      if y <= y_lo
        d_y = camera_depth_unclamped(y)
        d_y = @cam_d_min if d_y < @cam_d_min
        return -(d0 / s) * Math.log(d_y / d_a)
      end
      # Primer plano / margen bajo el clamp.
      return @cam_i_lo + (@cam_shape_floor * (y - y_lo))
    end

    def shape_integral(y)
      limit = (SHAPE_FLOOR - 1.0) * Graphics.height / @perspective
      return y + (@perspective * y * y / (2.0 * Graphics.height)) if y >= limit
      base = limit + (@perspective * limit * limit / (2.0 * Graphics.height))
      return base + (SHAPE_FLOOR * (y - limit))
    end

    def project_y(y)
      ys = @proj_y_shift || y_shift
      return (raw_project_y(y) + horizon_curve(y) - ys).round
    end

    def project_x(x, scale)
      cx = @proj_center_x || (Graphics.width / 2)
      return cx + ((x - cx) * scale).round
    end

    # Pixeles que se levanta un elemento vertical por nivel de prioridad cuando
    # se apoya en la fila "y".
    def lift_at(y)
      return 0 if @tile_lift <= 0
      return (@tile_lift * width_scale_at(y)).round
    end

    # Cuanto se pone de pie un elemento vertical. El suelo se acorta con la
    # inclinacion, pero lo que esta de cara a la camara no: cuanto mas baja la
    # camara, mas alto se ve.
    def vertical_gain
      return @proj_vertical_gain if @proj_vertical_gain
      rt = (@tilt || 0) * blend
      return 1.0 if rt <= 0 || Config::VERTICAL_GAIN <= 0
      upright = 1.0 / Math.cos(rt * Math::PI / 180.0)
      return 1.0 + ((upright - 1.0) * Config::VERTICAL_GAIN)
    end

    # Altura en pantalla de un tramo de un tile de alto de algo que esta de pie
    # sobre la fila "y".
    def vertical_unit_at(y)
      return ((TilemapRenderer::DISPLAY_TILE_HEIGHT * vertical_gain) + @tile_lift) *
             width_scale_at(y)
    end

    # Los personajes se levantan solo una parte de lo que se levantan las
    # paredes: si crecieran igual, su cabeza se meteria en la fila de arriba y
    # los tiles con prioridad de esa fila los taparian.
    def character_unit_at(y)
      flat = TilemapRenderer::DISPLAY_TILE_HEIGHT * width_scale_at(y)
      return flat + ((vertical_unit_at(y) - flat) * Config::CHARACTER_GAIN)
    end

    # Lift extra para un evento [hN] (ver [004]). No es N*unit sobre SU casilla
    # (eso lo dejaba flotando encima del hueco). Se ancla como un tile
    # prioridad N: pies en cy+N, el sprite apoya en la banda N (cima de 1..N-1).
    # Si la casilla del evento YA es la cima de esa pila (pri == N-1), se trata
    # como el siguiente tramo (ancla una fila al norte).
    def event_tag_lift(character, ground)
      return 0 if !character.is_a?(Game_Event)
      height = character.hd25_tag_height
      return 0 if height <= 0
      b = blend
      return 0 if b <= 0.0
      extra = 0
      extra = character_lift(character, ground) if respond_to?(:character_lift)
      band = event_column_band_bottom(character, height)
      full = if band.nil?
               height * vertical_unit_at(ground)
             else
               # Cancela el character_lift de screen_y: la columna ya mete el
               # Cliff en wall_column_feet_y. El hop del salto se resta fuera.
               project_y(ground) - extra - band
             end
      # El fundido 2D→2.5D arranca con tilt~0: aplicar la columna entera
      # teletransporta el evento N casillas al sur. Se interpola con blend.
      return (full * b).round
    end

    # Casilla logica (cx, cy, h) del slot pri-N del evento.
    def event_column_cell(character, height)
      cx = character.x
      cy = character.y
      if character.respond_to?(:hd25_column_cell_cached)
        cached = character.hd25_column_cell_cached(cx, cy, height)
        return cached if cached
      end
      ax = cx
      ay = cy
      map = character.map
      if map && respond_to?(:own_priority)
        here = own_priority(map, cx, cy).to_i
        if here >= 1 && here == height - 1
          ay = cy - 1
        end
      end
      cell = [ax, ay, height]
      if character.respond_to?(:hd25_column_cell_set)
        character.hd25_column_cell_set(cx, cy, height, cell)
      end
      return cell
    end

    # Y de pantalla de los pies del evento: base de la banda N (encima de N-1).
    def event_column_band_bottom(character, height)
      map = character.map
      return nil if !map || !respond_to?(:grid_row_for_map_cell)
      cx, cy, h = event_column_cell(character, height)
      return nil if cy.nil? || h.to_i <= 0
      ensure_projection
      cell_row = grid_row_for_map_cell(map, cy)
      return nil if cell_row.nil?
      field = respond_to?(:wall_field) ? wall_field(map) : nil
      field = nil if field && field.flat
      if respond_to?(:column_stack_geom)
        _f, _u, _s, _x, edges = column_stack_geom(
          field, cx, cy, cell_row, h, map.map_id)
        return edges[h - 1] if edges && edges[h - 1]
      end
      x_row = raised_width_row(cell_row, h)
      unit = row_unit(x_row)
      unit = vertical_unit_at(row_top(x_row + 1)) if !unit || unit <= 0
      feet = wall_column_feet_y(field, cx, cy, cell_row, h)
      return (feet - ((h - 1) * unit)).round
    end

    def event_column_scales(character, height, ground)
      local_s = width_scale_at(ground)
      local_u = character_unit_at(ground)
      map = character.map
      if !map || !respond_to?(:grid_row_for_map_cell)
        return local_s, local_u
      end
      _cx, cy, h = event_column_cell(character, height)
      ensure_projection
      cell_row = grid_row_for_map_cell(map, cy)
      if cell_row.nil?
        return local_s, local_u
      end
      x_row = raised_width_row(cell_row, h)
      scale = row_width_scale(x_row)
      band_ground = row_top(x_row + 1)
      col_u = character_unit_at(band_ground)
      b = blend
      return scale, col_u if b >= 1.0
      return local_s, local_u if b <= 0.0
      return local_s + ((scale - local_s) * b), local_u + ((col_u - local_u) * b)
    end

    def event_column_z(character, height, native_z)
      return always_on_top_z if always_on_top_z?(native_z)
      if defined?(MakerStudio::ALWAYS_ON_BOTTOM_Z) &&
         native_z == MakerStudio::ALWAYS_ON_BOTTOM_Z
        return native_z
      end
      map = character.map
      if !map || !respond_to?(:grid_row_for_map_cell)
        return character_z(native_z, character.screen_y_ground)
      end
      _cx, cy, h = event_column_cell(character, height)
      row = grid_row_for_map_cell(map, cy)
      if row.nil?
        return character_z(native_z, character.screen_y_ground)
      end
      th = TilemapRenderer::DISPLAY_TILE_HEIGHT
      poy = 0
      if $scene.is_a?(Scene_Map) && $scene.respond_to?(:map_renderer)
        r = $scene.map_renderer
        poy = r.instance_variable_get(:@pixel_offset_y).to_i if r && !r.disposed?
      end
      z = ((row + h + 1) * th) - poy + 1
      col_z = raised_tile_z(z) + 1
      b = blend
      return col_z if b >= 1.0
      base = character_z(native_z, character.screen_y_ground)
      return (base + ((col_z - base) * b)).round
    end

    # Punto de luz / oscuridad para un Game_Character (coords planas → 2.5D).
    # y_offset: pixeles hacia arriba desde screen_y (p.ej. mitad del sprite).
    # Devuelve [sx, sy, wscale].
    def project_darkness_point(character, y_offset = 0)
      flat_x = character.screen_x
      flat_y = character.screen_y - y_offset.to_i
      ground = character.screen_y_ground
      wscale = width_scale_at(ground)
      if character.is_a?(Game_Event) && character.hd25_tag_height > 0
        wscale, _cunit = event_column_scales(character, character.hd25_tag_height, ground)
      end
      hop = ground - flat_y
      lift = 0
      lift = character_lift(character, ground) if respond_to?(:character_lift)
      lift += shelf_character_lift(character, ground) if respond_to?(:shelf_character_lift)
      lift += event_tag_lift(character, ground)
      sx = project_x(flat_x, wscale)
      sy = project_y(ground) - (hop * wscale).round - lift
      return sx, sy, wscale
    end

    # Altura de un sprite medida en casillas del mundo proyectado: cuanto ocupa
    # en pantalla comparado con lo que mide ahora una casilla del suelo.
    def projected_height(height, ground)
      height = height.to_i
      return height if height <= 0
      cell = TilemapRenderer::DISPLAY_TILE_HEIGHT * scale_at(ground)
      return height if cell <= 0
      return (height * character_unit_at(ground) / cell).round
    end

    # Z / Z_LIFT: prioridad PINTADA (geom). cell_band=0 bajo el ground-cap MS
    # no puede tumbar la Z de un arbol pri 1..5 (eventos salian por encima).
    def raised_tile?(tile)
      return false if tile.shows_reflection || tile.bridge
      return geom_priority(tile) > 0
    end

    # Todo lo que esta de pie sobre el suelo (tiles con prioridad, personajes) se
    # sube en bloque por encima de la franja del suelo con este desplazamiento.
    #
    # Las filas que caen por encima del borde de la pantalla dan Z negativa, y
    # antes se comprimian todas en unas pocas unidades para que no se colaran por
    # debajo del suelo. Ahi los empates hacian parpadear los tiles con prioridad y
    # colaban a los personajes lejanos por delante de ellos. Desplazando en bloque
    # se conserva el orden exacto entre unos y otros.
    def raised_tile_z(value)
      return value + Z_LIFT
    end

    # Antes daba igual que un tile con prioridad ganase al personaje apoyado en su
    # misma casilla, porque el tile se quedaba en su fila y no llegaba a tocarlo.
    # Ahora se levanta sobre esa casilla y le pisa la cabeza, asi que el personaje
    # tiene que ir por delante.
    #
    # Idempotente: MakerStudio congela Game_Event#screen_z al alias viejo; el wrap
    # de Character Depth puede llamar aqui tras Game_Character (ya con Z_LIFT) o
    # tras el alias MS (sin el). offset >= Z_LIFT = ya aplicado.
    def always_on_top_z
      return ALWAYS_ON_TOP_Z
    end

    def always_on_top_z?(value)
      return false if value.nil?
      return value == 999 || value == ALWAYS_ON_TOP_Z
    end

    def character_z(value, ground)
      return ALWAYS_ON_TOP_Z if always_on_top_z?(value)
      if defined?(MakerStudio::ALWAYS_ON_BOTTOM_Z) &&
         value == MakerStudio::ALWAYS_ON_BOTTOM_Z
        return value
      end
      offset = value - ground
      return value if offset >= Z_LIFT
      # Fuera de este margen no es un personaje de pie sobre su casilla (grafico
      # de tile con prioridad, always_on_top...), y su Z se respeta.
      value += TILE_CLEARANCE if offset >= 0 && offset < TILE_CLEARANCE
      return value + Z_LIFT
    end

    # Desplazamiento que mantiene al jugador en el centro de la pantalla, salvo
    # que la rejilla no de para tanto (ver refresh_margins).
    def centred_shift
      half = Graphics.height / 2
      return raw_project_y(half) - half
    end

    def y_shift
      refresh_margins if !@margin_rows
      return @y_shift
    end

    # Tabla de filas del tilemap, para no rehacer las cuentas en cada tile.
    # Se reconstruye cuando el mapa se desplaza en vertical.
    def update_projection(pixel_offset_y)
      return if @row_offset == pixel_offset_y && !@projection_dirty
      perf_tick(:proj_rebuild)
      @row_offset = pixel_offset_y
      @projection_dirty = false
      @projection_stamp = (@projection_stamp || 0) + 1
      tile_height = TilemapRenderer::DISPLAY_TILE_HEIGHT
      margin = margin_rows
      row_max = (Graphics.height / tile_height) + (margin * 2) + Config::MAX_PRIORITY + 4
      @row_max = row_max
      count = row_max + 1
      # Reusar arrays: al andar se reconstruye la tabla cada frame de scroll.
      @row_top = Array.new(count) if !@row_top || @row_top.length != count
      @row_width = Array.new(count) if !@row_width || @row_width.length != count
      @row_unit = Array.new(count) if !@row_unit || @row_unit.length != count
      @row_taper = Array.new(count) if !@row_taper || @row_taper.length != count
      # Escalares calientes (shape/project_y/project_x los releen miles de veces).
      @proj_center_x = Graphics.width / 2
      @proj_tilt_normal = (@perspective == 0) ? 1.0 : (1.0 + (@perspective / 2.0))
      @proj_min_width = begin
        half = Graphics.width / 2.0
        half / (half + ((Config::MAX_MARGIN_COLUMNS - 1) * TilemapRenderer::DISPLAY_TILE_WIDTH))
      end
      @proj_y_shift = y_shift
      # Fundido: vertical_gain sigue el tilt * blend (no el tilt guardado a tope).
      rt = (@tilt || 0) * blend
      @proj_vertical_gain = if rt <= 0 || Config::VERTICAL_GAIN <= 0
                              1.0
                            else
                              upright = 1.0 / Math.cos(rt * Math::PI / 180.0)
                              1.0 + ((upright - 1.0) * Config::VERTICAL_GAIN)
                            end
      unit_base = (tile_height * @proj_vertical_gain) + @tile_lift
      half_h = tile_height / 2
      ys = @proj_y_shift
      # ponytail: inline width_scale (scroll Y reconstruye la tabla cada frame)
      zoom = @zoom
      persp = @perspective
      tn = @proj_tilt_normal
      vmin = @proj_min_width
      vanish = Config::VANISHING_STRENGTH
      gh = Graphics.height.to_f
      use_cam = camera_projection? && persp != 0
      if use_cam
        ensure_camera_params!
        cam_d0 = @cam_d0
        cam_slope = @cam_slope
        cam_half = @cam_half
        cam_d_min = @cam_d_min
      end
      row = 0
      while row < count
        top = (row * tile_height) - pixel_offset_y
        @row_top[row] = (raw_project_y(top) + horizon_curve(top) - ys).round
        y_mid = top + half_h
        if gen5_projection? || persp == 0
          wscale = zoom
        elsif use_cam
          d = cam_d0 + (cam_slope * (cam_half - y_mid))
          d = cam_d_min if d < cam_d_min
          shape = cam_d0 / d
          wscale = zoom * (1.0 + ((shape - 1.0) * vanish))
          wscale = vmin if wscale < vmin
        else
          raw = 1.0 + (persp * y_mid / gh)
          raw = SHAPE_FLOOR if raw < SHAPE_FLOOR
          shape = raw / tn
          wscale = zoom * (1.0 + ((shape - 1.0) * vanish))
          wscale = vmin if wscale < vmin
        end
        @row_width[row] = wscale
        @row_unit[row] = unit_base * wscale
        row += 1
      end
      # Taper de cada fila: cuanto mide su borde de arriba (fila de detras)
      # respecto al de abajo (esta fila). Precalculado junto al resto de la
      # tabla porque project_tile lo lee por cada tile de suelo.
      row = 0
      while row < row_max
        near = @row_width[row + 1]
        @row_taper[row] = (near && near > 0) ? (@row_width[row] / near) : 1.0
        row += 1
      end
      @row_taper[row_max] = 1.0
      build_row_slices(row_max, tile_height)
    end

    def row_top(row)
      return 0 if !@row_top
      row = 0 if row < 0
      row = @row_max if row > @row_max
      return @row_top[row]
    end

    # Fuera de la tabla (tile que acaba de entrar por el borde) row_top
    # devuelve la ultima fila y la tapa Shelf se aplasta a 1 px.
    def row_covered?(row)
      return false if !@row_top || @row_max.nil?
      return row.to_i >= 0 && row.to_i <= @row_max
    end

    def row_top_any(row)
      return row_top(row) if row_covered?(row)
      th = TilemapRenderer::DISPLAY_TILE_HEIGHT
      top = (row.to_i * th) - (@row_offset || 0)
      shift = @proj_y_shift
      shift = y_shift if shift.nil?
      return (raw_project_y(top) + horizon_curve(top) - shift).round
    end

    def row_width_scale_any(row)
      return row_width_scale(row) if row_covered?(row)
      th = TilemapRenderer::DISPLAY_TILE_HEIGHT
      top = (row.to_i * th) - (@row_offset || 0)
      return width_scale_at(top + (th / 2.0))
    end

    # Fila de la tabla que le corresponde a una coordenada de pantalla sin
    # proyectar. Es la inversa de "top = (row * alto) - @row_offset", y permite
    # que cualquier sprite ajeno a la rejilla del motor (las capas extendidas de
    # MakerStudio, las paredes generadas) use exactamente las mismas cuentas que
    # los tiles nativos y encaje con ellos sin costuras.
    def row_at(unprojected_y)
      if @row_offset
        return ((unprojected_y + @row_offset).to_f / TilemapRenderer::DISPLAY_TILE_HEIGHT).round
      end
      return (unprojected_y.to_f / TilemapRenderer::DISPLAY_TILE_HEIGHT).floor
    end

    def row_width_scale(row)
      return 1.0 if !@row_width
      row = 0 if row < 0
      row = @row_max if row > @row_max
      return @row_width[row]
    end

    def row_taper(row)
      return 1.0 if !@row_taper
      row = 0 if row < 0
      row = @row_max if row > @row_max
      return @row_taper[row]
    end

    def row_unit(row)
      return 0.0 if !@row_unit
      row = 0 if row < 0
      row = @row_max if row > @row_max
      return @row_unit[row]
    end

    # Lo que sube en pantalla el borde de una casilla por cada tile de pared.
    #
    # Es una fraccion fija del alto de la fila, asi que el bordillo se lleva
    # siempre la misma porcion de suelo a cualquier distancia y no cambia de
    # forma mientras el mapa se desplaza.
    def row_step(row)
      if !@row_top
        pixel_offset_y = @row_offset
        if pixel_offset_y.nil?
          renderer = ($scene.is_a?(Scene_Map) && $scene.respond_to?(:map_renderer)) ? $scene.map_renderer : nil
          pixel_offset_y = renderer.instance_variable_get(:@pixel_offset_y) if renderer && !renderer.disposed?
        end
        return step_at_row(row, pixel_offset_y) if pixel_offset_y
        return 0.0
      end
      height = row_top(row + 1) - row_top(row)
      return 0.0 if height <= 0
      return height * Config::WALL_STEP_RATIO
    end

    # Igual que row_step, pero continuo: lo usan los personajes, que no van por
    # filas de la rejilla sino por pixeles.
    def step_at(y)
      height = project_y(y + TilemapRenderer::DISPLAY_TILE_HEIGHT) - project_y(y)
      return 0.0 if height <= 0
      return height * Config::WALL_STEP_RATIO
    end

    def step_at_row(row, pixel_offset_y)
      tile_height = TilemapRenderer::DISPLAY_TILE_HEIGHT
      y = (row * tile_height) - pixel_offset_y
      return step_at(y)
    end

    # Los sprites de personaje se actualizan antes que el tilemap; hay que tener
    # la tabla de filas lista para row_step y row_at. Si pixel_offset_y cambio
    # (correr N/S), reconstruir: el early-out viejo dejaba la tabla del frame
    # anterior y los sprites se arrastraban respecto al suelo.
    def ensure_projection
      if enabled? && $game_map
        poy = display_pixel_offset_y($game_map)
        if !@row_top || @projection_dirty || @row_offset != poy
          update_projection(poy)
        end
        return
      end
      return if @row_top && !@projection_dirty
      renderer = ($scene.is_a?(Scene_Map) && $scene.respond_to?(:map_renderer)) ? $scene.map_renderer : nil
      return if !renderer || renderer.disposed?
      pixel_offset_y = renderer.instance_variable_get(:@pixel_offset_y)
      return if pixel_offset_y.nil?
      update_projection(pixel_offset_y)
    end

    # pixel_offset_y que usara el tilemap este frame, con display SIN shift
    # (el resto % 32 coincide con el display corrido) mas el margen V25D.
    def display_pixel_offset_y(map)
      return 0 if !map
      zoom_y = TilemapRenderer::ZOOM_Y
      display_y = (map.display_y.to_f / Game_Map::Y_SUBPIXELS).round
      if zoom_y != 1
        display_y = ((display_y + (Graphics.height / 2)) * zoom_y) - (Graphics.height / 2)
      end
      remainder = (display_y % TilemapRenderer::SOURCE_TILE_HEIGHT) * zoom_y
      return remainder + margin_offset_y
    end

    # Antes de Sprite_Character: misma tabla de filas que el tilemap de este frame.
    def sync_projection_from_map!(map = $game_map)
      return if !enabled? || !map
      refresh_margins if !@margin_rows
      update_projection(display_pixel_offset_y(map))
      prime_map_offsets!
    end

    #---------------------------------------------------------------------------
    # Texturas generadas por codigo
    #---------------------------------------------------------------------------

    def cached_bitmap(key)
      @bitmaps ||= {}
      bitmap = @bitmaps[key]
      return bitmap if bitmap && !bitmap.disposed?
      bitmap = yield
      @bitmaps[key] = bitmap
      return bitmap
    end

    # Degradado vertical de la niebla, a pantalla completa. :top es la distancia
    # y :bottom el primer plano.
    def haze_bitmap(edge = :top)
      falloff = (edge == :top) ? Config::HAZE_FALLOFF : Config::NEAR_HAZE_FALLOFF
      ratio = (edge == :top) ? Config::HAZE_HEIGHT : Config::NEAR_HAZE_HEIGHT
      color = Config::HAZE_COLOR
      # Cache incluye curva/color: cambiar Settings + reload no deja Bitmap viejo.
      cached_bitmap([:haze, edge, Graphics.width, Graphics.height,
                     ratio, falloff, color.red, color.green, color.blue]) do
        width  = Graphics.width
        height = Graphics.height
        bitmap = Bitmap.new(width, height)
        limit = [(height * ratio).round, 1].max
        limit.times do |j|
          strength = 1.0 - (j.to_f / limit)
          alpha = (255 * (strength**falloff)).round
          next if alpha <= 0
          row = (edge == :top) ? j : height - 1 - j
          bitmap.fill_rect(0, row, width, 1, Color.new(color.red, color.green, color.blue, alpha))
        end
        bitmap
      end
    end

    def vignette_size
      return [([Graphics.width, Graphics.height].min * Config::VIGNETTE_SIZE).round, 1].max
    end

    # Degradado de un borde de pantalla. Los cuatro se solapan en las esquinas,
    # que es justo donde el vineteado tiene que ser mas intenso.
    def vignette_bitmap(edge)
      size = vignette_size
      color = Config::VIGNETTE_COLOR
      falloff = Config::VIGNETTE_FALLOFF.to_f
      falloff = 2.0 if falloff <= 0
      cached_bitmap([:vignette, edge, size, Graphics.width, Graphics.height,
                     falloff, color.red, color.green, color.blue]) do
        horizontal = [:left, :right].include?(edge)
        bitmap = horizontal ? Bitmap.new(size, Graphics.height) : Bitmap.new(Graphics.width, size)
        reversed = [:right, :bottom].include?(edge)
        size.times do |i|
          strength = 1.0 - (i.to_f / size)
          alpha = (255 * (strength**falloff)).round
          next if alpha <= 0
          pos = reversed ? size - 1 - i : i
          shade = Color.new(color.red, color.green, color.blue, alpha)
          if horizontal
            bitmap.fill_rect(pos, 0, 1, Graphics.height, shade)
          else
            bitmap.fill_rect(0, pos, Graphics.width, 1, shade)
          end
        end
        bitmap
      end
    end
  end
end

Visual25D.reset_to_defaults

# Cargar partida → releer tilt/zoom/enabled del save.
EventHandlers.add(:on_game_load, :visual25d_sync_save, proc {
  Visual25D.mark_save_sync_dirty!
  Visual25D.ensure_perf_auto!
})

#===============================================================================
# [VERMEIL] Visual 2.5D - 030_ModelStream.rb
# V5.14 - Deferred/idle Model Studio mesh loader
#
# MapXXX.v25r contains first-frame geometry. Model faces live in
# MapXXX.v25m and are decoded/registered with a strict per-frame budget.
# This keeps large authored models off the synchronous Scene_Map load path.
#===============================================================================

class Mode7Renderer
  if method_defined?(:update) && !method_defined?(:_VERMEIL_V513_stream_orig_update)
    alias_method :_VERMEIL_V513_stream_orig_update, :update
  end
  if method_defined?(:dispose) && !method_defined?(:_VERMEIL_V513_stream_orig_dispose)
    alias_method :_VERMEIL_V513_stream_orig_dispose, :dispose
  end

  def update
    _VERMEIL_V513_stream_orig_update
    nds_model_stream_step
  end

  def dispose
    nds_close_model_stream
    _VERMEIL_V513_stream_orig_dispose
  end

  private

  def nds_close_model_stream
    io = @nds_model_stream_io
    io.close if io && !io.closed?
  rescue Exception
  ensure
    @nds_model_stream_io = nil
    @nds_model_stream_materials = nil
    @nds_model_stream_done = true
  end

  def nds_prepare_model_stream
    geo = @nds_surface_geometry
    path = geo && geo.respond_to?(:model_stream_path) ? geo.model_stream_path : nil
    return false if !path || path.to_s.empty?
    return false if @nds_model_stream_done && @nds_model_stream_map_id == @map_id
    return true if @nds_model_stream_io && !@nds_model_stream_io.closed? &&
                   @nds_model_stream_map_id == @map_id

    nds_close_model_stream if @nds_model_stream_io
    @nds_model_stream_done = false
    @nds_model_stream_map_id = @map_id
    unless File.file?(path)
      @nds_model_stream_done = true
      return false
    end

    @nds_model_stream_io = File.open(path, "rb")
    magic = @nds_model_stream_io.gets.to_s.strip
    raise "Expected V25M1" if magic != "V25M1"
    header_line = @nds_model_stream_io.gets.to_s.strip
    raise "Missing V25M header" if header_line.empty? || header_line.getbyte(0) != 72
    header = Mode7::V25Codec.decode(header_line.byteslice(1, header_line.bytesize - 1))
    @nds_model_stream_materials = header.is_a?(Hash) && header["materials"].is_a?(Array) ? header["materials"] : []
    @nds_model_stream_total = header.is_a?(Hash) ? header["count"].to_i : 0
    @nds_model_stream_loaded = 0
    true
  rescue Exception => e
    Console.echo_error("2.5D model stream open: #{e.message}") if defined?(Console)
    nds_close_model_stream
    false
  end

  def nds_model_stream_step
    geo = @nds_surface_geometry
    return if !geo || !geo.respond_to?(:model_stream_path) || !geo.model_stream_path
    return if @nds_model_stream_done && @nds_model_stream_map_id == @map_id

    # Do not even open the model stream during Scene_Map's first frames. Terrain
    # planes are already in the tiny runtime file, so the player gets control
    # before optional low-poly props start parsing.
    @nds_model_stream_age = @nds_model_stream_age.to_i + 1
    delay = Mode7::Config.const_defined?(:NDS_MODEL_STREAM_START_DELAY_FRAMES) ?
            Mode7::Config::NDS_MODEL_STREAM_START_DELAY_FRAMES.to_i : 8
    return if @nds_model_stream_age <= [delay, 0].max
    interval = Mode7::Config.const_defined?(:NDS_MODEL_STREAM_INTERVAL_FRAMES) ?
               Mode7::Config::NDS_MODEL_STREAM_INTERVAL_FRAMES.to_i : 1
    interval = 1 if interval < 1
    return if (@nds_model_stream_age % interval) != 0
    idle_only = Mode7::Config.const_defined?(:NDS_MODEL_STREAM_IDLE_ONLY) ?
                Mode7::Config::NDS_MODEL_STREAM_IDLE_ONLY : true
    if idle_only && defined?($game_player) && $game_player &&
       $game_player.respond_to?(:moving?) && $game_player.moving?
      return
    end

    return if !nds_prepare_model_stream

    io = @nds_model_stream_io
    return if !io || io.closed?
    budget = Mode7::Config.const_defined?(:NDS_MODEL_STREAM_FACE_BUDGET) ?
             Mode7::Config::NDS_MODEL_STREAM_FACE_BUDGET.to_i : 32
    budget = 1 if budget < 1
    time_ms = Mode7::Config.const_defined?(:NDS_MODEL_STREAM_TIME_MS) ?
              Mode7::Config::NDS_MODEL_STREAM_TIME_MS.to_f : 0.75
    time_ms = 0.5 if time_ms <= 0.0
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC) rescue nil

    tw = Game_Map::TILE_WIDTH.to_f
    th = Game_Map::TILE_HEIGHT.to_f
    step = geo.height_step.to_f
    step = 32.0 if step <= 0.0
    loaded = 0
    while loaded < budget
      line = io.gets
      if !line
        nds_close_model_stream
        Console.echoln("[VERMEIL] Model stream ready: #{@nds_model_stream_loaded}/#{@nds_model_stream_total} faces") if defined?(Console) && Mode7::Config::NDS_SHOW_PERFORMANCE_DEBUG
        break
      end
      line = line.strip
      next if line.empty?
      next if line.getbyte(0) != 70
      row = Mode7::V25Codec.decode(line.byteslice(1, line.bytesize - 1))
      mf = Mode7::SurfaceGeometry.normalize_compact_mesh_face(row, @nds_model_stream_materials || [])
      next if !mf
      geo.mesh_faces << mf
      # Register only this newly parsed face. Bitmaps/sprites stay lazy and are
      # still governed by NDS_OBJECT_FACE_BUILD_BUDGET/culling.
      nds_object_build_region_mesh_faces(tw, th, step, [mf]) if respond_to?(:nds_object_build_region_mesh_faces, true)
      @nds_model_stream_loaded = @nds_model_stream_loaded.to_i + 1
      loaded += 1
      if t0
        elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0 rescue 0.0
        break if elapsed >= time_ms
      end
    end
    # Force visibility recalc after adding bucket entries.
    if loaded > 0 && defined?(Mode7::ModelPhysicsWorld) &&
       Mode7::ModelPhysicsWorld.respond_to?(:refresh_surface_fallback)
      Mode7::ModelPhysicsWorld.refresh_surface_fallback(@map_id, geo)
    end
    @nds_object_projection_key = nil
    @nds_object_visibility_key = nil
  rescue Exception => e
    Console.echo_error("2.5D model stream: #{e.message}") if defined?(Console)
    nds_close_model_stream
  end
end

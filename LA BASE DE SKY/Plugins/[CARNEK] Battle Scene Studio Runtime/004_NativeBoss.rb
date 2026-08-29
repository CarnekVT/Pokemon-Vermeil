#===============================================================================
# Battle Scene Studio Runtime 0.6.37
# BSS-native Boss/Totem layer.
#
# Totem aura goals:
# - EBDX-style charge sequence when opening stat stages are configured.
# - Persistent charged particles for the whole battle.
# - Persistent particles follow the *live* BattlerSprite geometry (x/y/z,
#   zoom, rotation, mirror, opacity and visibility) instead of a cached anchor.
# - The aura is updated from the same frame pumps used by normal battle UI and
#   BAS playback, so target selection/message windows do not freeze it.
# - When Battle Animation Studio Runtime is present, the charge sequence uses a
#   BAS camera-only timeline to focus/zoom the Totem. Without BAS, the exact
#   same charge sequence plays without camera zoom.
# - BSS aura sprites are registered in Scene#@sprites. A tiny BAS compatibility
#   layer marks their keys as world sprites so BAS camera transforms also affect
#   them while move/common animations are running.
#
# The default particle/ray/ripple behavior is adapted from the supplied Elite
# Battle DX AURAFLARE/charged behavior, but this runtime remains BSS-owned and
# does not require EBDX to be installed.
#===============================================================================
module BSS064
  BOSS_AURA_FRAME_GRAPHICS = [
    "Graphics/BattleSceneStudio/Auras/TotemCharged001.png",
    "Graphics/BattleSceneStudio/Auras/TotemCharged002.png",
    "Graphics/BattleSceneStudio/Auras/TotemCharged003.png",
    "Graphics/BattleSceneStudio/Auras/TotemCharged004.png"
  ]
  BOSS_INTRO_PARTICLES    = [
    "Graphics/BattleSceneStudio/Auras/TotemIntroParticle001.png",
    "Graphics/BattleSceneStudio/Auras/TotemIntroParticle002.png",
    "Graphics/BattleSceneStudio/Auras/TotemIntroParticle003.png",
    "Graphics/BattleSceneStudio/Auras/TotemIntroParticle004.png"
  ]
  BOSS_AURA_RAY_GRAPHIC   = "Graphics/BattleSceneStudio/Auras/TotemAuraRay.png"
  BOSS_AURA_RIPPLE_GRAPHIC= "Graphics/BattleSceneStudio/Auras/TotemAuraRipple.png"
  BOSS_AURA_IMPACT_GRAPHIC= "Graphics/BattleSceneStudio/Auras/TotemImpact.png"
  BOSS_AURA_DEFAULT_RGB   = [221, 68, 91]

  class << self
    def configure_native_boss(battle, bp)
      cfg = hget(bp, "boss")
      cfg = {} if !cfg.is_a?(Hash)
      battle.bss_boss_config = cfg if battle.respond_to?(:bss_boss_config=)
      battle.bss_boss_applied = false if battle.respond_to?(:bss_boss_applied=)
      battle.bss_boss_intro_pending = false if battle.respond_to?(:bss_boss_intro_pending=)
      battle.bss_boss_intro_shown = false if battle.respond_to?(:bss_boss_intro_shown=)
      battle.bss_boss_aura_active = false if battle.respond_to?(:bss_boss_aura_active=)
      if cfg["enabled"] == true
        install_bas_aura_compat
        install_scene_aura_compat(battle)
      end
    rescue => e
      log("Boss configure failed: #{e.class}: #{e.message}")
    end

    def bas_available?
      return false if !defined?(BattleAnimationStudioRuntime)
      return false if !defined?(BattleAnimationStudioRuntime::Player)
      true
    rescue
      false
    end

    def install_bas_aura_compat
      return false if !bas_available?
      klass = BattleAnimationStudioRuntime::Player
      # Only extend BAS when the method actually exists. This keeps BSS from
      # injecting an incomplete override into unrelated BAS builds/battles.
      has_world_key = klass.method_defined?(:camera_world_sprite_key?) || klass.private_method_defined?(:camera_world_sprite_key?)
      return false if !has_world_key
      if !klass.ancestors.include?(BSS064BASWorldSpriteCompat)
        klass.prepend(BSS064BASWorldSpriteCompat)
      end
      true
    rescue => e
      log("Boss BAS aura compat warning: #{e.class}: #{e.message}")
      false
    end

    def install_scene_aura_compat(battle)
      scene = battle.instance_variable_get(:@scene) rescue nil
      return false if !scene
      singleton = class << scene; self; end
      if (scene.respond_to?(:pbFrameUpdate) || scene.respond_to?(:pbUpdate)) && !singleton.ancestors.include?(BSS064BossAuraFrameCompat)
        singleton.prepend(BSS064BossAuraFrameCompat)
      end
      if scene.respond_to?(:bas_runtime_pump_frame) && !singleton.ancestors.include?(BSS064BossAuraBASPumpCompat)
        singleton.prepend(BSS064BossAuraBASPumpCompat)
      end
      if !singleton.ancestors.include?(BSS064BossAnimationScaleCompat)
        singleton.prepend(BSS064BossAnimationScaleCompat)
      end
      if scene.respond_to?(:pbPlayBattleAnimationStudio) && !singleton.ancestors.include?(BSS064BossBASAnimationScaleCompat)
        singleton.prepend(BSS064BossBASAnimationScaleCompat)
      end
      true
    rescue => e
      log("Boss scene compat warning: #{e.class}: #{e.message}")
      false
    end

    # Numeric config can be absent in older blueprints. Avoid Integer(nil)/
    # Float(nil) entirely: mkxp-z/PBDebug reports even rescued exceptions, which
    # previously produced an endless TypeError log from the aura frame loop.
    def clamp_int(v, min, max, fallback)
      lo=min.to_i; hi=max.to_i
      base=fallback.is_a?(Numeric) ? fallback.to_i : lo
      n=base
      if v.is_a?(Numeric)
        n=v.to_i
      elsif !v.nil?
        text=v.to_s.strip
        n=text.to_f.to_i if text =~ /\A[+-]?(?:\d+(?:\.\d*)?|\.\d+)\z/
      end
      [[n,lo].max,hi].min
    end

    def clamp_float(v, min, max, fallback)
      lo=min.to_f; hi=max.to_f
      base=fallback.is_a?(Numeric) ? fallback.to_f : lo
      n=base
      if v.is_a?(Numeric)
        n=v.to_f
      elsif !v.nil?
        text=v.to_s.strip
        n=text.to_f if text =~ /\A[+-]?(?:\d+(?:\.\d*)?|\.\d+)\z/
      end
      n=base if n.respond_to?(:finite?) && !n.finite?
      [[n,lo].max,hi].min
    end

    def aura_color_rgb(value)
      s = value.to_s.strip
      if s =~ /\A#?([0-9a-fA-F]{6})\z/
        hex = $1
        return [hex[0,2].to_i(16), hex[2,2].to_i(16), hex[4,2].to_i(16)]
      end
      BOSS_AURA_DEFAULT_RGB.clone
    rescue
      BOSS_AURA_DEFAULT_RGB.clone
    end

    def aura_graphic_paths(raw)
      fallback=BOSS_AURA_FRAME_GRAPHICS.clone
      raw={} if !raw.is_a?(Hash)
      mode=raw["graphicMode"].to_s.downcase
      mode="sequence" if !["single","sequence"].include?(mode)
      clean=lambda do |v|
        path=v.to_s.strip.tr("\\","/")
        next nil if path.empty? || path.include?("..")
        next nil if path !~ /\AGraphics\/.+\.(?:png|gif|jpg|jpeg|webp)\z/i
        path
      end
      if mode=="single"
        one=clean.call(raw["particleGraphic"]) || fallback[0]
        return [one]
      end
      rows=raw["particleGraphics"].is_a?(Array) ? raw["particleGraphics"] : []
      rows=rows[0,12].map { |v| clean.call(v) }.compact
      rows.empty? ? fallback : rows
    rescue
      BOSS_AURA_FRAME_GRAPHICS.clone
    end

    def boss_aura_config(boss_cfg)
      raw = boss_cfg.is_a?(Hash) && boss_cfg["aura"].is_a?(Hash) ? boss_cfg["aura"] : {}
      spawn_mode=raw["spawnMode"].to_s
      spawn_mode="async" if !["async","simultaneous"].include?(spawn_mode)
      {
        "profileId"      => (raw["profileId"].to_s.empty? ? "ebdx_default" : raw["profileId"].to_s),
        "enabled"        => raw["enabled"] != false,
        "introEnabled"   => raw["introEnabled"] != false,
        "introSpotlight" => raw["introSpotlight"] != false,
        "color"          => (raw["color"].to_s.empty? ? "#DD445B" : raw["color"].to_s),
        "particleCount"  => clamp_int(raw["particleCount"], 4, 24, 12),
        "riseSpeed"      => clamp_float(raw["riseSpeed"], 25.0, 300.0, 135.0),
        "cycleFrames"    => clamp_float(raw["cycleFrames"], 10.0, 120.0, 30.0),
        "riseHeight"     => clamp_float(raw["riseHeight"], 20.0, 300.0, 100.0),
        "spreadX"        => clamp_float(raw["spreadX"], 25.0, 200.0, 100.0),
        "spreadY"        => clamp_float(raw["spreadY"], 25.0, 180.0, 80.0),
        "laneWidth"      => clamp_float(raw["laneWidth"], 25.0, 200.0, 100.0),
        "swayAmount"     => clamp_float(raw["swayAmount"], 0.0, 300.0, 100.0),
        "offsetX"        => clamp_float(raw["offsetX"], -100.0, 100.0, 0.0),
        "offsetY"        => clamp_float(raw["offsetY"], -100.0, 100.0, 0.0),
        "particleScale"  => clamp_float(raw["particleScale"], 25.0, 250.0, 100.0),
        "stretchStart"   => clamp_float(raw["stretchStart"], 10.0, 250.0, 62.0),
        "stretchEnd"     => clamp_float(raw["stretchEnd"], 10.0, 300.0, 132.0),
        "opacity"        => clamp_float(raw["opacity"], 0.0, 100.0, 100.0),
        "opacityStart"   => clamp_float(raw["opacityStart"], 0.0, 100.0, 0.0),
        "opacityMid"     => clamp_float(raw["opacityMid"], 0.0, 100.0, 100.0),
        "opacityEnd"     => clamp_float(raw["opacityEnd"], 0.0, 100.0, 0.0),
        "spawnMode"      => spawn_mode,
        "asyncAmount"    => clamp_float(raw["asyncAmount"], 0.0, 300.0, 100.0),
        "graphicMode"    => (["single","sequence"].include?(raw["graphicMode"].to_s.downcase) ? raw["graphicMode"].to_s.downcase : "sequence"),
        "particleGraphic"=> (raw["particleGraphic"].to_s.empty? ? BOSS_AURA_FRAME_GRAPHICS[0] : raw["particleGraphic"].to_s),
        "particleGraphics"=> aura_graphic_paths(raw.merge("graphicMode"=>"sequence")),
        "graphicFrameFrames"=> clamp_float(raw["graphicFrameFrames"], 1.0, 60.0, 6.0),
        "depthMode"      => (["alternate","front","back"].include?(raw["depthMode"].to_s) ? raw["depthMode"].to_s : "alternate"),
        "blendMode"      => (["normal","additive"].include?(raw["blendMode"].to_s) ? raw["blendMode"].to_s : "normal"),
        "introDuration"  => clamp_int(raw["introDuration"], 48, 180, 104),
        "impactHold"     => clamp_int(raw["impactHold"], 0, 120, 56),
        "introReturnFrames"=> clamp_int(raw["introReturnFrames"], 8, 60, 24),
        "fadeOutFrames"  => clamp_int(raw["fadeOutFrames"], 1, 90, 18),
        "outlineEnabled" => raw["outlineEnabled"] != false,
        "outlineColor"   => (raw["outlineColor"].to_s.empty? ? (raw["color"].to_s.empty? ? "#DD445B" : raw["color"].to_s) : raw["outlineColor"].to_s),
        "outlineOpacity" => clamp_float(raw["outlineOpacity"], 0.0, 100.0, 46.0),
        "outlineSize"    => clamp_int(raw["outlineSize"], 1, 8, 2),
        "basZoomEnabled" => raw["basZoomEnabled"] != false,
        "basZoom"        => clamp_float(raw["basZoom"], 100.0, 220.0, 150.0),
        "basZoomBounds"  => (["screen","extended"].include?(raw["basZoomBounds"].to_s) ? raw["basZoomBounds"].to_s : "screen")
      }
    rescue
      {
        "profileId"=>"ebdx_default", "enabled"=>true, "introEnabled"=>true, "introSpotlight"=>true, "color"=>"#DD445B",
        "particleCount"=>12, "riseSpeed"=>135.0, "cycleFrames"=>30.0, "riseHeight"=>100.0, "spreadX"=>100.0, "spreadY"=>80.0,
        "laneWidth"=>100.0, "swayAmount"=>100.0, "offsetX"=>0.0, "offsetY"=>0.0, "particleScale"=>100.0, "stretchStart"=>62.0, "stretchEnd"=>132.0,
        "opacity"=>100.0, "opacityStart"=>0.0, "opacityMid"=>100.0, "opacityEnd"=>0.0, "spawnMode"=>"async", "asyncAmount"=>100.0, "graphicMode"=>"sequence", "particleGraphic"=>BOSS_AURA_FRAME_GRAPHICS[0], "particleGraphics"=>BOSS_AURA_FRAME_GRAPHICS.clone, "graphicFrameFrames"=>6.0, "depthMode"=>"alternate", "blendMode"=>"normal",
        "introDuration"=>104, "impactHold"=>56, "introReturnFrames"=>24, "fadeOutFrames"=>18,
        "outlineEnabled"=>true, "outlineColor"=>"#DD445B", "outlineOpacity"=>46.0, "outlineSize"=>2,
        "basZoomEnabled"=>true, "basZoom"=>150.0, "basZoomBounds"=>"screen"
      }
    end

    # EBDX authored its aura at a 40 FPS baseline.  Normalizing every
    # per-frame delta keeps the same visual speed at 60/120 FPS and also avoids
    # fast-forwarding when a UI calls pbFrameUpdate more than once per frame.
    def ebdx_frame_delta
      rate=(Graphics.frame_rate rescue 40).to_f
      rate=40.0 if rate<=0
      [rate/40.0,0.25].max
    rescue
      1.0
    end

    def play_aura_se(name,volume=100,pitch=100)
      return false if name.to_s.empty? || !defined?(pbSEPlay)
      pbSEPlay(name.to_s,volume.to_i,pitch.to_i)
      true
    rescue => e
      log("Boss aura SE #{name} warning: #{e.class}: #{e.message}")
      false
    end

    def resolve_bitmap_path(path)
      resolved = nil
      begin
        resolved = pbResolveBitmap(path) if defined?(pbResolveBitmap)
      rescue
      end
      resolved && !resolved.to_s.empty? ? resolved : path
    end

    def new_bitmap(path)
      Bitmap.new(resolve_bitmap_path(path))
    rescue => e
      log("Boss aura bitmap failed #{path}: #{e.class}: #{e.message}")
      nil
    end

    # Real-time clock for aura pacing. Graphics.frame_rate is not reliable in
    # every mkxp-z/LBDS setup (some projects render at 120 FPS while reporting
    # a lower logical rate), which made the passive aura race ahead.
    def monotonic_seconds
      if Process.respond_to?(:clock_gettime) && defined?(Process::CLOCK_MONOTONIC)
        return Process.clock_gettime(Process::CLOCK_MONOTONIC).to_f
      end
      return System.uptime.to_f if defined?(System) && System.respond_to?(:uptime)
      fc=(Graphics.frame_count rescue 0).to_f
      fr=(Graphics.frame_rate rescue 40).to_f
      fr=40.0 if fr<=0
      fc/fr
    rescue
      Time.now.to_f
    end
  end

  # Geometry helpers shared by the intro and persistent emitter.
  module BossAuraGeometry
    def target_state(target_sprite)
      return nil if !target_sprite || (target_sprite.respond_to?(:disposed?) && target_sprite.disposed?)
      bmp = target_sprite.respond_to?(:bitmap) ? target_sprite.bitmap : nil
      return nil if !bmp || (bmp.respond_to?(:disposed?) && bmp.disposed?)
      src=(target_sprite.src_rect rescue nil)
      visible_w=(src && src.width.to_i>0) ? src.width.to_f : bmp.width.to_f
      visible_h=(src && src.height.to_i>0) ? src.height.to_f : bmp.height.to_f
      {
        :x => (target_sprite.x rescue 0).to_f,
        :y => (target_sprite.y rescue 0).to_f,
        :z => (target_sprite.z rescue 50).to_i,
        :ox => (target_sprite.ox rescue 0).to_f,
        :oy => (target_sprite.oy rescue 0).to_f,
        :zoom_x => (target_sprite.zoom_x rescue 1.0).to_f,
        :zoom_y => (target_sprite.zoom_y rescue 1.0).to_f,
        :angle => (target_sprite.angle rescue 0).to_f,
        :mirror => !!(target_sprite.mirror rescue false),
        :opacity => (target_sprite.opacity rescue 255).to_i,
        :visible => (target_sprite.visible rescue true),
        # Use the actually visible frame, not the full animated battler sheet.
        # This is important for Animated Pokémon/BAS where bitmap.width can be
        # several frames wide even though only src_rect is on screen.
        :width => visible_w,
        :height => visible_h
      }
    rescue
      nil
    end

    def local_to_world(state, nx, ny, rise_px = 0.0)
      px = nx.to_f * state[:width]
      px = state[:width] - px if state[:mirror]
      py = ny.to_f * state[:height] - rise_px.to_f
      dx = (px - state[:ox]) * state[:zoom_x]
      dy = (py - state[:oy]) * state[:zoom_y]
      rad = state[:angle].to_f * Math::PI / 180.0
      cos = Math.cos(rad)
      sin = Math.sin(rad)
      [state[:x] + dx * cos - dy * sin, state[:y] + dx * sin + dy * cos]
    rescue
      [state[:x], state[:y]]
    end

    def target_center(state)
      local_to_world(state, 0.5, 0.48, 0.0)
    end

    def aura_tone(rgb)
      d = BSS064::BOSS_AURA_DEFAULT_RGB
      Tone.new(
        [[rgb[0].to_i - d[0], -255].max, 255].min,
        [[rgb[1].to_i - d[1], -255].max, 255].min,
        [[rgb[2].to_i - d[2], -255].max, 255].min,
        0
      )
    rescue
      Tone.new(0,0,0,0)
    end
  end

  # Persistent EBDX-style charged particles.
  # The original reference is a 4-frame strip, but BSS ships and loads four
  # separate frame PNGs. No persistent Sprite ever receives the full strip.
  class BossAuraEmitter
    include BossAuraGeometry
    FRAME_COUNT = 4

    def initialize(viewport, scene_sprites, cfg, key_prefix = "bss_totem_persistent")
      @viewport = viewport
      @scene_sprites = scene_sprites.is_a?(Hash) ? scene_sprites : nil
      @cfg = cfg || {}
      @key_prefix = key_prefix.to_s
      # Persistent aura never loads the 4-cell strip. Each cell is shipped as
      # its own 70x70 asset so no renderer/BAS wrapper can ever expose the full
      # sheet outside the activation sequence.
      paths=BSS064.aura_graphic_paths(@cfg);@frame_bitmaps = paths.map { |path| BSS064.new_bitmap(path) }.compact;@frame_bitmaps = BSS064::BOSS_AURA_FRAME_GRAPHICS.map { |path| BSS064.new_bitmap(path) }.compact if @frame_bitmaps.empty?
      @particles = []
      @frame = 0.0
      @last_clock = nil
      @disposed = false
      @rgb = BSS064.aura_color_rgb(@cfg["color"])
      @tone = aura_tone(@rgb)
      count = BSS064.clamp_int(@cfg["particleCount"], 4, 24, 12)
      count.times { |i| create_particle(i, count) }
    end

    def disposed?; @disposed; end

    def logical_step
      now=BSS064.monotonic_seconds
      if @last_clock.nil?
        @last_clock=now
        return 0.0
      end
      dt=now-@last_clock
      @last_clock=now
      return 0.0 if dt<=0
      # Do not fast-forward the emitter after a blocking transition/menu stall.
      dt=0.05 if dt>0.05
      dt*40.0
    rescue
      0.0
    end

    def frame_bitmap(index)
      return nil if @frame_bitmaps.empty?
      @frame_bitmaps[index.to_i % @frame_bitmaps.length]
    end

    def create_particle(i, count)
      sp = Sprite.new(@viewport)
      bmp=frame_bitmap(0)
      sp.bitmap = bmp if bmp
      if bmp
        sp.ox = bmp.width / 2
        sp.oy = bmp.height
      end
      sp.visible = false
      sp.opacity = 0
      sp.tone = @tone if sp.respond_to?(:tone=)
      sp.blend_type = (@cfg["blendMode"].to_s == "additive" ? 1 : 0) if sp.respond_to?(:blend_type=)
      key = "#{@key_prefix}_#{i}"
      @scene_sprites[key] = sp if @scene_sprites
      # Stable lanes instead of a new random point on every respawn. The four
      # TotemCharged cells now play in order, so the passive aura reads as a
      # coherent flame field hugging the battler rather than sparks scattered
      # independently around it.
      denom=[count.to_i-1,1].max.to_f
      lane=i.to_f/denom
      row=(i % 3)
      @particles << {
        :sprite=>sp, :key=>key, :lane=>lane, :row=>row,
        :phase=>(@cfg["spawnMode"].to_s=="simultaneous" ? 0.0 : i.to_f*7.0*(BSS064.clamp_float(@cfg["asyncAmount"],0,300,100)/100.0)), :front=>(i % 2 == 0),
        :frame_index=>0
      }
    rescue => e
      BSS064.log("Boss aura particle create warning: #{e.class}: #{e.message}")
    end

    def dispose
      return if @disposed
      @particles.each do |row|
        sp = row[:sprite]
        begin
          @scene_sprites.delete(row[:key]) if @scene_sprites && @scene_sprites[row[:key]].equal?(sp)
        rescue
        end
        begin
          sp.dispose if sp && !sp.disposed?
        rescue
        end
      end
      @particles.clear
      @frame_bitmaps.each do |bmp|
        begin; bmp.dispose if bmp && !bmp.disposed?; rescue; end
      end
      @frame_bitmaps.clear
      @disposed = true
    end

    def smoothstep01(x)
      x=[[x.to_f,0.0].max,1.0].min
      x*x*(3.0-2.0*x)
    end

    def opacity_curve(t)
      start=BSS064.clamp_float(@cfg["opacityStart"],0,100,0)/100.0
      mid=BSS064.clamp_float(@cfg["opacityMid"],0,100,100)/100.0
      finish=BSS064.clamp_float(@cfg["opacityEnd"],0,100,0)/100.0
      if t.to_f<=0.5
        q=smoothstep01(t.to_f*2.0)
        start+(mid-start)*q
      else
        q=smoothstep01((t.to_f-0.5)*2.0)
        mid+(finish-mid)*q
      end
    rescue
      1.0
    end

    def update(target_sprite, battler, master_alpha=1.0, allow_fainted=false)
      return if @disposed
      state = target_state(target_sprite)
      fainted=(battler.fainted? rescue false)
      if !state || !battler || (fainted && !allow_fainted) || ((!state[:visible] || state[:opacity] <= 0) && !allow_fainted) || @frame_bitmaps.empty?
        hide_all
        return
      end
      step=logical_step
      # A final fade still needs to render even if two update hooks hit the same
      # monotonic instant. Geometry remains live; only particle phase waits.
      @frame += step if step>0
      speed = BSS064.clamp_float(@cfg["riseSpeed"],25,300,135) / 100.0
      cycle_frames = BSS064.clamp_float(@cfg["cycleFrames"],10,120,30)
      rise_height = BSS064.clamp_float(@cfg["riseHeight"],20,300,100) / 100.0
      spread_x = BSS064.clamp_float(@cfg["spreadX"],25,200,100) / 100.0
      spread_y = BSS064.clamp_float(@cfg["spreadY"],25,180,80) / 100.0
      lane_width = BSS064.clamp_float(@cfg["laneWidth"],25,200,100) / 100.0
      sway_amount = BSS064.clamp_float(@cfg["swayAmount"],0,300,100) / 100.0
      offset_x = BSS064.clamp_float(@cfg["offsetX"],-100,100,0) / 100.0
      offset_y = BSS064.clamp_float(@cfg["offsetY"],-100,100,0) / 100.0
      scale_cfg = BSS064.clamp_float(@cfg["particleScale"],25,250,100) / 100.0
      stretch_start = BSS064.clamp_float(@cfg["stretchStart"],10,250,62) / 100.0
      stretch_end = BSS064.clamp_float(@cfg["stretchEnd"],10,300,132) / 100.0
      opacity_cfg = BSS064.clamp_float(@cfg["opacity"],0,100,100) / 100.0
      depth_mode = @cfg["depthMode"].to_s
      depth_mode = "alternate" if !["alternate","front","back"].include?(depth_mode)
      blend_mode = @cfg["blendMode"].to_s
      global_alpha=[[master_alpha.to_f,0.0].max,1.0].min
      life=[cycle_frames/[speed,0.25].max,14.0].max
      @particles.each_with_index do |row,i|
        sp = row[:sprite]
        next if !sp || (sp.disposed? rescue true)
        raw_t=((@frame+row[:phase].to_f) % life)/life
        start_t=0.075; end_t=0.925
        if raw_t<=start_t || raw_t>=end_t
          sp.opacity=0;sp.visible=false
          next
        end
        t=(raw_t-start_t)/(end_t-start_t)
        t=[[t,0.0].max,1.0].min
        base_lane=0.5 + 0.68*(row[:lane].to_f-0.5)*lane_width
        nx=0.5 + (base_lane-0.5)*spread_x
        nx += Math.sin((t*Math::PI*2.0)+(i*0.73))*0.012*spread_x*sway_amount
        nx=[[nx,0.04].max,0.96].min
        base_y=[0.68,0.54,0.78][row[:row].to_i % 3]
        ny=0.5 + (base_y-0.5)*spread_y
        ny=[[ny,0.10].max,0.92].min
        rise=state[:height]*0.12*t*speed*rise_height
        x,y=local_to_world(state,nx+offset_x,ny+offset_y,rise)
        sp.x=x;sp.y=y
        sp.z = depth_mode == "front" ? state[:z]+1 : (depth_mode == "back" ? state[:z]-1 : (row[:front] ? state[:z]+1 : state[:z]-1))
        sp.blend_type=(blend_mode=="additive" ? 1 : 0) if sp.respond_to?(:blend_type=)
        sp.angle=state[:angle] if sp.respond_to?(:angle=)
        sp.mirror=((nx >= 0.5) ^ state[:mirror]) if sp.respond_to?(:mirror=)
        graphic_frames=BSS064.clamp_float(@cfg["graphicFrameFrames"],1,60,6)
        fi=@frame_bitmaps.empty? ? 0 : (((@frame+row[:phase].to_f)/graphic_frames).floor % @frame_bitmaps.length)
        if row[:frame_index].to_i!=fi
          row[:frame_index]=fi
          bmp=frame_bitmap(fi)
          if bmp && !sp.bitmap.equal?(bmp)
            sp.bitmap=bmp;sp.ox=bmp.width/2;sp.oy=bmp.height
          end
        end
        stretch=stretch_start + (stretch_end-stretch_start)*t
        sp.zoom_x=[state[:zoom_x].abs*scale_cfg,0.05].max
        sp.zoom_y=[state[:zoom_y].abs*scale_cfg*stretch,0.05].max
        alpha=opacity_curve(t)
        live_opacity=allow_fainted ? 255.0 : state[:opacity].to_f
        live_alpha=live_opacity*opacity_cfg*alpha*global_alpha
        sp.opacity=[[live_alpha.round,0].max,255].min
        sp.visible=sp.opacity>1
      end
    rescue => e
      BSS064.log("Boss aura update warning: #{e.class}: #{e.message}")
      hide_all
    end

    def hide_all
      @particles.each do |row|
        sp = row[:sprite]
        sp.visible = false if sp && !(sp.disposed? rescue true)
      end
    rescue
    end
  end

  # Persistent bright contour.  Eight tinted copies of the live battler are
  # rendered just behind it.  They share the battler bitmap (never dispose it)
  # and mirror src_rect/origin/zoom/angle every frame, so forms, spritesheet
  # frames and BAS-authored transformations remain aligned.
  class BossAuraOutline
    def initialize(viewport,scene_sprites,cfg,key_prefix="bss_totem_outline")
      @viewport=viewport;@scene_sprites=scene_sprites.is_a?(Hash) ? scene_sprites : nil
      @cfg=cfg||{};@sprites=[];@disposed=false
      @rgb=BSS064.aura_color_rgb(@cfg["outlineColor"])
      r=BSS064.clamp_int(@cfg["outlineSize"],1,8,2)
      offsets=[[-r,-r],[0,-r],[r,-r],[-r,0],[r,0],[-r,r],[0,r],[r,r]]
      offsets.each_with_index do |ofs,i|
        sp=Sprite.new(@viewport);sp.visible=false;sp.opacity=0
        # Normal blend + a full Color overlay preserves the exact user-picked
        # outline hue. Additive blending could wash saturated colors to white.
        sp.blend_type=0 if sp.respond_to?(:blend_type=)
        sp.color=Color.new(@rgb[0],@rgb[1],@rgb[2],255) if sp.respond_to?(:color=)
        key="#{key_prefix}_#{i}";@scene_sprites[key]=sp if @scene_sprites
        @sprites << [sp,key,ofs]
      end
    rescue => e
      BSS064.log("Boss outline create warning: #{e.class}: #{e.message}")
    end

    def disposed?;@disposed;end

    def update(target,battler,master_alpha=1.0,allow_fainted=false)
      return if @disposed
      bmp=target && target.respond_to?(:bitmap) ? target.bitmap : nil
      fainted=(battler.fainted? rescue false)
      visible=target && bmp && !(bmp.disposed? rescue true) && !(target.disposed? rescue true) && (!fainted || allow_fainted) && (allow_fainted || ((target.visible rescue true) && (target.opacity rescue 255).to_i>0))
      if !visible
        hide_all;return
      end
      src=(target.src_rect rescue nil)
      cfg_op=BSS064.clamp_float(@cfg["outlineOpacity"],0,100,46)/100.0
      fade=[[master_alpha.to_f,0.0].max,1.0].min
      target_op=allow_fainted ? 255.0 : (target.opacity rescue 255).to_f
      base_op=[(target_op*cfg_op*fade).round,0].max
      @sprites.each do |sp,key,ofs|
        next if !sp || (sp.disposed? rescue true)
        sp.bitmap=bmp if !sp.bitmap.equal?(bmp)
        sp.color=Color.new(@rgb[0],@rgb[1],@rgb[2],255) if sp.respond_to?(:color=)
        sp.blend_type=0 if sp.respond_to?(:blend_type=)
        if src && sp.respond_to?(:src_rect) && sp.src_rect
          sp.src_rect.set(src.x,src.y,src.width,src.height)
        end
        sp.ox=(target.ox rescue 0);sp.oy=(target.oy rescue 0)
        sp.zoom_x=(target.zoom_x rescue 1.0);sp.zoom_y=(target.zoom_y rescue 1.0)
        sp.angle=(target.angle rescue 0) if sp.respond_to?(:angle=)
        sp.mirror=(target.mirror rescue false) if sp.respond_to?(:mirror=)
        sp.x=(target.x rescue 0)+ofs[0];sp.y=(target.y rescue 0)+ofs[1]
        sp.z=(target.z rescue 50)-1
        sp.opacity=base_op;sp.visible=base_op>1
      end
    rescue => e
      BSS064.log("Boss outline update warning: #{e.class}: #{e.message}")
      hide_all
    end

    def hide_all
      @sprites.each{|row|sp=row[0];sp.visible=false if sp && !(sp.disposed? rescue true)}
    rescue;end

    def dispose
      return if @disposed
      @sprites.each do |sp,key,ofs|
        begin;@scene_sprites.delete(key) if @scene_sprites && @scene_sprites[key].equal?(sp);rescue;end
        begin;sp.bitmap=nil if sp && !(sp.disposed? rescue true);sp.dispose if sp && !sp.disposed?;rescue;end
      end
      @sprites.clear;@disposed=true
    rescue;@disposed=true;end
  end

  # Opening charge animation. This intentionally mirrors EBDX's broad rhythm:
  # converging sparks -> radial rays/ripples -> flash/impact -> persistent aura.
  class BossAuraIntro
    include BossAuraGeometry

    PRELUDE_FRAMES=16.0
    CANONICAL_CHARGE=104.0
    IMPACT_FRAMES=40.0

    def initialize(scene, target_sprite, battler, cfg, &activate_proc)
      @scene = scene
      @target = target_sprite
      @battler = battler
      @activate_proc = activate_proc
      @viewport = scene.instance_variable_get(:@viewport) rescue nil
      @scene_sprites = scene.instance_variable_get(:@sprites) rescue nil
      @scene_sprites = nil if !@scene_sprites.is_a?(Hash)
      @cfg = cfg || {}
      @rgb = BSS064.aura_color_rgb(@cfg["color"])
      @sprites = []
      @bitmaps = []
      @original_target_color = nil
      @hud_sprites = []
      @focus_sprites = []
      @charge_duration = BSS064.clamp_int(@cfg["introDuration"],48,180,104).to_f
      # The reference sequence is authored at a hard 40 FPS. The outer scene
      # loop now clocks these logical frames from monotonic real time, so this
      # object itself always advances in genuine EBDX frames.
      @fps_scale=1.0
      @hold_duration=BSS064.clamp_int(@cfg["impactHold"],0,120,56).to_f
      @total_logical=PRELUDE_FRAMES+@charge_duration+IMPACT_FRAMES+@hold_duration
      @total_duration=[@total_logical.round,1].max
      @activated=false;@sfx_start=false;@sfx_twine=false;@sfx_refresh=false;@sfx_impact=false;@cry_played=false
      create_assets
      capture_hud
      capture_stage_focus
    end

    attr_reader :total_duration

    def register(sp, key)
      @sprites << [sp,key]
      @scene_sprites[key] = sp if @scene_sprites
      sp
    end

    def bitmap(path)
      bmp = BSS064.new_bitmap(path)
      @bitmaps << bmp if bmp
      bmp
    end

    def create_assets
      @particle_bitmaps = BSS064::BOSS_INTRO_PARTICLES.map { |p| bitmap(p) }.compact
      @ray_bitmap = bitmap(BSS064::BOSS_AURA_RAY_GRAPHIC)
      @ripple_bitmap = bitmap(BSS064::BOSS_AURA_RIPPLE_GRAPHIC)
      @impact_bitmap = bitmap(BSS064::BOSS_AURA_IMPACT_GRAPHIC)
      @particles=[]; @rays=[]; @ripples=[]
      16.times do |i|
        sp=Sprite.new(@viewport); sp.bitmap=@particle_bitmaps[i % [@particle_bitmaps.length,1].max] if @particle_bitmaps.length>0
        if sp.bitmap;sp.ox=sp.bitmap.width/2;sp.oy=sp.bitmap.height/2;end
        sp.opacity=0;sp.visible=false
        register(sp,"bss_totem_intro_particle_#{i}")
        @particles << {:sprite=>sp,:spawned=>false,:nx=>0.5,:ny=>0.5}
      end
      angles=(0...8).map{|i|(360.0/8.0)*i+15.0}.sort_by{rand}
      8.times do |i|
        sp=Sprite.new(@viewport);sp.bitmap=@ray_bitmap if @ray_bitmap
        if sp.bitmap;sp.ox=0;sp.oy=sp.bitmap.height/2;end
        sp.color=Color.new(@rgb[0],@rgb[1],@rgb[2],255) if sp.respond_to?(:color=)
        sp.opacity=0;sp.zoom_x=0;sp.zoom_y=0;sp.angle=angles[i]||((360.0/8.0)*i+15);sp.visible=false
        register(sp,"bss_totem_intro_ray_#{i}");@rays << sp
      end
      3.times do |i|
        sp=Sprite.new(@viewport);sp.bitmap=@ripple_bitmap if @ripple_bitmap
        if sp.bitmap;sp.ox=sp.bitmap.width/2;sp.oy=sp.bitmap.height/2;end
        sp.color=Color.new(@rgb[0],@rgb[1],@rgb[2],255) if sp.respond_to?(:color=)
        sp.opacity=0;sp.visible=false
        register(sp,"bss_totem_intro_ripple_#{i}");@ripples << {:sprite=>sp,:toggle=>1.0,:started=>false}
      end
      @impact=Sprite.new(@viewport);@impact.bitmap=@impact_bitmap if @impact_bitmap
      if @impact.bitmap
        @impact.ox=@impact.bitmap.width/2;@impact.oy=@impact.bitmap.height/2
        # TotemImpact is authored at 512x384. Fill the live game resolution
        # (640x480, 640x440, custom, etc.) instead of leaving a tiny center card.
        gw=(Graphics.width rescue 512).to_f;gh=(Graphics.height rescue 384).to_f
        @impact.zoom_x=gw/[@impact.bitmap.width.to_f,1.0].max
        @impact.zoom_y=gh/[@impact.bitmap.height.to_f,1.0].max
      end
      @impact.x=(Graphics.width rescue 512)/2;@impact.y=(Graphics.height rescue 384)/2;@impact.z=9999;@impact.opacity=0;@impact.visible=false
      register(@impact,"bss_totem_intro_impact")

      # Safe screen-space drama: these are sprites, never Viewport#color, so an
      # interrupted transition cannot strand the whole game on a black screen.
      @veil_bitmap=Bitmap.new(1,1);@veil_bitmap.fill_rect(0,0,1,1,Color.new(0,0,0,255));@bitmaps << @veil_bitmap
      @veil=Sprite.new(@viewport);@veil.bitmap=@veil_bitmap;@veil.x=0;@veil.y=0;@veil.z=1
      @veil.zoom_x=(Graphics.width rescue 512);@veil.zoom_y=(Graphics.height rescue 384);@veil.opacity=0;@veil.visible=true
      register(@veil,"bss_totem_intro_veil")
      @flash_bitmap=Bitmap.new(1,1);@flash_bitmap.fill_rect(0,0,1,1,Color.new(255,255,255,255));@bitmaps << @flash_bitmap
      @flash=Sprite.new(@viewport);@flash.bitmap=@flash_bitmap;@flash.x=0;@flash.y=0;@flash.z=10000
      @flash.zoom_x=(Graphics.width rescue 512);@flash.zoom_y=(Graphics.height rescue 384);@flash.opacity=0;@flash.visible=true
      register(@flash,"bss_totem_intro_flash")
      begin
        col=@target.color
        @original_target_color=Color.new(col.red,col.green,col.blue,col.alpha) if col
      rescue;@original_target_color=nil;end
    rescue => e
      BSS064.log("Boss intro create warning: #{e.class}: #{e.message}")
    end

    def capture_hud
      return if !@scene_sprites
      seen={}
      candidates=[]
      @scene_sprites.each { |key,sp| candidates << [key,sp] }
      # Some Essentials/LBDS message windows live as direct scene instance
      # variables instead of @sprites entries. Capture them too so text fades
      # with the rest of the HUD instead of remaining fully opaque.
      begin
        @scene.instance_variables.each do |ivar|
          sp=@scene.instance_variable_get(ivar)
          cls=(sp.class.to_s rescue "")
          candidates << [ivar,sp] if cls =~ /(Window|PokemonDataBox|CommandMenu|FightMenu)/i
        end
      rescue
      end
      candidates.each do |key,sp|
        next if !sp || (sp.disposed? rescue false)
        k=key.to_s
        cls=(sp.class.to_s rescue "")
        # Keep battlers, bases, shadows and aura effects in world space. Everything
        # that behaves like a databox/window/menu/message is captured as HUD.
        is_hud=(k =~ /(databox|message|command|fight|target|party|help|text|window|info|ability|choice|menu|prompt)/i) || (cls =~ /(Window|PokemonDataBox|CommandMenu|FightMenu)/i)
        next if !is_hud
        oid=(sp.object_id rescue k)
        next if seen[oid];seen[oid]=true
        @hud_sprites << {
          :sprite=>sp,
          :visible=>(sp.visible rescue true),
          :opacity=>(sp.respond_to?(:opacity) ? (sp.opacity rescue 255) : nil),
          :contents_opacity=>(sp.respond_to?(:contents_opacity) ? (sp.contents_opacity rescue 255) : nil)
        }
      end
    rescue => e
      BSS064.log("Boss HUD capture warning: #{e.class}: #{e.message}")
    end

    def capture_stage_focus
      return if @cfg["introSpotlight"] == false || !@scene_sprites
      target_index=(@battler.index rescue -1).to_i
      seen={}
      @scene_sprites.each do |key,sp|
        next if !sp || (sp.disposed? rescue false)
        k=key.to_s
        m=k.match(/\A(?:pokemon|shadow)_(\d+)\z/i)
        next if !m
        next if m[1].to_i==target_index
        oid=(sp.object_id rescue k);next if seen[oid];seen[oid]=true
        @focus_sprites << {
          :sprite=>sp,
          :visible=>(sp.visible rescue true),
          :opacity=>(sp.respond_to?(:opacity) ? (sp.opacity rescue 255) : nil)
        }
      end
    rescue => e
      BSS064.log("Boss focus capture warning: #{e.class}: #{e.message}")
    end

    def update_focus_alpha(factor)
      return if @cfg["introSpotlight"] == false
      f=[[factor.to_f,0.0].max,1.0].min
      @focus_sprites.each do |row|
        sp=row[:sprite];next if !sp || (sp.disposed? rescue true)
        sp.opacity=(row[:opacity].to_f*f).round if sp.respond_to?(:opacity=) && !row[:opacity].nil?
        sp.visible=(row[:visible] && f>0.005) if sp.respond_to?(:visible=)
      end
    rescue
    end

    def restore_stage_focus
      @focus_sprites.each do |row|
        sp=row[:sprite];next if !sp || (sp.disposed? rescue true)
        sp.opacity=row[:opacity] if sp.respond_to?(:opacity=) && !row[:opacity].nil?
        sp.visible=row[:visible] if sp.respond_to?(:visible=)
      end
      @focus_sprites.clear
    rescue
    end

    def hud_smoothstep(x)
      x=[[x.to_f,0.0].max,1.0].min
      x*x*(3.0-2.0*x)
    end

    def update_hud_alpha(factor)
      f=[[factor.to_f,0.0].max,1.0].min
      @hud_sprites.each do |row|
        sp=row[:sprite];next if !sp || (sp.disposed? rescue true)
        if sp.respond_to?(:opacity=) && !row[:opacity].nil?
          sp.opacity=(row[:opacity].to_f*f).round
        end
        if sp.respond_to?(:contents_opacity=) && !row[:contents_opacity].nil?
          sp.contents_opacity=(row[:contents_opacity].to_f*f).round
        end
        sp.visible=(row[:visible] && f>0.005) if sp.respond_to?(:visible=)
      end
    rescue
    end

    def update_hud_for_frame(logical)
      fade_out=18.0
      fade_in=BSS064.clamp_int(@cfg["introReturnFrames"],8,60,24).to_f
      restore_at=[@total_logical-fade_in,fade_out].max
      factor=if logical<fade_out
               1.0-hud_smoothstep(logical/fade_out)
             elsif logical>=restore_at
               hud_smoothstep((logical-restore_at)/fade_in)
             else
               0.0
             end
      update_hud_alpha(factor)
      update_focus_alpha(factor)
    end

    def restore_databoxes
      @hud_sprites.each do |row|
        sp=row[:sprite];next if !sp || (sp.disposed? rescue true)
        sp.opacity=row[:opacity] if sp.respond_to?(:opacity=) && !row[:opacity].nil?
        sp.contents_opacity=row[:contents_opacity] if sp.respond_to?(:contents_opacity=) && !row[:contents_opacity].nil?
        sp.visible=row[:visible] if sp.respond_to?(:visible=)
      end
      @hud_sprites.clear
    rescue
    end

    def fade_intro_transients(factor)
      f=[[factor.to_f,0.0].max,1.0].min
      @particles.each do |row|
        sp=row[:sprite];next if !sp || (sp.disposed? rescue true)
        sp.opacity=[sp.opacity.to_i,(255*f).round].min
        sp.visible=sp.opacity>1
      end
      @rays.each do |sp|
        next if !sp || (sp.disposed? rescue true)
        sp.opacity=[sp.opacity.to_i,(255*f).round].min
        sp.visible=sp.opacity>1
      end
      @ripples.each do |row|
        sp=row[:sprite];next if !sp || (sp.disposed? rescue true)
        sp.opacity=[sp.opacity.to_i,(255*f).round].min
        sp.visible=sp.opacity>1
      end
    rescue
    end

    def play_cry_once
      return if @cry_played;@cry_played=true
      pkmn=begin @battler.pokemon rescue nil end
      begin
        if pkmn && defined?(GameData::Species) && GameData::Species.respond_to?(:play_cry)
          GameData::Species.play_cry(pkmn.species,pkmn.form)
          return
        end
      rescue;end
      begin
        if @scene.respond_to?(:pbPlayCry)
          @scene.pbPlayCry(pkmn || @battler)
          return
        end
      rescue;end
    end

    def activate_persistent_once
      return if @activated;@activated=true
      begin;@activate_proc.call if @activate_proc;rescue => e;BSS064.log("Boss aura activate callback warning: #{e.class}: #{e.message}");end
      play_cry_once
    end

    def update(frame)
      state=target_state(@target);return if !state
      logical=frame.to_f
      update_hud_for_frame(logical)
      # EBDX deliberately waits before the flare.  This also gives BAS time to
      # settle into the Totem focus instead of snapping camera + particles at once.
      return if logical < PRELUDE_FRAMES
      charge=((logical-PRELUDE_FRAMES)*CANONICAL_CHARGE/[@charge_duration,0.0001].max)
      cx,cy=target_center(state)
      if @veil
        @veil.z=[state[:z]-20,1].max
      end
      if charge < CANONICAL_CHARGE
        if !@sfx_start;BSS064.play_aura_se("Anim/Harden",120);@sfx_start=true;end
        if !@sfx_twine && charge>=40;BSS064.play_aura_se("Anim/Twine",80);@sfx_twine=true;end
        if !@sfx_refresh && charge>=56;BSS064.play_aura_se("Anim/Refresh",100);@sfx_refresh=true;end
        if @target.respond_to?(:color=)
          alpha=[[charge*8.0,0].max,255].min.round
          @target.color=Color.new(@rgb[0],@rgb[1],@rgb[2],alpha)
        end
        # Pull the background back as the aura builds. This reproduces the
        # punch of EBDX's battlebg.defocus without depending on EBDX itself.
        @veil.opacity=[[charge*1.15,0].max,118].min.round if @veil
        @particles.each_with_index do |row,j|
          sp=row[:sprite];next if !sp || (sp.disposed? rescue true)
          if charge>=j*8.0 && charge<76.0
            if sp.opacity<=0 && charge<72.0
              ang=rand*2*Math::PI;rad=0.35+rand*0.55
              row[:nx]=0.5+Math.cos(ang)*rad;row[:ny]=0.48+Math.sin(ang)*rad
              px,py=local_to_world(state,row[:nx],row[:ny],0);sp.x=px;sp.y=py
              sp.opacity=255;sp.visible=true
            end
            lerp=1.0-(0.9 ** (1.0/[ @fps_scale,0.0001].max))
            sp.x += (cx-sp.x)*lerp;sp.y += (cy-sp.y)*lerp
            sp.z=state[:z]+10;sp.zoom_x=[state[:zoom_x].abs,0.1].max;sp.zoom_y=[state[:zoom_y].abs,0.1].max
            sp.opacity=[sp.opacity-(16.0/[ @fps_scale,0.0001].max),0].max.round;sp.visible=sp.opacity>0
          else
            sp.opacity=[sp.opacity-(24.0/[ @fps_scale,0.0001].max),0].max.round;sp.visible=sp.opacity>0
          end
        end
        @rays.each_with_index do |sp,j|
          next if !sp || (sp.disposed? rescue true)
          if charge<96.0 && sp.opacity<=0 && j <= ((charge%128.0)/16.0).floor
            sp.opacity=255;sp.zoom_x=0;sp.zoom_y=0;sp.visible=true
          end
          sp.x=cx;sp.y=cy;sp.z=state[:z]+2
          sp.opacity=[sp.opacity-(4.0/[ @fps_scale,0.0001].max),0].max.round
          sp.zoom_x += 0.05/[ @fps_scale,0.0001].max;sp.zoom_y += 0.05/[ @fps_scale,0.0001].max
          sp.visible=sp.opacity>0
        end
        if charge>=24.0
          @ripples.each_with_index do |row,j|
            sp=row[:sprite];next if !sp || (sp.disposed? rescue true)
            next if j > ((charge-32.0)/12.0).floor || sp.zoom_x<=0 && row[:started]
            if !row[:started]
              row[:started]=true;row[:toggle]=1.0;sp.opacity=0
              sp.zoom_x=2.0*[state[:zoom_x].abs,0.3].max;sp.zoom_y=2.0*[state[:zoom_y].abs,0.3].max;sp.visible=true
            end
            sp.x=cx;sp.y=cy;sp.z=state[:z]+1;sp.angle=state[:angle]
            step=1.0/[ @fps_scale,0.0001].max
            sp.opacity=[[sp.opacity+(16*row[:toggle]*step).round,0].max,255].min
            sp.zoom_x=[sp.zoom_x-0.05*step,0].max;sp.zoom_y=[sp.zoom_y-0.05*step,0].max
            row[:toggle]=-0.2 if sp.zoom_x < 1.6*[state[:zoom_x].abs,0.3].max
          end
        end
        return
      end

      # EBDX enables chargedUpdate before the impact, not after a dialogue box.
      activate_persistent_once
      impact=(logical-PRELUDE_FRAMES-@charge_duration)
      transient_fade=1.0-hud_smoothstep(impact/18.0)
      fade_intro_transients(transient_fade)
      if impact>=0 && impact<IMPACT_FRAMES && @impact
        if !@sfx_impact
          BSS064.play_aura_se("Anim/Refresh",120,90)
          @sfx_impact=true
        end
        @impact.visible=true
        # Full-screen flash replaces Viewport#color. It is equally strong but
        # cannot leak into the next screen if the sequence is interrupted.
        if @flash
          @flash.opacity=255 if impact<1.5
          @flash.opacity=[255-(impact*16.0),0].max.round if impact>=1.5
        end
        @veil.opacity=[118-(impact*4.0),0].max.round if @veil
        if @target.respond_to?(:color=)
          pulse=[220-(impact*14.0),0].max.round
          @target.color=Color.new(@rgb[0],@rgb[1],@rgb[2],pulse)
        end
        if impact<24
          @impact.opacity=[@impact.opacity+(64.0/[ @fps_scale,0.0001].max).round,255].min
          tick=impact.floor
          @impact.angle+=180 if tick%4==0 && @last_impact_turn!=tick
          @impact.mirror=!@impact.mirror if tick%4==2 && @impact.respond_to?(:mirror=) && @last_impact_mirror!=tick
          @last_impact_turn=tick if tick%4==0;@last_impact_mirror=tick if tick%4==2
        else
          @impact.opacity=[@impact.opacity-(64.0/[ @fps_scale,0.0001].max).round,0].max
        end
        return
      end
      # Hold on the fully charged Totem after the impact has cleared. The UI
      # stays hidden and BAS keeps the focus for most of this window, giving
      # the player time to actually read the powered-up silhouette/aura before
      # the camera returns and the aura message appears.
      fade_intro_transients(0.0)
      if @impact
        @impact.opacity=0;@impact.visible=false
      end
      @flash.opacity=0 if @flash
      @veil.opacity=0 if @veil
      if @target.respond_to?(:color=)
        @target.color=Color.new(@rgb[0],@rgb[1],@rgb[2],0)
      end
    rescue => e
      BSS064.log("Boss intro update warning: #{e.class}: #{e.message}")
    end

    def dispose
      restore_databoxes
      restore_stage_focus
      begin
        @target.color=@original_target_color if @original_target_color && @target && !(@target.disposed? rescue false) && @target.respond_to?(:color=)
      rescue;end
      @sprites.each do |sp,key|
        begin;@scene_sprites.delete(key) if @scene_sprites && @scene_sprites[key].equal?(sp);rescue;end
        begin;sp.dispose if sp && !sp.disposed?;rescue;end
      end
      @sprites.clear
      @bitmaps.each{|bmp|begin;bmp.dispose if bmp && !bmp.disposed?;rescue;end};@bitmaps.clear
    rescue;end
  end
end

# BAS only transforms known battle-world sprite keys. BSS aura/intro sprites are
# in the same world and must receive the exact camera transform as their Totem.
module BSS064BASWorldSpriteCompat
  def camera_world_sprite_key?(key)
    k=key.to_s
    # Full-screen impact/flash/veil are HUD/screen-space effects. Letting BAS
    # transform them as world sprites is exactly what made TotemImpact look
    # small while the camera was zoomed.
    return false if k.start_with?("bss_totem_intro_impact") || k.start_with?("bss_totem_intro_flash") || k.start_with?("bss_totem_intro_veil")
    return true if k.start_with?("bss_totem_")
    super
  end
end

class Battle
  attr_accessor :bss_boss_config
  attr_accessor :bss_boss_applied
  attr_accessor :bss_boss_intro_pending
  attr_accessor :bss_boss_intro_shown
  attr_accessor :bss_boss_aura_active

  def bss_boss_enabled?
    @bss_boss_config.is_a?(Hash) && @bss_boss_config["enabled"] == true
  end

  def bss_boss_target_party_index
    cfg=@bss_boss_config.is_a?(Hash) ? @bss_boss_config : {}
    [cfg["foeIndex"].to_i,0].max
  end

  def bss_boss_has_stat_aura?
    return false if !bss_boss_enabled?
    cfg=@bss_boss_config.is_a?(Hash) ? @bss_boss_config : {}
    aura=BSS064.boss_aura_config(cfg)
    return false if !aura["enabled"]
    stats=cfg["stats"].is_a?(Hash) ? cfg["stats"] : {}
    ["ATTACK","DEFENSE","SPECIAL_ATTACK","SPECIAL_DEFENSE","SPEED","ACCURACY","EVASION"].any? { |stat| stats[stat].to_i != 0 }
  rescue
    false
  end

  def bss_find_boss_battler
    wanted=bss_boss_target_party_index
    rows=@battlers.is_a?(Array) ? @battlers : []
    rows.compact.find do |b|
      next false if !b || (b.fainted? rescue false)
      idx=(b.index rescue -1).to_i
      next false if idx<0 || idx.even?
      (b.pokemonIndex rescue 0).to_i==wanted
    end
  rescue
    nil
  end

  def bss_boss_name_for_intro
    begin
      party=pbParty(1);idx=bss_boss_target_party_index;pkmn=party[idx]||party[0]
      return pkmn.name.to_s if pkmn
    rescue
    end
    battler=bss_find_boss_battler
    return battler.name.to_s if battler && battler.respond_to?(:name)
    "Pokémon"
  end

  def bss_boss_message(template,battler=nil)
    text=template.to_s
    return "" if text.empty?
    # {1} is intentionally the raw Pokémon nickname/species display name only.
    # Articles/roles such as "salvaje", "rival" or "dominante" belong to the
    # editable template, never to pbThis (which can inject battle grammar).
    name=if battler
      begin battler.name.to_s rescue bss_boss_name_for_intro end
    else
      bss_boss_name_for_intro
    end
    text.gsub("{1}",name.to_s)
  end

  def bss_default_aura_message
    role=(trainerBattle? rescue false) ? "rival" : "salvaje"
    "¡El {1} #{role} está rodeado por un aura!"
  rescue
    "¡El {1} salvaje está rodeado por un aura!"
  end

  def bss_boss_encounter_message
    return "" if !bss_boss_enabled?
    cfg=@bss_boss_config.is_a?(Hash) ? @bss_boss_config : {}
    bss_boss_message(cfg["encounterMessage"],nil)
  end

  def bss_apply_boss_stat_stage(battler,stat,delta)
    amount=[[delta.to_i,-6].max,6].min
    return if amount==0 || !battler
    stages=battler.respond_to?(:stages) ? battler.stages : nil
    return if !stages || !stages.respond_to?(:[]) || !stages.respond_to?(:[]=)
    key=stat.to_s.upcase.to_sym
    stages[key]=[[stages[key].to_i+amount,-6].max,6].min
  rescue => e
    BSS064.log("Boss stat #{stat} failed: #{e.class}: #{e.message}")
  end

  def bss_apply_boss_opening
    return if @bss_boss_applied || !bss_boss_enabled?
    battler=bss_find_boss_battler
    return if !battler
    begin; @scene.bss_capture_boss_native_scale(battler,true) if @scene && @scene.respond_to?(:bss_capture_boss_native_scale); rescue; end
    cfg=@bss_boss_config
    if !@bss_boss_intro_shown
      intro=bss_boss_encounter_message
      if !intro.empty? && respond_to?(:pbDisplay)
        pbDisplay(intro);@bss_boss_intro_shown=true
      end
    end
    stats=cfg["stats"].is_a?(Hash) ? cfg["stats"] : {}
    ["ATTACK","DEFENSE","SPECIAL_ATTACK","SPECIAL_DEFENSE","SPEED","ACCURACY","EVASION"].each { |stat| bss_apply_boss_stat_stage(battler,stat,stats[stat]) }
    has_boost=["ATTACK","DEFENSE","SPECIAL_ATTACK","SPECIAL_DEFENSE","SPEED","ACCURACY","EVASION"].any? { |stat| stats[stat].to_i!=0 }
    aura_cfg=BSS064.boss_aura_config(cfg)
    if has_boost && aura_cfg["enabled"]
      if aura_cfg["introEnabled"] && @scene && @scene.respond_to?(:bss_play_boss_aura_sequence)
        @scene.bss_play_boss_aura_sequence(battler,cfg)
      else
        @bss_boss_aura_active=true
        @scene.bss_update_boss_aura if @scene && @scene.respond_to?(:bss_update_boss_aura)
      end
    end
    # The charged aura/outline is already visible when this line is shown.
    aura_template=cfg["auraMessage"].to_s
    aura_template=bss_default_aura_message if aura_template.strip.empty?
    message=bss_boss_message(aura_template,battler)
    pbDisplay(message) if has_boost && !message.empty? && respond_to?(:pbDisplay)
    @bss_boss_applied=true
    @scene.bss_update_boss_aura if @scene && @scene.respond_to?(:bss_update_boss_aura)
  rescue => e
    BSS064.log("Boss opening failed: #{e.class}: #{e.message}")
    @bss_boss_applied=true
  end

  # DBK/LBDS can wrap pbStartBattleSendOut. Preserve their method and replace
  # only the first paused intro message when a custom Totem line is configured.
  if method_defined?(:pbStartBattleSendOut) && !method_defined?(:bss067_start_sendout_without_totem_intro) && !private_method_defined?(:bss067_start_sendout_without_totem_intro)
    alias bss067_start_sendout_without_totem_intro pbStartBattleSendOut
  end
  if method_defined?(:bss067_start_sendout_without_totem_intro) || private_method_defined?(:bss067_start_sendout_without_totem_intro)
    # F12-safe: the alias survives mkxp's script reset, but the base method is
    # redefined. Reinstall our wrapper on every plugin evaluation.
    def pbStartBattleSendOut(*args)
      @bss_boss_intro_pending=bss_boss_enabled? && !bss_boss_encounter_message.empty?
      bss067_start_sendout_without_totem_intro(*args)
    ensure
      @bss_boss_intro_pending=false
    end
  end

  if method_defined?(:pbDisplayPaused) && !method_defined?(:bss067_display_paused_without_totem_intro) && !private_method_defined?(:bss067_display_paused_without_totem_intro)
    alias bss067_display_paused_without_totem_intro pbDisplayPaused
  end
  if method_defined?(:bss067_display_paused_without_totem_intro) || private_method_defined?(:bss067_display_paused_without_totem_intro)
    def pbDisplayPaused(msg,&block)
      if @bss_boss_intro_pending
        custom=bss_boss_encounter_message
        if !custom.empty?
          @bss_boss_intro_pending=false;@bss_boss_intro_shown=true
          return bss067_display_paused_without_totem_intro(custom,&block)
        end
      end
      bss067_display_paused_without_totem_intro(msg,&block)
    end
  end

  if method_defined?(:pbCommandPhase) && !method_defined?(:bss067_command_phase_without_native_boss) && !private_method_defined?(:bss067_command_phase_without_native_boss)
    alias bss067_command_phase_without_native_boss pbCommandPhase
  end
  if method_defined?(:bss067_command_phase_without_native_boss) || private_method_defined?(:bss067_command_phase_without_native_boss)
    def pbCommandPhase(*args)
      bss_apply_boss_opening
      bss067_command_phase_without_native_boss(*args)
    end
  end
end

class Battle::Scene
  def bss_scene_sprites
    @sprites.is_a?(Hash) ? @sprites : {}
  rescue
    {}
  end

  def bss_boss_target_sprite(battler)
    return nil if !battler
    idx=(battler.index rescue -1).to_i
    return nil if idx<0
    bss_scene_sprites["pokemon_#{idx}"]
  rescue
    nil
  end

  def bss_dispose_boss_aura
    emitter=@bss_boss_aura_emitter;outline=@bss_boss_aura_outline
    emitter.dispose if emitter && emitter.respond_to?(:dispose)
    outline.dispose if outline && outline.respond_to?(:dispose)
    @bss_boss_aura_emitter=nil;@bss_boss_aura_outline=nil;@bss_boss_aura_index=nil
    @bss_boss_aura_battler=nil;@bss_boss_aura_fade_started=nil
  rescue
    @bss_boss_aura_emitter=nil;@bss_boss_aura_outline=nil;@bss_boss_aura_index=nil
    @bss_boss_aura_battler=nil;@bss_boss_aura_fade_started=nil
  end

  def bss_capture_boss_native_scale(battler=nil,force=false)
    battle=@battle
    battler ||= (battle.bss_find_boss_battler rescue nil) if battle
    return nil if !battler
    sprite=bss_boss_target_sprite(battler);return nil if !sprite || (sprite.disposed? rescue true)
    @bss_boss_native_scale ||= {}
    idx=(battler.index rescue 1).to_i
    current=[(sprite.zoom_x rescue 1.0).to_f,(sprite.zoom_y rescue 1.0).to_f]
    return @bss_boss_native_scale[idx] if !force && @bss_boss_native_scale[idx]
    @bss_boss_native_scale[idx]=current if current[0]>0 && current[1]>0
    @bss_boss_native_scale[idx]
  rescue => e
    BSS064.log("Boss native scale capture warning: #{e.class}: #{e.message}")
    nil
  end

  def bss_guard_boss_sprite_scale
    return if @bss_boss_animation_depth.to_i>0
    battle=@battle;return if !battle || !battle.respond_to?(:bss_boss_enabled?) || !battle.bss_boss_enabled?
    battler=battle.bss_find_boss_battler rescue nil;return if !battler
    sprite=bss_boss_target_sprite(battler);return if !sprite || (sprite.disposed? rescue true)
    base=bss_capture_boss_native_scale(battler,false);return if !base
    bx,by=base;zx=(sprite.zoom_x rescue bx).to_f;zy=(sprite.zoom_y rescue by).to_f
    # The renderer scale captured before the first Totem animation is the
    # stable baseline. Temporary move/BAS scaling is allowed only while an
    # animation is executing; any leaked shrink or enlargement is restored.
    if (zx-bx.to_f).abs>0.001 || (zy-by.to_f).abs>0.001
      sprite.zoom_x=bx if sprite.respond_to?(:zoom_x=)
      sprite.zoom_y=by if sprite.respond_to?(:zoom_y=)
    end
  rescue => e
    BSS064.log("Boss scale guard warning: #{e.class}: #{e.message}")
  end

  def bss_update_boss_aura
    bss_guard_boss_sprite_scale
    battle=@battle
    if !battle || !battle.respond_to?(:bss_boss_enabled?) || !battle.bss_boss_enabled? ||
       !battle.respond_to?(:bss_boss_has_stat_aura?) || !battle.bss_boss_has_stat_aura? ||
       !battle.respond_to?(:bss_boss_aura_active) || battle.bss_boss_aura_active!=true
      bss_dispose_boss_aura if @bss_boss_aura_emitter || @bss_boss_aura_outline
      return
    end

    live=battle.bss_find_boss_battler rescue nil
    battler=live || @bss_boss_aura_battler
    if !battler
      bss_dispose_boss_aura if @bss_boss_aura_emitter || @bss_boss_aura_outline
      return
    end
    idx=(battler.index rescue -1).to_i
    sprite=bss_boss_target_sprite(battler)
    if idx<0 || !sprite || (sprite.disposed? rescue true)
      bss_dispose_boss_aura if @bss_boss_aura_emitter || @bss_boss_aura_outline
      return
    end

    if !@bss_boss_aura_emitter || (@bss_boss_aura_emitter.disposed? rescue true) || @bss_boss_aura_index!=idx
      bss_dispose_boss_aura
      cfg=BSS064.boss_aura_config(battle.bss_boss_config)
      @bss_boss_aura_emitter=BSS064::BossAuraEmitter.new(@viewport,bss_scene_sprites,cfg,"bss_totem_persistent")
      @bss_boss_aura_outline=BSS064::BossAuraOutline.new(@viewport,bss_scene_sprites,cfg,"bss_totem_outline") if cfg["outlineEnabled"]
      @bss_boss_aura_index=idx
      @bss_boss_aura_battler=battler
      @bss_boss_aura_fade_started=nil
    end

    fainted=(battler.fainted? rescue false)
    if fainted
      cfg=BSS064.boss_aura_config(battle.bss_boss_config)
      @bss_boss_aura_fade_started ||= BSS064.monotonic_seconds
      duration=[BSS064.clamp_int(cfg["fadeOutFrames"],1,90,18).to_f/40.0,0.025].max
      elapsed=BSS064.monotonic_seconds-@bss_boss_aura_fade_started
      factor=1.0-(elapsed/duration)
      if factor<=0.0
        bss_dispose_boss_aura
        return
      end
      factor=[[factor,0.0].max,1.0].min
      @bss_boss_aura_emitter.update(sprite,battler,factor,true) if @bss_boss_aura_emitter
      @bss_boss_aura_outline.update(sprite,battler,factor,true) if @bss_boss_aura_outline
      return
    end

    @bss_boss_aura_battler=battler
    @bss_boss_aura_fade_started=nil
    @bss_boss_aura_emitter.update(sprite,battler,1.0,false) if @bss_boss_aura_emitter
    @bss_boss_aura_outline.update(sprite,battler,1.0,false) if @bss_boss_aura_outline
  rescue => e
    BSS064.log("Boss aura scene warning: #{e.class}: #{e.message}")
  end

  # Update once per logical scene frame. pbFrameUpdate covers normal menus and
  # target selection; BAS has its own pump hook below for the exact pre-camera
  # point during Studio animations.
  def bss_tick_boss_aura_once(force=false)
    token=(Graphics.frame_count rescue nil)
    return if !force && !token.nil? && @bss_boss_aura_last_tick==token
    @bss_boss_aura_last_tick=token if !token.nil?
    bss_update_boss_aura
  rescue
  end

  def bss_plain_frame_pump
    if respond_to?(:pbUpdate)
      pbUpdate
      return
    end
    Graphics.update
    respond_to?(:pbInputUpdate) ? pbInputUpdate : Input.update
    pbFrameUpdate(nil) if respond_to?(:pbFrameUpdate)
  rescue
    Graphics.update rescue nil
    Input.update rescue nil
  end

  def bss_boss_static_camera_offset(sprite)
    cx=(Graphics.width rescue 512).to_f/2.0
    cy=(Graphics.height rescue 384).to_f/2.0
    return [0.0,0.0] if !sprite || (sprite.disposed? rescue true)
    sx=(sprite.x rescue cx).to_f
    sy=(sprite.y rescue cy).to_f
    src=(sprite.src_rect rescue nil)
    bmp=(sprite.bitmap rescue nil)
    h=if src && src.height.to_i>0 then src.height.to_f elsif bmp && !(bmp.disposed? rescue true) then bmp.height.to_f else 80.0 end
    zy=(sprite.zoom_y rescue 1.0).to_f.abs
    # Sample once. Animated battler frame/bitmap changes can no longer pull the
    # camera around during the Totem charge like BAS's live focus directive did.
    [sx-cx,(sy-(h*zy/2.0))-cy]
  rescue
    [0.0,0.0]
  end

  def bss_bas_camera_data(total,zoom,bounds_mode="screen",offset_x=0.0,offset_y=0.0)
    fps=40.0
    focus_in=28
    out_frames=28
    clear_start=[total.to_i-out_frames,focus_in+1].max
    clear_start=[clear_start,total.to_i-2].min
    mode=(bounds_mode.to_s=="extended" ? "extended" : "screen")
    {
      "id"=>"bss_totem_aura_camera", "name"=>"BSS Totem Aura Camera",
      "fps"=>fps, "duration"=>total.to_i,
      "source"=>{"type"=>"custom","catalogType"=>"common","targetMode"=>"foe"},
      "battlers"=>{}, "tracks"=>[], "events"=>[], "logic"=>[],
      "scene"=>{"cameraBoundsMode"=>mode},
      "camera"=>{
        "id"=>"camera_main","type"=>"camera","name"=>"Camera","enabled"=>true,
        "visual"=>{"cameraX"=>0,"cameraY"=>0,"cameraZoom"=>100,"cameraRotation"=>0,"opacity"=>100},
        "visibleKeys"=>[{"frame"=>0,"value"=>true}],
        "valueKeys"=>{
          "cameraX"=>[
            {"frame"=>0,"value"=>0,"easing"=>"ease_both"},
            {"frame"=>focus_in,"value"=>offset_x.to_f,"easing"=>"ease_both"},
            {"frame"=>clear_start,"value"=>offset_x.to_f,"easing"=>"linear"},
            {"frame"=>total.to_i-1,"value"=>0,"easing"=>"ease_both"}
          ],
          "cameraY"=>[
            {"frame"=>0,"value"=>0,"easing"=>"ease_both"},
            {"frame"=>focus_in,"value"=>offset_y.to_f,"easing"=>"ease_both"},
            {"frame"=>clear_start,"value"=>offset_y.to_f,"easing"=>"linear"},
            {"frame"=>total.to_i-1,"value"=>0,"easing"=>"ease_both"}
          ],
          "cameraRotation"=>[],
          "cameraZoom"=>[
            {"frame"=>0,"value"=>100,"easing"=>"ease_both"},
            {"frame"=>focus_in,"value"=>zoom.to_f,"easing"=>"ease_both"},
            {"frame"=>clear_start,"value"=>zoom.to_f,"easing"=>"linear"},
            {"frame"=>total.to_i-1,"value"=>100,"easing"=>"ease_both"}
          ]
        },
        "logic"=>[]
      }
    }
  end

  def bss_play_boss_aura_sequence(battler,boss_cfg)
    sprite=bss_boss_target_sprite(battler);return if !sprite
    cfg=BSS064.boss_aura_config(boss_cfg)
    intro=BSS064::BossAuraIntro.new(self,sprite,battler,cfg) do
      if @battle && @battle.respond_to?(:bss_boss_aura_active=)
        @battle.bss_boss_aura_active=true
      end
      bss_update_boss_aura
    end
    total=intro.total_duration.to_i
    BSS064.install_bas_aura_compat
    player=nil
    use_bas=cfg["basZoomEnabled"] && BSS064.bas_available? && respond_to?(:bas_runtime_pump_frame)
    if use_bas
      offset=bss_boss_static_camera_offset(sprite)
      data=bss_bas_camera_data(total,cfg["basZoom"],cfg["basZoomBounds"],offset[0],offset[1])
      player=BattleAnimationStudioRuntime::Player.new(bss_scene_sprites,@viewport,battler,battler,data,[battler])
      BattleAnimationStudioRuntime.active_player=player if BattleAnimationStudioRuntime.respond_to?(:active_player=)
    end

    # Run visual logic at the same fixed 40 Hz as EBDX, while allowing the
    # actual scene/BAS camera to render at any refresh rate. This fixes both the
    # "too fast" charge and the weak 120-FPS version of the sequence.
    started=BSS064.monotonic_seconds
    last_logic=-1
    safety=0
    loop do
      elapsed=BSS064.monotonic_seconds-started
      logical=(elapsed*40.0).floor
      logical=0 if logical<0
      logical=total-1 if logical>=total
      if logical>last_logic
        first=[last_logic+1,0].max
        (first..logical).each { |f| intro.update(f) }
        last_logic=logical
      end
      if use_bas
        player.update
        bas_runtime_pump_frame(player)
      else
        bss_plain_frame_pump
      end
      break if elapsed*40.0>=total
      safety+=1
      break if safety>20000
    end
  rescue => e
    BSS064.log("Boss aura sequence warning: #{e.class}: #{e.message}")
  ensure
    begin
      if player && defined?(BattleAnimationStudioRuntime) && BattleAnimationStudioRuntime.respond_to?(:active_player=) && BattleAnimationStudioRuntime.active_player.equal?(player)
        BattleAnimationStudioRuntime.active_player=nil
      end
    rescue;end
    begin;player.restore_camera! if player;rescue;end
    begin;player.dispose if player;rescue;end
    # Even if a third-party camera/runtime interrupts the intro, a configured
    # Totem keeps its charged state instead of silently losing the aura.
    if @battle && @battle.respond_to?(:bss_boss_aura_active=) && @battle.respond_to?(:bss_boss_has_stat_aura?) && @battle.bss_boss_has_stat_aura?
      @battle.bss_boss_aura_active=true
      begin;bss_update_boss_aura;rescue;end
    end
    intro.dispose if intro
  end
end

# A move/common animation may temporarily scale a battler, but several BAS/DBK
# combinations restore that temporary value as if it were the battler's native
# renderer scale. Snapshot the Totem immediately before each animation and put
# that exact scale back afterward. The animation is still free to scale it while
# it is playing; only the leaked post-animation state is corrected.
module BSS064BossAnimationScaleCompat
  def bss_boss_animation_scale_snapshot
    battle=@battle
    return nil if !battle || !battle.respond_to?(:bss_boss_enabled?) || !battle.bss_boss_enabled?
    battler=(battle.bss_find_boss_battler rescue nil) || @bss_boss_aura_battler
    return nil if !battler
    sprite=bss_boss_target_sprite(battler) rescue nil
    return nil if !sprite || (sprite.disposed? rescue true)
    idx=(battler.index rescue -1).to_i
    base=bss_capture_boss_native_scale(battler,false) rescue nil
    zx=base ? base[0].to_f : (sprite.zoom_x rescue 1.0).to_f
    zy=base ? base[1].to_f : (sprite.zoom_y rescue 1.0).to_f
    [sprite,zx,zy,idx]
  rescue
    nil
  end

  def bss_restore_boss_animation_scale(snapshot)
    return if !snapshot
    sprite,zx,zy,idx=snapshot
    return if !sprite || (sprite.disposed? rescue true)
    sprite.zoom_x=zx if sprite.respond_to?(:zoom_x=)
    sprite.zoom_y=zy if sprite.respond_to?(:zoom_y=)
    @bss_boss_native_scale ||= {}
    @bss_boss_native_scale[idx]=[zx,zy] if idx && idx>=0 && !@bss_boss_native_scale[idx]
  rescue => e
    BSS064.log("Boss animation scale restore warning: #{e.class}: #{e.message}")
  end

  def pbAnimation(*args,&block)
    @bss_boss_animation_depth=@bss_boss_animation_depth.to_i+1
    snapshot=bss_boss_animation_scale_snapshot
    super
  ensure
    @bss_boss_animation_depth=[@bss_boss_animation_depth.to_i-1,0].max
    bss_restore_boss_animation_scale(snapshot) if @bss_boss_animation_depth==0
  end

  def pbCommonAnimation(*args,&block)
    @bss_boss_animation_depth=@bss_boss_animation_depth.to_i+1
    snapshot=bss_boss_animation_scale_snapshot
    super
  ensure
    @bss_boss_animation_depth=[@bss_boss_animation_depth.to_i-1,0].max
    bss_restore_boss_animation_scale(snapshot) if @bss_boss_animation_depth==0
  end
end

# BAS-exported move/custom animations are invoked through pbPlayBattleAnimationStudio
# directly and can bypass Scene#pbAnimation entirely. Protect the Totem scale on
# that real playback entry point as well; this module is only prepended when BAS
# actually defines the method on the active scene.
module BSS064BossBASAnimationScaleCompat
  def pbPlayBattleAnimationStudio(*args,&block)
    @bss_boss_animation_depth=@bss_boss_animation_depth.to_i+1
    snapshot=bss_boss_animation_scale_snapshot
    super
  ensure
    @bss_boss_animation_depth=[@bss_boss_animation_depth.to_i-1,0].max
    bss_restore_boss_animation_scale(snapshot) if @bss_boss_animation_depth==0
  end

  def pbPlayBattleAnimationStudioCustom(*args,&block)
    @bss_boss_animation_depth=@bss_boss_animation_depth.to_i+1
    snapshot=bss_boss_animation_scale_snapshot
    super
  ensure
    @bss_boss_animation_depth=[@bss_boss_animation_depth.to_i-1,0].max
    bss_restore_boss_animation_scale(snapshot) if @bss_boss_animation_depth==0
  end
end

# Normal battle/UI pump. This is what keeps the aura moving during menus,
# target selection, switch prompts and message windows.
module BSS064BossAuraFrameCompat
  def pbUpdate(*args,&block)
    result=super
    if !@bss_boss_aura_in_bas_pump && respond_to?(:bss_tick_boss_aura_once)
      bss_tick_boss_aura_once(false)
    end
    result
  end

  def pbFrameUpdate(*args,&block)
    result=super
    # BAS calls pbFrameUpdate from inside its own pump after Graphics.update.
    # The aura has already been sampled immediately before BAS camera/render in
    # BSS064BossAuraBASPumpCompat, so do not advance it a second time here.
    if !@bss_boss_aura_in_bas_pump && respond_to?(:bss_tick_boss_aura_once)
      bss_tick_boss_aura_once(false)
    end
    result
  end

  def dispose(*args,&block)
    bss_dispose_boss_aura if respond_to?(:bss_dispose_boss_aura)
    super
  end
end

# BAS bypasses Battle::Scene#pbUpdate and drives its own frame pump. Update the
# persistent aura after BAS has modified battler properties but *before* BAS
# applies the temporary camera transform and calls Graphics.update.
module BSS064BossAuraBASPumpCompat
  def bas_runtime_pump_frame(player)
    @bss_boss_aura_in_bas_pump=true
    # Player#update has already written the animation's live Battler properties.
    # Sample them now; super will apply the temporary BAS camera transform next.
    bss_tick_boss_aura_once(false) if respond_to?(:bss_tick_boss_aura_once)
    super
  ensure
    @bss_boss_aura_in_bas_pump=false
  end
end

# Scene/BAS frame hooks are installed only on the active Boss/Totem scene
# instance by configure_native_boss. Normal battles are left completely untouched.

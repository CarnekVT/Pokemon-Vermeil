#===============================================================================
# Battle Scene Studio Runtime 0.6.40
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

    def aura_layer_config(raw, index=0)
      raw={} if !raw.is_a?(Hash)
      mode=raw["graphicMode"].to_s.downcase
      mode="single" if !["single","sequence"].include?(mode)
      spawn=raw["spawnMode"].to_s
      spawn="async" if !["async","simultaneous"].include?(spawn)
      depth=raw["depthMode"].to_s
      depth="alternate" if !["alternate","front","back"].include?(depth)
      seq=aura_graphic_paths(raw.merge("graphicMode"=>"sequence"))
      {
        "id"                    => (raw["id"].to_s.empty? ? "layer_#{index.to_i+1}" : raw["id"].to_s),
        "name"                  => (raw["name"].to_s.empty? ? "Capa paralela #{index.to_i+1}" : raw["name"].to_s),
        "enabled"               => raw["enabled"] != false,
        "graphicMode"           => mode,
        "particleGraphic"       => (raw["particleGraphic"].to_s.empty? ? (seq[0] || BOSS_AURA_FRAME_GRAPHICS[0]) : raw["particleGraphic"].to_s),
        "particleGraphics"      => seq,
        "graphicFrameFrames"    => clamp_float(raw["graphicFrameFrames"],1.0,60.0,6.0),
        "graphicTransitionFrames"=> clamp_float(raw["graphicTransitionFrames"],0.0,30.0,2.0),
        "opacity"               => clamp_float(raw["opacity"],0.0,100.0,100.0),
        "opacityStart"          => clamp_float(raw["opacityStart"],0.0,100.0,0.0),
        "opacityMid"            => clamp_float(raw["opacityMid"],0.0,100.0,100.0),
        "opacityEnd"            => clamp_float(raw["opacityEnd"],0.0,100.0,0.0),
        "particleCount"         => clamp_int(raw["particleCount"],4,24,12),
        "scale"                 => clamp_float(raw["scale"],10.0,300.0,100.0),
        "riseSpeed"             => clamp_float(raw["riseSpeed"],25.0,300.0,135.0),
        "cycleFrames"           => clamp_float(raw["cycleFrames"],10.0,120.0,30.0),
        "riseHeight"            => clamp_float(raw["riseHeight"],20.0,300.0,100.0),
        "spreadX"               => clamp_float(raw["spreadX"],25.0,200.0,100.0),
        "spreadY"               => clamp_float(raw["spreadY"],25.0,180.0,80.0),
        "laneWidth"             => clamp_float(raw["laneWidth"],25.0,200.0,100.0),
        "swayAmount"            => clamp_float(raw["swayAmount"],0.0,300.0,100.0),
        "stretchStart"          => clamp_float(raw["stretchStart"],10.0,250.0,62.0),
        "stretchEnd"            => clamp_float(raw["stretchEnd"],10.0,300.0,132.0),
        "spawnMode"             => spawn,
        "asyncAmount"           => clamp_float(raw["asyncAmount"],0.0,300.0,100.0),
        "phaseOffset"           => clamp_float(raw["phaseOffset"],0.0,100.0,((index.to_i+1)*23)%100),
        "offsetX"               => clamp_float(raw["offsetX"],-100.0,100.0,0.0),
        "offsetY"               => clamp_float(raw["offsetY"],-100.0,100.0,0.0),
        "depthMode"             => depth,
        "blendMode"             => (["normal","additive"].include?(raw["blendMode"].to_s) ? raw["blendMode"].to_s : "additive")
      }
    rescue
      {
        "id"=>"layer_#{index.to_i+1}","name"=>"Capa paralela #{index.to_i+1}","enabled"=>true,
        "graphicMode"=>"single","particleGraphic"=>BOSS_AURA_FRAME_GRAPHICS[0],
        "particleGraphics"=>BOSS_AURA_FRAME_GRAPHICS.clone,"graphicFrameFrames"=>6.0,
        "graphicTransitionFrames"=>2.0,"opacity"=>100.0,"opacityStart"=>0.0,"opacityMid"=>100.0,"opacityEnd"=>0.0,"particleCount"=>12,"scale"=>100.0,
        "riseSpeed"=>135.0,"cycleFrames"=>30.0,"riseHeight"=>100.0,"spreadX"=>100.0,"spreadY"=>80.0,
        "laneWidth"=>100.0,"swayAmount"=>100.0,"stretchStart"=>62.0,"stretchEnd"=>132.0,
        "spawnMode"=>"async","asyncAmount"=>100.0,"phaseOffset"=>((index.to_i+1)*23)%100,
        "offsetX"=>0.0,"offsetY"=>0.0,"depthMode"=>"alternate","blendMode"=>"additive"
      }
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
        "graphicTransitionFrames"=> clamp_float(raw["graphicTransitionFrames"], 0.0, 30.0, 2.0),
        "parallelLayers"  => (raw["parallelLayers"].is_a?(Array) ? raw["parallelLayers"][0,3].each_with_index.map { |layer,i| aura_layer_config(layer,i) } : []),
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
        "outlineEffect"  => (["standard","roaring_knight","pulse"].include?(raw["outlineEffect"].to_s) ? raw["outlineEffect"].to_s : "standard"),
        "outlineCopies"  => clamp_int(raw["outlineCopies"], 1, 12, 6),
        "outlineCopySpacing"=> clamp_float(raw["outlineCopySpacing"], 25.0, 300.0, 100.0),
        "roaringStrength"=> clamp_float(raw["roaringStrength"], 0.0, 250.0, 100.0),
        "roaringSpeed"   => clamp_float(raw["roaringSpeed"], 10.0, 300.0, 100.0),
        "pulseStrength"  => clamp_float(raw["pulseStrength"], 0.0, 250.0, 100.0),
        "pulseSpeed"     => clamp_float(raw["pulseSpeed"], 10.0, 300.0, 100.0),
        "basZoomEnabled" => raw["basZoomEnabled"] != false,
        "basZoom"        => clamp_float(raw["basZoom"], 100.0, 220.0, 150.0),
        "basZoomBounds"  => (["screen","extended"].include?(raw["basZoomBounds"].to_s) ? raw["basZoomBounds"].to_s : "screen")
      }
    rescue
      {
        "profileId"=>"ebdx_default", "enabled"=>true, "introEnabled"=>true, "introSpotlight"=>true, "color"=>"#DD445B",
        "particleCount"=>12, "riseSpeed"=>135.0, "cycleFrames"=>30.0, "riseHeight"=>100.0, "spreadX"=>100.0, "spreadY"=>80.0,
        "laneWidth"=>100.0, "swayAmount"=>100.0, "offsetX"=>0.0, "offsetY"=>0.0, "particleScale"=>100.0, "stretchStart"=>62.0, "stretchEnd"=>132.0,
        "opacity"=>100.0, "opacityStart"=>0.0, "opacityMid"=>100.0, "opacityEnd"=>0.0, "spawnMode"=>"async", "asyncAmount"=>100.0, "graphicMode"=>"sequence", "particleGraphic"=>BOSS_AURA_FRAME_GRAPHICS[0], "particleGraphics"=>BOSS_AURA_FRAME_GRAPHICS.clone, "graphicFrameFrames"=>6.0, "graphicTransitionFrames"=>2.0, "parallelLayers"=>[], "depthMode"=>"alternate", "blendMode"=>"normal",
        "introDuration"=>104, "impactHold"=>56, "introReturnFrames"=>24, "fadeOutFrames"=>18,
        "outlineEnabled"=>true, "outlineColor"=>"#DD445B", "outlineOpacity"=>46.0, "outlineSize"=>2, "outlineEffect"=>"standard", "outlineCopies"=>6, "outlineCopySpacing"=>100.0,
        "roaringStrength"=>100.0, "roaringSpeed"=>100.0, "pulseStrength"=>100.0, "pulseSpeed"=>100.0,
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
      # The user's base exposes System.unscaled_uptime specifically so Turbo
      # can speed gameplay without shortening authored animation timing.
      if defined?(System) && System.respond_to?(:unscaled_uptime)
        value=(System.unscaled_uptime.to_f rescue nil)
        return value if value && value>=0
      end
      if Process.respond_to?(:clock_gettime) && defined?(Process::CLOCK_MONOTONIC)
        value=(Process.clock_gettime(Process::CLOCK_MONOTONIC).to_f rescue nil)
        return value if value && value>=0
      end
      if defined?(System) && System.respond_to?(:uptime)
        value=(System.uptime.to_f rescue nil)
        return value if value && value>=0
      end
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

    def initialize(viewport, scene_sprites, cfg, key_prefix = "bss_totem_persistent")
      @viewport=viewport
      @scene_sprites=scene_sprites.is_a?(Hash) ? scene_sprites : nil
      @cfg=cfg || {}
      @key_prefix=key_prefix.to_s
      @particles=[]
      @frame=0.0
      @last_clock=nil
      @disposed=false
      @rgb=BSS064.aura_color_rgb(@cfg["color"])
      @tone=aura_tone(@rgb)
      @layers=[]
      build_layers
      count=[BSS064.clamp_int(@cfg["particleCount"],4,24,12),*@layers.map { |layer| layer[:particle_count].to_i }].max
      count=BSS064.clamp_int(count,4,24,12)
      count.times { |i| create_particle(i,count) }
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
      dt=0.05 if dt>0.05
      dt*40.0
    rescue
      0.0
    end

    def layer_from_raw(raw, primary=false, index=0)
      raw={} if !raw.is_a?(Hash)
      src=primary ? @cfg : raw
      mode=src["graphicMode"].to_s.downcase
      mode=(primary ? "sequence" : "single") if !["single","sequence"].include?(mode)
      paths=BSS064.aura_graphic_paths(src.merge("graphicMode"=>mode))
      paths=BSS064::BOSS_AURA_FRAME_GRAPHICS.clone if paths.empty?
      bitmaps=paths.map { |path| BSS064.new_bitmap(path) }.compact
      return nil if bitmaps.empty?
      spawn=src["spawnMode"].to_s
      spawn="async" if !["async","simultaneous"].include?(spawn)
      depth=src["depthMode"].to_s
      depth="alternate" if !["alternate","front","back"].include?(depth)
      {
        :primary=>primary,
        :bitmaps=>bitmaps,
        :hold=>BSS064.clamp_float(src["graphicFrameFrames"],1,60,6),
        :transition=>BSS064.clamp_float(src["graphicTransitionFrames"],0,30,2),
        :opacity=>BSS064.clamp_float(src["opacity"],0,100,100)/100.0,
        :opacity_start=>BSS064.clamp_float(src["opacityStart"],0,100,0)/100.0,
        :opacity_mid=>BSS064.clamp_float(src["opacityMid"],0,100,100)/100.0,
        :opacity_end=>BSS064.clamp_float(src["opacityEnd"],0,100,0)/100.0,
        :particle_count=>BSS064.clamp_int(src["particleCount"],4,24,12),
        :scale=>(primary ? BSS064.clamp_float(src["particleScale"],25,250,100)/100.0 : BSS064.clamp_float(src["scale"],10,300,100)/100.0),
        :rise_speed=>BSS064.clamp_float(src["riseSpeed"],25,300,135)/100.0,
        :cycle_frames=>BSS064.clamp_float(src["cycleFrames"],10,120,30),
        :rise_height=>BSS064.clamp_float(src["riseHeight"],20,300,100)/100.0,
        :spread_x=>BSS064.clamp_float(src["spreadX"],25,200,100)/100.0,
        :spread_y=>BSS064.clamp_float(src["spreadY"],25,180,80)/100.0,
        :lane_width=>BSS064.clamp_float(src["laneWidth"],25,200,100)/100.0,
        :sway_amount=>BSS064.clamp_float(src["swayAmount"],0,300,100)/100.0,
        :stretch_start=>BSS064.clamp_float(src["stretchStart"],10,250,62)/100.0,
        :stretch_end=>BSS064.clamp_float(src["stretchEnd"],10,300,132)/100.0,
        :spawn_mode=>spawn,
        :async_amount=>BSS064.clamp_float(src["asyncAmount"],0,300,100)/100.0,
        :phase_offset=>(primary ? 0.0 : BSS064.clamp_float(src["phaseOffset"],0,100,((index+1)*23)%100)/100.0),
        :offset_x=>BSS064.clamp_float(src["offsetX"],-100,100,0)/100.0,
        :offset_y=>BSS064.clamp_float(src["offsetY"],-100,100,0)/100.0,
        :depth=>depth,
        :blend=>(src["blendMode"].to_s=="additive" ? 1 : 0),
        :id=>(primary ? "main" : (src["id"].to_s.empty? ? "parallel_#{index+1}" : src["id"].to_s))
      }
    rescue => e
      BSS064.log("Boss aura layer warning: #{e.class}: #{e.message}")
      nil
    end

    def build_layers
      main=layer_from_raw(@cfg,true,0)
      @layers << main if main
      rows=@cfg["parallelLayers"].is_a?(Array) ? @cfg["parallelLayers"] : []
      rows[0,3].each_with_index do |raw,i|
        next if !raw.is_a?(Hash) || raw["enabled"]==false
        layer=layer_from_raw(raw,false,i)
        @layers << layer if layer
      end
    end

    def create_layer_sprite(layer, i, suffix)
      sp=Sprite.new(@viewport)
      bmp=layer[:bitmaps][0]
      if bmp
        sp.bitmap=bmp
        sp.ox=bmp.width/2
        sp.oy=bmp.height
      end
      sp.visible=false;sp.opacity=0
      sp.tone=@tone if sp.respond_to?(:tone=)
      sp.blend_type=layer[:blend] if sp.respond_to?(:blend_type=)
      key="#{@key_prefix}_#{layer[:id]}_#{i}_#{suffix}"
      @scene_sprites[key]=sp if @scene_sprites
      [sp,key]
    end

    def create_particle(i,count)
      denom=[count.to_i-1,1].max.to_f
      lane=i.to_f/denom
      layer_rows=@layers.map do |layer|
        a=create_layer_sprite(layer,i,"a");b=create_layer_sprite(layer,i,"b")
        # Every layer gets its own phase. Parallel async layers therefore do not
        # spawn on the same frame merely because the main particle did.
        particle_phase=(layer[:spawn_mode]=="simultaneous" ? 0.0 : i.to_f*7.0*layer[:async_amount])
        {:layer=>layer,:a=>a[0],:a_key=>a[1],:b=>b[0],:b_key=>b[1],:phase=>particle_phase}
      end
      @particles << {:layers=>layer_rows,:lane=>lane,:row=>(i%3),:front=>(i%2==0)}
    rescue => e
      BSS064.log("Boss aura particle create warning: #{e.class}: #{e.message}")
    end

    def dispose
      return if @disposed
      @particles.each do |row|
        row[:layers].each do |lr|
          [[:a,:a_key],[:b,:b_key]].each do |spk,keyk|
            sp=lr[spk];key=lr[keyk]
            begin;@scene_sprites.delete(key) if @scene_sprites && @scene_sprites[key].equal?(sp);rescue;end
            begin;sp.dispose if sp && !sp.disposed?;rescue;end
          end
        end
      end
      @particles.clear
      @layers.each do |layer|
        layer[:bitmaps].each { |bmp| begin;bmp.dispose if bmp && !bmp.disposed?;rescue;end }
        layer[:bitmaps].clear
      end
      @layers.clear;@disposed=true
    end

    def smoothstep01(x)
      x=[[x.to_f,0.0].max,1.0].min
      x*x*(3.0-2.0*x)
    end

    def layer_opacity_curve(layer,t)
      start=layer[:opacity_start].to_f;mid=layer[:opacity_mid].to_f;finish=layer[:opacity_end].to_f
      if t.to_f<=0.5
        q=smoothstep01(t.to_f*2.0);start+(mid-start)*q
      else
        q=smoothstep01((t.to_f-0.5)*2.0);mid+(finish-mid)*q
      end
    rescue
      1.0
    end

    # One-shot graphic sequence: 1 -> 2 -> 3 -> 4 -> final graphic while the
    # particle fades. It never loops 4 -> 1 inside one particle life.
    def sequence_state(layer,age)
      list=layer[:bitmaps]
      return [0,nil,1.0,0.0] if !list || list.length<=1
      hold=[layer[:hold].to_f,1.0].max;trans=[layer[:transition].to_f,0.0].max;cursor=[age.to_f,0.0].max
      (0...(list.length-1)).each do |i|
        return [i,nil,1.0,0.0] if cursor<hold
        cursor-=hold
        if trans>0.0
          if cursor<trans
            q=smoothstep01(cursor/trans);return [i,i+1,1.0-q,q]
          end
          cursor-=trans
        end
      end
      [list.length-1,nil,1.0,0.0]
    rescue
      [0,nil,1.0,0.0]
    end

    def assign_bitmap(sp,layer,index)
      return if !sp
      bmp=layer[:bitmaps][index.to_i] rescue nil
      return if !bmp
      if !sp.bitmap.equal?(bmp)
        sp.bitmap=bmp;sp.ox=bmp.width/2;sp.oy=bmp.height
      end
    rescue;end

    def hide_layer(lr)
      [lr[:a],lr[:b]].each do |sp|
        next if !sp || (sp.disposed? rescue true)
        sp.opacity=0;sp.visible=false
      end
    rescue;end

    def update_layer(lr,state,row,i,global_alpha,live_opacity)
      layer=lr[:layer]
      count=[layer[:particle_count].to_i,1].max
      if i>=count
        hide_layer(lr);return
      end
      speed=layer[:rise_speed].to_f
      life=[layer[:cycle_frames].to_f/[speed,0.25].max,14.0].max
      raw_frame=@frame+lr[:phase].to_f+(life*layer[:phase_offset].to_f)
      raw_t=(raw_frame % life)/life
      start_t=0.075;end_t=0.925
      if raw_t<=start_t || raw_t>=end_t
        hide_layer(lr);return
      end
      t=(raw_t-start_t)/(end_t-start_t);t=[[t,0.0].max,1.0].min
      lane=count>1 ? i.to_f/(count-1).to_f : 0.5
      base_lane=0.5+0.68*(lane-0.5)*layer[:lane_width].to_f
      nx=0.5+(base_lane-0.5)*layer[:spread_x].to_f
      nx+=Math.sin((t*Math::PI*2.0)+(i*0.73)+(layer[:phase_offset].to_f*Math::PI*2.0))*0.012*layer[:spread_x].to_f*layer[:sway_amount].to_f
      nx=[[nx+layer[:offset_x].to_f,0.04].max,0.96].min
      base_y=[0.68,0.54,0.78][row[:row].to_i%3]
      ny=0.5+(base_y-0.5)*layer[:spread_y].to_f
      ny=[[ny+layer[:offset_y].to_f,0.10].max,0.92].min
      rise=state[:height]*0.12*t*speed*layer[:rise_height].to_f
      stretch=layer[:stretch_start].to_f+(layer[:stretch_end].to_f-layer[:stretch_start].to_f)*t
      base_alpha=(live_opacity.to_f/255.0)*layer[:opacity].to_f*layer_opacity_curve(layer,t)*global_alpha.to_f
      sequence_age=(raw_t-start_t)*life
      ia,ib,wa,wb=sequence_state(layer,sequence_age)
      assign_bitmap(lr[:a],layer,ia);assign_bitmap(lr[:b],layer,ib) if ib
      x,y=local_to_world(state,nx,ny,rise)
      depth=layer[:depth]
      z=depth=="front" ? state[:z]+1 : (depth=="back" ? state[:z]-1 : (row[:front] ? state[:z]+1 : state[:z]-1))
      [[:a,wa],[:b,wb]].each do |which,weight|
        sp=lr[which];next if !sp || (sp.disposed? rescue true)
        if weight.to_f<=0.001 || (which==:b && ib.nil?)
          sp.opacity=0;sp.visible=false;next
        end
        sp.x=x;sp.y=y;sp.z=z;sp.blend_type=layer[:blend] if sp.respond_to?(:blend_type=)
        sp.angle=state[:angle] if sp.respond_to?(:angle=);sp.mirror=((nx>=0.5) ^ state[:mirror]) if sp.respond_to?(:mirror=)
        sp.zoom_x=[state[:zoom_x].abs*layer[:scale].to_f,0.05].max
        sp.zoom_y=[state[:zoom_y].abs*layer[:scale].to_f*stretch,0.05].max
        alpha=base_alpha*weight.to_f;sp.opacity=[[(alpha*255.0).round,0].max,255].min;sp.visible=sp.opacity>1
      end
    rescue => e
      BSS064.log("Boss aura layer update warning: #{e.class}: #{e.message}");hide_layer(lr)
    end

    def update(target_sprite,battler,master_alpha=1.0,allow_fainted=false)
      return if @disposed
      state=target_state(target_sprite);fainted=(battler.fainted? rescue false)
      if !state || !battler || (fainted && !allow_fainted) || ((!state[:visible] || state[:opacity]<=0) && !allow_fainted) || @layers.empty?
        hide_all;return
      end
      step=logical_step;@frame+=step if step>0
      global_alpha=[[master_alpha.to_f,0.0].max,1.0].min
      live_opacity=allow_fainted ? 255.0 : state[:opacity].to_f
      @particles.each_with_index do |row,i|
        row[:layers].each { |lr| update_layer(lr,state,row,i,global_alpha,live_opacity) }
      end
    rescue => e
      BSS064.log("Boss aura update warning: #{e.class}: #{e.message}");hide_all
    end

    def hide_all
      @particles.each { |row| row[:layers].each { |lr| hide_layer(lr) } }
    rescue;end
  end

  # Persistent bright contour.  Eight tinted copies of the live battler are
  # rendered just behind it.  They share the battler bitmap (never dispose it)
  # and mirror src_rect/origin/zoom/angle every frame, so forms, spritesheet
  # frames and BAS-authored transformations remain aligned.
  class BossAuraOutline
    def initialize(viewport,scene_sprites,cfg,key_prefix="bss_totem_outline")
      @viewport=viewport;@scene_sprites=scene_sprites.is_a?(Hash) ? scene_sprites : nil
      @cfg=cfg||{};@contours=[];@ghosts=[];@disposed=false;@rgb=BSS064.aura_color_rgb(@cfg["outlineColor"])
      r=BSS064.clamp_int(@cfg["outlineSize"],1,8,2)
      [[-1,-1],[0,-1],[1,-1],[-1,0],[1,0],[-1,1],[0,1],[1,1]].each_with_index do |unit,i|
        sp=make_sprite("#{key_prefix}_edge_#{i}");@contours << [sp,"#{key_prefix}_edge_#{i}",unit,r]
      end
      count=BSS064.clamp_int(@cfg["outlineCopies"],1,12,6)
      count.times do |i|
        key="#{key_prefix}_ghost_#{i}";sp=make_sprite(key);@ghosts << [sp,key,i]
      end
    rescue => e
      BSS064.log("Boss outline create warning: #{e.class}: #{e.message}")
    end

    def make_sprite(key)
      sp=Sprite.new(@viewport);sp.visible=false;sp.opacity=0
      sp.blend_type=0 if sp.respond_to?(:blend_type=)
      sp.color=Color.new(@rgb[0],@rgb[1],@rgb[2],255) if sp.respond_to?(:color=)
      @scene_sprites[key]=sp if @scene_sprites
      sp
    end

    def disposed?;@disposed;end

    def sync_from_target(sp,target,bmp,src)
      return if !sp || (sp.disposed? rescue true)
      sp.bitmap=bmp if !sp.bitmap.equal?(bmp)
      if src && sp.respond_to?(:src_rect) && sp.src_rect
        sp.src_rect.set(src.x,src.y,src.width,src.height)
      end
      sp.ox=(target.ox rescue 0);sp.oy=(target.oy rescue 0)
      sp.angle=(target.angle rescue 0) if sp.respond_to?(:angle=)
      sp.mirror=(target.mirror rescue false) if sp.respond_to?(:mirror=)
      sp.color=Color.new(@rgb[0],@rgb[1],@rgb[2],255) if sp.respond_to?(:color=)
      sp.blend_type=0 if sp.respond_to?(:blend_type=)
    rescue;end

    def gaussian(x,center,width)
      Math.exp(-(((x-center)/width)**2))
    rescue
      0.0
    end

    def update(target,battler,master_alpha=1.0,allow_fainted=false)
      return if @disposed
      bmp=target && target.respond_to?(:bitmap) ? target.bitmap : nil
      fainted=(battler.fainted? rescue false)
      visible=target && bmp && !(bmp.disposed? rescue true) && !(target.disposed? rescue true) && (!fainted || allow_fainted) && (allow_fainted || ((target.visible rescue true) && (target.opacity rescue 255).to_i>0))
      if !visible;hide_all;return;end
      src=(target.src_rect rescue nil);fade=[[master_alpha.to_f,0.0].max,1.0].min
      cfg_op=BSS064.clamp_float(@cfg["outlineOpacity"],0,100,46)/100.0;target_op=allow_fainted ? 255.0 : (target.opacity rescue 255).to_f
      effect=@cfg["outlineEffect"].to_s;effect="standard" if !["standard","roaring_knight","pulse"].include?(effect)
      base_op=[[(target_op*cfg_op*fade).round,0].max,255].min
      zbase_x=(target.zoom_x rescue 1.0).to_f;zbase_y=(target.zoom_y rescue 1.0).to_f;clock=BSS064.monotonic_seconds
      radius=BSS064.clamp_int(@cfg["outlineSize"],1,8,2).to_f
      roaring_strength=BSS064.clamp_float(@cfg["roaringStrength"],0,250,100)/100.0
      roaring_speed=BSS064.clamp_float(@cfg["roaringSpeed"],10,300,100)/100.0
      pulse_strength=BSS064.clamp_float(@cfg["pulseStrength"],0,250,100)/100.0
      pulse_speed=BSS064.clamp_float(@cfg["pulseSpeed"],10,300,100)/100.0
      spacing=BSS064.clamp_float(@cfg["outlineCopySpacing"],25,300,100)/100.0

      # The close 8-way contour always follows the live battler exactly. This is
      # separate from the Roaring/Pulse copies so the silhouette never becomes
      # the noisy multi-outline artifact of the old implementation.
      @contours.each_with_index do |row,i|
        sp,key,unit,r=row;next if !sp || (sp.disposed? rescue true);sync_from_target(sp,target,bmp,src)
        local_radius=radius
        if effect=="pulse"
          phase=(clock*1.90*pulse_speed)%1.0;beat=[gaussian(phase,0.10,0.10)+0.76*gaussian(phase,0.33,0.115),1.0].min
          pulse_body=0.10+0.90*beat
          local_radius=radius*(1.0+0.28*pulse_body*pulse_strength)
        end
        sp.zoom_x=zbase_x;sp.zoom_y=zbase_y;sp.x=(target.x rescue 0)+unit[0]*local_radius;sp.y=(target.y rescue 0)+unit[1]*local_radius
        sp.z=(target.z rescue 50)-1;sp.opacity=base_op;sp.visible=sp.opacity>1
      end

      @ghosts.each do |row|
        sp,key,i=row;next if !sp || (sp.disposed? rescue true);sync_from_target(sp,target,bmp,src)
        n=i+1;fall=[1.0-(i.to_f/[@ghosts.length,1].max.to_f),0.08].max
        if effect=="roaring_knight"
          # Reference-style displaced afterimages: a directional white/tinted
          # trail with staggered jitter, not a circular glow.
          phase=clock*9.0*roaring_speed+i*1.83
          dist=n*radius*2.55*spacing*roaring_strength
          dx=dist*(0.72+0.20*Math.sin(phase*0.53))
          dy=-dist*0.16+Math.sin(phase)*radius*1.85*roaring_strength
          zoom=1.0+n*0.010*roaring_strength
          sp.x=(target.x rescue 0)+dx;sp.y=(target.y rescue 0)+dy;sp.zoom_x=zbase_x*zoom;sp.zoom_y=zbase_y*zoom
          sp.z=(target.z rescue 50)-2-n;sp.opacity=[[base_op*fall*(0.22+0.28*(Math.sin(phase*0.71)*0.5+0.5))*[roaring_strength,0.15].max,205].min,0].max.to_i;sp.visible=sp.opacity>1
        elsif effect=="pulse"
          phase=(clock*1.90*pulse_speed-i*0.075*spacing)%1.0;phase+=1.0 if phase<0
          beat=[gaussian(phase,0.10,0.10)+0.76*gaussian(phase,0.33,0.115),1.0].min
          pulse_body=0.10+0.90*beat
          grow=1.0+n*0.024*spacing*pulse_strength*(0.48+pulse_body*1.38)
          sp.x=(target.x rescue 0);sp.y=(target.y rescue 0);sp.zoom_x=zbase_x*grow;sp.zoom_y=zbase_y*grow
          sp.z=(target.z rescue 50)-2-n;sp.opacity=[[base_op*fall*pulse_body*[pulse_strength,0.15].max,190].min,0].max.to_i;sp.visible=sp.opacity>1
        else
          sp.visible=false;sp.opacity=0
        end
      end
    rescue => e
      BSS064.log("Boss outline update warning: #{e.class}: #{e.message}");hide_all
    end

    def hide_all
      (@contours+@ghosts).each{|row|sp=row[0];sp.visible=false if sp && !(sp.disposed? rescue true);sp.opacity=0 if sp && !(sp.disposed? rescue true)}
    rescue;end

    def dispose
      return if @disposed
      (@contours+@ghosts).each do |row|
        sp=row[0];key=row[1]
        begin;@scene_sprites.delete(key) if @scene_sprites && @scene_sprites[key].equal?(sp);rescue;end
        begin;sp.bitmap=nil if sp && !(sp.disposed? rescue true);sp.dispose if sp && !sp.disposed?;rescue;end
      end
      @contours.clear;@ghosts.clear;@disposed=true
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

  def bss_boss_frame_dimensions(sprite)
    return [0.0,0.0] if !sprite || (sprite.disposed? rescue true)
    bmp=(sprite.bitmap rescue nil);src=(sprite.src_rect rescue nil)
    w=(src && src.width.to_i>0) ? src.width.to_f : (bmp && !(bmp.disposed? rescue true) ? bmp.width.to_f : 0.0)
    h=(src && src.height.to_i>0) ? src.height.to_f : (bmp && !(bmp.disposed? rescue true) ? bmp.height.to_f : 0.0)
    [w,h]
  rescue
    [0.0,0.0]
  end

  def bss_capture_boss_native_scale(battler=nil,force=false)
    battle=@battle
    battler ||= (battle.bss_find_boss_battler rescue nil) if battle
    return nil if !battler
    sprite=bss_boss_target_sprite(battler);return nil if !sprite || (sprite.disposed? rescue true)
    @bss_boss_native_scale ||= {};@bss_boss_native_renderer ||= {}
    idx=(battler.index rescue 1).to_i
    current=[(sprite.zoom_x rescue 1.0).to_f,(sprite.zoom_y rescue 1.0).to_f]
    bmp=(sprite.bitmap rescue nil);src=(sprite.src_rect rescue nil);fw,fh=bss_boss_frame_dimensions(sprite)
    renderer={
      :width=>(bmp && !(bmp.disposed? rescue true) ? bmp.width.to_i : 0),
      :height=>(bmp && !(bmp.disposed? rescue true) ? bmp.height.to_i : 0),
      :src_w=>(src ? src.width.to_i : 0),:src_h=>(src ? src.height.to_i : 0),
      :frame_w=>fw,:frame_h=>fh,
      # Store what the player actually sees, not only zoom. LBDS/Animated DBK
      # can bake a multiplier into the bitmap/src_rect during SOS/BAS.
      :display_w=>fw*current[0].abs,:display_h=>fh*current[1].abs,
      :x=>(sprite.x rescue 0).to_f,:y=>(sprite.y rescue 0).to_f,:z=>(sprite.z rescue 50).to_i,
      :back=>((battler.index.to_i.even?) rescue false)
    }
    return @bss_boss_native_scale[idx] if !force && @bss_boss_native_scale[idx]
    if current[0]!=0 && current[1]!=0 && fw>0 && fh>0
      @bss_boss_native_scale[idx]=current;@bss_boss_native_renderer[idx]=renderer
    end
    @bss_boss_native_scale[idx]
  rescue => e
    BSS064.log("Boss native scale capture warning: #{e.class}: #{e.message}");nil
  end

  def bss_boss_renderer_profile_mismatch?(sprite,idx)
    info=@bss_boss_native_renderer && @bss_boss_native_renderer[idx]
    return false if !info || !sprite || (sprite.disposed? rescue true)
    bmp=(sprite.bitmap rescue nil);return false if !bmp || (bmp.disposed? rescue true)
    src=(sprite.src_rect rescue nil);w=bmp.width.to_i;h=bmp.height.to_i;sw=src ? src.width.to_i : 0;sh=src ? src.height.to_i : 0
    return true if info[:width].to_i>0 && (w-info[:width].to_i).abs>1
    return true if info[:height].to_i>0 && (h-info[:height].to_i).abs>1
    return true if info[:src_w].to_i>0 && sw>0 && (sw-info[:src_w].to_i).abs>1
    return true if info[:src_h].to_i>0 && sh>0 && (sh-info[:src_h].to_i).abs>1
    false
  rescue
    false
  end

  def bss_apply_boss_display_size(sprite,idx)
    info=@bss_boss_native_renderer && @bss_boss_native_renderer[idx]
    base=@bss_boss_native_scale && @bss_boss_native_scale[idx]
    return false if !sprite || !info || !base
    fw,fh=bss_boss_frame_dimensions(sprite);return false if fw<=0 || fh<=0
    want_w=info[:display_w].to_f;want_h=info[:display_h].to_f
    return false if want_w<=0 || want_h<=0
    sx=base[0].to_f<0 ? -1.0 : 1.0;sy=base[1].to_f<0 ? -1.0 : 1.0
    sprite.zoom_x=sx*(want_w/fw) if sprite.respond_to?(:zoom_x=)
    sprite.zoom_y=sy*(want_h/fh) if sprite.respond_to?(:zoom_y=)
    true
  rescue => e
    BSS064.log("Boss display-size restore warning: #{e.class}: #{e.message}");false
  end

  # Reassert the physical on-screen size of the Totem. This is intentionally
  # callable by SOS because that flow can rebuild every battler renderer without
  # going through Scene#pbAnimation.
  def bss_reassert_boss_visual_scale(battler=nil,rebuild=true)
    battle=@battle;battler ||= (battle.bss_find_boss_battler rescue nil) if battle
    return false if !battler || (battler.fainted? rescue false)
    idx=(battler.index rescue -1).to_i;return false if idx<0
    bss_capture_boss_native_scale(battler,false)
    sprite=bss_boss_target_sprite(battler);return false if !sprite || (sprite.disposed? rescue true)
    if rebuild && bss_boss_renderer_profile_mismatch?(sprite,idx)
      bss_restore_boss_natural_renderer(battler,nil,true)
      sprite=bss_boss_target_sprite(battler) rescue sprite
    end
    bss_apply_boss_display_size(sprite,idx)
  rescue => e
    BSS064.log("Boss visual-scale reassert warning: #{e.class}: #{e.message}");false
  end

  # BAS/Animated DBK can replace the whole battler bitmap while showing a
  # temporary Front/Back view. Rebuild the natural renderer and restore the
  # original DISPLAYED dimensions instead of blindly reusing zoom_x/zoom_y.
  def bss_restore_boss_natural_renderer(battler,snapshot=nil,force=false)
    return false if !battler || (battler.fainted? rescue false)
    sprite=bss_boss_target_sprite(battler);return false if !sprite || (sprite.disposed? rescue true)
    idx=(battler.index rescue -1).to_i;return false if idx<0
    return false if !force && !bss_boss_renderer_profile_mismatch?(sprite,idx)
    pkmn=(battler.visiblePokemon rescue nil) if battler.respond_to?(:visiblePokemon)
    pkmn ||= (battler.pokemon rescue nil) if battler.respond_to?(:pokemon)
    return false if !pkmn
    back=(battler.index.to_i.even? rescue false)
    x=snapshot && snapshot[:x] ? snapshot[:x] : (sprite.x rescue nil);y=snapshot && snapshot[:y] ? snapshot[:y] : (sprite.y rescue nil);z=snapshot && snapshot[:z] ? snapshot[:z] : (sprite.z rescue nil)
    begin;sprite.setPokemonBitmap(pkmn,battler,back);rescue ArgumentError, TypeError;sprite.setPokemonBitmap(pkmn,back);end
    sprite.x=x if !x.nil? && sprite.respond_to?(:x=);sprite.y=y if !y.nil? && sprite.respond_to?(:y=);sprite.z=z if !z.nil? && sprite.respond_to?(:z=)
    bss_apply_boss_display_size(sprite,idx)
    true
  rescue => e
    BSS064.log("Boss natural renderer restore warning: #{e.class}: #{e.message}");false
  end

  def bss_guard_boss_sprite_scale
    return if @bss_boss_animation_depth.to_i>0
    battle=@battle;return if !battle || !battle.respond_to?(:bss_boss_enabled?) || !battle.bss_boss_enabled?
    battler=battle.bss_find_boss_battler rescue nil;return if !battler
    bss_reassert_boss_visual_scale(battler,true)
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
    intro=nil;player=nil;turbo_restore=nil
    sprite=bss_boss_target_sprite(battler);return if !sprite
    cfg=BSS064.boss_aura_config(boss_cfg)

    # Aura intro is authored in real 40-Hz time. Lock the user's native Turbo
    # to x1 for the whole sequence so Input.update cannot change it mid-charge.
    if defined?(Turbo) && Turbo.respond_to?(:set_speed)
      begin
        old_speed=Turbo.respond_to?(:speed) ? Turbo.speed.to_i : (defined?($GameSpeed) ? $GameSpeed.to_i : 0)
        old_toggle=defined?($CanToggle) ? $CanToggle : nil
        turbo_restore={:speed=>old_speed,:toggle=>old_toggle}
        $CanToggle=false if defined?($CanToggle)
        Turbo.set_speed(0)
      rescue => e
        BSS064.log("Aura Turbo lock warning: #{e.class}: #{e.message}")
      end
    end

    intro=BSS064::BossAuraIntro.new(self,sprite,battler,cfg) do
      if @battle && @battle.respond_to?(:bss_boss_aura_active=);@battle.bss_boss_aura_active=true;end
      bss_update_boss_aura
    end
    total=intro.total_duration.to_i;BSS064.install_bas_aura_compat
    use_bas=cfg["basZoomEnabled"] && BSS064.bas_available? && respond_to?(:bas_runtime_pump_frame)
    if use_bas
      offset=bss_boss_static_camera_offset(sprite);data=bss_bas_camera_data(total,cfg["basZoom"],cfg["basZoomBounds"],offset[0],offset[1])
      player=BattleAnimationStudioRuntime::Player.new(bss_scene_sprites,@viewport,battler,battler,data,[battler])
      BattleAnimationStudioRuntime.active_player=player if BattleAnimationStudioRuntime.respond_to?(:active_player=)
    end
    started=BSS064.monotonic_seconds;last_logic=-1;safety=0
    loop do
      elapsed=BSS064.monotonic_seconds-started;logical=(elapsed*40.0).floor;logical=0 if logical<0;logical=total-1 if logical>=total
      if logical>last_logic
        first=[last_logic+1,0].max;(first..logical).each { |f| intro.update(f) };last_logic=logical
      end
      use_bas ? (player.update;bas_runtime_pump_frame(player)) : bss_plain_frame_pump
      break if elapsed*40.0>=total;safety+=1;break if safety>20000
    end
  rescue => e
    BSS064.log("Boss aura sequence warning: #{e.class}: #{e.message}")
  ensure
    begin
      if player && defined?(BattleAnimationStudioRuntime) && BattleAnimationStudioRuntime.respond_to?(:active_player=) && BattleAnimationStudioRuntime.active_player.equal?(player);BattleAnimationStudioRuntime.active_player=nil;end
    rescue;end
    begin;player.restore_camera! if player;rescue;end;begin;player.dispose if player;rescue;end
    if @battle && @battle.respond_to?(:bss_boss_aura_active=) && @battle.respond_to?(:bss_boss_has_stat_aura?) && @battle.bss_boss_has_stat_aura?
      @battle.bss_boss_aura_active=true;begin;bss_update_boss_aura;rescue;end
    end
    begin;intro.dispose if intro;rescue;end
    if turbo_restore && defined?(Turbo) && Turbo.respond_to?(:set_speed)
      begin
        Turbo.set_speed(turbo_restore[:speed].to_i)
        $CanToggle=turbo_restore[:toggle] if defined?($CanToggle) && !turbo_restore[:toggle].nil?
      rescue => e
        BSS064.log("Aura Turbo restore warning: #{e.class}: #{e.message}")
      end
    end
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
    {
      :sprite=>sprite,:battler=>battler,:idx=>idx,:zoom_x=>zx,:zoom_y=>zy,
      :x=>(sprite.x rescue 0).to_f,:y=>(sprite.y rescue 0).to_f,:z=>(sprite.z rescue 50).to_i,
      :display_w=>((bss_boss_frame_dimensions(sprite)[0] rescue 0).to_f*(sprite.zoom_x rescue 1.0).to_f.abs),
      :display_h=>((bss_boss_frame_dimensions(sprite)[1] rescue 0).to_f*(sprite.zoom_y rescue 1.0).to_f.abs)
    }
  rescue
    nil
  end

  def bss_restore_boss_animation_scale(snapshot)
    return if !snapshot.is_a?(Hash)
    battler=snapshot[:battler]
    sprite=snapshot[:sprite]
    return if !sprite || (sprite.disposed? rescue true)
    idx=snapshot[:idx].to_i
    # Repair a leaked Front/Back renderer profile first. This is the missing
    # step for LBDS Animated DBK, where the view's x2/x3 scale lives inside the
    # rebuilt bitmap rather than only in sprite.zoom_x/y.
    bss_restore_boss_natural_renderer(battler,snapshot,false) if battler && respond_to?(:bss_restore_boss_natural_renderer)
    sprite=bss_boss_target_sprite(battler) rescue sprite
    return if !sprite || (sprite.disposed? rescue true)
    # Renderer dimensions may have changed. First restore the exact physical
    # footprint seen immediately before this animation/SOS call. This is more
    # robust than restoring raw zoom on LBDS Animated DBK because Front/Back
    # changes can rebuild a bitmap at a different baked-in scale.
    applied=false
    begin
      fw,fh=bss_boss_frame_dimensions(sprite)
      want_w=snapshot[:display_w].to_f;want_h=snapshot[:display_h].to_f
      if fw.to_f>0 && fh.to_f>0 && want_w>0 && want_h>0
        sx=snapshot[:zoom_x].to_f<0 ? -1.0 : 1.0
        sy=snapshot[:zoom_y].to_f<0 ? -1.0 : 1.0
        sprite.zoom_x=sx*(want_w/fw.to_f) if sprite.respond_to?(:zoom_x=)
        sprite.zoom_y=sy*(want_h/fh.to_f) if sprite.respond_to?(:zoom_y=)
        applied=true
      end
    rescue
      applied=false
    end
    bss_apply_boss_display_size(sprite,idx) if !applied && respond_to?(:bss_apply_boss_display_size)
    sprite.x=snapshot[:x] if sprite.respond_to?(:x=)
    sprite.y=snapshot[:y] if sprite.respond_to?(:y=)
    sprite.z=snapshot[:z] if sprite.respond_to?(:z=)
    @bss_boss_native_scale ||= {}
    @bss_boss_native_scale[idx]=[snapshot[:zoom_x].to_f,snapshot[:zoom_y].to_f] if idx>=0 && !@bss_boss_native_scale[idx]
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

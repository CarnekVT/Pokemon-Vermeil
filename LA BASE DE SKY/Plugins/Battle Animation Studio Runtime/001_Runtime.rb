#===============================================================================
# Battle Animation Studio Runtime v1.10.7
# Plays animations exported by the Maker Studio Battle Animation Studio.
# Credits: CarnekVT
# Source data: PBS/AnimationStudio/compiled_animations.json
#===============================================================================
begin
  require "json"
rescue LoadError
end

module BattleAnimationStudioRuntime
  DATA_FILE = File.join("PBS", "AnimationStudio", "compiled_animations.json")
  VERSION = 16
  RUNTIME_PARTICLE_LIMIT = 240
  @cache = nil
  @mtime = nil
  @lookup_index = nil
  @active_player = nil

  module_function

  def active_player
    @active_player
  end

  def active_player=(player)
    @active_player = player
  end

  def log(msg)
    echoln("[Battle Animation Studio Runtime] #{msg}") if defined?(echoln)
  rescue
  end

  def normalize_move_id(move)
    return move.id.to_s.upcase if move.respond_to?(:id)
    return move.to_s.sub(/^:/, "").upcase
  rescue
    move.to_s.upcase
  end

  def rebuild_lookup_index
    @lookup_index = {}
    arr = @cache && @cache["animations"]
    return @lookup_index if !arr.is_a?(Array)
    arr.each do |anim|
      next if !anim.is_a?(Hash)
      src = source_of(anim)
      catalog = src["catalogType"].to_s.downcase
      kind = catalog == "common" ? 1 : (catalog == "custom" ? 2 : 0)
      move_id = (src["move"] || anim["name"]).to_s.upcase
      next if move_id.empty?
      key = [kind, move_id]
      (@lookup_index[key] ||= []) << anim
    end
    @lookup_index
  rescue => e
    log("index #{e.class}: #{e.message}")
    @lookup_index = {}
  end

  def load_data
    return nil if !File.exist?(DATA_FILE)
    mtime = File.mtime(DATA_FILE).to_i rescue 0
    return @cache if @cache && @mtime == mtime && @lookup_index
    if !defined?(JSON)
      log("Ruby JSON is unavailable; cannot read #{DATA_FILE}.")
      return nil
    end
    @cache = JSON.parse(File.binread(DATA_FILE))
    @mtime = mtime
    rebuild_lookup_index
    @cache
  rescue => e
    log("#{e.class}: #{e.message}")
    @cache = nil
    @lookup_index = nil
  end

  def animations
    data = load_data
    arr = data && data["animations"]
    arr.is_a?(Array) ? arr : []
  end

  def source_of(anim)
    s = anim["source"]
    s.is_a?(Hash) ? s : {}
  end

  def matching(move_id, version, user_index, common = false)
    mid = normalize_move_id(move_id)
    load_data
    list = ((@lookup_index || {})[[common ? 1 : 0, mid]] || []).select do |anim|
      src = source_of(anim)
      !(src.key?("runtimeEnabled") && !src["runtimeEnabled"])
    end
    return nil if list.empty?
    ver = version.to_i
    exact_version = list.select { |a| source_of(a)["version"].to_i == ver }
    list = exact_version unless exact_version.empty?
    opposing = user_index.to_i.odd?
    side_matches = list.select { |a| !!source_of(a)["opposing"] == opposing }
    list = side_matches unless side_matches.empty?

    # A Studio-authored animation must win over an imported reference using the
    # same Move ID/version/side. Imported Ruby/PBS/EBDX entries are useful as
    # sources, but choosing the first registered entry meant the battle could
    # play a completely different animation from the one currently previewed.
    # If several Studio entries collide, the last registered one wins, matching
    # the editor's newest/most-recent registration semantics.
    studio = list.reverse.find do |a|
      src = source_of(a)
      src["type"].to_s.downcase == "studio" || src["system"].to_s.downcase == "battle_animation_studio"
    end
    return studio if studio

    list.find { |a| !source_of(a)["opposing"] } || list.first
  end

  def common_matching(name, user_index)
    matching(name, 0, user_index || 0, true)
  end

  def custom_matching(name, version = 0, user_index = 0)
    mid = normalize_move_id(name)
    load_data
    list = ((@lookup_index || {})[[2, mid]] || []).select do |anim|
      src = source_of(anim)
      !(src.key?("runtimeEnabled") && !src["runtimeEnabled"])
    end
    return nil if list.empty?
    exact_version = list.select { |a| source_of(a)["version"].to_i == version.to_i }
    list = exact_version unless exact_version.empty?
    opposing = user_index.to_i.odd?
    side_matches = list.select { |a| !!source_of(a)["opposing"] == opposing }
    list = side_matches unless side_matches.empty?
    studio = list.reverse.find do |a|
      src = source_of(a)
      src["type"].to_s.downcase == "studio" || src["system"].to_s.downcase == "battle_animation_studio"
    end
    studio || list.find { |a| !source_of(a)["opposing"] } || list.first
  end

  def deep_number(value, fallback = 0.0)
    n = value.to_f
    n.finite? ? n : fallback
  rescue
    fallback
  end

   DEFAULT_BATTLER_WIDTH  = 96
   DEFAULT_BATTLER_HEIGHT = 96
   class Player
     def initialize(sprites, viewport, user, target, data)
      @sprites = sprites || {}
      @viewport = viewport
      @user = user
      @target = target || user
      @data = data || {}
      @frame = 0.0
      @previous_event_frame = nil
      @clock_start = monotonic_seconds
      @done = false
      @effect_sprites = {}
      @effect_bitmap_names = {}
      @procedural_bitmaps = {}
      @overlay_sprites = []
      @overlay_signatures = {}
      @emitter_sprites = {}
      @second_layer_sprites = {}
      @original = {}
      @viewport_origin = { :ox => (@viewport.ox rescue 0), :oy => (@viewport.oy rescue 0) }
      @camera_restore_states = []
      @camera_restore_count = 0
      @camera_state_buffer = { :x => 0.0, :y => 0.0, :zoom => 1.0, :rotation => 0.0, :cx => 0.0, :cy => 0.0, :cos => 1.0, :sin => 0.0 }
      @camera_seen = {}
      @emitter_particle_cache = {}
      @emitter_lifetime_cache = {}
      @emitter_frame_cache = {}
      @value_key_cache = {}
      @visible_key_cache = {}
      @position_key_cache = {}
      @graphic_switch_cache = {}
      @resolved_graphic_cache = {}
      @missing_graphics_logged = {}
      @missing_se_logged = {}
      @fx_cache = {}
      @emitter_command_cache = {}
      @pbs_command_cache = {}
      @preloaded_bitmaps = []
      @hidden_scene_states = {}
      @form_restore = {}
      @active_visual_pokemon = {}
      @battler_view_state = {}
      @applied_form_rule_ids = {}
      @anchor_cache = {}
      prepare_runtime_cache
      capture_original_battlers
      capture_scene_hide_targets
      create_effect_sprites
      prewarm_animation_assets
      prepare_emitter_caches
    end

    def animDone?; @done; end

    def duration
      [1.0, (@data["duration"] || 1).to_f].max
    end

    # Studio animations can use 20 FPS (PBS, legacy and static PictureEx code)
    # or the game's actual frame rate (resolved runtime captures). The battle
    # scene itself still updates at Graphics.frame_rate, so advance the Studio
    # timeline by the proper fractional amount instead of assuming 1 Studio
    # frame == 1 game update.
    def animation_fps
      [1.0, (@data["fps"] || 20).to_f].max
    end

    def game_fps
      fps = Graphics.frame_rate.to_f rescue 40.0
      [1.0, fps].max
    end

    # Use elapsed real time as the animation clock. Counting pbUpdate calls is
    # unreliable because battle/UI plugins can invoke updates at a cadence that
    # differs from Graphics.frame_rate, which made Studio animations play too fast.
    def monotonic_seconds
      if defined?(System) && System.respond_to?(:uptime)
        value = System.uptime.to_f rescue nil
        return value if value && value >= 0
      end
      if defined?(Process) && Process.respond_to?(:clock_gettime) && defined?(Process::CLOCK_MONOTONIC)
        value = Process.clock_gettime(Process::CLOCK_MONOTONIC).to_f rescue nil
        return value if value && value >= 0
      end
      if defined?(Graphics) && Graphics.respond_to?(:frame_count)
        return Graphics.frame_count.to_f / game_fps
      end
      Time.now.to_f rescue 0.0
    end

    def timeline_frame
      elapsed = monotonic_seconds - (@clock_start || monotonic_seconds)
      elapsed = 0.0 if elapsed < 0
      [elapsed * animation_fps, duration].min
    end

    def user_sprite
      @user ? @sprites["pokemon_#{@user.index}"] : nil
    end

    def target_sprite
      @target ? @sprites["pokemon_#{@target.index}"] : nil
    end

    def battler_for_side(side)
      side.to_sym == :user ? @user : @target
    end

    def sprite_for_side(side)
      side.to_sym == :user ? user_sprite : target_sprite
    end

    def form_rules_for(side)
      battlers = @data["battlers"]
      return [] if !battlers.is_a?(Hash)
      track = battlers[side.to_s]
      return [] if !track.is_a?(Hash)
      rules = track["formRules"]
      rules.is_a?(Array) ? rules : []
    rescue
      []
    end

    # Loads a battler bitmap using the signature available in the current battle
    # sprite implementation. DBK's Battle::Scene::BattlerSprite expects
    # (pokemon, battler, back), while vanilla/other renderers commonly expose
    # (pokemon, back). Keep the switch local and let the renderer build the
    # correct front/back bitmap (DBK bakes x3 Back / x2 Front into its wrapper).
    def set_battler_bitmap_view(side, pokemon, back)
      battler = battler_for_side(side)
      sprite = sprite_for_side(side)
      return false if !sprite || !pokemon
      if sprite.respond_to?(:setPokemonBitmap)
        begin
          sprite.setPokemonBitmap(pokemon, battler, !!back)
        rescue ArgumentError, TypeError
          sprite.setPokemonBitmap(pokemon, !!back)
        end
      elsif sprite.respond_to?(:pokemon=)
        sprite.pokemon = pokemon
      else
        return false
      end
      @battler_view_state[side.to_s] = !!back
      clear_battler_anchor_cache(side) if respond_to?(:clear_battler_anchor_cache)
      true
    rescue => e
      BattleAnimationStudioRuntime.log("battler view #{side} #{e.class}: #{e.message}")
      false
    end

    BAS_EDITOR_BACK_SCALE  = 3.0 unless const_defined?(:BAS_EDITOR_BACK_SCALE)
    BAS_EDITOR_FRONT_SCALE = 2.0  unless const_defined?(:BAS_EDITOR_FRONT_SCALE)

    # BAS mirrors the actual DBK battler footprint in the editor: Back x3 and
    # Front x2 by default. Because DBK bakes those multipliers into
    # DeluxeBitmapWrapper, the correction below becomes 1:1 for the defaults
    # and only compensates genuinely different per-view renderer profiles.
    def renderer_default_view_scale(back)
      if back && defined?(Settings::BACK_BATTLER_SPRITE_SCALE)
        n = Settings::BACK_BATTLER_SPRITE_SCALE.to_f rescue 1.0
        return n > 0 ? n : 1.0
      elsif !back && defined?(Settings::FRONT_BATTLER_SPRITE_SCALE)
        n = Settings::FRONT_BATTLER_SPRITE_SCALE.to_f rescue 1.0
        return n > 0 ? n : 1.0
      end
      1.0
    rescue
      1.0
    end

    def asymmetric_battler_renderer?
      return false if !defined?(Settings::BACK_BATTLER_SPRITE_SCALE) || !defined?(Settings::FRONT_BATTLER_SPRITE_SCALE)
      b = renderer_default_view_scale(true)
      f = renderer_default_view_scale(false)
      (b - f).abs > 0.001
    rescue
      false
    end

    def editor_view_profile_scale(back)
      return 1.0 if !asymmetric_battler_renderer?
      back ? BAS_EDITOR_BACK_SCALE : BAS_EDITOR_FRONT_SCALE
    end

    def battler_view_profile_correction(side, track, frame)
      return 1.0 if !asymmetric_battler_renderer?
      battler = battler_for_side(side)
      return 1.0 if !battler
      natural_back = (battler.index.to_i.even? rescue side.to_sym == :user)
      wanted_back = desired_battler_back?(side, track, frame)
      return 1.0 if wanted_back == natural_back
      natural_renderer = renderer_default_view_scale(natural_back)
      wanted_renderer = renderer_default_view_scale(wanted_back)
      natural_editor = editor_view_profile_scale(natural_back)
      wanted_editor = editor_view_profile_scale(wanted_back)
      return 1.0 if wanted_renderer <= 0 || natural_editor <= 0
      correction = (wanted_editor / natural_editor) * (natural_renderer / wanted_renderer)
      correction.finite? && correction > 0 ? correction : 1.0
    rescue
      1.0
    end

    def special_battler_view_for(clip)
      graphic = clip.is_a?(Hash) && clip["graphic"].is_a?(Hash) ? clip["graphic"] : {}
      source = graphic["source"].to_s
      return nil if !source.start_with?("battler-")
      side = source.include?("target") ? :target : :user
      battler = battler_for_side(side)
      natural_back = (battler.index.to_i.even? rescue side == :user)
      wanted_back = if source.include?("-front")
                      false
                    elsif source.include?("-back")
                      true
                    elsif source.include?("-opp")
                      !natural_back
                    else
                      natural_back
                    end
      [side, wanted_back]
    rescue
      nil
    end

    def apply_special_battler_profile_scale(sprite, clip)
      return if !sprite || !asymmetric_battler_renderer?
      info = special_battler_view_for(clip)
      return if !info
      back = info[1]
      renderer = renderer_default_view_scale(back)
      return if renderer <= 0
      # The special view bitmap is already resized by the battle renderer.
      # Convert that baked renderer scale back into BAS's editor presentation.
      correction = editor_view_profile_scale(back) / renderer
      sprite.zoom_x *= correction
      sprite.zoom_y *= correction
    rescue
    end

    def desired_battler_back?(side, track, frame)
      battler = battler_for_side(side)
      natural = (battler.index.to_i.even? rescue side.to_sym == :user)
      facing = sample_discrete_value(track, "facing", frame, 0).to_i rescue 0
      return true if facing == 1
      return false if facing == 2
      natural
    end

    def apply_battler_view(side, track, frame)
      battler = battler_for_side(side)
      sprite = sprite_for_side(side)
      return if !battler || !sprite || !track
      back = desired_battler_back?(side, track, frame)
      key = side.to_s
      return if @battler_view_state.key?(key) && @battler_view_state[key] == back
      pokemon = @active_visual_pokemon[key]
      pokemon ||= battler.respond_to?(:visiblePokemon) ? battler.visiblePokemon : nil
      pokemon ||= battler.pokemon if battler.respond_to?(:pokemon)
      set_battler_bitmap_view(side, pokemon, back) if pokemon
    rescue => e
      BattleAnimationStudioRuntime.log("apply battler view #{side} #{e.class}: #{e.message}")
    end

    def apply_visual_form(side, form)
      battler = battler_for_side(side)
      sprite = sprite_for_side(side)
      pokemon = battler && battler.respond_to?(:pokemon) ? battler.pokemon : nil
      return if !pokemon || !sprite
      visual = pokemon.clone rescue nil
      return if !visual
      return if !visual.respond_to?(:form=)
      visual.form = form.to_i
      key = side.to_s
      @form_restore[key] ||= pokemon
      @active_visual_pokemon[key] = visual
      clear_battler_anchor_cache(side)
      track = battler_track(side)
      back = track ? desired_battler_back?(side, track, @frame) : (battler.index.to_i.even? rescue side.to_sym == :user)
      set_battler_bitmap_view(side, visual, back)
    rescue => e
      BattleAnimationStudioRuntime.log("form #{side} #{e.class}: #{e.message}")
    end

    def apply_conditional_form_rules(previous_frame, current_frame)
      [:user, :target].each do |side|
        battler = battler_for_side(side)
        pokemon = battler && battler.respond_to?(:pokemon) ? battler.pokemon : nil
        next if !pokemon
        species = (pokemon.species.to_s.upcase rescue "")
        form_rules_for(side).each_with_index do |rule, i|
          next if !rule.is_a?(Hash)
          rid = "#{side}:#{i}:#{rule["frame"]}:#{rule["species"]}:#{rule["form"]}"
          next if @applied_form_rule_ids[rid]
          rf = rule["frame"].to_f
          crossed = previous_frame.nil? ? rf <= current_frame.to_f : (rf > previous_frame.to_f && rf <= current_frame.to_f)
          next if !crossed
          next if rule["species"].to_s.upcase != species
          apply_visual_form(side, rule["form"].to_i)
          @applied_form_rule_ids[rid] = true
        end
      end
    rescue => e
      BattleAnimationStudioRuntime.log("form rules #{e.class}: #{e.message}")
    end

    def restore_visual_forms
      @form_restore.each do |key, pokemon|
        side = key.to_sym
        battler = battler_for_side(side)
        next if !pokemon
        back = (battler.index.to_i.even? rescue side == :user)
        set_battler_bitmap_view(side, pokemon, back)
      end
      @active_visual_pokemon.clear
      @form_restore.clear
      clear_battler_anchor_cache
    rescue
      @active_visual_pokemon.clear
      @form_restore.clear
    end

    def restore_battler_views
      [:user, :target].each do |side|
        battler = battler_for_side(side)
        sprite = sprite_for_side(side)
        next if !battler || !sprite
        pokemon = battler.respond_to?(:visiblePokemon) ? battler.visiblePokemon : nil
        pokemon ||= battler.pokemon if battler.respond_to?(:pokemon)
        next if !pokemon
        natural_back = (battler.index.to_i.even? rescue side == :user)
        set_battler_bitmap_view(side, pokemon, natural_back)
      end
      @battler_view_state.clear
      clear_battler_anchor_cache
    rescue
      @battler_view_state.clear
    end

    def capture_sprite(sprite)
      return nil if !sprite
      { x: sprite.x, y: sprite.y, zoom_x: sprite.zoom_x, zoom_y: sprite.zoom_y,
        angle: sprite.angle, opacity: sprite.opacity, visible: sprite.visible,
        z: sprite.z, mirror: (sprite.mirror rescue false), tone: (sprite.tone.clone rescue nil),
        color: (sprite.color.clone rescue nil) }
    end

    def capture_original_battlers
      @original[:user] = capture_sprite(user_sprite)
      @original[:target] = capture_sprite(target_sprite)
    end

    def ui_sprite_key?(key)
      s = key.to_s
      return true if s =~ /\AdataBox_\d+\z/i
      return false if s =~ /\Apokemon_\d+\z/i
      return false if s =~ /\Abase_\d+\z/i
      return false if s =~ /shadow/i
      return true if s =~ /(message|msg|command|fight|target|party|bag|run|prompt|help|choice|window)/i
      false
    end

    def active_battler_indices
      [(@user.index rescue nil), (@target.index rescue nil)].compact.map { |v| v.to_i }.uniq
    end

    def adjacent_sprite_key?(key)
      s = key.to_s
      if s =~ /\A(?:pokemon|shadow)_(\d+)\z/i
        idx = $1.to_i
        return !active_battler_indices.include?(idx)
      end
      false
    end

    def capture_scene_hide_targets
      @hidden_scene_states.clear
      hide_boxes = !!@data["hidesDataBoxes"]
      hide_adjacents = !!@data["hidesAdjacents"]
      return if !hide_boxes && !hide_adjacents
      (@sprites || {}).each do |key, sprite|
        next if !sprite
        key_s = key.to_s
        kind = nil
        kind = :ui if hide_boxes && ui_sprite_key?(key_s)
        kind = :adjacent if !kind && hide_adjacents && adjacent_sprite_key?(key_s)
        next if !kind
        @hidden_scene_states[key_s] = {
          :kind => kind,
          :visible => (sprite.visible rescue true),
          :opacity => (sprite.opacity rescue 255)
        }
      end
      apply_scene_hide_progress(0.0)
    rescue
    end

    def scene_hide_fade_span
      @scene_hide_fade_span ||= begin
        dur = [1.0, duration.to_f].max
        [[dur * 0.12, 3.0].max, 8.0].min
      end
    end

    def hidden_mix_for_frame(frame_value)
      return 0.0 if @hidden_scene_states.empty?
      span = scene_hide_fade_span
      return 1.0 if span <= 0.0
      dur = [1.0, duration.to_f].max
      mix = [[frame_value.to_f / span, 1.0].min, 0.0].max
      tail = [[(dur - frame_value.to_f) / span, 1.0].min, 0.0].max
      [mix, tail].min
    end

    def apply_scene_hide_progress(frame_value = @frame)
      return if @hidden_scene_states.empty?
      mix = hidden_mix_for_frame(frame_value)
      (@hidden_scene_states || {}).each do |key, st|
        sprite = @sprites[key]
        next if !sprite
        base_visible = st[:visible] != false
        base_opacity = (st[:opacity] || 255).to_f
        opacity = (base_opacity * (1.0 - mix)).round
        sprite.opacity = opacity if sprite.respond_to?(:opacity=)
        sprite.visible = (base_visible && opacity > 0) if sprite.respond_to?(:visible=)
      end
    rescue
    end

    def restore_scene_visibility
      @hidden_scene_states.each do |key, st|
        sprite = @sprites[key]
        next if !sprite
        sprite.visible = st[:visible] if sprite.respond_to?(:visible=)
        sprite.opacity = st[:opacity] if sprite.respond_to?(:opacity=)
      end
      @hidden_scene_states.clear
    rescue
    end

    def restore_sprite(sprite, st)
      return if !sprite || !st
      st.each do |key, value|
        next if [:tone, :color].include?(key)
        writer = "#{key}="
        sprite.send(writer, value) if sprite.respond_to?(writer)
      end
      sprite.tone = st[:tone] if st[:tone] && sprite.respond_to?(:tone=)
      sprite.color = st[:color] if st[:color] && sprite.respond_to?(:color=)
    rescue
    end

    def dispose
      restore_camera!
      restore_visual_forms
      restore_battler_views
      restore_sprite(user_sprite, @original[:user])
      restore_sprite(target_sprite, @original[:target]) if target_sprite != user_sprite
      restore_scene_visibility
      @effect_sprites.each_value { |s| s.dispose if s && !s.disposed? }
      @emitter_sprites.each_value { |pool| pool.each { |s| s.dispose if s && !s.disposed? } }
      @second_layer_sprites.each_value { |s| s.dispose if s && !s.disposed? }
      @overlay_sprites.each { |s| s.dispose if s && !s.disposed? }
      @procedural_bitmaps.each_value { |b| b.dispose if b && !b.disposed? }
      # RPG::Cache owns prewarmed bitmaps. Do not dispose shared cache entries
      # here; doing so forced later animations to decode them again and could
      # invalidate a bitmap still referenced elsewhere.
      @effect_sprites.clear
      @emitter_sprites.clear
      @second_layer_sprites.clear
      @overlay_sprites.clear
      @procedural_bitmaps.clear
      @preloaded_bitmaps.clear
      begin
        @viewport.ox = @viewport_origin[:ox] if @viewport && @viewport.respond_to?(:ox=)
        @viewport.oy = @viewport_origin[:oy] if @viewport && @viewport.respond_to?(:oy=)
      rescue
      end
    end

    def prepare_runtime_cache
      @tracks_cache = @data["tracks"].is_a?(Array) ? @data["tracks"] : []
      @clips_cache = []
      @tracks_cache.each do |track|
        next if !track.is_a?(Hash) || !track["clips"].is_a?(Array)
        track["clips"].each { |clip| @clips_cache << clip if clip.is_a?(Hash) }
      end
      events = @data["events"].is_a?(Array) ? @data["events"] : []
      @se_events = events.select { |ev| ev.is_a?(Hash) && ev["type"].to_s.downcase == "se" }.sort_by { |ev| (ev["frame"] || 0).to_f }
      @screen_events = events.select { |ev| ev.is_a?(Hash) && ["screen_black_envelope", "screen_white_envelope", "screen_flash", "flash", "darken"].include?(ev["type"].to_s) }
      @shake_events = events.select { |ev| ev.is_a?(Hash) && ev["type"].to_s == "screen_shake" }
    end

    def tracks
      @tracks_cache || []
    end

    def clips
      @clips_cache || []
    end

    def battler_track(side)
      h = @data["battlers"]
      h.is_a?(Hash) ? h[side.to_s] : nil
    end

    def create_battler_view(side, back)
      battler = side == :target ? @target : @user
      return nil if !battler
      begin
        side_size = battler.battle.pbSideSize(battler.index) rescue 1
        sprite = Battle::Scene::BattlerSprite.new(@viewport, side_size, battler.index, [])
        pkmn = battler.respond_to?(:visiblePokemon) ? battler.visiblePokemon : nil
        pkmn ||= battler.pokemon if battler.respond_to?(:pokemon)
        begin
          sprite.setPokemonBitmap(pkmn, battler, !!back)
        rescue ArgumentError, TypeError
          sprite.setPokemonBitmap(pkmn, !!back) if pkmn
        end
        # Ensure default size if the battler sprite ended up without a bitmap.
        if !sprite.bitmap || sprite.bitmap.disposed? || sprite.bitmap.width == 0 || sprite.bitmap.height == 0
          sprite.bitmap = Bitmap.new(DEFAULT_BATTLER_WIDTH, DEFAULT_BATTLER_HEIGHT)
          sprite.ox = DEFAULT_BATTLER_WIDTH / 2
          sprite.oy = DEFAULT_BATTLER_HEIGHT
        end
        return sprite
      rescue => e
        BattleAnimationStudioRuntime.log("create battler view #{side}/#{back ? 'back' : 'front'} #{e.class}: #{e.message}")
        return nil
      end
    end

    def setup_mask(sprite, clip)
      return if !sprite || !sprite.respond_to?(:pattern=)
      pbs = clip["pbs"].is_a?(Hash) ? clip["pbs"] : {}
      graphic = clip["graphic"].is_a?(Hash) ? clip["graphic"] : {}
      mask = (pbs["maskGraphic"] || graphic["maskGraphic"] || "").to_s
      return if mask.empty? || !defined?(RPG::Cache)
      sprite.pattern = RPG::Cache.load_bitmap("Graphics/Battle animations/", mask)
    rescue => e
      BattleAnimationStudioRuntime.log("mask #{e.class}: #{e.message}")
    end

    def create_effect_sprites
      clips.each do |clip|
        id = clip["id"].to_s
        graphic = clip["graphic"].is_a?(Hash) ? clip["graphic"] : {}
        source = graphic["source"].to_s
        sprite = nil
        if source.start_with?("battler-")
          side = source.include?("target") ? :target : :user
          battler = side == :target ? @target : @user
          natural_back = (battler.index.to_i.even? rescue side == :user)
          wanted_back = if source.include?("-front")
                          false
                        elsif source.include?("-back")
                          true
                        elsif source.include?("-opp")
                          !natural_back
                        else
                          natural_back
                        end
          # Build the requested view with the real battle renderer. This is
          # essential for DBK, whose back/front bitmap scales are different
          # (commonly Back x3 and Front x2) and are baked into the bitmap.
          sprite = create_battler_view(side, wanted_back)
          if !sprite
            original = side == :target ? target_sprite : user_sprite
            if original
              sprite = Sprite.new(@viewport)
              sprite.bitmap = original.bitmap
              sprite.src_rect.set(original.src_rect.x, original.src_rect.y, original.src_rect.width, original.src_rect.height) if original.respond_to?(:src_rect) && original.src_rect
              sprite.ox = original.ox; sprite.oy = original.oy
              sprite.mirror = original.mirror if sprite.respond_to?(:mirror=) && original.respond_to?(:mirror)
            end
          end
        else
          sprite = graphic["procedural"] ? Sprite.new(@viewport) : IconSprite.new(0, 0, @viewport)
        end
        next if !sprite
        sprite.visible = false
        setup_mask(sprite, clip)
        @effect_sprites[id] = sprite
      end
    end

    def preload_bitmap_path(path)
      return if !defined?(RPG::Cache)
      name = path.to_s.gsub("\\", "/")
      return if name.empty?
      slash = name.rindex("/")
      folder = slash ? name[0..slash] : ""
      filename = slash ? name[(slash + 1)..-1] : name
      return if filename.nil? || filename.empty?
      RPG::Cache.load_bitmap(folder, filename)
    rescue => e
      BattleAnimationStudioRuntime.log("preload #{name}: #{e.class}: #{e.message}")
    end

    def runtime_graphic_candidates(graphic, raw = nil)
      graphic = {} if !graphic.is_a?(Hash)
      values = []
      add_value = proc do |value|
        v = value.to_s.tr("\\", "/").sub(/^\/+/, "").strip
        values << v if !v.empty? && !values.include?(v)
      end
      add_value.call(raw)
      add_value.call(graphic["projectPath"])
      (graphic["assetCandidates"] || []).each { |v| add_value.call(v) }
      add_value.call(graphic["relativeHint"])
      add_value.call(graphic["name"])
      folder = graphic["folder"].to_s.tr("\\", "/").sub(/^Graphics\//i, "").sub(/^\/+|\/+$/, "")
      roots = [
        "Graphics/Animations",
        "Graphics/Battle animations",
        "Graphics/EBDX/Animations/Moves",
        "Graphics/EBDX/Animations/Common",
        "Graphics/Battle",
        "Graphics/BattleParticlesAnimations"
      ]
      candidates = []
      values.each do |value|
        if value =~ /^Graphics\//i
          candidates << value
          next
        end
        roots.each { |root| candidates << "#{root}/#{value}" }
        candidates << "Graphics/#{folder}/#{value}" if !folder.empty?
      end
      candidates.map! { |v| v.gsub(/\/{2,}/, "/") }
      candidates.uniq
    rescue
      []
    end

    def runtime_graphic_exists?(path)
      return false if path.nil? || path.to_s.empty?
      if defined?(pbResolveBitmap)
        resolved = pbResolveBitmap(path.to_s) rescue nil
        return true if resolved && !resolved.to_s.empty?
      end
      return true if File.exist?(path.to_s)
      [".png", ".bmp", ".jpg", ".jpeg", ".gif"].each do |ext|
        return true if File.exist?(path.to_s + ext)
      end
      false
    rescue
      false
    end

    def resolve_runtime_graphic(clip, raw = nil)
      graphic = clip["graphic"].is_a?(Hash) ? clip["graphic"] : {}
      key = [clip.object_id, raw.to_s]
      cached = @resolved_graphic_cache[key]
      return cached if cached
      candidates = runtime_graphic_candidates(graphic, raw)
      resolved = candidates.find { |candidate| runtime_graphic_exists?(candidate) }
      if !resolved && !candidates.empty?
        label = candidates.first
        if !@missing_graphics_logged[label]
          @missing_graphics_logged[label] = true
          BattleAnimationStudioRuntime.log("Graphic not found for #{clip['name'] || clip['id']}: #{candidates.join(' | ')}")
        end
      end
      @resolved_graphic_cache[key] = (resolved || "")
    rescue
      ""
    end

    # Load the graphics used by this animation before its first rendered frame.
    # Disk decode during a MoveGraphic/first particle was causing visible hitches
    # in battle. References are held only for this Player and released on dispose.
    def prewarm_animation_assets
      names = {}
      clips.each do |clip|
        graphic = clip["graphic"].is_a?(Hash) ? clip["graphic"] : {}
        if graphic["procedural"]
          sprite = @effect_sprites[clip["id"].to_s]
          update_bitmap(sprite, clip, 0) if sprite
        elsif !graphic["source"].to_s.start_with?("battler-")
          base = resolve_runtime_graphic(clip)
          names[base] = true if !base.empty?
          switches = clip["graphicSwitches"].is_a?(Array) ? clip["graphicSwitches"] : []
          switches.each do |sw|
            name = resolve_runtime_graphic(clip, sw["value"])
            names[name] = true if !name.empty?
          end
        end
        pbs = clip["pbs"].is_a?(Hash) ? clip["pbs"] : {}
        mask = pbs["maskGraphic"].to_s
        names["Graphics/Battle animations/#{mask}"] = true if !mask.empty?
      end
      names.each_key { |name| preload_bitmap_path(name) }
      # Give each template its first bitmap now as well, so the first active
      # frame only changes properties/source rect and doesn't decode a file.
      clips.each do |clip|
        sprite = @effect_sprites[clip["id"].to_s]
        update_bitmap(sprite, clip, (clip["startFrame"] || 0).to_f) if sprite
      end
    rescue => e
      BattleAnimationStudioRuntime.log("prewarm #{e.class}: #{e.message}")
    end

    def prepare_emitter_caches
      clips.each do |clip|
        next if emitter_type(clip) == "none"
        cached_emitter_particles(clip)
        emitter_particle_lifetime(clip)
      end
    rescue => e
      BattleAnimationStudioRuntime.log("emitter precompute #{e.class}: #{e.message}")
    end

    def ease01(t, mode)
      x = [[t.to_f, 0.0].max, 1.0].min
      case mode.to_s
      when "linear" then x
      when "ease_in" then x * x
      when "ease_out" then 1.0 - ((1.0 - x) * (1.0 - x))
      else
        x < 0.5 ? 2.0 * x * x : 1.0 - (((-2.0 * x + 2.0) ** 2) / 2.0)
      end
    end

    def cached_value_keys(obj, prop)
      key = [obj.object_id, prop.to_s]
      @value_key_cache[key] ||= begin
        raw = (((obj["valueKeys"] || {})[prop] rescue nil) || [])
        raw.is_a?(Array) ? raw.sort_by { |k| (k["frame"] || 0).to_f } : []
      end
    end

    def sample_value(obj, prop, frame, fallback)
      keys = cached_value_keys(obj, prop)
      base = ((obj["visual"] || {})[prop] rescue nil)
      base = fallback if base.nil?
      return base.to_f if keys.empty?
      return keys.first["value"].to_f if frame <= keys.first["frame"].to_f
      return keys.last["value"].to_f if frame >= keys.last["frame"].to_f
      lo = 0; hi = keys.length - 1
      while lo + 1 < hi
        mid = (lo + hi) / 2
        if keys[mid]["frame"].to_f <= frame
          lo = mid
        else
          hi = mid
        end
      end
      a = keys[lo]; b = keys[hi]
      span = [0.0001, b["frame"].to_f - a["frame"].to_f].max
      t = ease01((frame - a["frame"].to_f) / span, a["easing"])
      a["value"].to_f + ((b["value"].to_f - a["value"].to_f) * t)
    rescue
      fallback.to_f
    end

    # Frame selection, src_rect and similar properties are discrete in the
    # Studio. Interpolating them produces in-between cells and visual tearing.
    def sample_discrete_value(obj, prop, frame, fallback)
      keys = cached_value_keys(obj, prop)
      base = ((obj["visual"] || {})[prop] rescue nil)
      base = fallback if base.nil?
      return base.to_f if keys.empty?
      f = frame.to_f.floor + 0.000001
      return keys.first["value"].to_f if f <= keys.first["frame"].to_f
      return keys.last["value"].to_f if f >= keys.last["frame"].to_f
      lo = 0; hi = keys.length - 1
      while lo + 1 < hi
        mid = (lo + hi) / 2
        if keys[mid]["frame"].to_f <= f
          lo = mid
        else
          hi = mid
        end
      end
      keys[lo]["value"].to_f
    rescue
      fallback.to_f
    end

    def sample_visible(obj, frame)
      keys = @visible_key_cache[obj.object_id] ||= begin
        raw = obj["visibleKeys"] || []
        raw.is_a?(Array) ? raw.sort_by { |k| (k["frame"] || 0).to_f } : []
      end
      base = obj["enabled"] != false
      return base if keys.empty? || frame < keys.first["frame"].to_f
      return !!keys.last["value"] if frame >= keys.last["frame"].to_f
      lo = 0; hi = keys.length - 1
      while lo + 1 < hi
        mid = (lo + hi) / 2
        if keys[mid]["frame"].to_f <= frame
          lo = mid
        else
          hi = mid
        end
      end
      !!keys[lo]["value"]
    rescue
      true
    end

    # Returns the natural battle view for a battler slot. This is intentionally
    # separate from the view BAS may force during an animation.
    def natural_battler_back?(side)
      battler = battler_for_side(side)
      return side.to_sym == :user if !battler
      battler.index.to_i.even?
    rescue
      side.to_sym == :user
    end

    def visual_pokemon_for_side(side)
      key = side.to_s
      active = @active_visual_pokemon[key] rescue nil
      return active if active
      battler = battler_for_side(side)
      return nil if !battler
      pkmn = battler.respond_to?(:visiblePokemon) ? (battler.visiblePokemon rescue nil) : nil
      pkmn ||= (battler.pokemon rescue nil) if battler.respond_to?(:pokemon)
      pkmn
    rescue
      nil
    end

    # DBK's BattlerSprite#pbSetPosition applies metrics by battler index, even
    # when setPokemonBitmap is explicitly asked for the opposite view. BAS
    # therefore keeps the scene/plugin's settled natural position and adds only
    # the metric delta for the requested Back/Front view. This also preserves
    # offsets introduced by custom battle scenes.
    def battler_metric_offset_for_view(side, back)
      pkmn = visual_pokemon_for_side(side)
      return [0.0, 0.0] if !pkmn || !defined?(GameData::SpeciesMetrics)
      species = (pkmn.species rescue nil)
      form = (pkmn.form rescue 0).to_i
      female = (pkmn.respond_to?(:female?) ? (pkmn.female? rescue false) : false)
      metrics = nil
      begin
        metrics = GameData::SpeciesMetrics.get_species_form(species, form, female)
      rescue ArgumentError
        metrics = GameData::SpeciesMetrics.get_species_form(species, form) rescue nil
      end
      return [0.0, 0.0] if !metrics
      raw = back ? (metrics.back_sprite rescue nil) : (metrics.front_sprite rescue nil)
      raw = [0, 0] if !raw.is_a?(Array)
      x = (raw[0] || 0).to_f * 2.0
      y = (raw[1] || 0).to_f * 2.0
      y -= (metrics.front_sprite_altitude rescue 0).to_f * 2.0 if !back
      [x, y]
    rescue
      [0.0, 0.0]
    end

    def clear_battler_anchor_cache(side = nil)
      if !@anchor_cache
        @anchor_cache = {}
        return
      end
      if side.nil?
        @anchor_cache.clear
      else
        target = side.to_sym
        @anchor_cache.keys.each do |key|
          @anchor_cache.delete(key) if key.is_a?(Array) && key[0].to_sym == target
        end
      end
    rescue
      @anchor_cache.clear if @anchor_cache
    end

    def base_anchor(side, focus = false)
      track = battler_track(side)
      wanted_back = track ? desired_battler_back?(side, track, @frame) : natural_battler_back?(side)
      visual = visual_pokemon_for_side(side)
      form_key = visual ? "#{(visual.species rescue '')}:#{(visual.form rescue 0)}" : ""
      key = [side, focus ? 1 : 0, wanted_back ? 1 : 0, form_key]
      cached = @anchor_cache[key]
      return cached if cached
      sprite = side == :target ? target_sprite : user_sprite
      original = @original[side]
      ret = if !sprite || !original
              [Graphics.width / 2.0, Graphics.height / 2.0]
            else
              x = original[:x].to_f
              y = original[:y].to_f
              natural_back = natural_battler_back?(side)
              if wanted_back != natural_back
                natural_metric = battler_metric_offset_for_view(side, natural_back)
                wanted_metric = battler_metric_offset_for_view(side, wanted_back)
                x += wanted_metric[0] - natural_metric[0]
                y += wanted_metric[1] - natural_metric[1]
              end
              if focus
                # Match the actual rendered bitmap used by gameplay. DBK's
                # wrapper already contains x3/x2 (or a per-species scale), so
                # this gives the exact visual centre without applying scale twice.
                h = (sprite.bitmap && !sprite.bitmap.disposed?) ? sprite.bitmap.height.to_f : 80.0
                y -= h / 2.0
              end
              [x, y]
            end
      @anchor_cache[key] = ret
      ret
    rescue
      [Graphics.width / 2.0, Graphics.height / 2.0]
    end

    def script_anchor(side)
      key = [side, 2]
      cached = @anchor_cache[key]
      return cached if cached
      battler = side == :target ? @target : @user
      if !battler
        ret = base_anchor(side, false)
      else
        size = battler.battle.pbSideSize(battler.index) rescue 1
        p = Battle::Scene.pbBattlerPosition(battler.index, size) rescue Battle::Scene.pbBattlerPosition(battler.index)
        ret = [p[0].to_f, p[1].to_f]
      end
      @anchor_cache[key] = ret
      ret
    rescue
      base_anchor(side, false)
    end

    def responsive_scale
      scene = @data["scene"].is_a?(Hash) ? @data["scene"] : {}
      return [1.0, 1.0] if scene["responsive"] == false
      rw = scene["referenceWidth"].to_f
      rh = scene["referenceHeight"].to_f
      return [1.0, 1.0] if rw <= 0 || rh <= 0
      [Graphics.width.to_f / rw, Graphics.height.to_f / rh]
    rescue
      [1.0, 1.0]
    end

    def resolve_point(point)
      p = point.is_a?(Hash) ? point : {}
      anchor = p["anchor"].to_s
      ox = p["offsetX"].to_f; oy = p["offsetY"].to_f
      x = p["x"].to_f; y = p["y"].to_f
      if anchor.start_with?("pbs:") && !anchor.include?("_and_")
        idx = anchor.include?("target") ? (@target.index rescue 1) : (@user.index rescue 0)
        if idx.to_i.odd?
          x *= -1 if p["foeInvertX"]
          y *= -1 if p["foeInvertY"]
        end
      end
      case anchor
      when "user", "pbs:user"
        a = base_anchor(:user, true); [a[0] + x + ox, a[1] + y + oy]
      when "pbs:user_position"
        a = base_anchor(:user, true); s = script_anchor(:user); [a[0] + x + ox, s[1] + y + oy]
      when "target", "pbs:target"
        a = base_anchor(:target, true); [a[0] + x + ox, a[1] + y + oy]
      when "pbs:target_position"
        a = base_anchor(:target, true); s = script_anchor(:target); [a[0] + x + ox, s[1] + y + oy]
      when "user_battler"
        a = base_anchor(:user, false); [a[0] + ox, a[1] + oy]
      when "target_battler"
        a = base_anchor(:target, false); [a[0] + ox, a[1] + oy]
      when "user_target", "pbs:user_and_target"
        u = base_anchor(:user, true); t = base_anchor(:target, true)
        [u[0] + ((x / 200.0) * (t[0] - u[0])).to_i + ox,
         u[1] + ((y / -200.0) * (t[1] - u[1])).to_i + oy]
      when "pbs:user_position_and_target"
        u = base_anchor(:user, true); t = base_anchor(:target, true); us = script_anchor(:user)
        [u[0] + ((x / 200.0) * (t[0] - u[0])).to_i + ox,
         us[1] + ((y / -200.0) * (t[1] - us[1])).to_i + oy]
      when "pbs:user_and_target_position"
        u = base_anchor(:user, true); t = base_anchor(:target, true); ts = script_anchor(:target)
        [u[0] + ((x / 200.0) * (t[0] - u[0])).to_i + ox,
         u[1] + ((y / -200.0) * (ts[1] - u[1])).to_i + oy]
      when "pbs:user_position_and_target_position"
        u = base_anchor(:user, true); t = base_anchor(:target, true); us = script_anchor(:user); ts = script_anchor(:target)
        [u[0] + ((x / 200.0) * (t[0] - u[0])).to_i + ox,
         us[1] + ((y / -200.0) * (ts[1] - us[1])).to_i + oy]
      when "pbs:user_side_foreground", "pbs:user_side_background"
        s = script_anchor(:user); [s[0] + x + ox, s[1] + y + oy]
      when "pbs:target_side_foreground", "pbs:target_side_background"
        s = script_anchor(:target); [s[0] + x + ox, s[1] + y + oy]
      else
        if anchor.start_with?("pbs:") || anchor.empty? || anchor == "screen"
          rs = responsive_scale
          [(x + ox) * rs[0], (y + oy) * rs[1]]
        else
          [x + ox, y + oy]
        end
      end
    end

    def pbs_battler_baseline_offset(obj)
      imported = obj.is_a?(Hash) ? (obj["imported"] || {}) : {}
      return 0.0 if obj["type"].to_s != "battler" || imported["format"].to_s != "pbs" || !imported["pbsBattlerParticle"]
      side = obj["side"].to_s == "target" ? :target : :user
      sprite = side == :target ? target_sprite : user_sprite
      original = @original[side] || {}
      return 0.0 if !sprite || !sprite.bitmap || sprite.bitmap.disposed?
      sprite.bitmap.height.to_f / 2.0
    rescue
      0.0
    end

    def resolve_object_point(obj, point)
      ret = resolve_point(point)
      imported = obj.is_a?(Hash) ? (obj["imported"] || {}) : {}
      if obj["type"].to_s == "battler" && imported["pbsBattlerParticle"] && point.is_a?(Hash) && point["anchor"].to_s.start_with?("pbs:")
        ret = [ret[0], ret[1] + pbs_battler_baseline_offset(obj)]
      end
      ret
    end

    def sample_position(obj, frame)
      keys = @position_key_cache[obj.object_id] ||= begin
        raw = obj["positionKeys"] || []
        raw.is_a?(Array) ? raw.sort_by { |k| (k["frame"] || 0).to_f } : []
      end
      return [Graphics.width / 2.0, Graphics.height / 2.0] if keys.empty?
      return resolve_object_point(obj, keys.first["point"]) if frame <= keys.first["frame"].to_f
      return resolve_object_point(obj, keys.last["point"]) if frame >= keys.last["frame"].to_f
      lo = 0; hi = keys.length - 1
      while lo + 1 < hi
        mid = (lo + hi) / 2
        if keys[mid]["frame"].to_f <= frame
          lo = mid
        else
          hi = mid
        end
      end
      a = keys[lo]; b = keys[hi]
      pa = resolve_object_point(obj, a["point"]); pb = resolve_object_point(obj, b["point"])
      span = [0.0001, b["frame"].to_f - a["frame"].to_f].max
      t = ease01((frame - a["frame"].to_f) / span, a["easing"])
      [pa[0] + (pb[0] - pa[0]) * t, pa[1] + (pb[1] - pa[1]) * t]
    rescue
      [Graphics.width / 2.0, Graphics.height / 2.0]
    end

    def latest_graphic(clip, frame)
      raw_value = nil
      switches = @graphic_switch_cache[clip.object_id] ||= begin
        raw = clip["graphicSwitches"] || []
        raw.is_a?(Array) ? raw.sort_by { |sw| (sw["frame"] || 0).to_f } : []
      end
      switches.each do |sw|
        break if sw["frame"].to_f > frame
        raw_value = sw["value"].to_s unless sw["value"].to_s.empty?
      end
      resolve_runtime_graphic(clip, raw_value)
    end

    def runtime_color(raw, fallback = Color.new(255,255,255,255))
      return fallback if raw.nil?
      if raw.is_a?(Hash)
        r = raw["r"] || raw[:r] || 0; g = raw["g"] || raw[:g] || 0; b = raw["b"] || raw[:b] || 0; a = raw["a"] || raw[:a] || 255
        return Color.new(r.to_i, g.to_i, b.to_i, a.to_i)
      end
      m = raw.to_s.match(/rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)(?:\s*,\s*([\d.]+))?\s*\)/i)
      return fallback if !m
      alpha = m[4] ? m[4].to_f : 255.0
      alpha *= 255.0 if alpha <= 1.0
      Color.new(m[1].to_i, m[2].to_i, m[3].to_i, [[alpha.round,0].max,255].min)
    rescue
      fallback
    end

    def draw_runtime_circle(bitmap, cx, cy, rx, ry, color, hollow = false, line_width = nil)
      rx = [1, rx.to_i].max; ry = [1, ry.to_i].max
      thickness_px = [[(line_width || [rx, ry].min * 0.12).to_f.round, 1].max, [rx, ry].min].min
      inner_rx = [0, rx - thickness_px].max
      inner_ry = [0, ry - thickness_px].max
      (-ry..ry).each do |yy|
        ny = yy.to_f / ry
        next if ny.abs > 1.0
        span = (rx * Math.sqrt([0.0, 1.0 - ny * ny].max)).round
        if !hollow || inner_rx <= 0 || inner_ry <= 0 || yy.abs >= inner_ry
          bitmap.fill_rect(cx - span, cy + yy, span * 2 + 1, 1, color)
        else
          iny = yy.to_f / inner_ry
          inner_span = (inner_rx * Math.sqrt([0.0, 1.0 - iny * iny].max)).round
          left_w = [1, span - inner_span].max
          bitmap.fill_rect(cx - span, cy + yy, left_w, 1, color)
          bitmap.fill_rect(cx + inner_span + 1, cy + yy, left_w, 1, color)
        end
      end
    rescue
    end

    def build_procedural_bitmap(graphic)
      w = [[(graphic["proceduralW"] || 16).to_i, 1].max, 2048].min
      h = [[(graphic["proceduralH"] || 16).to_i, 1].max, 2048].min
      bmp = Bitmap.new(w, h)
      kind = graphic["procedural"].to_s
      case kind
      when "composite"
        (graphic["proceduralLayers"] || []).each do |layer|
          next if !layer.is_a?(Hash)
          bmp.fill_rect((layer["x"] || 0).to_i, (layer["y"] || 0).to_i, (layer["w"] || 0).to_i, (layer["h"] || 0).to_i, runtime_color(layer["color"]))
        end
      when "spotlight"
        # Rasterized cone with alpha falloff. Built once, so it doesn't affect playback FPS.
        h.times do |yy|
          t = h <= 1 ? 1.0 : yy.to_f / (h - 1)
          half = ((w * 0.07) + (w * 0.43 * t)).round
          alpha = (170 * (1.0 - t)).round
          bmp.fill_rect((w / 2) - half, yy, half * 2, 1, Color.new(255,255,255,alpha))
        end
      when "circle"
        color = runtime_color(graphic["proceduralColor"])
        draw_runtime_circle(bmp, w / 2, h / 2, w / 2, h / 2, color, !!graphic["proceduralHollow"], graphic["proceduralLineWidth"])
      else
        bmp.fill_rect(0, 0, w, h, runtime_color(graphic["proceduralColor"]))
      end
      bmp
    rescue
      nil
    end

    def update_bitmap(sprite, clip, frame)
      return if !sprite
      graphic = clip["graphic"].is_a?(Hash) ? clip["graphic"] : {}
      id = clip["id"].to_s
      if graphic["procedural"]
        signature = [graphic["procedural"], graphic["proceduralW"], graphic["proceduralH"], graphic["proceduralColor"], graphic["proceduralHollow"], graphic["proceduralLineWidth"], graphic["proceduralLayers"]].inspect
        return if @effect_bitmap_names[id] == signature && sprite.bitmap && !sprite.bitmap.disposed?
        old = @procedural_bitmaps[id]
        old.dispose if old && !old.disposed?
        bmp = build_procedural_bitmap(graphic)
        return if !bmp
        sprite.bitmap = bmp
        @procedural_bitmaps[id] = bmp
        @effect_bitmap_names[id] = signature
        return
      end
      return if !sprite.respond_to?(:setBitmap)
      name = latest_graphic(clip, frame)
      return if name.empty? || @effect_bitmap_names[id] == name
      sprite.setBitmap(name)
      @effect_bitmap_names[id] = name
    rescue
    end


    def dynamic_code_grid(bitmap)
      width = bitmap.width.to_i; height = bitmap.height.to_i
      return [1, 1, [width, 1].max, [height, 1].max, 1] if width <= 0 || height <= 0 || width == height
      if width >= height * 2 && width % height == 0 && width / height <= 16
        cols = width / height
        return [cols, 1, height, height, cols]
      end
      if height >= width * 2 && height % width == 0 && height / width <= 16
        rows = height / width
        return [1, rows, width, width, rows]
      end
      best = [1, 1, width, height, 1]
      score = 1.0 / 0.0
      (1..8).each do |cols|
        next if width % cols != 0
        (1..8).each do |rows|
          next if height % rows != 0 || (cols == 1 && rows == 1)
          fw = width / cols; fh = height / rows
          next if fw < 12 || fh < 12
          ratio = fw.to_f / fh
          pen = Math.log([0.0001, ratio.abs].max).abs + [0, cols * rows - 16].max + ((fw * fh < 22 * 22) ? 10 : 0)
          if pen < score
            score = pen
            best = [cols, rows, fw, fh, cols * rows]
          end
        end
      end
      best
    rescue
      [1, 1, [bitmap.width.to_i, 1].max, [bitmap.height.to_i, 1].max, 1]
    end

    def stable_seed(text)
      h = 2166136261
      text.to_s.each_byte do |b|
        h ^= b
        h = (h * 16777619) & 0xffffffff
      end
      h
    rescue
      1
    end

    def seeded_random(seed)
      state = seed.to_i & 0xffffffff
      state = 0x6D2B79F5 if state == 0
      proc do
        state ^= (state << 13) & 0xffffffff
        state ^= (state >> 17)
        state ^= (state << 5) & 0xffffffff
        state &= 0xffffffff
        state.to_f / 4294967296.0
      end
    end

    def apply_source_frame(sprite, clip, frame, random_seed = nil, forced_frame = nil)
      return if !sprite || !sprite.respond_to?(:src_rect) || !sprite.src_rect || !sprite.bitmap || sprite.bitmap.disposed?
      graphic = clip["graphic"].is_a?(Hash) ? clip["graphic"] : {}
      # Battler proxy/clones already inherit the live battler src_rect. Only an
      # explicit src_rect timeline is allowed to replace it.
      special_battler = graphic["source"].to_s.start_with?("battler-")
      custom_w = sample_discrete_value(clip, "srcW", frame, 0).round
      custom_h = sample_discrete_value(clip, "srcH", frame, 0).round
      if custom_w > 0 && custom_h > 0
        sx = sample_discrete_value(clip, "srcX", frame, 0).round
        sy = sample_discrete_value(clip, "srcY", frame, 0).round
        sw = [[custom_w, 1].max, sprite.bitmap.width - [sx, 0].max].min
        sh = [[custom_h, 1].max, sprite.bitmap.height - [sy, 0].max].min
        sprite.src_rect.set([sx, 0].max, [sy, 0].max, [sw, 1].max, [sh, 1].max)
        return
      end
      return if special_battler
      width = sprite.bitmap.width.to_i; height = sprite.bitmap.height.to_i
      return if width <= 0 || height <= 0
      fr = forced_frame.nil? ? [0, sample_discrete_value(clip, "graphicFrame", frame, (graphic["frame"] || 0)).round].max : [forced_frame.to_i, 0].max
      random_max = ((clip["pbs"] || {})["randomFrameMax"] rescue nil).to_i
      if forced_frame.nil? && random_seed && random_max > 0
        fr = (seeded_random(random_seed).call * (random_max + 1)).floor
      end
      mode = graphic["spritesheet"].to_s
      mode = "auto" if mode.empty?
      if mode == "rmxp"
        cw = [(graphic["cellW"] || 192).to_i, 1].max
        ch = [(graphic["cellH"] || 192).to_i, 1].max
        cols = [(graphic["cols"] || (width / cw)).to_i, 1].max
        rows = [height / ch, 1].max
        count = [cols * rows, 1].max
        fr %= count
        sprite.src_rect.set((fr % cols) * cw, (fr / cols) * ch, [cw, width].min, [ch, height].min)
        return
      end
      if mode == "code-dynamic-grid"
        cols, rows, fw, fh, count = dynamic_code_grid(sprite.bitmap)
        idx = 0
        style = graphic["sheetStyle"].to_s.downcase
        idx = [count / 3, count - 1].min if style == "charge"
        idx = [count - 1, (rows / 2) * cols + (cols / 2)].min if style == "burst"
        if graphic["playSheet"] && forced_frame.nil?
          start = (graphic["playStart"] || 0).to_f
          span = [[(graphic["playFrameCount"] || count).to_i, 1].max, count].min
          ticks = [(graphic["ticksPerFrame"] || 1).to_f, 1.0].max
          base = style == "burst" ? [0, count / 3].max : 0
          idx = base + ([0, ((frame - start) / ticks).floor].max % span)
        end
        idx %= [count, 1].max
        sx = (idx % cols) * fw; sy = (idx / cols) * fh
        sprite.src_rect.set(sx, sy, [fw, width - sx].min, [fh, height - sy].min)
        return
      end
      if mode == "code-auto-grid" || mode == "code-grid"
        fallback = graphic["cellMode"].to_s == "square-height" ? height : [width, height].min
        cw = [(graphic["cellW"] || fallback).to_i, 1].max
        ch = [(graphic["cellH"] || cw).to_i, 1].max
        cols = [(graphic["gridCols"] || graphic["cols"] || (width / cw)).to_i, 1].max
        rows = [height / ch, 1].max
        count = [cols * rows, 1].max
        if graphic["playSheet"] && forced_frame.nil?
          ticks = [(graphic["ticksPerFrame"] || 1).to_f, 1.0].max
          start = (graphic["playStart"] || clip["startFrame"] || 0).to_f
          first = [(graphic["playFirstFrame"] || 0).to_i, 0].max
          limited = [(graphic["playFrameCount"] || 0).to_i, 0].max
          span = limited > 0 ? [count, limited].min : count
          fr = first + ([0, ((frame - start) / ticks).floor].max % [span, 1].max)
        end
        fr %= count
        sx = (fr % cols) * cw; sy = (fr / cols) * ch
        sprite.src_rect.set(sx, sy, [cw, width - sx].min, [ch, height - sy].min)
        return
      end
      sheet = (mode == "sheet")
      if mode == "auto"
        code_like = graphic["source"].to_s == "code" || clip["type"].to_s.include?("code")
        if code_like && (width > height * 1.35 || height > width * 1.35)
          cols, rows, fw, fh, count = dynamic_code_grid(sprite.bitmap)
          if count > 1
            fr %= count
            sx = (fr % cols) * fw; sy = (fr / cols) * fh
            sprite.src_rect.set(sx, sy, [fw, width - sx].min, [fh, height - sy].min)
            return
          end
        end
        sheet = code_like ? (width > height && width % height == 0) : (width > height * 2)
      end
      if !sheet
        sprite.src_rect.set(0, 0, width, height)
        return
      end
      side = height
      count = [width / [side, 1].max, 1].max
      if graphic["playSheet"] && forced_frame.nil?
        sec = [0.0, frame.to_f - (clip["startFrame"] || 0).to_f].max / animation_fps
        fr = (sec * [(graphic["sheetFps"] || 20).to_f, 1.0].max).floor
      end
      fr %= count
      sprite.src_rect.set(fr * side, 0, [side, width - fr * side].min, side)
    rescue => e
      BattleAnimationStudioRuntime.log("source frame #{e.class}: #{e.message}")
    end

    def apply_origin(sprite, clip, frame = @frame)
      return if !sprite || !sprite.bitmap || sprite.bitmap.disposed?
      g = clip["graphic"].is_a?(Hash) ? clip["graphic"] : {}
      origin = g["origin"].to_s
      origin = "auto" if origin.empty?
      w = sprite.src_rect && sprite.src_rect.width > 0 ? sprite.src_rect.width : sprite.bitmap.width
      h = sprite.src_rect && sprite.src_rect.height > 0 ? sprite.src_rect.height : sprite.bitmap.height
      focus = (clip["pbs"].is_a?(Hash) ? clip["pbs"]["focus"] : nil).to_s
      special = g["source"].to_s.start_with?("battler-")
      if origin == "bottom" || special
        ox = w / 2.0; oy = h.to_f
      elsif origin == "top_left" || (origin == "auto" && ["foreground", "midground", "background"].include?(focus) && w >= Graphics.width * 0.8)
        ox = 0.0; oy = 0.0
      else
        ox = w / 2.0; oy = h / 2.0
      end
      if !cached_value_keys(clip, "originX").empty? || ((clip["visual"] || {}).key?("originX") rescue false)
        ox = sample_value(clip, "originX", frame, ox)
      end
      if !cached_value_keys(clip, "originY").empty? || ((clip["visual"] || {}).key?("originY") rescue false)
        oy = sample_value(clip, "originY", frame, oy)
      end
      ox += sample_value(clip, "originOffsetX", frame, 0)
      oy += sample_value(clip, "originOffsetY", frame, 0)
      sprite.ox = ox if sprite.respond_to?(:ox=)
      sprite.oy = oy if sprite.respond_to?(:oy=)
    rescue
    end

    def fx_at(clip, kind, frame)
      value = nil
      ops = @fx_cache[clip.object_id] ||= begin
        raw = clip["fxOps"] || []
        raw.is_a?(Array) ? raw.sort_by { |op| (op["frame"] || 0).to_f } : []
      end
      ops.each do |op|
        f = (op["frame"] || 0).to_f
        break if f > frame
        next if op["name"].to_s != "legacyFx"
        value = op[kind]
      end
      keys = clip["valueKeys"].is_a?(Hash) ? clip["valueKeys"] : {}
      if kind.to_s == "tone" && ["toneRed", "toneGreen", "toneBlue", "toneGray"].any? { |p| keys[p].is_a?(Array) && !keys[p].empty? }
        base = value.is_a?(Hash) ? value : {}
        return {
          "red"   => sample_value(clip, "toneRed", frame, base["red"] || 0),
          "green" => sample_value(clip, "toneGreen", frame, base["green"] || 0),
          "blue"  => sample_value(clip, "toneBlue", frame, base["blue"] || 0),
          "gray"  => sample_value(clip, "toneGray", frame, base["gray"] || 0)
        }
      end
      value
    end

    def to_tone(raw)
      return nil if !raw.is_a?(Hash)
      Tone.new(raw["red"].to_f, raw["green"].to_f, raw["blue"].to_f, raw["gray"].to_f)
    rescue
      nil
    end

    def to_color(raw)
      return nil if !raw.is_a?(Hash)
      Color.new(raw["red"].to_f, raw["green"].to_f, raw["blue"].to_f, raw["alpha"].to_f)
    rescue
      nil
    end

    def rgss_angle_between(x1, y1, x2, y2)
      diff_x = x1.to_f - x2.to_f
      diff_y = y1.to_f - y2.to_f
      return diff_x >= 0 ? 90.0 : -90.0 if diff_y.abs < 0.0000001
      ret = Math.atan(diff_x / diff_y) * 180.0 / Math::PI
      ret += 180.0 if diff_y < 0
      ret
    end

    def pbs_initial_command_value(clip, prop)
      pbs = clip["pbs"].is_a?(Hash) ? clip["pbs"] : {}
      commands = pbs["commands"].is_a?(Hash) ? (pbs["commands"][prop] || []) : []
      first = commands[0]
      return 0.0 if !first || first["duration"].to_f > 0
      first["value"].to_f
    rescue
      0.0
    end

    def pbs_initial_angle_origin(clip)
      pbs = clip["pbs"].is_a?(Hash) ? clip["pbs"] : {}
      point = {
        "anchor" => "pbs:#{pbs["focus"] || "foreground"}",
        "x" => pbs_initial_command_value(clip, "x"),
        "y" => pbs_initial_command_value(clip, "y"),
        "offsetX" => 0, "offsetY" => 0,
        "foeInvertX" => false, "foeInvertY" => false
      }
      resolve_point(point)
    end

    def pbs_focus_target(clip)
      pbs = clip["pbs"].is_a?(Hash) ? clip["pbs"] : {}
      focus = pbs["focus"].to_s
      uf = base_anchor(:user, true); tf = base_anchor(:target, true)
      us = script_anchor(:user); ts = script_anchor(:target)
      return [tf[0], ts[1]] if focus.include?("and_target_position")
      return tf if focus.include?("and_target")
      return [tf[0], ts[1]] if focus.start_with?("target_position")
      return tf if focus.start_with?("target")
      return [uf[0], us[1]] if focus.start_with?("user_position")
      uf
    end

    def apply_pbs_angle_override(sprite, clip, frame)
      pbs = clip["pbs"].is_a?(Hash) ? clip["pbs"] : {}
      mode = pbs["angleOverride"].to_s.downcase
      return if !mode.include?("focus")
      target = pbs_focus_target(clip).dup
      initial = mode.include?("initial")
      origin = initial ? pbs_initial_angle_origin(clip) : sample_position(clip, frame)
      origin = origin.dup
      graphic = clip["graphic"].is_a?(Hash) ? clip["graphic"] : {}
      special = graphic["source"].to_s.start_with?("battler-")
      offset = (special && sprite.bitmap && !sprite.bitmap.disposed?) ? ((sprite.src_rect && sprite.src_rect.height > 0) ? sprite.src_rect.height / 2.0 : sprite.bitmap.height / 2.0) : 0.0
      # AnimationPlayer::Helper#get_xy_offset participates in both the current
      # sprite coordinate and the focus target used by the angle override.
      origin[1] += offset
      target[1] += offset
      sprite.angle = sample_value(clip, "rotation", frame, 0) + rgss_angle_between(origin[0], origin[1], target[0], target[1])
    rescue
    end

    # Emitter version of the PBS angle override. RandomAngleRange replaces
    # InitialAngleToFocus, while AlwaysPointAtFocus adds the random offset. This
    # is the same order used by the Studio preview/New Animation Editor.
    def apply_emitter_angle_override(sprite, clip, frame, desc)
      pbs = clip["pbs"].is_a?(Hash) ? clip["pbs"] : {}
      mode = pbs["angleOverride"].to_s.downcase
      base_rotation = sample_value(clip, "rotation", frame, 0).to_f
      range = (desc[:random_angle_range] || 0).to_i
      angle_offset = (desc[:random_angle] || 0).to_f
      target = pbs_focus_target(clip).dup
      graphic = clip["graphic"].is_a?(Hash) ? clip["graphic"] : {}
      special = graphic["source"].to_s.start_with?("battler-")
      offset = (special && sprite.bitmap && !sprite.bitmap.disposed?) ? sprite.bitmap.height / 2.0 : 0.0

      if mode.include?("always") && mode.include?("focus")
        origin = sample_position(clip, frame).dup
        origin[1] += offset
        target[1] += offset
        sprite.angle = base_rotation + rgss_angle_between(origin[0], origin[1], target[0], target[1]) + angle_offset
      elsif mode.include?("initial") && mode.include?("focus") && range <= 0
        origin = pbs_initial_angle_origin(clip).dup
        origin[1] += offset
        # InitialAngleToFocus adds get_xy_offset to the source point only.
        sprite.angle = base_rotation + rgss_angle_between(origin[0], origin[1], target[0], target[1])
      else
        sprite.angle = base_rotation + angle_offset
      end
      sprite.angle *= -1 if desc[:random_angle_invert]
    rescue => e
      BattleAnimationStudioRuntime.log("emitter angle #{e.class}: #{e.message}")
    end

    def priority_reference(obj, frame)
      explicit = (obj["priorityReference"] || "auto").to_s.downcase
      return explicit if explicit != "auto"
      pbs = obj["pbs"].is_a?(Hash) ? obj["pbs"] : {}
      focus = pbs["focus"].to_s.downcase
      return "target" if focus.include?("target")
      return "user" if focus.include?("user")
      keys = @position_key_cache[obj.object_id] ||= begin
        raw = obj["positionKeys"] || []
        raw.is_a?(Array) ? raw.sort_by { |k| (k["frame"] || 0).to_f } : []
      end
      anchor = ""
      keys.each do |key|
        break if (key["frame"] || 0).to_f > frame.to_f
        point = key["point"].is_a?(Hash) ? key["point"] : {}
        anchor = point["anchor"].to_s.downcase
      end
      if anchor.empty? && !keys.empty?
        point = keys.first["point"].is_a?(Hash) ? keys.first["point"] : {}
        anchor = point["anchor"].to_s.downcase
      end
      return "target" if anchor.include?("target")
      return "user" if anchor.include?("user")
      "absolute"
    rescue
      "absolute"
    end

    def pbs_native_layer?(obj)
      return false if !obj.is_a?(Hash)
      imported = obj["imported"].is_a?(Hash) ? obj["imported"] : {}
      imported["format"].to_s.downcase == "pbs" || obj["type"].to_s == "pbs-particle"
    rescue
      false
    end

    def nae_battler_z(index)
      idx = index.to_i
      1000 + (100 * ((idx / 2) + 1) * (idx.even? ? 1 : -1))
    end

    def pbs_z_focus(obj)
      pbs = obj["pbs"].is_a?(Hash) ? obj["pbs"] : {}
      focus = pbs["focus"].to_s.downcase
      ui = (@user.index rescue 0).to_i
      ti = (@target.index rescue 1).to_i
      uz = nae_battler_z(ui)
      tz = nae_battler_z(ti)
      case focus
      when "foreground" then 2000
      when "midground" then 1000
      when "background" then 0
      when "user", "user_position" then uz
      when "target", "target_position" then tz
      when "user_and_target", "user_position_and_target", "user_and_target_position", "user_position_and_target_position" then [uz, tz]
      when "user_side_foreground", "target_side_foreground"
        idx = focus.start_with?("user") ? ui : ti
        1000 + (idx.even? ? 1000 : 0)
      when "user_side_background", "target_side_background"
        idx = focus.start_with?("user") ? ui : ti
        idx.even? ? 1000 : 0
      else
        nil
      end
    rescue
      nil
    end

    def apply_pbs_native_z(sprite, obj, frame)
      return if !sprite || !pbs_native_layer?(obj)
      z = sample_value(obj, "z", frame, 0).to_f
      focus = pbs_z_focus(obj)
      if focus.is_a?(Array)
        distance = -100.0
        u = focus[0].to_f; t = focus[1].to_f
        if z >= 0
          sprite.z = u > t ? u + z : u - z
        elsif z <= distance
          sprite.z = u > t ? t + z + distance : t - z + distance
        else
          sprite.z = u + ((z / distance) * (t - u)).to_i
        end
      elsif !focus.nil?
        sprite.z = z + focus.to_f
      else
        sprite.z = z
      end
    rescue => e
      BattleAnimationStudioRuntime.log("pbs z #{e.class}: #{e.message}")
    end

    def apply_layer_priority(sprite, obj, frame)
      return if !sprite || !obj
      priority = (obj["priority"] || 0).to_f
      explicit = (obj["priorityReference"] || "auto").to_s.downcase
      # Explicit references are authoritative even at priority 0. This makes
      # "Normal (0) respecto a Target/User" mean exactly the battler's layer.
      if explicit == "absolute"
        sprite.z = priority
        return
      end
      ref = priority_reference(obj, frame)
      if explicit == "auto" && priority == 0
        return
      end
      case ref
      when "target"
        base = target_sprite
        sprite.z = (base ? base.z.to_f : sprite.z.to_f) + priority
      when "user"
        base = user_sprite
        sprite.z = (base ? base.z.to_f : sprite.z.to_f) + priority
      when "foreground"
        sprite.z = 100000 + priority
      when "background"
        sprite.z = -100000 + priority
      else
        sprite.z = sprite.z.to_f + priority if priority != 0
      end
    rescue
    end

    def apply_object(sprite, obj, frame, battler = false, side = nil)
      return if !sprite || !obj
      pos = sample_position(obj, frame)
      sprite.x = pos[0]; sprite.y = pos[1]
      size = sample_value(obj, "size", frame, 100) / 100.0
      view_scale = battler ? sample_value(obj, "viewScale", frame, 100) / 100.0 : 1.0
      sx = sample_value(obj, "scaleX", frame, 100) / 100.0 * size * view_scale
      sy = sample_value(obj, "scaleY", frame, 100) / 100.0 * size * view_scale
      sy *= -1.0 if sample_value(obj, "flipY", frame, 0) >= 0.5
      if battler
        side ||= sprite.equal?(target_sprite) ? :target : :user
        view_correction = battler_view_profile_correction(side, obj, frame)
        sx *= view_correction
        sy *= view_correction
        base = side.to_sym == :target ? @original[:target] : @original[:user]
        sprite.zoom_x = (base && base[:zoom_x] ? base[:zoom_x] : 1.0) * sx
        sprite.zoom_y = (base && base[:zoom_y] ? base[:zoom_y] : 1.0) * sy
        sprite.angle = (base && base[:angle] ? base[:angle] : 0).to_f + sample_value(obj, "rotation", frame, 0)
      else
        sprite.zoom_x = sx; sprite.zoom_y = sy
        sprite.angle = sample_value(obj, "rotation", frame, 0)
      end
      sprite.opacity = [[(sample_value(obj, "opacity", frame, 100) * 2.55).round, 0].max, 255].min
      sprite.visible = sample_visible(obj, frame)
      if battler
        side ||= sprite.equal?(target_sprite) ? :target : :user
        base = side.to_sym == :target ? @original[:target] : @original[:user]
        sprite.z = ((base && base[:z] ? base[:z] : sprite.z).to_f + sample_value(obj, "z", frame, 0).to_f).round
      else
        sprite.z = sample_value(obj, "z", frame, sprite.z).round
        apply_pbs_native_z(sprite, obj, frame)
      end
      sprite.blend_type = sample_value(obj, "blend", frame, 0).round if sprite.respond_to?(:blend_type=)
      sprite.mirror = sample_value(obj, "flip", frame, 0) >= 0.5 if sprite.respond_to?(:mirror=)
      tone = to_tone(fx_at(obj, "tone", frame))
      sprite.tone = tone if tone && sprite.respond_to?(:tone=)
    rescue => e
      BattleAnimationStudioRuntime.log("apply_object #{e.class}: #{e.message}")
    end

    def apply_battlers
      u = battler_track(:user); t = battler_track(:target)
      if u && user_sprite
        apply_battler_view(:user, u, @frame)
        apply_object(user_sprite, u, @frame, true, :user)
      end
      if t && target_sprite && target_sprite != user_sprite
        apply_battler_view(:target, t, @frame)
        apply_object(target_sprite, t, @frame, true, :target)
      end
    end

    def emitter_type(clip)
      pbs = clip["pbs"].is_a?(Hash) ? clip["pbs"] : {}
      type = (pbs["emitter"] || pbs["emitterType"] || "none").to_s.downcase
      type.gsub(/[^a-z]/, "")
    rescue
      "none"
    end

    def cached_emitter_commands(clip, name)
      key = [clip.object_id, name.to_s]
      @emitter_command_cache[key] ||= begin
        pbs = clip["pbs"].is_a?(Hash) ? clip["pbs"] : {}
        map = pbs["emitterCommands"].is_a?(Hash) ? pbs["emitterCommands"] : {}
        raw = map[name.to_s] || []
        raw.is_a?(Array) ? raw.sort_by { |cmd| (cmd["frame"] || 0).to_f } : []
      end
    end

    def emitter_value(clip, name, frame, fallback = 0)
      list = cached_emitter_commands(clip, name)
      return fallback if list.empty?
      value = fallback
      list.each do |cmd|
        cf = (cmd["frame"] || 0).to_f
        break if frame < cf
        dur = (cmd["duration"] || 0).to_f
        target = cmd["value"]
        if dur > 0 && frame < cf + dur
          t = ease01((frame - cf) / [dur, 0.0001].max, cmd["easing"] || "linear")
          return value.to_f + ((target.to_f - value.to_f) * t) if target.is_a?(Numeric) || value.is_a?(Numeric)
          return target
        end
        value = target
      end
      value
    rescue
      fallback
    end

    def cached_pbs_commands(clip, name)
      key = [clip.object_id, name.to_s]
      @pbs_command_cache[key] ||= begin
        pbs = clip["pbs"].is_a?(Hash) ? clip["pbs"] : {}
        map = pbs["commands"].is_a?(Hash) ? pbs["commands"] : {}
        raw = map[name.to_s] || []
        raw.is_a?(Array) ? raw.sort_by { |cmd| (cmd["frame"] || 0).to_f } : []
      end
    end

    def sample_pbs_scalar(clip, name, frame, fallback = 0)
      list = cached_pbs_commands(clip, name)
      return fallback if list.empty?
      value = fallback
      list.each do |cmd|
        cf = (cmd["frame"] || 0).to_f
        break if frame < cf
        dur = (cmd["duration"] || 0).to_f
        target = cmd["value"]
        if dur > 0 && frame < cf + dur
          t = ease01((frame - cf) / [dur, 0.0001].max, cmd["easing"] || "linear")
          return value.to_f + ((target.to_f - value.to_f) * t) if target.is_a?(Numeric) || value.is_a?(Numeric)
          return target
        end
        value = target
      end
      value
    rescue
      fallback
    end

    def emitter_particle_command_frame(clip, emission_frame, age)
      pbs = clip["pbs"].is_a?(Hash) ? clip["pbs"] : {}
      mode = pbs["particleCommandSpace"].to_s.downcase
      return emission_frame.to_f + age.to_f if mode == "animation"
      return age.to_f if mode == "particle"
      # Compatibility with BAS 1.9.4-1.9.6. Studio-created emitter radius keys
      # were written on the animation timeline; native PBS keeps them particle-local.
      emitting = pbs["emitterCommands"].is_a?(Hash) ? (pbs["emitterCommands"]["emitting"] || []) : []
      emitting = emitting.is_a?(Array) ? emitting.sort_by { |cmd| (cmd["frame"] || 0).to_f } : []
      start_cmd = emitting.find { |cmd| runtime_bool(cmd["value"]) }
      start_frame = start_cmd ? (start_cmd["frame"] || 0).to_f : 0.0
      min_radius_frame = nil
      commands = pbs["commands"].is_a?(Hash) ? pbs["commands"] : {}
      ["radiusX", "radiusY", "radiusZ"].each do |prop|
        list = commands[prop]
        next if !list.is_a?(Array)
        list.each do |cmd|
          cf = (cmd["frame"] || 0).to_f
          min_radius_frame = cf if min_radius_frame.nil? || cf < min_radius_frame
        end
      end
      if start_frame > 0.0 && !min_radius_frame.nil? && min_radius_frame >= start_frame
        return emission_frame.to_f + age.to_f
      end
      age.to_f
    rescue
      age.to_f
    end

    def emitter_randomized(clip, key, range_key, frame, rnd, fallback = 0)
      base = emitter_value(clip, key, frame, fallback).to_f
      range = [0.0, emitter_value(clip, range_key, frame, 0).to_f].max
      range > 0 ? base + ((rnd.call * 2.0 - 1.0) * range) : base
    end

    def runtime_bool(value)
      return true if value == true
      return false if value == false || value.nil?
      return value.to_i != 0 if value.respond_to?(:to_i)
      !!value
    rescue
      false
    end

    # Build emission times once for the whole animation. The old runtime rebuilt
    # the complete emission history on every render frame, which was one of the
    # main sources of allocation/GC hitches in particle-heavy attacks.
    def cached_emitter_frames(clip)
      key = clip.object_id
      cached = @emitter_frame_cache[key]
      return cached if cached
      list = cached_emitter_commands(clip, "emitting")
      base_rate = [((clip["pbs"] || {})["emitterRate"] || 1).to_f, 0.01].max
      out = []
      state = false
      active_start = nil

      # Match the Studio preview exactly: every SetEmitting=true restarts the
      # cadence, but emissions from the already-active interval are preserved.
      flush_interval = proc do |finish_frame|
        next if !state || active_start.nil?
        stop = [finish_frame.to_f, duration.to_f].min
        t = active_start.to_f
        guard = 0
        while t <= stop + 0.000001 && guard < 20000
          out << t
          rate = [emitter_value(clip, "emitterRate", t, base_rate).to_f, 0.01].max
          t += animation_fps / rate
          guard += 1
        end
      end

      list.each do |cmd|
        f = (cmd["frame"] || 0).to_f
        break if f > duration.to_f + 0.000001
        flush_interval.call(f - 0.0000001)
        state = runtime_bool(cmd["value"])
        active_start = state ? f : nil
      end
      flush_interval.call(duration.to_f)

      @emitter_frame_cache[key] = out
      out
    rescue => e
      BattleAnimationStudioRuntime.log("emitter frames #{e.class}: #{e.message}")
      @emitter_frame_cache[key] = []
    end

    def emitter_particle_lifetime(clip)
      key = clip.object_id
      return @emitter_lifetime_cache[key] if @emitter_lifetime_cache.key?(key)
      pbs = clip["pbs"].is_a?(Hash) ? clip["pbs"] : {}
      type = emitter_type(clip)
      if type == "drain"
        base_travel = (pbs["drainTravelFrames"] || 14).to_f
        travel_keys = cached_emitter_commands(clip, "drainTravelFrames")
        max_travel = ([base_travel] + travel_keys.map { |cmd| cmd["value"].to_f }).max
        life = [max_travel + 4.0, 1.0].max
        @emitter_lifetime_cache[key] = life
        return life
      elsif type == "energyin" || type == "energyout"
        base_travel = (pbs["energyTravelFrames"] || 16).to_f
        travel_keys = cached_emitter_commands(clip, "energyTravelFrames")
        max_travel = ([base_travel] + travel_keys.map { |cmd| cmd["value"].to_f }).max
        life = [max_travel + 4.0, 1.0].max
        @emitter_lifetime_cache[key] = life
        return life
      end
      commands = pbs["commands"].is_a?(Hash) ? pbs["commands"] : {}
      max_end = 0.0
      commands.each_value do |list|
        next if !list.is_a?(Array)
        list.each do |cmd|
          max_end = [max_end, (cmd["frame"] || 0).to_f + (cmd["duration"] || 0).to_f].max
        end
      end
      # If the particle ends invisible/transparent, its last process marks its
      # useful lifetime. Otherwise it remains alive until animation disposal,
      # exactly like New Animation Editor's ParticleSprite.
      probe = [duration, max_end + 1.0].max
      final_visible = sample_visible(clip, probe)
      final_opacity = sample_value(clip, "opacity", probe, 100).to_f
      life = (!final_visible || final_opacity <= 0.001) ? [max_end + 0.25, 1.0].max : duration
      @emitter_lifetime_cache[key] = life
      life
    rescue
      @emitter_lifetime_cache[key] = duration
    end

    # Emitter randomness is intentionally deterministic so a particle has the
    # same spawn position/size/angle/frame in Studio preview and in gameplay.
    # The seed format mirrors preview.js: `${clip.id}:${round(frame*1000)}:${j}`.
    def emitter_seed(clip, emission_frame, particle_index)
      frame_key = (emission_frame.to_f * 1000.0).round
      stable_seed("#{clip["id"]}:#{frame_key}:#{particle_index.to_i}")
    rescue
      1
    end

    # preview.js uses xorshift32 and exposes the low six decimal digits. Keep an
    # emitter-specific generator instead of changing the runtime RNG used by
    # unrelated effects.
    def emitter_seeded_random(seed)
      state = seed.to_i & 0xffffffff
      proc do
        state ^= ((state << 13) & 0xffffffff)
        state &= 0xffffffff
        state ^= (state >> 17)
        state &= 0xffffffff
        state ^= ((state << 5) & 0xffffffff)
        state &= 0xffffffff
        (state % 1_000_000).to_f / 1_000_000.0
      end
    end

    def build_emitter_descriptor(clip, ef, emission_index, particle_in_emission)
      seed = emitter_seed(clip, ef, particle_in_emission)
      rnd = emitter_seeded_random(seed)
      pbs = clip["pbs"].is_a?(Hash) ? clip["pbs"] : {}
      desc = {}
      desc[:frame] = ef
      desc[:seed] = seed
      desc[:ox] = emitter_randomized(clip, "emitX", "emitXRange", ef, rnd, 0)
      desc[:oy] = emitter_randomized(clip, "emitY", "emitYRange", ef, rnd, 0)
      desc[:speed] = emitter_randomized(clip, "emitSpeed", "emitSpeedRange", ef, rnd, 0)
      desc[:angle] = emitter_randomized(clip, "emitAngle", "emitAngleRange", ef, rnd, 0)
      desc[:gravity] = emitter_randomized(clip, "emitGravity", "emitGravityRange", ef, rnd, 0)
      desc[:period_x] = [0.0001, emitter_randomized(clip, "emitPeriodX", "emitPeriodXRange", ef, rnd, 100) / 100.0].max
      desc[:period_y] = [0.0001, emitter_randomized(clip, "emitPeriodY", "emitPeriodYRange", ef, rnd, 100) / 100.0].max
      desc[:period_z] = [0.0001, emitter_randomized(clip, "emitPeriodZ", "emitPeriodZRange", ef, rnd, 100) / 100.0].max
      desc[:radius_x_mult] = (100.0 + ((rnd.call * 2.0 - 1.0) * [0.0, emitter_value(clip, "emitRadiusXRange", ef, 0).to_f].max)) / 100.0
      desc[:radius_y_mult] = (100.0 + ((rnd.call * 2.0 - 1.0) * [0.0, emitter_value(clip, "emitRadiusYRange", ef, 0).to_f].max)) / 100.0
      desc[:radius_z_mult] = (100.0 + ((rnd.call * 2.0 - 1.0) * [0.0, emitter_value(clip, "emitRadiusZRange", ef, 0).to_f].max)) / 100.0
      particle_size = [1.0, emitter_value(clip, "particleSize", ef, (pbs["particleSize"] || 100)).to_f].max
      particle_size_range = [0.0, emitter_value(clip, "particleSizeRange", ef, (pbs["particleSizeRange"] || 0)).to_f].max
      particle_size_value = particle_size + (particle_size_range > 0 ? ((rnd.call * 2.0 - 1.0) * particle_size_range) : 0.0)
      desc[:particle_size_mult] = [0.01, particle_size_value / 100.0].max
      desc[:zoom_mult] = (100.0 + ((rnd.call * 2.0 - 1.0) * [0.0, emitter_value(clip, "emitZoomRange", ef, 0).to_f].max)) / 100.0
      desc[:zoom_x_mult] = (100.0 + ((rnd.call * 2.0 - 1.0) * [0.0, emitter_value(clip, "emitZoomXRange", ef, 0).to_f].max)) / 100.0
      desc[:zoom_y_mult] = (100.0 + ((rnd.call * 2.0 - 1.0) * [0.0, emitter_value(clip, "emitZoomYRange", ef, 0).to_f].max)) / 100.0
      desc[:clockwise] = runtime_bool(emitter_value(clip, "emitClockwise", ef, false))

      # drawClip() deliberately starts a fresh PRNG for visual-only spawn
      # choices. Reproduce that exact sequence here instead of continuing the
      # movement RNG, which previously made gameplay particles visibly differ.
      visual_rnd = emitter_seeded_random(seed)
      random_max = [0, emitter_value(clip, "randomFrameMax", ef, (pbs["randomFrameMax"] || 0)).to_i].max
      frame_rnd = emitter_seeded_random(seed)
      desc[:random_frame] = random_max > 0 ? (frame_rnd.call * (random_max + 1)).floor : nil

      random_flip_enabled = runtime_bool(emitter_value(clip, "randomInvertFlip", ef, !!pbs["randomInvertFlip"]))
      desc[:random_flip] = random_flip_enabled && visual_rnd.call < 0.5

      range = [0, emitter_value(clip, "randomAngleRange", ef, (pbs["randomAngleRange"] || 0)).to_i].max
      desc[:random_angle_range] = range
      desc[:random_angle] = range > 0 ? ((visual_rnd.call * (range * 2 + 1)).floor - range) : 0

      random_invert_enabled = runtime_bool(emitter_value(clip, "randomInvertAngle", ef, !!pbs["randomInvertAngle"]))
      desc[:random_angle_invert] = random_invert_enabled && visual_rnd.call < 0.5

      desc[:drain_travel] = [emitter_value(clip, "drainTravelFrames", ef, (pbs["drainTravelFrames"] || 14)).to_f, 1.0].max
      desc[:energy_travel] = [emitter_value(clip, "energyTravelFrames", ef, (pbs["energyTravelFrames"] || 16)).to_f, 1.0].max
      desc[:energy_turns] = emitter_value(clip, "energyTurns", ef, (pbs["energyTurns"] || 0)).to_f
      desc
    end

    def cached_emitter_particles(clip)
      key = clip.object_id
      return @emitter_particle_cache[key] if @emitter_particle_cache[key]
      frames = cached_emitter_frames(clip)
      pbs = clip["pbs"].is_a?(Hash) ? clip["pbs"] : {}
      base_intensity = [[(pbs["emitterIntensity"] || 1).to_i, 1].max, 100].min
      out = []
      frames.each_with_index do |ef, emission_index|
        intensity = [[emitter_value(clip, "emitterIntensity", ef, base_intensity).to_i, 1].max, 100].min
        intensity.times do |j|
          out << build_emitter_descriptor(clip, ef, emission_index, j)
        end
      end
      @emitter_particle_cache[key] = out
      out
    rescue => e
      BattleAnimationStudioRuntime.log("emitter cache #{e.class}: #{e.message}")
      @emitter_particle_cache[key] = []
    end

    def lower_bound_particle(particles, minimum_frame)
      lo = 0; hi = particles.length
      while lo < hi
        mid = (lo + hi) / 2
        if particles[mid][:frame].to_f < minimum_frame
          lo = mid + 1
        else
          hi = mid
        end
      end
      lo
    end

    def ensure_emitter_sprite(clip, index, template)
      id = clip["id"].to_s
      pool = (@emitter_sprites[id] ||= [])
      while pool.length <= index
        sp = Sprite.new(@viewport)
        sp.visible = false
        sp.bitmap = template.bitmap if template && template.bitmap && !template.bitmap.disposed?
        setup_mask(sp, clip) if sp.respond_to?(:pattern=)
        pool << sp
      end
      sprite = pool[index]
      if template && template.bitmap && !template.bitmap.disposed? && sprite.bitmap != template.bitmap
        sprite.bitmap = template.bitmap
      end
      sprite
    rescue
      nil
    end

    def emitter_layer_key(clip, index)
      "#{clip["id"]}@@emitter#{index}"
    end

    def hide_emitter_tail(clip, from_index)
      pool = @emitter_sprites[clip["id"].to_s] || []
      i = from_index
      while i < pool.length
        pool[i].visible = false if pool[i] && !pool[i].disposed?
        hide_second_layer(clip, emitter_layer_key(clip, i))
        i += 1
      end
    rescue
    end

    def apply_emitter_particle(sprite, clip, local_frame, extra, desc, pool_index)
      return if !sprite
      apply_object(sprite, clip, local_frame, false)
      apply_special_battler_profile_scale(sprite, clip)
      apply_layer_priority(sprite, clip, local_frame)
      if !sprite.visible
        hide_second_layer(clip, emitter_layer_key(clip, pool_index))
        return
      end
      sprite.x += extra[:dx].to_f
      sprite.y += extra[:dy].to_f
      sprite.z = sprite.z.to_f + extra[:z].to_f
      sprite.zoom_x *= extra[:scale_x].to_f
      sprite.zoom_y *= extra[:scale_y].to_f
      # Opacity has two timelines for emitters: the particle's own opacity is
      # sampled in local lifetime (above), while emitterOpacity is a global
      # animation-frame multiplier controlled by the Studio inspector.
      emitter_alpha = [[sample_value(clip, "emitterOpacity", @frame, 100).to_f / 100.0, 0.0].max, 1.0].min
      sprite.opacity = [[(sprite.opacity.to_f * emitter_alpha).round, 0].max, 255].min
      apply_emitter_angle_override(sprite, clip, local_frame, desc)
      pbs = clip["pbs"].is_a?(Hash) ? clip["pbs"] : {}
      focus = pbs["focus"].to_s.downcase
      relative_index = if focus.include?("and")
                         -1
                       elsif focus.start_with?("user")
                         (@user.index rescue -1)
                       elsif focus.start_with?("target")
                         (@target.index rescue -1)
                       else
                         -1
                       end
      # Match preview.js semantics for imported PBS FoeFlip.
      sprite.mirror = true if pbs["foeFlip"] && relative_index.to_i >= 0 && relative_index.to_i.odd? && sprite.respond_to?(:mirror=)
      sprite.mirror = !sprite.mirror if desc[:random_flip] && sprite.respond_to?(:mirror=)
      # RandomFrameMax is a spawn-time choice. Keep it until a Frame process
      # begins, rather than rolling a new frame every render update.
      frame_keys = cached_value_keys(clip, "graphicFrame")
      random_frame = desc[:random_frame]
      use_random_frame = !random_frame.nil? && (frame_keys.empty? || local_frame < frame_keys.first["frame"].to_f)
      apply_source_frame(sprite, clip, local_frame, nil, use_random_frame ? random_frame : nil)
      apply_origin(sprite, clip, local_frame)
      apply_mask_properties(sprite, clip, local_frame)
      tone = to_tone(fx_at(clip, "tone", local_frame)); color = to_color(fx_at(clip, "color", local_frame))
      sprite.tone = tone if tone && sprite.respond_to?(:tone=)
      sprite.color = color if color && sprite.respond_to?(:color=)
      apply_second_layer(clip, sprite, local_frame, emitter_layer_key(clip, pool_index), desc[:random_angle_invert], emitter_alpha)
    rescue => e
      BattleAnimationStudioRuntime.log("emitter particle #{e.class}: #{e.message}")
      sprite.visible = false rescue nil
      hide_second_layer(clip, emitter_layer_key(clip, pool_index))
    end

    def apply_emitter(clip)
      template = @effect_sprites[clip["id"].to_s]
      return if !template
      update_bitmap(template, clip, @frame)
      template.visible = false
      particles = cached_emitter_particles(clip)
      life = emitter_particle_lifetime(clip)
      first = lower_bound_particle(particles, @frame - life - 0.0001)
      type = emitter_type(clip)
      fps = animation_fps
      particle_index = 0
      i = first
      while i < particles.length && particle_index < RUNTIME_PARTICLE_LIMIT
        desc = particles[i]
        ef = desc[:frame].to_f
        break if ef > @frame + 0.000001
        age = @frame - ef
        i += 1
        next if age < 0 || age > life
        sec = age.to_f / fps
        phase = desc[:angle].to_f * Math::PI / 180.0
        dir = desc[:clockwise] ? -1.0 : 1.0
        particle_command_frame = emitter_particle_command_frame(clip, ef, age)
        radius_x = sample_pbs_scalar(clip, "radiusX", particle_command_frame, 0).to_f
        radius_y = sample_pbs_scalar(clip, "radiusY", particle_command_frame, 0).to_f
        radius_z = sample_pbs_scalar(clip, "radiusZ", particle_command_frame, 0).to_f
        dx = desc[:ox].to_f; dy = desc[:oy].to_f; zoff = 0.0
        if type == "straight" || type == "projectile"
          dx += Math.cos(phase) * desc[:speed].to_f * sec
          dy -= Math.sin(phase) * desc[:speed].to_f * sec
          dy += desc[:gravity].to_f * sec * sec / 2.0 if type == "projectile"
        elsif type == "helix"
          dx += radius_x * desc[:radius_x_mult].to_f * Math.sin(phase + (Math::PI * 2.0 * sec / desc[:period_x].to_f) * dir)
          dy += desc[:speed].to_f * sec if desc[:speed].to_f != 0
          zoff += radius_z * desc[:radius_z_mult].to_f * Math.cos(phase + (Math::PI * 2.0 * sec / desc[:period_z].to_f) * dir)
        elsif type == "polar"
          dx += radius_x * desc[:radius_x_mult].to_f * Math.sin(phase + (Math::PI * 2.0 * sec / desc[:period_x].to_f) * dir)
          dy += radius_y * desc[:radius_y_mult].to_f * Math.cos(phase + (Math::PI * 2.0 * sec / desc[:period_y].to_f))
        elsif type == "energyin" || type == "energyout"
          travel = [desc[:energy_travel].to_f, 1.0].max
          next if age > travel + 4
          t = [[age / travel, 0.0].max, 1.0].min
          theta = phase + (Math::PI * 2.0 * desc[:energy_turns].to_f * t * dir)
          radial = type == "energyin" ? (1.0 - t) : t
          dx += Math.cos(theta) * radius_x * desc[:radius_x_mult].to_f * radial
          dy += Math.sin(theta) * radius_y * desc[:radius_y_mult].to_f * radial
        elsif type == "orbit"
          theta = phase + (Math::PI * 2.0 * sec / desc[:period_x].to_f) * dir
          dx += Math.cos(theta) * radius_x * desc[:radius_x_mult].to_f
          dy += Math.sin(theta) * radius_y * desc[:radius_y_mult].to_f
        elsif type == "drain"
          from = base_anchor(:target, false); to = base_anchor(:user, false)
          travel = [desc[:drain_travel].to_f, 1.0].max
          next if age > travel + 4
          t = [[age / travel, 0.0].max, 1.0].min
          eased = 1.0 - ((1.0 - t) ** 2)
          dx += (to[0] - from[0]) * eased
          dy += (to[1] - from[1]) * eased
          wobble = Math.sin((t * Math::PI * 2.0) + phase) * 10.0 * (1.0 - t)
          dx += wobble
          dy += Math.cos((t * Math::PI * 2.0) + phase) * 5.0 * (1.0 - t)
        end
        sprite = ensure_emitter_sprite(clip, particle_index, template)
        next if !sprite
        apply_emitter_particle(sprite, clip, age,
          { :dx => dx, :dy => dy, :z => zoff,
            :scale_x => desc[:particle_size_mult].to_f * desc[:zoom_mult].to_f * desc[:zoom_x_mult].to_f,
            :scale_y => desc[:particle_size_mult].to_f * desc[:zoom_mult].to_f * desc[:zoom_y_mult].to_f }, desc, particle_index)
        particle_index += 1
      end
      hide_emitter_tail(clip, particle_index)
    rescue => e
      BattleAnimationStudioRuntime.log("emitter #{e.class}: #{e.message}")
      hide_emitter_tail(clip, 0)
    end

    def parse_pbs_tone(raw)
      return Tone.new(0, 0, 0, 0) if raw.nil?
      return to_tone(raw) if raw.is_a?(Hash)
      vals = raw.to_s.scan(/[+-]?\d+/).map(&:to_i)
      vals = [0, 0, 0, 0] if vals.empty?
      Tone.new(vals[0] || 0, vals[1] || 0, vals[2] || 0, vals[3] || 0)
    rescue
      Tone.new(0, 0, 0, 0)
    end

    def parse_pbs_color(raw)
      return Color.new(0, 0, 0, 0) if raw.nil?
      return to_color(raw) if raw.is_a?(Hash)
      hex = raw.to_s.sub(/^#/, "")
      hex = hex.rjust(8, "0")[0, 8]
      vals = [hex[0,2], hex[2,2], hex[4,2], hex[6,2]].map { |v| v.to_i(16) }
      Color.new(vals[0], vals[1], vals[2], vals[3])
    rescue
      Color.new(0, 0, 0, 0)
    end

    def ensure_second_layer_sprite(clip, main, instance_key = nil)
      id = (instance_key || clip["id"]).to_s
      sprite = @second_layer_sprites[id]
      if !sprite || sprite.disposed?
        sprite = Sprite.new(@viewport)
        sprite.visible = false
        @second_layer_sprites[id] = sprite
      end
      if main && main.bitmap && !main.bitmap.disposed? && sprite.bitmap != main.bitmap
        sprite.bitmap = main.bitmap
      end
      sprite
    rescue
      nil
    end

    def hide_second_layer(clip, instance_key = nil)
      id = (instance_key || clip["id"]).to_s
      sprite = @second_layer_sprites[id]
      sprite.visible = false if sprite && !sprite.disposed?
    rescue
    end

    def apply_mask_properties(sprite, clip, frame)
      return if !sprite
      sprite.pattern_opacity = sample_pbs_scalar(clip, "maskOpacity", frame, 0).to_i if sprite.respond_to?(:pattern_opacity=)
      sprite.pattern_scroll_x = sample_pbs_scalar(clip, "maskX", frame, 0).to_f if sprite.respond_to?(:pattern_scroll_x=)
      sprite.pattern_scroll_y = sample_pbs_scalar(clip, "maskY", frame, 0).to_f if sprite.respond_to?(:pattern_scroll_y=)
      sprite.pattern_zoom_x = sample_pbs_scalar(clip, "maskZoomX", frame, 100).to_f / 100.0 if sprite.respond_to?(:pattern_zoom_x=)
      sprite.pattern_zoom_y = sample_pbs_scalar(clip, "maskZoomY", frame, 100).to_f / 100.0 if sprite.respond_to?(:pattern_zoom_y=)
      sprite.pattern_blend_type = sample_pbs_scalar(clip, "maskBlending", frame, 0).to_i if sprite.respond_to?(:pattern_blend_type=)
    rescue
    end

    def apply_second_layer(clip, main, frame, instance_key = nil, random_angle_inverted = false, opacity_multiplier = 1.0)
      pbs = clip["pbs"].is_a?(Hash) ? clip["pbs"] : {}
      if !pbs["secondLayer"] || !main || !main.visible || !main.bitmap || main.bitmap.disposed?
        hide_second_layer(clip, instance_key)
        return
      end
      sprite = ensure_second_layer_sprite(clip, main, instance_key)
      return if !sprite
      sprite.visible = true
      # Match AnimationPlayer::ParticleSprite exactly: X2/Y2 are screen-space
      # offsets from layer 1; they are not rotated or mirrored with layer 1.
      sprite.x = main.x.to_f + sample_pbs_scalar(clip, "x2", frame, 0).to_f
      sprite.y = main.y.to_f + sample_pbs_scalar(clip, "y2", frame, 0).to_f
      zx2 = sample_pbs_scalar(clip, "zoomX2", frame, 100).to_f / 100.0
      zy2 = sample_pbs_scalar(clip, "zoomY2", frame, 100).to_f / 100.0
      sprite.zoom_x = main.zoom_x.to_f * zx2
      sprite.zoom_y = main.zoom_y.to_f * zy2
      angle2 = sample_pbs_scalar(clip, "angle2", frame, 0).to_f
      angle2 *= -1.0 if random_angle_inverted
      sprite.angle = main.angle.to_f + angle2
      sprite.opacity = [[main.opacity.to_f + (sample_pbs_scalar(clip, "opacity2", frame, 0).to_f * opacity_multiplier.to_f), 0].max, 255].min.round
      sprite.z = main.z.to_f + sample_pbs_scalar(clip, "z2", frame, 0).to_f
      raw_flip2 = sample_pbs_scalar(clip, "flip2", frame, false)
      flip2 = (raw_flip2 == true || (raw_flip2.respond_to?(:to_i) && raw_flip2.to_i != 0))
      sprite.mirror = (!!(main.mirror rescue false)) ^ flip2 if sprite.respond_to?(:mirror=)
      sprite.blend_type = sample_pbs_scalar(clip, "blending2", frame, 0).to_i if sprite.respond_to?(:blend_type=)
      frame2_list = cached_pbs_commands(clip, "frame2")
      frame2 = frame2_list.empty? ? 0 : sample_pbs_scalar(clip, "frame2", frame, 0).to_i
      apply_source_frame(sprite, clip, frame, nil, frame2)
      apply_origin(sprite, clip, frame)
      sprite.tone = parse_pbs_tone(sample_pbs_scalar(clip, "tone2", frame, "+00+00+00+00")) if sprite.respond_to?(:tone=)
      sprite.color = parse_pbs_color(sample_pbs_scalar(clip, "color2", frame, "00000000")) if sprite.respond_to?(:color=)
      if sprite.respond_to?(:invert=)
        main_inv = main.respond_to?(:invert) ? !!main.invert : false
        raw_inv2 = sample_pbs_scalar(clip, "invertColor2", frame, false)
        inv2 = (raw_inv2 == true || (raw_inv2.respond_to?(:to_i) && raw_inv2.to_i != 0))
        sprite.invert = inv2 ? !main_inv : main_inv
      end
    rescue => e
      BattleAnimationStudioRuntime.log("second layer #{e.class}: #{e.message}")
      hide_second_layer(clip, instance_key)
    end

    def apply_clip(clip)
      if emitter_type(clip) != "none"
        apply_emitter(clip)
        return
      end
      sprite = @effect_sprites[clip["id"].to_s]
      return if !sprite
      start_f = (clip["startFrame"] || 0).to_f; end_f = (clip["endFrame"] || duration).to_f
      active = @frame >= start_f && @frame <= end_f && sample_visible(clip, @frame)
      if !active
        sprite.visible = false
        hide_second_layer(clip)
        return
      end
      update_bitmap(sprite, clip, @frame)
      apply_object(sprite, clip, @frame, false)
      apply_special_battler_profile_scale(sprite, clip)
      apply_layer_priority(sprite, clip, @frame)
      apply_pbs_angle_override(sprite, clip, @frame)
      apply_source_frame(sprite, clip, @frame)
      apply_origin(sprite, clip, @frame)
      apply_mask_properties(sprite, clip, @frame)
      tone = to_tone(fx_at(clip, "tone", @frame)); color = to_color(fx_at(clip, "color", @frame))
      sprite.tone = tone if tone && sprite.respond_to?(:tone=)
      sprite.color = color if color && sprite.respond_to?(:color=)
      apply_second_layer(clip, sprite, @frame)
    end

    def resolve_runtime_se_name(name)
      raw = name.to_s.tr("\\", "/").sub(/^Audio\/SE\//i, "").sub(/^\/+/, "")
      raw = raw.sub(/\.(wav|ogg|mp3|m4a)$/i, "")
      return "" if raw.empty?
      src = @data["source"].is_a?(Hash) ? @data["source"] : {}
      source_type = (src["type"] || src["system"] || "").to_s.downcase
      candidates = []
      if raw =~ /^Anim\//i
        candidates << raw
      elsif ["pbs", "vanilla", "legacy", "new"].include?(source_type) || src["system"].to_s.downcase == "pbs"
        candidates << "Anim/#{raw}"
        candidates << raw
      else
        candidates << raw
        candidates << "Anim/#{raw}"
      end
      candidates << raw.sub(/^SE\//i, "") if raw =~ /^SE\//i
      candidates.uniq!
      if defined?(pbResolveAudioSE)
        candidates.each do |candidate|
          return candidate if (pbResolveAudioSE(candidate) rescue nil)
        end
      end
      # Match the New Animation Editor convention even when the resolver cannot
      # inspect the file (e.g. encrypted RTP): PBS names are relative to Anim/.
      fallback = candidates.first || raw
      if !@missing_se_logged[fallback] && defined?(pbResolveAudioSE) && !(pbResolveAudioSE(fallback) rescue nil)
        @missing_se_logged[fallback] = true
        BattleAnimationStudioRuntime.log("SE not resolved: #{candidates.join(' | ')}")
      end
      fallback
    rescue
      name.to_s
    end

    def play_events(previous_frame, current_frame)
      (@se_events || []).each do |ev|
        ef = (ev["frame"] || 0).to_f
        crossed = if previous_frame.nil?
                    ef <= current_frame + 0.0001
                  else
                    ef > previous_frame + 0.0001 && ef <= current_frame + 0.0001
                  end
        next if !crossed
        name = resolve_runtime_se_name(ev["name"])
        next if name.empty?
        pbSEPlay(name, (ev["volume"] || 100).to_i, (ev["pitch"] || 100).to_i)
      end
    rescue => e
      BattleAnimationStudioRuntime.log("SE playback #{e.class}: #{e.message}")
    end

    def envelope_alpha(ev)
      start = (ev["frame"] || 0).to_f; local = @frame - start
      dur = [(ev["duration"] || 1).to_f, 1.0].max
      return 0.0 if local < 0 || local > dur
      fi = [(ev["fadeIn"] || 1).to_f, 1.0].max
      hold = [(ev["hold"] || 0).to_f, 0.0].max
      fo = [(ev["fadeOut"] || [dur - fi - hold, 1].max).to_f, 1.0].max
      return [[local / fi, 0.0].max, 1.0].min if local < fi
      return 1.0 if local <= fi + hold
      [[1.0 - ((local - fi - hold) / fo), 0.0].max, 1.0].min
    end

    def update_screen_events
      screen_events = @screen_events || []
      screen_events.each_with_index do |ev, i|
        sprite = @overlay_sprites[i]
        if !sprite
          sprite = Sprite.new(@viewport)
          sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
          @overlay_sprites[i] = sprite
        end
        type = ev["type"].to_s
        alpha = 0.0
        color = Color.new(255,255,255,255)
        if type == "screen_black_envelope" || type == "screen_white_envelope"
          color = type == "screen_black_envelope" ? Color.new(0,0,0,255) : Color.new(255,255,255,255)
          alpha = envelope_alpha(ev)
        else
          start = (ev["frame"] || 0).to_f; dur = [(ev["duration"] || 1).to_f, 1.0].max; local = @frame - start
          raw = ev["color"]
          if raw.is_a?(String)
            hex = raw.sub(/^#/, "").ljust(8, "F")[0,8]
            raw = [hex[0,2], hex[2,2], hex[4,2], hex[6,2]].map { |v| v.to_i(16) }
          end
          raw = [255,255,255,255] if !raw.is_a?(Array)
          color = Color.new((raw[0] || 255).to_i, (raw[1] || 255).to_i, (raw[2] || 255).to_i, 255)
          source_alpha = (raw[3] || 255).to_f / 255.0
          alpha = (local >= 0 && local <= dur) ? source_alpha * [[1.0 - local / dur, 0.0].max, 1.0].min : 0.0
        end
        signature = [color.red.to_i, color.green.to_i, color.blue.to_i, Graphics.width, Graphics.height]
        if @overlay_signatures[i] != signature
          sprite.bitmap.clear
          sprite.bitmap.fill_rect(0,0,Graphics.width,Graphics.height,color)
          @overlay_signatures[i] = signature
        end
        sprite.z = 9999 + i
        sprite.opacity = (alpha * 255).round
        sprite.visible = sprite.opacity > 0
      end
      (@overlay_sprites.length - 1).downto(screen_events.length) { |i| @overlay_sprites[i].visible = false if @overlay_sprites[i] }
    rescue
    end

    def neutral_camera_state
      state = @camera_state_buffer
      state[:x] = 0.0; state[:y] = 0.0; state[:zoom] = 1.0; state[:rotation] = 0.0
      state[:cx] = Graphics.width.to_f / 2.0; state[:cy] = Graphics.height.to_f / 2.0
      state[:cos] = 1.0; state[:sin] = 0.0
      state
    end

    def camera_state
      state = neutral_camera_state
      camera = @data["camera"].is_a?(Hash) ? @data["camera"] : nil
      return state if camera && (camera["enabled"] == false || !sample_visible(camera, @frame))
      x = camera ? sample_value(camera, "cameraX", @frame, 0).to_f : 0.0
      y = camera ? sample_value(camera, "cameraY", @frame, 0).to_f : 0.0
      rs = responsive_scale
      x *= rs[0]; y *= rs[1]
      zoom = camera ? [0.05, sample_value(camera, "cameraZoom", @frame, 100).to_f / 100.0].max : 1.0
      rotation = camera ? sample_value(camera, "cameraRotation", @frame, 0).to_f : 0.0
      (@shake_events || []).each do |ev|
        start = (ev["frame"] || 0).to_f
        dur = [(ev["duration"] || 1).to_f, 1.0].max
        next if @frame < start || @frame > start + dur
        local = @frame - start
        falloff = [[1.0 - local / dur, 0.0].max, 1.0].min
        strength = (ev["strength"] || 0).to_f * falloff
        axis = (ev["axis"] || 0).to_i
        x += Math.sin(local * 2.73 + 0.31) * strength if axis != 2
        y += Math.cos(local * 3.91 + 0.77) * strength * 0.55 if axis != 1
      end
      state[:x] = x; state[:y] = y; state[:zoom] = zoom; state[:rotation] = rotation
      rad = rotation * Math::PI / 180.0
      state[:cos] = Math.cos(rad); state[:sin] = Math.sin(rad)
      state
    rescue
      neutral_camera_state
    end

    def camera_neutral?(state)
      state[:x].to_f.abs < 0.0001 && state[:y].to_f.abs < 0.0001 &&
        (state[:zoom].to_f - 1.0).abs < 0.0001 && state[:rotation].to_f.abs < 0.0001
    end

    def camera_world_sprite_key?(key)
      name = key.to_s
      return true if ["battle_bg", "battle_bg2", "battlebg", "battlebg2", "terrain_bg", "trick_room_bg", "captureBall"].include?(name)
      return true if name =~ /\A(?:base_[01]|base_terrain_[01]|pokemon_\d+|shadow_\d+|player_\d+|trainer_\d+)\z/
      false
    end

    def apply_camera_to_sprite(sprite, state)
      return if !sprite || (sprite.respond_to?(:disposed?) && sprite.disposed?)
      raw_x = (sprite.x rescue 0).to_f
      raw_y = (sprite.y rescue 0).to_f
      raw_zoom_x = (sprite.zoom_x rescue 1.0).to_f
      raw_zoom_y = (sprite.zoom_y rescue 1.0).to_f
      raw_angle = (sprite.angle rescue 0.0).to_f
      slot = @camera_restore_states[@camera_restore_count]
      if !slot
        slot = Array.new(6)
        @camera_restore_states[@camera_restore_count] = slot
      end
      slot[0] = sprite; slot[1] = raw_x; slot[2] = raw_y
      slot[3] = raw_zoom_x; slot[4] = raw_zoom_y; slot[5] = raw_angle
      @camera_restore_count += 1
      cx = state[:cx]; cy = state[:cy]
      dx = raw_x - cx - state[:x].to_f
      dy = raw_y - cy - state[:y].to_f
      rx = (dx * state[:cos]) - (dy * state[:sin])
      ry = (dx * state[:sin]) + (dy * state[:cos])
      zoom = state[:zoom].to_f
      sprite.x = cx + (rx * zoom) if sprite.respond_to?(:x=)
      sprite.y = cy + (ry * zoom) if sprite.respond_to?(:y=)
      sprite.zoom_x = raw_zoom_x * zoom if sprite.respond_to?(:zoom_x=)
      sprite.zoom_y = raw_zoom_y * zoom if sprite.respond_to?(:zoom_y=)
      # Preview composes Canvas camera rotation (clockwise on screen) with RGSS
      # sprite rotation (positive is anticlockwise), hence subtraction here.
      sprite.angle = raw_angle - state[:rotation].to_f if sprite.respond_to?(:angle=)
    rescue
    end

    # Called immediately before Graphics.update by a lightweight render hook.
    # Camera transforms are visible only for the rendered frame and are restored
    # immediately afterwards. The restore slots are reused to avoid per-frame
    # Hash/Array allocation and the GC hitches those allocations caused.
    def prepare_camera_render
      restore_camera! if @camera_restore_count.to_i > 0
      state = camera_state
      return if camera_neutral?(state)
      seen = @camera_seen
      seen.clear
      (@sprites || {}).each do |key, sprite|
        next if !camera_world_sprite_key?(key)
        next if !sprite || seen[sprite.object_id]
        nested = sprite.instance_variable_get(:@sprites) rescue nil
        if nested.is_a?(Hash) && (key.to_s == "battlebg" || key.to_s == "battle_bg")
          nested.each_value do |child|
            next if !child || seen[child.object_id]
            seen[child.object_id] = true
            apply_camera_to_sprite(child, state)
          end
        else
          seen[sprite.object_id] = true
          apply_camera_to_sprite(sprite, state)
        end
      end
      @effect_sprites.each_value do |sprite|
        next if !sprite || seen[sprite.object_id] || !sprite.visible
        seen[sprite.object_id] = true
        apply_camera_to_sprite(sprite, state)
      end
      @second_layer_sprites.each_value do |sprite|
        next if !sprite || seen[sprite.object_id] || !sprite.visible
        seen[sprite.object_id] = true
        apply_camera_to_sprite(sprite, state)
      end
      @emitter_sprites.each_value do |pool|
        pool.each do |sprite|
          next if !sprite || seen[sprite.object_id] || !sprite.visible
          seen[sprite.object_id] = true
          apply_camera_to_sprite(sprite, state)
        end
      end
    rescue => e
      BattleAnimationStudioRuntime.log("camera render #{e.class}: #{e.message}")
      restore_camera!
    end

    def restore_camera!
      count = @camera_restore_count.to_i
      return if count <= 0
      i = count - 1
      while i >= 0
        slot = @camera_restore_states[i]
        if slot
          sprite = slot[0]
          if sprite && !(sprite.respond_to?(:disposed?) && sprite.disposed?)
            sprite.x = slot[1] if sprite.respond_to?(:x=)
            sprite.y = slot[2] if sprite.respond_to?(:y=)
            sprite.zoom_x = slot[3] if sprite.respond_to?(:zoom_x=)
            sprite.zoom_y = slot[4] if sprite.respond_to?(:zoom_y=)
            sprite.angle = slot[5] if sprite.respond_to?(:angle=)
          end
        end
        i -= 1
      end
      @camera_restore_count = 0
    rescue
      @camera_restore_count = 0
    end

    def update
      return if @done

      # Resolve the Studio frame from elapsed time, not from the number of game
      # update calls. This preserves the editor's FPS exactly at 40/60+ game FPS
      # and also when another plugin performs extra pbUpdate calls.
      current_frame = timeline_frame
      current_frame = @frame if current_frame < @frame
      @frame = current_frame

      play_events(@previous_event_frame, @frame)
      apply_conditional_form_rules(@previous_event_frame, @frame)
      apply_battlers
      clips.each { |clip| apply_clip(clip) }
      update_screen_events
      apply_scene_hide_progress(@frame)

      if @frame >= duration - 0.0001
        @done = true
        return
      end

      @previous_event_frame = @frame
    end
  end

  module SceneHook
    def pbPlayBattleAnimationStudio(move_id, user, targets, version = 0, common = false)
      raw_target = targets.is_a?(Array) ? targets[0] : targets
      side_battler = user || raw_target
      idx = side_battler && side_battler.respond_to?(:index) ? side_battler.index : 0
      data = if common == :custom || common.to_s == "custom"
               BattleAnimationStudioRuntime.custom_matching(move_id, version, idx)
             elsif common
               BattleAnimationStudioRuntime.common_matching(move_id, idx)
             else
               BattleAnimationStudioRuntime.matching(move_id, version, idx, false)
             end
      return false if !data

      # Common animations in the New Animation Editor use NoUser/NoTarget to
      # describe which logical battler role exists. Essentials still commonly
      # calls them as pbCommonAnimation(name, affected_battler), even when the
      # animation itself is Target-only (e.g. Poison). Remap the supplied
      # battler into the role declared by the animation instead of blindly
      # treating the first argument as User.
      play_user = user
      play_target = raw_target
      if common && common != :custom && common.to_s != "custom"
        no_user = !!data["noUser"]
        no_target = !!data["noTarget"]
        affected = raw_target || user
        if no_user && !no_target
          play_user = nil
          play_target = affected
        elsif no_target && !no_user
          play_user = user || raw_target
          play_target = nil
        elsif no_user && no_target
          play_user = nil
          play_target = nil
        else
          # Commons that define both roles still need a useful Target when the
          # caller supplies only the affected battler. This mirrors the old
          # animation fallback where target || user is used.
          play_target ||= play_user
        end
      end

      player = BattleAnimationStudioRuntime::Player.new(@sprites, @viewport, play_user, play_target, data)
      begin
        BattleAnimationStudioRuntime.active_player = player
        loop do
          player.update
          # Do not prepend/alias Graphics.update globally. Several projects
          # (including sleep/idle animation plugins) also wrap Graphics.update;
          # chaining both wrappers can recurse until SystemStackError. Apply the
          # Studio camera only around the actual rendered Graphics frame instead.
          player.prepare_camera_render
          begin
            Graphics.update
          ensure
            player.restore_camera!
          end
          Input.update
          pbGraphicsUpdate
          pbInputUpdate
          pbFrameUpdate(nil)
          break if player.animDone?
        end
      ensure
        BattleAnimationStudioRuntime.active_player = nil if BattleAnimationStudioRuntime.active_player.equal?(player)
        player.restore_camera!
        player.dispose
      end
      true
    rescue => e
      BattleAnimationStudioRuntime.log("Playback failed for #{move_id}: #{e.class}: #{e.message}")
      false
    end

    # Plays a Custom/Standalone Studio animation that is not registered as a Move
    # or Common animation. Example:
    #   @scene.pbPlayBattleAnimationStudioCustom("WEATHER_INTRO", user, targets)
    def pbPlayBattleAnimationStudioCustom(anim_id, user = nil, targets = nil, version = 0)
      pbPlayBattleAnimationStudio(anim_id, user, targets, version, :custom)
    end

    def pbAnimation(move_id, user, targets, version = 0)
      return if pbPlayBattleAnimationStudio(move_id, user, targets, version, false)
      super
    end

    def pbCommonAnimation(anim_name, user = nil, target = nil)
      return if pbPlayBattleAnimationStudio(anim_name, user, target, 0, true)
      super
    end
  end
end


#-------------------------------------------------------------------------------
# New Animation Editor compatibility
#
# NAE's Emitter#create_particle_sprite can legitimately reach get_xy_focus with
# target_idx == -1 and target_coords == nil (for example a target-focused
# emitter played without a usable target). Its stock helper then indexes nil and
# raises NoMethodError. Keep this guard local to BAS Runtime: normal NAE behavior
# is unchanged whenever its user/target coordinates are valid.
#-------------------------------------------------------------------------------
module BattleAnimationStudioRuntimeNAEFocusGuard
  def get_xy_focus(particle, user_index, target_index, user_coords, target_coords, side_sizes)
    focus = (particle[:focus] rescue nil)
    sides = side_sizes.is_a?(Array) ? side_sizes.clone : [1, 1]
    sides[0] = 1 if !sides[0] || sides[0].to_i <= 0
    sides[1] = 1 if !sides[1] || sides[1].to_i <= 0
    ui = user_index.nil? ? 0 : user_index.to_i
    ti = target_index.nil? ? -1 : target_index.to_i
    ti = ui if ti < 0
    ucoords = user_coords
    tcoords = target_coords
    focus_name = focus.to_s
    if !ucoords && focus_name.include?("user")
      begin
        ucoords = Battle::Scene.pbBattlerPosition(ui, sides[ui % 2]).clone
      rescue
        ucoords = [(Graphics.width rescue 512) * 0.25, (Graphics.height rescue 384) * 0.75]
      end
    end
    if !tcoords && focus_name.include?("target")
      # A no-target animation is effectively self-focused. Prefer the user's
      # live focus when available; this is also what the editor preview expects.
      tcoords = ucoords.clone if ucoords
      if !tcoords
        begin
          tcoords = Battle::Scene.pbBattlerPosition(ti, sides[ti % 2]).clone
        rescue
          tcoords = [(Graphics.width rescue 512) * 0.75, (Graphics.height rescue 384) * 0.35]
        end
      end
    end
    super(particle, ui, ti, ucoords, tcoords, sides)
  end

  def get_z_focus(particle, user_index, target_index)
    ui = user_index.nil? ? 0 : user_index.to_i
    ti = target_index.nil? ? -1 : target_index.to_i
    ti = ui if ti < 0
    super(particle, ui, ti)
  end
end

module BattleAnimationStudioRuntimeNAEEmitterGuard
  def index_of_particle_focus(target_idx = -1)
    focus = (@particle[:focus] rescue nil)
    if @user.nil? && focus && focus.to_s.include?("user")
      return (target_idx && target_idx.to_i >= 0) ? target_idx.to_i : -1
    end
    super
  end
end

module BattleAnimationStudioRuntime
  def self.install_new_animation_editor_compat
    if defined?(AnimationPlayer::Helper)
      klass = AnimationPlayer::Helper.singleton_class
      unless klass.ancestors.include?(BattleAnimationStudioRuntimeNAEFocusGuard)
        klass.prepend(BattleAnimationStudioRuntimeNAEFocusGuard)
      end
    end
    if defined?(AnimationPlayer::Emitter)
      klass = AnimationPlayer::Emitter
      unless klass.ancestors.include?(BattleAnimationStudioRuntimeNAEEmitterGuard)
        klass.prepend(BattleAnimationStudioRuntimeNAEEmitterGuard)
      end
    end
  rescue => e
    log("NAE compat #{e.class}: #{e.message}")
  end
end

BattleAnimationStudioRuntime.install_new_animation_editor_compat

# Camera rendering is driven locally by SceneHook#pbPlayBattleAnimationStudio.
# Intentionally do not hook Graphics.update globally: other plugins may alias or
# prepend that singleton method and can otherwise form a recursive super/alias loop.

if defined?(Battle::Scene)
  Battle::Scene.prepend(BattleAnimationStudioRuntime::SceneHook) unless Battle::Scene.ancestors.include?(BattleAnimationStudioRuntime::SceneHook)
end

# Parse/index the exported library when the game is loaded instead of on the
# first move animation. This moves JSON parsing out of the battle hot path.
if defined?(EventHandlers)
  EventHandlers.add(:on_game_load, :battle_animation_studio_runtime_preload, proc {
    BattleAnimationStudioRuntime.install_new_animation_editor_compat
    BattleAnimationStudioRuntime.load_data
  })
end

# VERMEIL and other plugins can override Battle#pbAnimation before the request
# reaches Battle::Scene. Prepending here lets an explicitly exported Studio
# animation win; all other moves fall through untouched to the existing stack.
if defined?(Battle)
  module BattleAnimationStudioRuntimeBattleHook
    def pbAnimation(move, user, targets, hit_num = 0)
      if @showAnims && @scene && @scene.respond_to?(:pbPlayBattleAnimationStudio)
        return if @scene.pbPlayBattleAnimationStudio(move, user, targets, hit_num, false)
      end
      super
    end
  end
  Battle.prepend(BattleAnimationStudioRuntimeBattleHook) unless Battle.ancestors.include?(BattleAnimationStudioRuntimeBattleHook)
end

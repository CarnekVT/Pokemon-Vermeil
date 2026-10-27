# frozen_string_literal: true
# Pokemon Vermeil / Battle Scene Studio — visual-review adjustments (2026-10-26)
# Place at the end of the BSS runtime's 99_Hotfix folder.
# Targeted at BSS 0.8.36's archived API; inspect/update for newer installs.
# Keeps BAS's camera lease authoritative during move animations.

module BSSVideoReview
  VERSION = '0.1.0'
  # Camera: main/idle framing. Lower = farther away.
  OVERVIEW_ZOOM = 0.89
  SHOT_STRENGTH_PLAYER = 0.66
  SHOT_STRENGTH_ENEMY = 0.55  # Don't push the enemy to the far-right edge.
  CAMERA_TWEEN_FRAMES = 70
  AMBIENT_VECTOR_SPEED = 0.0040
  AMBIENT_HOLD_FRAMES = 260
  TRAINER_BLACKBAR_Y = 15
  MULTI_BATTLER_SPREAD_PX = 16.0
  # Set to false to respect authored fixed-hour (day/dawn/night) backdrops.
  MATCH_GAME_CLOCK = true
  # Turn off if scripted scene authors intentionally hide an already active mon.
  KEEP_ACTIVE_SECOND_VISIBLE_IN_DIALOGUE = true
  # Applied to scenery only, never to the Pokemon/HUD/special lights.
  NIGHT_TONE = [-49, -29, 11, 0]
  DUSK_TONE  = [-13, -20, -3, 0]
  DAY_TONE   = [0, 0, 0, 0]

  module_function

  def active?(scene)
    !!(scene && scene.respond_to?(:bss083_camera_active?) && scene.bss083_camera_active?)
  rescue StandardError
    false
  end

  def leased?(scene)
    !!(scene && scene.respond_to?(:bss_shared_camera_leased?) && scene.bss_shared_camera_leased?) ||
      scene.instance_variable_get(:@bss070_ebdx_bas_frame) == true
  rescue StandardError
    false
  end

  def log(message)
    BSS064.log('BSSVideoReview ' + message) if defined?(BSS064) && BSS064.respond_to?(:log)
  rescue StandardError
    nil
  end

  def time_slot(data)
    # Follow Essentials' game clock instead of a manually authored skyMode.
    # A project custom-time plugin only needs to implement PBDayNight normally.
    if MATCH_GAME_CLOCK && defined?(PBDayNight)
      return :night if PBDayNight.respond_to?(:isNight?) && PBDayNight.isNight?
      morning = PBDayNight.respond_to?(:isMorning?) && PBDayNight.isMorning?
      evening = PBDayNight.respond_to?(:isEvening?) && PBDayNight.isEvening?
      return :dawn if morning || evening
      return :day
    end
    return BSS106.time_slot(data) if defined?(BSS106) && BSS106.respond_to?(:time_slot)
    :day
  rescue StandardError
    :day
  end

  def offset_for_battler(scene, index)
    battle = scene.instance_variable_get(:@battle)
    return 0.0 unless battle && battle.respond_to?(:pbSideSize)
    index = index.to_i
    size = battle.pbSideSize(index).to_i
    return 0.0 if size < 2
    place = index / 2
    return 0.0 if place >= size
    spread = MULTI_BATTLER_SPREAD_PX
    (place.to_f - (size - 1) / 2.0) * (size == 2 ? 2.0 : 1.0) * spread
  rescue StandardError
    0.0
  end

  def vec(scene, side)
    main = BSS070EBDXCore.get_vector(:MAIN, scene.instance_variable_get(:@battle)).map { |x| x.to_f }
    main = main[0, 6]
    return nil unless main.length == 6
    if side == :player || side == :enemy
      authored = BSS083.camera_shot(side, scene.instance_variable_get(:@battle))
      strength = (side == :enemy ? SHOT_STRENGTH_ENEMY : SHOT_STRENGTH_PLAYER)
      4.times do |i|
        main[i] += (authored[i].to_f - main[i]) * strength
      end
    end
    # EBDX vectors use both last channels for perspective/zoom. Preserve their
    # ratio; never alter the battler sprites' own zoom every frame.
    main[4] *= OVERVIEW_ZOOM
    main[5] *= OVERVIEW_ZOOM
    main
  rescue StandardError => e
    log("camera vector: #{e.class}: #{e.message}")
    nil
  end

  def valid_sprite?(s)
    s && !(s.disposed? rescue false)
  end

  def battler_active?(b)
    b && !(b.fainted? rescue true)
  end
end

# Avoid swapping every authored background to a night image: only resolve
# dynamic *runtime* scene data against Essentials time for outdoor rooms.
module BSSVideoClockRoom
  def drawSky(*args, &block)
    data = instance_variable_get(:@data)
    outdoor = data.is_a?(Hash) && (data[:outdoor] != false && data['outdoor'] != false) &&
              (data[:outdoor] == true || data['outdoor'] == true || data[:sky] || data['sky'] || data[:skyMode] || data['skyMode'])
    return super unless BSSVideoReview::MATCH_GAME_CLOCK && outdoor
    # BSS 0.8.36 drawSky consults raw skyMode before BSS106.time_slot.
    old_sym = data[:skyMode]
    old_str = data['skyMode']
    had_sym = data.key?(:skyMode)
    had_str = data.key?('skyMode')
    data[:skyMode] = 'dynamic'
    data['skyMode'] = 'dynamic'
    super
  ensure
    if BSSVideoReview::MATCH_GAME_CLOCK && outdoor && data.is_a?(Hash)
      had_sym ? data[:skyMode] = old_sym : data.delete(:skyMode)
      had_str ? data['skyMode'] = old_str : data.delete('skyMode')
    end
  end

  def daylightTint(*args, &block)
    result = super
    data = instance_variable_get(:@data)
    return result unless data.is_a?(Hash)
    outdoors = (data[:outdoor] || data['outdoor'] || data[:sky] || data['sky'] || data[:skyMode] || data['skyMode'])
    return result unless outdoors
    slot = BSSVideoReview.time_slot(data)
    tone = case slot
           when :night then BSSVideoReview::NIGHT_TONE
           when :dawn then BSSVideoReview::DUSK_TONE
           else BSSVideoReview::DAY_TONE
           end
    sprites = instance_variable_get(:@sprites)
    return result unless sprites.is_a?(Hash)
    sprites.each do |key, sp|
      next unless BSSVideoReview.valid_sprite?(sp) && sp.respond_to?(:tone=)
      k = key.to_s.downcase
      next if k =~ /(trainer|battler|shadow|light|star|cloud|sun|sky|void)/
      row = (data[key] || data[key.to_s] || data[key.to_sym]) rescue nil
      next if row.is_a?(Hash) && (row[:shading] == false || row['shading'] == false)
      sp.tone = Tone.new(*tone)
    end
    result
  rescue StandardError => e
    BSSVideoReview.log("daylight tone: #{e.class}: #{e.message}")
    result
  end

  # Recheck only if the game-time slot actually changes, not every frame.
  def position(*args, &block)
    result = super
    data = instance_variable_get(:@data)
    if data.is_a?(Hash)
      slot = BSSVideoReview.time_slot(data)
      if @bss_video_last_lighting_slot != slot
        @bss_video_last_lighting_slot = slot
        daylightTint
      end
    end
    result
  end
end

# Both native EBDX metric anchors are offset BEFORE the room positions them.
# This is stable across camera movements and applies equally to shadows.
module BSSVideoFormationMetrics
  def bss070_ebdx_native_position_for(index, probe = false)
    xyz = super
    dx = BSSVideoReview.offset_for_battler(self, index)
    return xyz unless xyz.is_a?(Array) && xyz.length >= 2 && dx != 0.0
    adjusted = xyz.dup
    adjusted[0] = adjusted[0].to_f + dx
    adjusted
  end

  def bss070_ebdx_native_shadow_position_for(index, probe = false)
    xyz = super
    dx = BSSVideoReview.offset_for_battler(self, index)
    return xyz unless xyz.is_a?(Array) && xyz.length >= 2 && dx != 0.0
    adjusted = xyz.dup
    adjusted[0] = adjusted[0].to_f + dx
    adjusted
  end
end

# Scene camera never switches ownership away from BAS during an attack.
# Existing BSS087 tween is used rather than introducing a second update pump.
module BSSVideoSceneCamera
  def bss_video_camera_to(side, frames = BSSVideoReview::CAMERA_TWEEN_FRAMES)
    return false unless BSSVideoReview.active?(self)
    return false if BSSVideoReview.leased?(self) || @bss083_camera_freeze.to_i > 0
    dest = BSSVideoReview.vec(self, side)
    return false unless dest
    cur = @vector.get.map { |x| x.to_f }
    return false if cur.length < 6
    return true if (0...6).all? { |i| (cur[i] - dest[i]).abs < 0.015 }
    @bss087_camera_tween = {
      :key => "review_#{side}", :from => cur, :to => dest,
      :frame => 0, :frames => [[frames.to_i, 24].max, 120].min
    }
    @bss083_camera_state = side
    @bss070_ebdx_camera_mode = side
    @bss102_ambient_due = BSSVideoReview::AMBIENT_HOLD_FRAMES
    true
  rescue StandardError => e
    BSSVideoReview.log("camera transition: #{e.class}: #{e.message}")
    false
  end

  def pbInitSprites(*args, &block)
    result = super
    if BSSVideoReview.active?(self) && !BSSVideoReview.leased?(self)
      dest = BSSVideoReview.vec(self, :main)
      @vector.snap(dest) if dest && @vector.respond_to?(:snap)
      @bss_video_step = 0
      @bss102_ambient_due = BSSVideoReview::AMBIENT_HOLD_FRAMES
      bss070_ebdx_apply_world_alignment if respond_to?(:bss070_ebdx_apply_world_alignment)
    end
    result
  end

  # No random 2D jitter. Long, deterministic, slow player/enemy sweeps.
  def bss102_next_ambient_target(*args, &block)
    return super unless BSSVideoReview.active?(self)
    if BSSVideoReview.leased?(self) || @bss_video_menu_state || @bss_video_targeting
      @bss102_ambient_due = BSSVideoReview::AMBIENT_HOLD_FRAMES
      return nil
    end
    side = (@bss_video_step.to_i.even? ? :enemy : :player)
    @bss_video_step = @bss_video_step.to_i + 1
    dest = BSSVideoReview.vec(self, side)
    if dest
      @vector.inc = BSSVideoReview::AMBIENT_VECTOR_SPEED if @vector.respond_to?(:inc=)
      @vector.set(dest) if @vector.respond_to?(:set)
    end
    @bss102_ambient_due = BSSVideoReview::AMBIENT_HOLD_FRAMES
  rescue StandardError => e
    BSSVideoReview.log("ambient motion: #{e.class}: #{e.message}")
    nil
  end

  # BSS' old UnifiedCamera override can otherwise reset to MAIN when entering
  # fight, causing the very double-reposition problem visible in the recording.
  def bss_unified_camera_to(mode, idxBattler = nil)
    return super unless BSSVideoReview.active?(self)
    return nil if BSSVideoReview.leased?(self)
    returning = ['main', 'idle', 'overview'].include?(mode.to_s)
    return nil if returning && @bss_video_menu_state == :fight
    side = returning ? :main : :player
    bss_video_camera_to(side)
  end

  def bss070_ebdx_camera_enter(mode)
    result = super
    bss_video_camera_to(:player) if @bss_video_menu_state && !BSSVideoReview.leased?(self)
    result
  end

  def pbCommandMenu(*args, &block)
    @bss_video_menu_state = :command
    bss_video_camera_to(:player)
    super
  ensure
    @bss_video_menu_state = nil
  end

  def pbFightMenu(*args, &block)
    @bss_video_menu_state = :fight
    bss_video_camera_to(:player)
    super
  ensure
    @bss_video_menu_state = nil
  end

  # v21's choice window uses pbChooseTarget. Focus the opposing *side* while the
  # selection window is active; the deliberately limited shot avoids edge framing.
  def pbChooseTarget(*args, &block)
    @bss_video_targeting = true
    bss_video_camera_to(:enemy, 68)
    super
  ensure
    @bss_video_targeting = false
  end
end

# Keep scripted trainer dialogue above bars but the trainer sprite in the lower
# band of the composition; do not alter the sprite's authored home coordinates.
module BSSVideoCinematicScene
  def pbToggleBlackBars(toggle = false)
    @bss_video_blackbars = !!toggle
    super
  end

  def bss070_ebdx_apply_world_alignment(*args, &block)
    result = super
    if @bss_video_blackbars && @battle && @battle.opponent
      room = instance_variable_get(:@bss070_ebdx_room)
      sprites = instance_variable_get(:@sprites)
      if room && sprites.is_a?(Hash)
        @battle.opponent.each_index do |i|
          sp = sprites["trainer_#{i}"]
          a = (room.trainer(i * 2 + 1) rescue nil)
          next unless BSSVideoReview.valid_sprite?(sp) && BSSVideoReview.valid_sprite?(a)
          sp.y = a.y + BSSVideoReview::TRAINER_BLACKBAR_Y if sp.respond_to?(:y=)
        end
      end
    end
    result
  end

  def pbShowSpeakerWindows(*args, &block)
    result = super
    bss_video_ensure_second_battlers
    result
  end

  def bss_video_ensure_second_battlers
    return unless BSSVideoReview::KEEP_ACTIVE_SECOND_VISIBLE_IN_DIALOGUE
    return unless @bss_video_blackbars && @battle && @battle.respond_to?(:battlers)
    sprites = instance_variable_get(:@sprites)
    return unless sprites.is_a?(Hash)
    # Only slots 2/3: don't override an intentional hide on a first send-out.
    [2, 3].each do |i|
      b = @battle.battlers[i] rescue nil
      next unless BSSVideoReview.battler_active?(b)
      sp = sprites["pokemon_#{i}"]
      next unless BSSVideoReview.valid_sprite?(sp)
      next unless sp.respond_to?(:visible=) && sp.respond_to?(:bitmap) && sp.bitmap
      next unless (sp.opacity rescue 0).to_i > 0
      sp.visible = true
    end
  end
end

begin
  if defined?(BSS070EBDXRoom) && !BSS070EBDXRoom.ancestors.include?(BSSVideoClockRoom)
    BSS070EBDXRoom.prepend(BSSVideoClockRoom)
  end
  if defined?(Battle::Scene)
    Battle::Scene.prepend(BSSVideoFormationMetrics) unless Battle::Scene.ancestors.include?(BSSVideoFormationMetrics)
    Battle::Scene.prepend(BSSVideoSceneCamera) unless Battle::Scene.ancestors.include?(BSSVideoSceneCamera)
    Battle::Scene.prepend(BSSVideoCinematicScene) unless Battle::Scene.ancestors.include?(BSSVideoCinematicScene)
  end
rescue StandardError => e
  BSSVideoReview.log("installation: #{e.class}: #{e.message}")
end
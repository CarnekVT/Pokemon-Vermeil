#===============================================================================
# [VERMEIL] BattleAnimations
# [003] Toxic Spikes Cast Animation
#===============================================================================

module VermeilBattleAnimations
  module_function

  TOXIC_SPIKES_ASSETS = [
    "Graphics/UI/Battle/hazards/toxic_spikes",
    "Graphics/UI/Battle/hazards/toxic-spikes"
  ]

  TOXIC_PARTICLE_ASSETS = [
    "Graphics/Pictures/StatusParticles/toxic",
    "Graphics/Pictures/StatusParticles/poison",
    "Graphics/Pictures/statusparticles/toxic",
    "Graphics/Pictures/statusparticles/poison",
    "Graphics/Animations/poison",
    "Graphics/Animations/poison2"
  ]

  TOXIC_SPIKES_SE_THROW = "Anim/PRSFX- Toxic Spikes1"
  TOXIC_SPIKES_SE_LAND  = "Anim/PRSFX- Toxic Spikes2"

  def resolve_move_id(move)
    return move.id if move.respond_to?(:id)
    data = GameData::Move.try_get(move)
    return data.id if data
    return move
  end

  def first_existing_asset(paths)
    paths.each { |path| return path if pbResolveBitmap(path) }
    return nil
  end
end

class Battle::Scene::Animation::VermeilToxicSpikesCast < Battle::Scene::Animation
  def initialize(sprites, viewport, user, anchor_x, anchor_y, side_index)
    @user       = user
    @anchor_x   = anchor_x
    @anchor_y   = anchor_y
    @side_index = side_index
    super(sprites, viewport)
  end

  def createProcesses
    return if !@user
    user_sprite = @sprites["pokemon_#{@user.index}"]
    return if !user_sprite

    spike_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::TOXIC_SPIKES_ASSETS)
    return if !spike_asset
    particle_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::TOXIC_PARTICLE_ASSETS)
    @vermeil_effect_pics = []

    user_pic = addSprite(user_sprite, PictureOrigin::BOTTOM)
    forward_dir = (@user.index & 1) == 0 ? 1 : -1
    travel_scale = (@side_index == 0) ? 1.15 : 1.0

    user_pic.setSE(2, VermeilBattleAnimations::TOXIC_SPIKES_SE_THROW, 82, 105)
    user_pic.moveDelta(0, 5, 10 * forward_dir, -8)
    user_pic.moveDelta(5, 5, -10 * forward_dir, 8)

    offsets = [[-58, 8], [-36, 2], [-14, 10], [10, 1], [34, 9], [56, 4]]
    offsets.each_with_index do |(ox, oy), i|
      spike = addNewSprite(user_sprite.x, user_sprite.y - 56, spike_asset, PictureOrigin::CENTER)
      @vermeil_effect_pics << spike
      # Keep below textbox/UI layers.
      spike.setZ(0, 96 + i)
      spike.setOpacity(0, 0)
      spike.setVisible(0, false)
      spike.setZoom(0, 78 + (@side_index == 0 ? 20 : 0))

      start_t = 4 + (i * 2)
      peak_x = (@anchor_x + (ox * 0.4)).round
      peak_y = @anchor_y - 86 - ((i % 2) * 8)
      land_x = (@anchor_x + (ox * travel_scale)).round
      land_y = @anchor_y + oy

      spike.setVisible(start_t, true)
      spike.moveOpacity(start_t, 2, 255)
      spike.moveXY(start_t, 9, peak_x, peak_y)
      spike.moveXY(start_t + 9, 10, land_x, land_y)
      spike.moveAngle(start_t, 19, (forward_dir * 540) + (i * 30))

      # Quick bounce and settle.
      spike.moveDelta(start_t + 19, 2, 0, -8)
      spike.moveDelta(start_t + 21, 3, 0, 8)
      spike.moveDelta(start_t + 24, 2, 0, -3)
      spike.moveDelta(start_t + 26, 2, 0, 3)
      spike.setSE(start_t + 20, VermeilBattleAnimations::TOXIC_SPIKES_SE_LAND, 90, 98) if i == 2

      # Fade out quickly after landing; hazard icon display is separate.
      spike.moveOpacity(start_t + 28, 10, 0)
      spike.setVisible(start_t + 39, false)
    end

    if particle_asset
      4.times do |i|
        p = addNewSprite(@anchor_x + ((i - 2) * 14), @anchor_y - 10, particle_asset, PictureOrigin::CENTER)
        @vermeil_effect_pics << p
        # Keep below textbox/UI layers.
        p.setZ(0, 104 + i)
        p.setVisible(0, false)
        p.setOpacity(0, 0)
        p.setZoom(0, 56 + (i % 2) * 6)
        t = 30 + i
        p.setVisible(t, true)
        p.moveOpacity(t, 2, 150)
        p.moveDelta(t, 7, (i.even? ? -7 : 7), -18 - (i % 2) * 4)
        p.moveOpacity(t + 3, 6, 0)
        p.setVisible(t + 10, false)
      end

    end
  end
end

class Battle::Scene
  def vermeil_hazard_anchor_for_side(side_index)
    if defined?(HazardSettings)
      return [HazardSettings::PLAYER_SIDE_HAZARD_X, HazardSettings::PLAYER_SIDE_HAZARD_Y] if side_index == 0
      return [HazardSettings::FOE_SIDE_HAZARD_X, HazardSettings::FOE_SIDE_HAZARD_Y]
    end
    return [(Graphics.width * 0.30).round, (Graphics.height * 0.72).round] if side_index == 0
    return [(Graphics.width * 0.70).round, (Graphics.height * 0.44).round]
  end

  def pbPlayVermeilToxicSpikesCast(user, side_index)
    return false if !user
    spike_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::TOXIC_SPIKES_ASSETS)
    return false if !spike_asset

    ax, ay = vermeil_hazard_anchor_for_side(side_index)
    pbHazardsSuspend(:vermeil_toxicspikes_cast) if respond_to?(:pbHazardsSuspend)
    hidden_ui_keys = []
    ui_opacity = {}

    begin
      # Prepare UI list (all non-battler, non-background sprites).
      @sprites.each do |key, sprite|
        next if !sprite || !sprite.respond_to?(:visible=)
        k = key.to_s
        next if k.start_with?("pokemon_") || k.start_with?("shadow_")
        next if k.start_with?("battle_bg") || k.start_with?("base_")
        next if !sprite.visible
        hidden_ui_keys << key
        ui_opacity[key] = sprite.respond_to?(:opacity) ? sprite.opacity : nil
      end

      anim = Animation::VermeilToxicSpikesCast.new(@sprites, @viewport, user, ax, ay, side_index)
      # Keep timing unchanged; apply UI fades inside this same timeline.
      cast_end_frame = 200
      min_play_frames = 56
      fade_frames = 20
      ui_fade_started = false
      ui_fade_step = 0
      idle_frames = 0
      frame = 0
      loop do
        anim.update
        # Smooth UI fade-out at cast start.
        if frame < fade_frames
          hidden_ui_keys.each do |key|
            s = @sprites[key] rescue nil
            next if !s || !s.respond_to?(:opacity=)
            start_op = ui_opacity[key] || 255
            s.opacity = [start_op - (((frame + 1) * start_op) / fade_frames), 0].max
          end
          if frame == fade_frames - 1
            hidden_ui_keys.each do |key|
              s = @sprites[key] rescue nil
              s.visible = false if s && s.respond_to?(:visible=)
            end
          end
        end
        # Detect visual inactivity of cast effects (PictureEx has no disposed? method).
        if frame >= min_play_frames
          pics = anim.instance_variable_get(:@vermeil_effect_pics) rescue nil
          active = false
          if pics
            pics.each do |ps|
              next if !ps
              vis = ps.respond_to?(:visible) ? ps.visible : true
              op  = ps.respond_to?(:opacity) ? ps.opacity : 255
              if vis && op > 8
                active = true
                break
              end
            end
          end
          idle_frames = active ? 0 : (idle_frames + 1)
          if !ui_fade_started && idle_frames >= 1
            ui_fade_started = true
            ui_fade_step = 0
          end
        end

        # Smooth UI fade-in once cast visuals are done.
        if ui_fade_started
          ui_fade_step += 1
          if ui_fade_step == 1
            hidden_ui_keys.each do |key|
              s = @sprites[key] rescue nil
              next if !s || !s.respond_to?(:visible=)
              s.visible = true
              s.opacity = 0 if s.respond_to?(:opacity=)
            end
          end
          hidden_ui_keys.each do |key|
            s = @sprites[key] rescue nil
            next if !s || !s.respond_to?(:opacity=)
            target = ui_opacity[key] || 255
            s.opacity = [((ui_fade_step * target) / fade_frames), target].min
          end
        end
        pbUpdate
        frame += 1
        break if ui_fade_started && ui_fade_step >= fade_frames
        break if frame >= cast_end_frame
      end
      anim.dispose
    ensure
      hidden_ui_keys.each do |key|
        s = @sprites[key] rescue nil
        next if !s
        s.visible = true if s.respond_to?(:visible=)
        s.opacity = (ui_opacity[key] || 255) if s.respond_to?(:opacity=)
      end
      pbHazardsResume(:vermeil_toxicspikes_cast, false) if respond_to?(:pbHazardsResume)
    end
    return true
  end
end

class Battle
  alias_method :vermeil_toxicspikes_cast_pbAnimation, :pbAnimation unless method_defined?(:vermeil_toxicspikes_cast_pbAnimation)

  def pbAnimation(move, user, targets, hitNum = 0)
    move_id = VermeilBattleAnimations.resolve_move_id(move)
    if @showAnims && move_id == :TOXICSPIKES && @scene.respond_to?(:pbPlayVermeilToxicSpikesCast)
      anim_user = user
      if !anim_user || anim_user.fainted? || anim_user.hp <= 0
        alt = nil
        if targets.respond_to?(:each)
          targets.each do |t|
            next if !t || t.fainted? || t.hp <= 0
            alt = t.pbDirectOpposing if t.respond_to?(:pbDirectOpposing)
            break if alt && !alt.fainted? && alt.hp > 0
          end
        elsif targets && targets.respond_to?(:pbDirectOpposing)
          alt = targets.pbDirectOpposing
        end
        anim_user = alt if alt && !alt.fainted? && alt.hp > 0
      end
      if anim_user
        side_index = anim_user.respond_to?(:idxOwnSide) ? (anim_user.idxOwnSide ^ 1) : ((anim_user.index & 1) ^ 1)
        if @scene.pbPlayVermeilToxicSpikesCast(anim_user, side_index)
          return
        end
      end
    end
    vermeil_toxicspikes_cast_pbAnimation(move, user, targets, hitNum)
  end
end

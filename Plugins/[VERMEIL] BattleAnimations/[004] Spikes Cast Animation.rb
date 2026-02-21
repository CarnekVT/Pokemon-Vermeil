#===============================================================================
# [VERMEIL] BattleAnimations
# [004] Spikes Cast Animation
#===============================================================================

module VermeilBattleAnimations
  module_function

  SPIKES_ASSETS = [
    "Graphics/UI/Battle/hazards/spikes",
    "Graphics/UI/Battle/hazards/spike"
  ]

  SPIKES_SE_THROW = "Anim/PRSFX- Low Kick"
  SPIKES_SE_LAND  = "Anim/PRSFX- Spikes2"
end

class Battle::Scene::Animation::VermeilSpikesCast < Battle::Scene::Animation
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
    spike_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::SPIKES_ASSETS)
    return if !spike_asset

    @vermeil_effect_pics = []
    user_pic = addSprite(user_sprite, PictureOrigin::BOTTOM)
    forward_dir = (@user.index & 1) == 0 ? 1 : -1
    travel_scale = (@side_index == 0) ? 1.12 : 1.0

    user_pic.setSE(2, VermeilBattleAnimations::SPIKES_SE_THROW, 80, 100)
    user_pic.moveDelta(0, 5, 10 * forward_dir, -8)
    user_pic.moveDelta(5, 5, -10 * forward_dir, 8)

    offsets = [[-52, 8], [-30, 4], [-8, 10], [16, 5], [38, 9]]
    offsets.each_with_index do |(ox, oy), i|
      spike = addNewSprite(user_sprite.x, user_sprite.y - 56, spike_asset, PictureOrigin::CENTER)
      @vermeil_effect_pics << spike
      spike.setZ(0, 96 + i)
      spike.setOpacity(0, 0)
      spike.setVisible(0, false)
      spike.setZoom(0, 74 + (@side_index == 0 ? 16 : 0))

      start_t = 4 + (i * 2)
      peak_x = (@anchor_x + (ox * 0.45)).round
      peak_y = @anchor_y - 76 - ((i % 2) * 6)
      land_x = (@anchor_x + (ox * travel_scale)).round
      land_y = @anchor_y + oy

      spike.setVisible(start_t, true)
      spike.moveOpacity(start_t, 2, 255)
      spike.moveXY(start_t, 8, peak_x, peak_y)
      spike.moveXY(start_t + 8, 9, land_x, land_y)
      spike.moveAngle(start_t, 17, (forward_dir * 500) + (i * 28))
      spike.moveDelta(start_t + 17, 2, 0, -6)
      spike.moveDelta(start_t + 19, 3, 0, 6)
      spike.setSE(start_t + 18, VermeilBattleAnimations::SPIKES_SE_LAND, 88, 98) if i == 2
      spike.moveOpacity(start_t + 26, 10, 0)
      spike.setVisible(start_t + 37, false)
    end
  end
end

class Battle::Scene
  def pbPlayVermeilSpikesCast(user, side_index)
    return false if !user
    spike_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::SPIKES_ASSETS)
    return false if !spike_asset
    return false if !respond_to?(:vermeil_hazard_anchor_for_side)

    ax, ay = vermeil_hazard_anchor_for_side(side_index)
    vermeil_hazard_cast_text_lead_in(12) if respond_to?(:vermeil_hazard_cast_text_lead_in)
    pbHazardsSuspend(:vermeil_spikes_cast) if respond_to?(:pbHazardsSuspend)
    hidden_ui_keys = []
    ui_opacity = {}

    begin
      @sprites.each do |key, sprite|
        next if !sprite || !sprite.respond_to?(:visible=)
        k = key.to_s
        next if k.start_with?("pokemon_") || k.start_with?("shadow_")
        next if k.start_with?("battle_bg") || k.start_with?("base_")
        next if !sprite.visible
        hidden_ui_keys << key
        ui_opacity[key] = sprite.respond_to?(:opacity) ? sprite.opacity : nil
      end

      anim = Animation::VermeilSpikesCast.new(@sprites, @viewport, user, ax, ay, side_index)
      cast_end_frame = 200
      min_play_frames = 52
      fade_frames = 20
      force_fade_start_frame = 182
      active_opacity_threshold = 24
      ui_fade_started = false
      ui_fade_step = 0
      idle_frames = 0
      frame = 0
      loop do
        anim.update
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
        if frame >= min_play_frames
          pics = anim.instance_variable_get(:@vermeil_effect_pics) rescue nil
          active = false
          if pics
            pics.each do |ps|
              next if !ps
              vis = ps.respond_to?(:visible) ? ps.visible : true
              op  = ps.respond_to?(:opacity) ? ps.opacity : 255
              if vis && op > active_opacity_threshold
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
          if !ui_fade_started && frame >= force_fade_start_frame
            ui_fade_started = true
            ui_fade_step = 0
          end
        end
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
      pbHazardsResume(:vermeil_spikes_cast, false) if respond_to?(:pbHazardsResume)
    end
    return true
  end
end

class Battle
  alias_method :vermeil_spikes_cast_pbAnimation, :pbAnimation unless method_defined?(:vermeil_spikes_cast_pbAnimation)

  def pbAnimation(move, user, targets, hitNum = 0)
    move_id = VermeilBattleAnimations.resolve_move_id(move)
    if @showAnims && move_id == :SPIKES && @scene.respond_to?(:pbPlayVermeilSpikesCast)
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
        return if @scene.pbPlayVermeilSpikesCast(anim_user, side_index)
      end
    end
    vermeil_spikes_cast_pbAnimation(move, user, targets, hitNum)
  end
end

#===============================================================================
# [VERMEIL] BattleAnimations
# [006] Sticky Web Cast Animation
#===============================================================================

module VermeilBattleAnimations
  module_function

  STICKY_WEB_ASSETS = [
    "Graphics/UI/Battle/hazards/sticky_web",
    "Graphics/Animations/PRAS- Sticky Web",
    "Graphics/Animations/PRAS- Spider Web"
  ]
  STICKY_WEB_BALL_ASSETS = [
    "Graphics/Battle animations/ballBurst_particle",
    "Graphics/Animations/PRAS- Explosions"
  ]

  STICKY_WEB_SE_THROW = "Anim/PRSFX- String Shot1"
  STICKY_WEB_SE_CAST  = "Anim/PRSFX- Sticky Web"
  STICKY_WEB_SE_LAND  = "Anim/PRSFX- Spider Web2"
end

class Battle::Scene::Animation::VermeilStickyWebCast < Battle::Scene::Animation
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
    web_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::STICKY_WEB_ASSETS)
    return if !web_asset
    ball_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::STICKY_WEB_BALL_ASSETS)
    ball_asset = web_asset if !ball_asset

    @vermeil_effect_pics = []
    user_pic = addSprite(user_sprite, PictureOrigin::BOTTOM)
    forward_dir = (@user.index & 1) == 0 ? 1 : -1
    travel_scale = (@side_index == 0) ? 1.1 : 1.0

    user_pic.setSE(2, VermeilBattleAnimations::STICKY_WEB_SE_THROW, 84, 100)
    user_pic.moveDelta(0, 4, 8 * forward_dir, -7)
    user_pic.moveDelta(4, 4, -8 * forward_dir, 7)

    # Throw sticky "balls", then spawn web sheets only on impact.
    hits = [
      [-34, -2, 10],
      [30, 2, 12],
      [-12, 8, 14],
      [12, 10, 16]
    ]
    hits.each_with_index do |(ox, oy, t), i|
      # Projectile (small blob)
      blob = addNewSprite(user_sprite.x, user_sprite.y - 50, ball_asset, PictureOrigin::CENTER)
      @vermeil_effect_pics << blob
      blob.setZ(0, 96 + i)
      blob.setVisible(0, false)
      blob.setOpacity(0, 0)
      blob.setZoom(0, 22 + (i * 2))
      peak_x = (@anchor_x + (ox * 0.45)).round
      peak_y = @anchor_y - 56 - ((i % 2) * 8)
      land_x = (@anchor_x + (ox * travel_scale)).round
      land_y = @anchor_y + oy
      blob.setVisible(t, true)
      blob.moveOpacity(t, 1, 210)
      blob.moveXY(t, 7, peak_x, peak_y)
      blob.moveXY(t + 7, 6, land_x, land_y)
      blob.moveZoom(t, 13, 28 + (i * 2))
      blob.moveAngle(t, 13, (forward_dir * 320) + (i * 26))
      blob.moveOpacity(t + 13, 2, 0)
      blob.setVisible(t + 16, false)

      # Web born on impact
      web = addNewSprite(land_x, land_y, web_asset, PictureOrigin::CENTER)
      @vermeil_effect_pics << web
      web.setZ(0, 100 + i)
      web.setVisible(0, false)
      web.setOpacity(0, 0)
      web.setZoom(0, 26 + (i * 3))
      web.setSE(t + 12, VermeilBattleAnimations::STICKY_WEB_SE_LAND, 84, 98) if i == 1
      web.setVisible(t + 12, true)
      web.moveOpacity(t + 12, 2, 185)
      web.moveZoom(t + 12, 8, 86 + (i * 2))
      web.moveAngle(t + 12, 10, (forward_dir * 70) + (i * 14))
      web.moveDelta(t + 20, 2, 0, -2)
      web.moveDelta(t + 22, 2, 0, 2)
      web.moveOpacity(t + 24, 9, 0)
      web.setVisible(t + 34, false)
    end
    # Cast cue once when first blobs leave the user.
    cue = addNewSprite(@anchor_x, @anchor_y - 24, ball_asset, PictureOrigin::CENTER)
    @vermeil_effect_pics << cue
    cue.setZ(0, 95)
    cue.setVisible(0, false)
    cue.setOpacity(0, 0)
    cue.setZoom(0, 18)
    cue.setSE(9, VermeilBattleAnimations::STICKY_WEB_SE_CAST, 90, 100)
    cue.setVisible(9, true)
    cue.moveOpacity(9, 2, 120)
    cue.moveZoom(9, 6, 52)
    cue.moveOpacity(15, 5, 0)
    cue.setVisible(21, false)
  end
end

class Battle::Scene
  def pbPlayVermeilStickyWebCast(user, side_index)
    return false if !user
    web_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::STICKY_WEB_ASSETS)
    return false if !web_asset
    return false if !respond_to?(:vermeil_hazard_anchor_for_side)

    ax, ay = vermeil_hazard_anchor_for_side(side_index)
    vermeil_hazard_cast_text_lead_in(12) if respond_to?(:vermeil_hazard_cast_text_lead_in)
    pbHazardsSuspend(:vermeil_stickyweb_cast) if respond_to?(:pbHazardsSuspend)
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

      anim = Animation::VermeilStickyWebCast.new(@sprites, @viewport, user, ax, ay, side_index)
      cast_end_frame = 200
      min_play_frames = 54
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
      pbHazardsResume(:vermeil_stickyweb_cast, false) if respond_to?(:pbHazardsResume)
    end
    return true
  end
end

class Battle
  alias_method :vermeil_stickyweb_cast_pbAnimation, :pbAnimation unless method_defined?(:vermeil_stickyweb_cast_pbAnimation)

  def pbAnimation(move, user, targets, hitNum = 0)
    move_id = VermeilBattleAnimations.resolve_move_id(move)
    if @showAnims && move_id == :STICKYWEB && @scene.respond_to?(:pbPlayVermeilStickyWebCast)
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
        return if @scene.pbPlayVermeilStickyWebCast(anim_user, side_index)
      end
    end
    vermeil_stickyweb_cast_pbAnimation(move, user, targets, hitNum)
  end
end

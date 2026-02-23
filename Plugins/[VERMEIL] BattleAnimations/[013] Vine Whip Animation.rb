#===============================================================================
# [VERMEIL] BattleAnimations - Vine Whip v5 - Flawless Alignment & UI
#===============================================================================

module VermeilBattleAnimations
  module_function
  VINE_WHIP_ASSETS = ["Graphics/Animations/PRAS- Grass.png", "Graphics/Animations/PRAS- Grass"]
  VINE_WHIP_SE = "Anim/PRSFX- Vine Whip"
  def first_existing_asset(paths); paths.each { |p| return p if pbResolveBitmap(p) }; nil; end
  def resolve_move_id(move)
    return move.id if move.respond_to?(:id)
    d = GameData::Move.try_get(move); return d.id if d; move
  end
end

class Battle::Scene::Animation::VermeilCinematicVineWhip < Battle::Scene::Animation
  T_STRIKE = 2
  T_IMPACT = T_STRIKE + 4
  T_END    = T_IMPACT + 12

  def initialize(sprites, viewport, user, target)
    @user = user; @target = target; super(sprites, viewport)
  end

  def apply_pras_frame(sprite, absolute_frame, time = 0)
    fw = 192; fh = 192; cols = 5
    col = absolute_frame % cols; row = absolute_frame / cols
    sprite.setSrc(time, col * fw, row * fh)
    sprite.setSrcSize(time, fw, fh)
    if time == 0
      raw = @pictureSprites.last
      raw.src_rect.set(col * fw, row * fh, fw, fh) if raw && raw.respond_to?(:src_rect) && raw.src_rect
    end
  end

  def play_pras_sequence(sprite, start_time, start_frame, num_frames, ticks = 3)
    apply_pras_frame(sprite, start_frame, 0)
    dur = num_frames * ticks
    dur.times { |j| apply_pras_frame(sprite, start_frame + (j / ticks).floor, start_time + j) }
    return dur
  end

  def createProcesses
    return if !@user || !@target
    us = @sprites["pokemon_#{@user.index}"]; ts = @sprites["pokemon_#{@target.index}"]
    return if !us || !ts
    asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::VINE_WHIP_ASSETS)
    return if !asset

    f_dir = (@user.index & 1) == 0 ? 1 : -1
    
    # --- ALINEACIÓN EXACTA BASADA EN SNIPE SHOT ---
    t_h = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    ix = ts.x
    iy = ts.y - t_h

    up = addSprite(us, PictureOrigin::BOTTOM)
    tp = addSprite(ts, PictureOrigin::BOTTOM)

    up.moveDelta(T_STRIKE, 2, 10 * f_dir, 0)
    up.moveDelta(T_STRIKE + 2, 4, -10 * f_dir, 0)

    whip = addNewSprite(ix, iy, asset, PictureOrigin::CENTER)
    whip.setZ(0, 760); whip.setVisible(0, false)
    whip.setZoomXY(0, f_dir == 1 ? 130 : -130, 130) 

    whip.setVisible(T_STRIKE, true)
    whip.setSE(T_STRIKE, VermeilBattleAnimations::VINE_WHIP_SE, 100, 100)
    
    dur = play_pras_sequence(whip, T_STRIKE, 5, 5, 2)
    whip.setVisible(T_STRIKE + dur, false)

    tp.moveTone(T_IMPACT, 2, Tone.new(0, 80, 0, 0)) 
    tp.moveTone(T_IMPACT + 2, 6, Tone.new(0, 0, 0, 0))
    tp.setSE(T_IMPACT, "Anim/PRSFX- Slash2", 90, 100) 
    
    shake = 12
    tp.moveDelta(T_IMPACT, 1, shake * f_dir, 0)
    tp.moveDelta(T_IMPACT + 1, 2, -shake * 2 * f_dir, 0)
    tp.moveDelta(T_IMPACT + 3, 1, shake * f_dir, 0)
  end
end

class Battle
  alias_method :vermeil_vinewhip_pbAnimation, :pbAnimation unless method_defined?(:vermeil_vinewhip_pbAnimation)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = VermeilBattleAnimations.resolve_move_id(move)
    if @showAnims && mid == :VINEWHIP && @scene.respond_to?(:pbPlayVermeilVineWhip)
      if hitNum.to_i <= 0
        @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
        @scene.instance_variable_set(:@vermeil_ss_sequence_done,   false)
      end
      return if @scene.pbPlayVermeilVineWhip(user, targets)
    end
    if @scene && mid == :VINEWHIP
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, false)
      @scene.instance_variable_set(:@vermeil_ss_sequence_done,   false)
      @scene.instance_variable_set(:@vermeil_ss_anim_active,     false)
      @scene.vermeil_ss_set_message_skin(false) if @scene.respond_to?(:vermeil_ss_set_message_skin)
      @scene.vermeil_ss_clear_message_window! if @scene.respond_to?(:vermeil_ss_clear_message_window!)
    end
    vermeil_vinewhip_pbAnimation(move, user, targets, hitNum)
  end
end

class Battle::Scene
  unless method_defined?(:pbPlayVermeilVineWhip)
    def pbPlayVermeilVineWhip(user, targets)
      target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
      return false if !user || !target

      @vermeil_ss_anim_active = true if respond_to?(:vermeil_ss_set_message_skin)
      vermeil_ss_set_message_skin(true) if respond_to?(:vermeil_ss_set_message_skin)
      vermeil_ss_clear_message_window! if respond_to?(:vermeil_ss_clear_message_window!)
      pbToggleDataboxes if respond_to?(:pbToggleDataboxes)

      begin
        anim = Animation::VermeilCinematicVineWhip.new(@sprites, @viewport, user, target)
        loop do anim.update; pbUpdate; break if anim.animDone?; end
        anim.dispose
      ensure
        if respond_to?(:vermeil_ss_set_message_skin)
          @vermeil_ss_anim_active = false
          @vermeil_ss_sequence_active = false
          @vermeil_ss_sequence_done = true
          vermeil_ss_set_message_skin(false)
        end
        pbToggleDataboxes(true) if respond_to?(:pbToggleDataboxes)
        pbRefresh if respond_to?(:pbRefresh)
      end
      return true
    end
  end
end
#===============================================================================
# [VERMEIL] BattleAnimations - Ember v6 - Compact Fireball & Flawless UI
#===============================================================================

module VermeilBattleAnimations
  module_function
  EMBER_ASSETS = ["Graphics/Animations/PRAS- Fire.png", "Graphics/Animations/PRAS- Fire"]
  EMBER_SE = "Anim/PRSFX- Ember"
  def first_existing_asset(paths); paths.each { |p| return p if pbResolveBitmap(p) }; nil; end
  def resolve_move_id(move)
    return move.id if move.respond_to?(:id)
    d = GameData::Move.try_get(move); return d.id if d; move
  end
end

class Battle::Scene::Animation::VermeilCinematicEmber < Battle::Scene::Animation
  T_SHOOT  = 2
  T_TRAVEL = 5
  T_IMPACT = T_SHOOT + T_TRAVEL
  T_END    = T_IMPACT + 15

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
    asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::EMBER_ASSETS)
    return if !asset

    f_dir = (@user.index & 1) == 0 ? 1 : -1
    
    # --- ALINEACIÓN EXACTA ---
    u_h = us.bitmap ? (us.bitmap.height / 2.0) : 40
    t_h = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    sx = us.x + (40 * f_dir)
    sy = us.y - u_h
    ix = ts.x - (10 * f_dir)
    iy = ts.y - t_h

    dx = ix - sx; dy = iy - sy
    angle = -Math.atan2(dy, dx) * 180 / Math::PI

    up = addSprite(us, PictureOrigin::BOTTOM)
    tp = addSprite(ts, PictureOrigin::BOTTOM)

    up.moveDelta(T_SHOOT, 2, -6 * f_dir, 0)
    up.moveDelta(T_SHOOT + 2, 4, 6 * f_dir, 0)

    # --- PROYECTIL: Tamaño Reducido ---
    proj = addNewSprite(sx, sy, asset, PictureOrigin::CENTER)
    proj.setZ(0, 750); proj.setVisible(0, false)
    apply_pras_frame(proj, 0, 0) 
    
    proj.setAngle(0, angle)
    proj.setZoom(0, 45) # ANTES: 80. Ahora es una llamita pequeña y contenida.
    proj.setVisible(T_SHOOT, true)
    proj.setSE(T_SHOOT, VermeilBattleAnimations::EMBER_SE, 100, 100)
    proj.moveXY(T_SHOOT, T_TRAVEL, ix, iy)
    proj.setVisible(T_IMPACT, false)

    # --- IMPACTO: Chispas Proporcionales ---
    impact = addNewSprite(ix, iy, asset, PictureOrigin::CENTER)
    impact.setZ(0, 760); impact.setVisible(0, false)
    impact.setZoom(0, 60) # ANTES: 90. Explosión reducida para encajar con el proyectil.
    
    impact.setVisible(T_IMPACT, true)
    dur = play_pras_sequence(impact, T_IMPACT, 15, 4, 2) 
    impact.setVisible(T_IMPACT + dur, false)

    tp.moveTone(T_IMPACT, 2, Tone.new(100, 0, 0, 0))
    tp.moveTone(T_IMPACT + 4, 6, Tone.new(0, 0, 0, 0))
    tp.moveDelta(T_IMPACT, 2, 6 * f_dir, 0)
    tp.moveDelta(T_IMPACT + 2, 2, -12 * f_dir, 0)
    tp.moveDelta(T_IMPACT + 4, 2, 6 * f_dir, 0)
  end
end

class Battle
  alias_method :vermeil_ember_pbAnimation, :pbAnimation unless method_defined?(:vermeil_ember_pbAnimation)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = VermeilBattleAnimations.resolve_move_id(move)
    if @showAnims && mid == :EMBER && @scene.respond_to?(:pbPlayVermeilEmber)
      if hitNum.to_i <= 0
        @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
        @scene.instance_variable_set(:@vermeil_ss_sequence_done,   false)
      end
      return if @scene.pbPlayVermeilEmber(user, targets)
    end
    # Cleanup si se atasca
    if @scene && mid == :EMBER
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, false)
      @scene.instance_variable_set(:@vermeil_ss_sequence_done,   false)
      @scene.instance_variable_set(:@vermeil_ss_anim_active,     false)
      @scene.vermeil_ss_set_message_skin(false) if @scene.respond_to?(:vermeil_ss_set_message_skin)
      @scene.vermeil_ss_clear_message_window! if @scene.respond_to?(:vermeil_ss_clear_message_window!)
    end
    vermeil_ember_pbAnimation(move, user, targets, hitNum)
  end
end

class Battle::Scene
  unless method_defined?(:pbPlayVermeilEmber)
    def pbPlayVermeilEmber(user, targets)
      target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
      return false if !user || !target

      @vermeil_ss_anim_active = true if respond_to?(:vermeil_ss_set_message_skin)
      vermeil_ss_set_message_skin(true) if respond_to?(:vermeil_ss_set_message_skin)
      vermeil_ss_clear_message_window! if respond_to?(:vermeil_ss_clear_message_window!)
      

      begin
        anim = Animation::VermeilCinematicEmber.new(@sprites, @viewport, user, target)
        loop do anim.update; pbUpdate; break if anim.animDone?; end
        anim.dispose
      ensure
        if respond_to?(:vermeil_ss_set_message_skin)
          @vermeil_ss_anim_active = false
          @vermeil_ss_sequence_active = false
          @vermeil_ss_sequence_done = true
          vermeil_ss_set_message_skin(false)
        end
        pbRefresh if respond_to?(:pbRefresh)
      end
      return true
    end
  end
end
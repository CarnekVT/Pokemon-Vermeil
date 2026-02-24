#===============================================================================
# [VERMEIL] BattleAnimations - Focus Punch
# Fix: Internal methods restored. Native UI Overlay Patch for HP drain.
#===============================================================================

# ANIMACIÓN DE CARGA (Turno 1)
class Battle::Scene::Animation::VermeilFocusPunchCharge < Battle::Scene::Animation
  T_END = 40
  def initialize(sprites, viewport, user)
    @user = user; super(sprites, viewport)
  end

  def create_battler_clone(original_sprite)
    clone = Sprite.new(@viewport); clone.bitmap = original_sprite.bitmap
    if original_sprite.respond_to?(:src_rect) && original_sprite.src_rect
      clone.src_rect.set(original_sprite.src_rect.x, original_sprite.src_rect.y, original_sprite.src_rect.width, original_sprite.src_rect.height)
    end
    clone.ox = original_sprite.ox; clone.oy = original_sprite.oy; clone.x = original_sprite.x; clone.y = original_sprite.y
    clone.zoom_x = original_sprite.zoom_x; clone.zoom_y = original_sprite.zoom_y; clone.mirror = original_sprite.mirror
    @tempSprites << clone; return clone
  end

  def createProcesses
    us = @sprites["pokemon_#{@user.index}"]; return if !us
    f_dir = (@user.index & 1) == 0 ? 1 : -1
    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM)
    up.setZ(0, (us.z rescue 300) + 50); us.visible = false

    up.setSE(2, "Anim/Earth1", 100, 80)
    up.moveTone(2, 20, Tone.new(255, 100, 0, 100))
    up.moveXY(2, 20, up.x - (20 * f_dir), up.y) # Se echa hacia atrás concentrándose
    25.times { |i| up.moveDelta(2 + i, 1, (i.even? ? 4 : -4), 0) } # Tiembla de poder
    
    up.moveTone(30, 10, Tone.new(0,0,0,0)); up.moveXY(30, 10, us.x, us.y)
    up.setCallback(T_END, proc { us.visible = true })
  end
end

# ANIMACIÓN DE IMPACTO (Turno 2)
class Battle::Scene::Animation::VermeilFocusPunchStrike < Battle::Scene::Animation
  T_SHOOT = 2; T_IMPACT = 6; T_END = 50
  def initialize(sprites, viewport, user, target)
    @user = user; @target = target; super(sprites, viewport)
  end

  def apply_pras_frame(sprite, path, col, row, time = 0)
    resolved = pbResolveBitmap(path); return if !resolved
    fw = 192; fh = 192
    sprite.setSrc(time, col * fw, row * fh); sprite.setSrcSize(time, fw, fh)
    if time == 0 && (raw = @pictureSprites.last) && raw.respond_to?(:src_rect) && raw.src_rect
      raw.src_rect.set(col * fw, row * fh, fw, fh)
    end
  end

  def create_battler_clone(original_sprite)
    clone = Sprite.new(@viewport); clone.bitmap = original_sprite.bitmap
    if original_sprite.respond_to?(:src_rect) && original_sprite.src_rect
      clone.src_rect.set(original_sprite.src_rect.x, original_sprite.src_rect.y, original_sprite.src_rect.width, original_sprite.src_rect.height)
    end
    clone.ox = original_sprite.ox; clone.oy = original_sprite.oy; clone.x = original_sprite.x; clone.y = original_sprite.y
    clone.zoom_x = original_sprite.zoom_x; clone.zoom_y = original_sprite.zoom_y; clone.mirror = original_sprite.mirror
    @tempSprites << clone; return clone
  end

  def createProcesses
    us, ts = @sprites["pokemon_#{@user.index}"], @sprites["pokemon_#{@target.index}"]
    return if !us || !ts
    f_dir = (@user.index & 1) == 0 ? 1 : -1
    
    punches = pbResolveBitmap("Graphics/Animations/PRAS- Pummeling.png") ? "Graphics/Animations/PRAS- Pummeling.png" : "Graphics/Animations/punches.png"
    bg_asset = (f_dir == 1) ? "Graphics/Animations/PRAS- Focus Punch BG.png" : "Graphics/Animations/PRAS- Focus Punch Opp BG.png"

    target_z = (ts.z rescue 300) + 10
    user_z   = target_z + 40

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, user_z)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, target_z)
    us.visible = false; ts.visible = false

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    i_x = ts.x; i_y = ts.y - th; orig_ux = us.x; orig_uy = us.y; orig_tx = ts.x; orig_ty = ts.y

    bg = addNewSprite(Graphics.width/2, Graphics.height/2, bg_asset, PictureOrigin::CENTER) rescue nil
    if bg
      bg.setZ(0, 15); bg.setOpacity(0, 0); bg.setZoom(0, 150)
      bg.setVisible(0, false); bg.setVisible(T_IMPACT, true)
      bg.moveOpacity(T_IMPACT, 2, 255); bg.moveOpacity(T_END - 10, 10, 0)
    end

    up.setSE(T_SHOOT, "Anim/Wind1", 100, 130)
    up.moveXY(T_SHOOT, 2, orig_ux + (20 * f_dir), orig_uy)
    
    if pbResolveBitmap(punches)
      fist = addNewSprite(orig_ux + (20 * f_dir), orig_uy - uh, punches, PictureOrigin::CENTER); fist.setZ(0, user_z + 5)
      apply_pras_frame(fist, punches, 0, 0, 0)
      fist.setAngle(0, f_dir == 1 ? 0 : 180); fist.setZoom(0, 150)
      fist.setVisible(0, false); fist.setVisible(T_SHOOT, true)
      fist.moveXY(T_SHOOT, 3, i_x, i_y); fist.moveOpacity(T_IMPACT, 1, 0)
    end

    tp.setSE(T_IMPACT, "Anim/Super Damage", 100, 90)
    flash = addNewSprite(0, 0, "Graphics/Battle animations/white_screen") rescue nil
    if flash
      flash.setZ(0, 800); flash.setOpacity(0, 0); flash.moveOpacity(T_IMPACT, 1, 255); flash.moveOpacity(T_IMPACT + 3, 6, 0)
    end

    tp.moveXY(T_IMPACT, 4, orig_tx + (100 * f_dir), orig_ty - 20)
    tp.moveXY(T_IMPACT + 4, 6, orig_tx + (120 * f_dir), orig_ty)
    tp.moveXY(T_IMPACT + 15, 10, orig_tx, orig_ty)

    up.moveXY(T_IMPACT + 10, 10, orig_ux, orig_uy)
    up.setCallback(T_END, proc { us.visible = true; ts.visible = true })
  end
end

class Battle
  alias_method :vermeil_focus_punch_common_anim, :pbCommonAnimation unless method_defined?(:vermeil_focus_punch_common_anim)
  def pbCommonAnimation(animName, user = nil, target = nil)
    if @showAnims && animName == "FocusPunch" && user && @scene.respond_to?(:pbPlayVermeilFocusPunch)
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
      return if @scene.pbPlayVermeilFocusPunch(user, target, true)
    end
    vermeil_focus_punch_common_anim(animName, user, target)
  end

  alias_method :vermeil_focus_punch_anim, :pbAnimation unless method_defined?(:vermeil_focus_punch_anim)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = move.respond_to?(:id) ? move.id : move
    if @showAnims && mid == :FOCUSPUNCH && @scene.respond_to?(:pbPlayVermeilFocusPunch)
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
      return if @scene.pbPlayVermeilFocusPunch(user, targets, false)
    end
    vermeil_focus_punch_anim(move, user, targets, hitNum)
  end
end

class Battle::Scene
  def pbPlayVermeilFocusPunch(user, targets, is_charging)
    @vermeil_ss_anim_active = true
    vermeil_ss_set_message_skin(true) rescue nil
    vermeil_ss_clear_message_window! rescue nil
    
    
    begin
      if is_charging
        anim = Animation::VermeilFocusPunchCharge.new(@sprites, @viewport, user)
      else
        target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
        return false if !target
        anim = Animation::VermeilFocusPunchStrike.new(@sprites, @viewport, user, target)
      end
      loop do anim.update; pbUpdate; break if anim.animDone? end; anim.dispose
    ensure
      us = @sprites["pokemon_#{user.index}"]; us.visible = true if us
      if !is_charging
        target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
        ts = @sprites["pokemon_#{target.index}"] if target; ts.visible = true if ts
      end
      
      @vermeil_ss_anim_active = false
      vermeil_ss_set_message_skin(false) rescue nil
      pbRefresh if respond_to?(:pbRefresh)
    end
    return true
  end
end
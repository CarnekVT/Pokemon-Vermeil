#===============================================================================
# [VERMEIL] BattleAnimations - Sky Uppercut
# Fix: Internal methods restored. Native UI Overlay Patch for HP drain.
#===============================================================================

class Battle::Scene::Animation::VermeilSkyUppercut < Battle::Scene::Animation
  T_WINDUP = 2; T_VANISH = 6; T_IMPACT = 10; T_END = 55

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
    
    bg_asset = "Graphics/Animations/PRAS- Sky Uppercut BG.png"
    punches  = pbResolveBitmap("Graphics/Animations/PRAS- Pummeling.png") ? "Graphics/Animations/PRAS- Pummeling.png" : "Graphics/Animations/punches.png"
    strike   = "Graphics/Animations/PRAS- Strike.png"

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

    up.setXY(0, orig_ux, orig_uy)
    up.setSE(T_WINDUP, "Anim/Earth1", 100, 80)
    up.moveXY(T_WINDUP, 4, orig_ux + (10 * f_dir), orig_uy + 20) 
    up.setSE(T_VANISH, "Anim/Wind1", 100, 150)
    up.moveOpacity(T_VANISH, 2, 0)

    if pbResolveBitmap(punches)
      fist = addNewSprite(i_x - (20 * f_dir), i_y + 80, punches, PictureOrigin::CENTER); fist.setZ(0, target_z + 15)
      apply_pras_frame(fist, punches, 0, 0, 0) 
      fist.setAngle(0, -90); fist.setVisible(0, false); fist.setVisible(T_IMPACT - 2, true); fist.setZoom(0, 180)
      fist.moveXY(T_IMPACT - 2, 4, i_x, i_y - 200); fist.moveOpacity(T_IMPACT + 4, 2, 0)
    end

    if pbResolveBitmap(strike)
      pillar = addNewSprite(i_x, i_y + 60, strike, PictureOrigin::CENTER); pillar.setZ(0, target_z + 14)
      apply_pras_frame(pillar, strike, 0, 0, 0)
      pillar.setBlendType(0, 1); pillar.setTone(0, Tone.new(255, 150, 50, 0)); pillar.setAngle(0, -90)
      pillar.setVisible(0, false); pillar.setVisible(T_IMPACT, true); pillar.setZoomXY(0, 100, 300) 
      pillar.moveXY(T_IMPACT, 5, i_x, i_y - 250); pillar.moveOpacity(T_IMPACT + 4, 4, 0)
    end

    tp.setSE(T_IMPACT, "Anim/Super Damage", 100, 90)
    flash = addNewSprite(0, 0, "Graphics/Battle animations/white_screen") rescue nil
    if flash
      flash.setZ(0, 800); flash.setOpacity(0, 0); flash.moveOpacity(T_IMPACT, 1, 150); flash.moveOpacity(T_IMPACT + 3, 5, 0)
    end

    # Perfect Gravity Arch
    tp.moveXY(T_IMPACT, 4, orig_tx, orig_ty - 220)      
    tp.moveXY(T_IMPACT + 4, 8, orig_tx, orig_ty - 190)  
    tp.moveXY(T_IMPACT + 12, 6, orig_tx, orig_ty)       
    
    tp.setSE(T_IMPACT + 18, "Anim/Earth1", 100, 120)    
    6.times { |i| tp.moveDelta(T_IMPACT + 18 + i, 1, 0, (i.even? ? 8 : -8)) }
    tp.setXY(T_END - 1, orig_tx, orig_ty) # Absolute anchor back to normal

    up.setXY(T_IMPACT + 15, orig_ux, orig_uy); up.moveOpacity(T_IMPACT + 16, 4, 255)
    up.setCallback(T_END, proc { us.visible = true; ts.visible = true })
  end
end

class Battle
  alias_method :vermeil_sky_uppercut_anim, :pbAnimation unless method_defined?(:vermeil_sky_uppercut_anim)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = move.respond_to?(:id) ? move.id : move
    if @showAnims && mid == :SKYUPPERCUT && @scene.respond_to?(:pbPlayVermeilSkyUppercut)
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
      return if @scene.pbPlayVermeilSkyUppercut(user, targets)
    end
    vermeil_sky_uppercut_anim(move, user, targets, hitNum)
  end
end

class Battle::Scene
  def pbPlayVermeilSkyUppercut(user, targets)
    target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
    return false if !user || !target
    @vermeil_ss_anim_active = true
    
    vermeil_ss_set_message_skin(true) rescue nil
    vermeil_ss_clear_message_window! rescue nil
    
    
    begin
      anim = Animation::VermeilSkyUppercut.new(@sprites, @viewport, user, target)
      loop do anim.update; pbUpdate; break if anim.animDone? end; anim.dispose
    ensure
      us, ts = @sprites["pokemon_#{user.index}"], @sprites["pokemon_#{target.index}"]
      us.visible = true if us; ts.visible = true if ts
      
      @vermeil_ss_anim_active = false
      vermeil_ss_set_message_skin(false) rescue nil
      pbRefresh if respond_to?(:pbRefresh)
    end
    return true
  end
end
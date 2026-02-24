#===============================================================================
# [VERMEIL] BattleAnimations - Meteor Mash
# Fix: Internal methods restored. Native UI Overlay Patch for HP drain.
#===============================================================================

class Battle::Scene::Animation::VermeilMeteorMash < Battle::Scene::Animation
  T_WINDUP = 2; T_SHOOT = 8; T_IMPACT = 12; T_END = 50

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
    
    swift    = pbResolveBitmap("Graphics/Animations/PRAS- Swift.png") ? "Graphics/Animations/PRAS- Swift.png" : "Graphics/Animations/PRAS- Meteor Mash.png"
    pummelin = pbResolveBitmap("Graphics/Animations/PRAS- Pummeling.png") ? "Graphics/Animations/PRAS- Pummeling.png" : "Graphics/Animations/punches.png"

    target_z = (ts.z rescue 300) + 10
    user_z   = target_z + 40

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, user_z)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, target_z)
    us.visible = false; ts.visible = false

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    i_x = ts.x; i_y = ts.y - th; orig_ux = us.x; orig_uy = us.y

    up.setSE(T_WINDUP, "Anim/Earth1", 100, 90)
    up.moveXY(T_WINDUP, 6, orig_ux - (15 * f_dir), orig_uy)
    up.moveTone(T_WINDUP, 6, Tone.new(100, 150, 255, 100)) 
    
    up.setSE(T_SHOOT, "Anim/Wind1", 100, 110)
    up.moveXY(T_SHOOT, 3, orig_ux + (20 * f_dir), orig_uy)

    # El Meteoro desciende en diagonal
    start_x = i_x - (120 * f_dir); start_y = i_y - 150
    angle = f_dir == 1 ? 45 : 135 
    
    if pbResolveBitmap(swift)
      meteor = addNewSprite(start_x, start_y, swift, PictureOrigin::CENTER); meteor.setZ(0, target_z + 15)
      apply_pras_frame(meteor, swift, 0, 0, 0)
      meteor.setBlendType(0, 1); meteor.setTone(0, Tone.new(150, 200, 255, 0))
      meteor.setVisible(0, false); meteor.setVisible(T_SHOOT, true)
      meteor.setZoom(0, 200); meteor.moveAngle(T_SHOOT, 10, rand(360))
      meteor.moveXY(T_SHOOT, 4, i_x, i_y); meteor.moveOpacity(T_IMPACT, 1, 0)
    end

    if pbResolveBitmap(pummelin)
      fist = addNewSprite(start_x, start_y, pummelin, PictureOrigin::CENTER); fist.setZ(0, target_z + 16)
      apply_pras_frame(fist, pummelin, 0, 0, 0) 
      fist.setTone(0, Tone.new(100, 150, 255, 0)); fist.setAngle(0, angle); fist.setZoom(0, 120)
      fist.setVisible(0, false); fist.setVisible(T_SHOOT, true)
      fist.moveXY(T_SHOOT, 4, i_x, i_y); fist.moveOpacity(T_IMPACT, 1, 0)
    end

    tp.setSE(T_IMPACT, "Anim/Super Damage", 100, 100)
    tp.moveColor(T_IMPACT, 2, Color.new(200, 220, 255, 200)); tp.moveColor(T_IMPACT + 4, 6, Color.new(0, 0, 0, 0))
    6.times { |i| tp.moveDelta(T_IMPACT + i, 1, (i.even? ? 12 : -12) * f_dir, (i.even? ? 8 : -8)) }

    flash = addNewSprite(0, 0, "Graphics/Battle animations/white_screen") rescue nil
    if flash
      flash.setZ(0, 800); flash.setOpacity(0, 0); flash.moveOpacity(T_IMPACT, 1, 180); flash.moveOpacity(T_IMPACT + 3, 5, 0)
    end

    if pbResolveBitmap(swift)
      25.times do |i|
        s = addNewSprite(i_x, i_y, swift, PictureOrigin::CENTER); s.setZ(0, target_z + 20)
        apply_pras_frame(s, swift, rand(4), 0, 0) 
        s.setBlendType(0, 1)
        s.setVisible(0, false); s.setVisible(T_IMPACT, true); s.setZoom(0, 50 + rand(50))
        s.moveXY(T_IMPACT, 5 + rand(5), i_x + (rand(300) - 150), i_y + (rand(300) - 150))
        s.moveOpacity(T_IMPACT + 3, 6, 0)
      end
    end

    up.moveTone(T_IMPACT + 5, 8, Tone.new(0,0,0,0)); up.moveXY(T_IMPACT + 8, 6, orig_ux, orig_uy)
    up.setCallback(T_END, proc { us.visible = true; ts.visible = true })
  end
end

class Battle
  alias_method :vermeil_meteor_mash_anim, :pbAnimation unless method_defined?(:vermeil_meteor_mash_anim)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = move.respond_to?(:id) ? move.id : move
    if @showAnims && mid == :METEORMASH && @scene.respond_to?(:pbPlayVermeilMeteorMash)
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
      return if @scene.pbPlayVermeilMeteorMash(user, targets)
    end
    vermeil_meteor_mash_anim(move, user, targets, hitNum)
  end
end

class Battle::Scene
  def pbPlayVermeilMeteorMash(user, targets)
    target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
    return false if !user || !target
    @vermeil_ss_anim_active = true
    
    vermeil_ss_set_message_skin(true) rescue nil
    vermeil_ss_clear_message_window! rescue nil
    
    
    begin
      anim = Animation::VermeilMeteorMash.new(@sprites, @viewport, user, target)
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
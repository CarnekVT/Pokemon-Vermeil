#===============================================================================
# [VERMEIL] BattleAnimations - Elemental Punches (Fire, Ice, Thunder)
# Fix: Absolute High Z-Index & Native UI Overlay Patch.
#===============================================================================

class Battle::Scene::Animation::VermeilElementalPunches < Battle::Scene::Animation
  T_WINDUP = 2; T_SHOOT = 6; T_IMPACT = 10; T_END = 35

  def initialize(sprites, viewport, user, target, move_id)
    @user = user; @target = target; @move_id = move_id
    super(sprites, viewport)
  end

  def apply_pras_frame(sprite, path, col, row, time = 0)
    resolved = pbResolveBitmap(path); return if !resolved
    fw = 192; fh = 192
    sprite.setSrc(time, col * fw, row * fh); sprite.setSrcSize(time, fw, fh)
    if time == 0 && (raw = @pictureSprites.last) && raw.src_rect
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
    return if !@user || !@target
    us, ts = @sprites["pokemon_#{@user.index}"], @sprites["pokemon_#{@target.index}"]
    f_dir = (@user.index & 1) == 0 ? 1 : -1
    
    punches = "Graphics/Animations/punches.png"
    elem_bg = "Graphics/Animations/GEN8- Elemental Punch.png"
    
    c_fist = 0; r_fist = 0; r_spark = 0; tone = Tone.new(0,0,0,0); se_hit = "Anim/Hit1"
    case @move_id
    when :FIREPUNCH;    c_fist = 0; r_fist = 0; r_spark = 0; tone = Tone.new(255,50,0,0); se_hit = "Anim/Fire2"
    when :ICEPUNCH;     c_fist = 1; r_fist = 1; r_spark = 1; tone = Tone.new(0,200,255,0); se_hit = "Anim/Ice1"
    when :THUNDERPUNCH; c_fist = 1; r_fist = 0; r_spark = 2; tone = Tone.new(255,255,0,0); se_hit = "Anim/Thunder3"
    end

    # Absolute Z-Index so backgrounds NEVER cover the battlers
    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, 650)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, 600)
    us.visible = false; ts.visible = false

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    i_x = ts.x; i_y = ts.y - th; orig_ux = us.x; orig_uy = us.y

    up.setXY(0, orig_ux, orig_uy)
    up.moveDelta(T_WINDUP, 3, 20 * f_dir, 0); up.moveTone(T_WINDUP, 4, tone)
    up.setSE(T_SHOOT, "Anim/Wind1", 100, 120)

    if pbResolveBitmap(punches)
      fist = addNewSprite(orig_ux + (40 * f_dir), orig_uy - uh, punches, PictureOrigin::CENTER)
      fist.setZ(0, 655)
      apply_pras_frame(fist, punches, c_fist, r_fist, 0)
      fist.setAngle(0, f_dir == 1 ? 0 : 180); fist.setVisible(0, false); fist.setVisible(T_SHOOT, true)
      fist.setZoom(0, 100); fist.moveXY(T_SHOOT, 4, i_x, i_y); fist.moveOpacity(T_IMPACT, 1, 0)
    end

    tp.setSE(T_IMPACT, se_hit, 100, 100)
    tp.moveColor(T_IMPACT, 2, Color.new(255, 255, 255, 255)); tp.moveColor(T_IMPACT + 3, 5, Color.new(0,0,0,0))
    4.times { |i| tp.moveDelta(T_IMPACT + i, 1, (i.even? ? 10 : -10) * f_dir, 0) }

    if pbResolveBitmap(elem_bg)
      12.times do |i|
        p = addNewSprite(i_x, i_y, elem_bg, PictureOrigin::CENTER); p.setZ(0, 615)
        apply_pras_frame(p, elem_bg, rand(1..4), r_spark, 0)
        p.setBlendType(0, 1); p.setTone(0, tone)
        p.setVisible(0, false); p.setVisible(T_IMPACT, true)
        p.setZoom(0, 50 + rand(40))
        p.moveXY(T_IMPACT, 5 + rand(3), i_x + (rand(160) - 80), i_y + (rand(160) - 80))
        p.moveOpacity(T_IMPACT + 3, 5, 0)
      end
    end

    up.moveTone(T_IMPACT + 5, 5, Tone.new(0,0,0,0)); up.moveXY(T_IMPACT + 5, 5, orig_ux, orig_uy)
    up.setCallback(T_END, proc { us.visible = true; ts.visible = true })
  end
end

class Battle
  alias_method :vermeil_elem_punch_anim, :pbAnimation unless method_defined?(:vermeil_elem_punch_anim)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = move.respond_to?(:id) ? move.id : move
    if @showAnims && [:FIREPUNCH, :ICEPUNCH, :THUNDERPUNCH].include?(mid) && @scene.respond_to?(:pbPlayVermeilElementalPunches)
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
      return if @scene.pbPlayVermeilElementalPunches(user, targets, mid)
    end
    vermeil_elem_punch_anim(move, user, targets, hitNum)
  end
end

class Battle::Scene
  def pbPlayVermeilElementalPunches(user, targets, mid)
    target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
    return false if !user || !target
    @vermeil_ss_anim_active = true
    vermeil_ss_set_message_skin(true) rescue nil
    vermeil_ss_clear_message_window! rescue nil
    pbToggleDataboxes if respond_to?(:pbToggleDataboxes)
    begin
      anim = Animation::VermeilElementalPunches.new(@sprites, @viewport, user, target, mid)
      loop do anim.update; pbUpdate; break if anim.animDone? end; anim.dispose
    ensure
      us, ts = @sprites["pokemon_#{user.index}"], @sprites["pokemon_#{target.index}"]
      us.visible = true if us; ts.visible = true if ts
      @vermeil_ss_anim_active = false
      vermeil_ss_set_message_skin(false) rescue nil
      pbToggleDataboxes(true) if respond_to?(:pbToggleDataboxes)
      pbRefresh if respond_to?(:pbRefresh)
    end
    return true
  end
end
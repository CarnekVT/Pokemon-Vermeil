#===============================================================================
# [VERMEIL] BattleAnimations - Absorb (Official Game Feel)
#===============================================================================

module VermeilBattleAnimations
  module_function
  ABS_ENERGY = ["Graphics/Animations/PRAS- Magical Leaf.png", "Graphics/Animations/PRAS- Magical Leaf"]
  ABS_SE     = "Anim/PRSFX- Mega Drain2" 
  def first_existing_asset(paths); paths.each { |p| return p if pbResolveBitmap(p) }; nil; end
  def resolve_move_id(move)
    return move.id if move.respond_to?(:id); d = GameData::Move.try_get(move); return d.id if d; move
  end
end

class Battle::Scene::Animation::VermeilCinematicAbsorb < Battle::Scene::Animation
  T_IMPACT = 2; T_DRAIN = 6; T_END = 35
  def initialize(sprites, viewport, user, target); @user = user; @target = target; super(sprites, viewport); end

  def apply_pras_frame(sprite, col, row, time = 0)
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
    clone.ox, clone.oy = original_sprite.ox, original_sprite.oy; clone.x, clone.y = original_sprite.x, original_sprite.y
    clone.zoom_x, clone.zoom_y = original_sprite.zoom_x, original_sprite.zoom_y; clone.mirror = original_sprite.mirror
    @tempSprites << clone; return clone
  end

  def createProcesses
    return if !@user || !@target
    us, ts = @sprites["pokemon_#{@user.index}"], @sprites["pokemon_#{@target.index}"]
    ene_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::ABS_ENERGY)
    f_dir = (@user.index & 1) == 0 ? 1 : -1

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, 600)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, 600)
    us.visible = false; ts.visible = false

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    c_x, c_y = us.x + (40 * f_dir), us.y - uh; i_x, i_y = ts.x - (10 * f_dir), ts.y - th

    # 1. IMPACTO (Destello blanco y luego palidez)
    tp.setSE(T_IMPACT, VermeilBattleAnimations::ABS_SE, 100, 110)
    tp.moveColor(T_IMPACT, 2, Color.new(255, 255, 255, 200))
    tp.moveColor(T_IMPACT + 2, 4, Color.new(255, 255, 255, 0))
    tp.moveTone(T_IMPACT + 6, 4, Tone.new(-40, -40, -40, 50)) # Pierde color

    # 2. DRENAJE ORGÁNICO (Luz Aditiva)
    12.times do |i|
      t_s = T_DRAIN + (i * 2)
      p = addNewSprite(i_x, i_y, ene_asset, PictureOrigin::CENTER); p.setZ(0, 750)
      apply_pras_frame(p, 0, 0, 0) # Control absoluto: Fila 0, Columna 0
      p.setBlendType(0, 1) # RENDER ADITIVO (Luz Brillante)
      p.setTone(0, Tone.new(0, 100, 0, 0)) 
      p.setVisible(0, false); p.setVisible(t_s, true); p.setZoom(t_s, 30 + rand(15))
      
      # Pop Out (Estallar)
      pop_x = i_x + (rand(80) - 40); pop_y = i_y + (rand(80) - 40)
      p.moveXY(t_s, 5, pop_x, pop_y)
      # Swoop (Succión al User)
      p.moveXY(t_s + 5, 8, c_x, c_y)
      p.moveZoom(t_s + 5, 8, 10) 
      p.moveOpacity(t_s + 10, 3, 0)
    end

    # 3. EL USER SE CURA
    up.moveColor(T_DRAIN + 15, 6, Color.new(50, 255, 50, 120))
    up.moveColor(T_DRAIN + 21, 10, Color.new(0, 0, 0, 0))
    tp.moveTone(T_END - 10, 10, Tone.new(0,0,0,0))
    up.setCallback(T_END, proc { us.visible = true; ts.visible = true })
  end
end

class Battle; alias_method :vermeil_absorb_anim, :pbAnimation unless method_defined?(:vermeil_absorb_anim)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = VermeilBattleAnimations.resolve_move_id(move)
    if @showAnims && mid == :ABSORB && @scene.respond_to?(:pbPlayVermeilAbsorb)
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
      return if @scene.pbPlayVermeilAbsorb(user, targets)
    end
    vermeil_absorb_anim(move, user, targets, hitNum)
  end
end

class Battle::Scene; unless method_defined?(:pbPlayVermeilAbsorb)
  def pbPlayVermeilAbsorb(user, targets)
    target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
    return false if !user || !target
    @vermeil_ss_anim_active = true; vermeil_ss_set_message_skin(true) rescue nil; vermeil_ss_clear_message_window! rescue nil
    begin
      anim = Animation::VermeilCinematicAbsorb.new(@sprites, @viewport, user, target)
      loop do anim.update; pbUpdate; break if anim.animDone? end; anim.dispose
    ensure
      us, ts = @sprites["pokemon_#{user.index}"], @sprites["pokemon_#{target.index}"]
      us.visible = true if us; ts.visible = true if ts; @vermeil_ss_anim_active = false
      vermeil_ss_set_message_skin(false) rescue nil; pbRefresh if respond_to?(:pbRefresh)
    end; return true
  end
end; end
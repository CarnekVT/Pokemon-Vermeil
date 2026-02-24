#===============================================================================
# [VERMEIL] BattleAnimations - Thundershock (True Projectile Bolt)
# Style: Sparks born from User -> Bolt travels to Target -> Impact.
#===============================================================================

module VermeilBattleAnimations
  module_function
  TS_ELEC = ["Graphics/Animations/PRAS- Electric.png", "Graphics/Animations/PRAS- Electric"]
  
  TS_SE_CHARGE = "Anim/PRSFX- Spark"
  TS_SE_HIT    = "Anim/Thunder3"

  def first_existing_asset(paths); paths.each { |p| return p if pbResolveBitmap(p) }; nil; end
  def resolve_move_id(move)
    return move.id if move.respond_to?(:id); d = GameData::Move.try_get(move); return d.id if d; move
  end
end

class Battle::Scene::Animation::VermeilCinematicThundershock < Battle::Scene::Animation
  T_CHARGE = 2
  T_SHOOT  = 8
  T_IMPACT = 12
  T_END    = 35

  def initialize(sprites, viewport, user, target); @user = user; @target = target; super(sprites, viewport); end

  def apply_pras_frame(sprite, path, col, row, time = 0)
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
    elec_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::TS_ELEC)
    f_dir = (@user.index & 1) == 0 ? 1 : -1

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, 600)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, 600)
    us.visible = false; ts.visible = false

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    c_x, c_y = us.x + (40 * f_dir), us.y - uh; i_x, i_y = ts.x, ts.y - th

    # 1. LA ENERGÍA NACE DEL USUARIO (Chispas cargando)
    up.setSE(T_CHARGE, VermeilBattleAnimations::TS_SE_CHARGE, 100, 120)
    up.moveColor(T_CHARGE, 4, Color.new(255, 255, 0, 150)); up.moveColor(T_CHARGE + 4, 4, Color.new(0, 0, 0, 0))

    if elec_asset
      8.times do |i|
        t_s = T_CHARGE + i
        sp = addNewSprite(c_x, c_y, elec_asset, PictureOrigin::CENTER); sp.setZ(0, 760)
        apply_pras_frame(sp, elec_asset, rand(5), 1, 0) # Chispas
        sp.setBlendType(0, 1); sp.setVisible(0, false); sp.setVisible(t_s, true)
        sp.setTone(0, Tone.new(255, 255, 0, 0)); sp.setZoom(0, 30)
        sp.moveXY(t_s, 4, c_x + rand(60)-30, c_y + rand(60)-30)
        sp.moveOpacity(t_s + 2, 3, 0)
      end
    end

    # 2. EL RAYO VIAJA (De User a Target)
    if elec_asset
      dx = i_x - c_x; dy = i_y - c_y
      angle = -Math.atan2(dy, dx) * 180.0 / Math::PI

      bolt = addNewSprite(c_x, c_y, elec_asset, PictureOrigin::CENTER); bolt.setZ(0, 750)
      apply_pras_frame(bolt, elec_asset, rand(3), 2, 0) # Rayo horizontal Fila 2
      bolt.setBlendType(0, 1); bolt.setTone(0, Tone.new(255, 255, 0, 0))
      bolt.setVisible(0, false); bolt.setVisible(T_SHOOT, true)
      
      bolt.setAngle(0, angle)
      bolt.setZoomXY(0, 60, 40)
      bolt.moveXY(T_SHOOT, 4, i_x, i_y) # Viaja en 4 frames
      bolt.moveOpacity(T_IMPACT, 2, 0)
    end

    # 3. IMPACTO EN EL RIVAL
    tp.setSE(T_IMPACT, VermeilBattleAnimations::TS_SE_HIT, 100, 130)
    tp.moveColor(T_IMPACT, 2, Color.new(255, 255, 200, 200)); tp.moveColor(T_IMPACT + 2, 4, Color.new(0, 0, 0, 0))
    4.times { |i| tp.moveDelta(T_IMPACT + i, 1, (i.even? ? 8 : -8) * f_dir, 0) }

    if elec_asset
      10.times do |i|
        t_s = T_IMPACT
        sp = addNewSprite(i_x, i_y, elec_asset, PictureOrigin::CENTER); sp.setZ(0, 760)
        apply_pras_frame(sp, elec_asset, rand(5), 1, 0) 
        sp.setBlendType(0, 1); sp.setVisible(0, false); sp.setVisible(t_s, true)
        sp.setTone(0, Tone.new(255, 255, (i.even? ? 0 : 255), 0)); sp.setZoom(t_s, 30 + rand(20))
        sp.moveXY(t_s, 5 + rand(3), i_x + (rand(100) - 50), i_y + (rand(100) - 50))
        sp.moveOpacity(t_s + 3, 5, 0)
      end
    end

    up.setCallback(T_END, proc { us.visible = true; ts.visible = true })
  end
end

class Battle; alias_method :vermeil_thundershock_anim, :pbAnimation unless method_defined?(:vermeil_thundershock_anim)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = VermeilBattleAnimations.resolve_move_id(move)
    if @showAnims && mid == :THUNDERSHOCK && @scene.respond_to?(:pbPlayVermeilThundershock)
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
      return if @scene.pbPlayVermeilThundershock(user, targets)
    end
    vermeil_thundershock_anim(move, user, targets, hitNum)
  end
end

class Battle::Scene; unless method_defined?(:pbPlayVermeilThundershock)
  def pbPlayVermeilThundershock(user, targets)
    target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
    return false if !user || !target
    @vermeil_ss_anim_active = true; vermeil_ss_set_message_skin(true) rescue nil; vermeil_ss_clear_message_window! rescue nil
    begin
      anim = Animation::VermeilCinematicThundershock.new(@sprites, @viewport, user, target)
      loop do anim.update; pbUpdate; break if anim.animDone? end; anim.dispose
    ensure
      us, ts = @sprites["pokemon_#{user.index}"], @sprites["pokemon_#{target.index}"]
      us.visible = true if us; ts.visible = true if ts; @vermeil_ss_anim_active = false
      vermeil_ss_set_message_skin(false) rescue nil; pbRefresh if respond_to?(:pbRefresh)
    end; return true
  end
end; end
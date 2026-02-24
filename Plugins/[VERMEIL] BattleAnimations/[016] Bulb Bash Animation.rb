#===============================================================================
# [VERMEIL] BattleAnimations - Bulb Bash v3 - The Crushing Blow (Fixed + Layering)
# Fixes: Sprite Clone System applied to prevent invisible battlers.
# Fixes: Battler Z-Priority set to 600 to stay ABOVE shadows.
#===============================================================================

module VermeilBattleAnimations
  module_function
  BULB_BASH_STRIKE = ["Graphics/Animations/PRAS- Strike.png", "Graphics/Animations/PRAS- Strike"]
  BULB_BASH_ROCKS  = ["Graphics/Animations/PRAS- Rock Smash.png", "Graphics/Animations/PRAS- Rock Smash"]
  BULB_BASH_LEAVES = ["Graphics/Animations/PRAS- Grass.png", "Graphics/Animations/PRAS- Grass"]
  
  BULB_BASH_SE     = "Anim/PRSFX- Focus Punch2" 

  def first_existing_asset(paths); paths.each { |p| return p if pbResolveBitmap(p) }; nil; end
  def resolve_move_id(move)
    return move.id if move.respond_to?(:id)
    d = GameData::Move.try_get(move); return d.id if d; move
  end
end

class Battle::Scene::Animation::VermeilCinematicBulbBash < Battle::Scene::Animation
  T_WINDUP = 0
  T_LUNGE  = 6  
  T_IMPACT = T_LUNGE + 3 
  T_END    = T_IMPACT + 25

  def initialize(sprites, viewport, user, target)
    @user = user; @target = target; super(sprites, viewport)
  end

  def get_frame_info(path)
    @_sheet_cache ||= {}
    return @_sheet_cache[path] if @_sheet_cache[path]
    resolved = pbResolveBitmap(path)
    return nil if !resolved
    bmp = Bitmap.new(resolved)
    fw = 192; fh = 192 
    cols = [1, (bmp.width / fw.to_f).round].max
    rows = [1, (bmp.height / fh.to_f).round].max
    count = cols * rows
    bmp.dispose
    info = { fw: fw, fh: fh, cols: cols, rows: rows, count: count }
    @_sheet_cache[path] = info; return info
  end

  def apply_frame(sprite, path, frame_index, time = 0)
    info = get_frame_info(path)
    return if !info
    idx = frame_index % info[:count]
    col = idx % info[:cols]; row = idx / info[:cols]
    sprite.setSrc(time, col * info[:fw], row * info[:fh])
    sprite.setSrcSize(time, info[:fw], info[:fh])
    if time == 0
      raw = @pictureSprites.last
      if raw && raw.respond_to?(:src_rect) && raw.src_rect
        raw.src_rect.set(col * info[:fw], row * info[:fh], info[:fw], info[:fh])
      end
    end
  end

  def createProcesses
    return if !@user || !@target
    us = @sprites["pokemon_#{@user.index}"]; ts = @sprites["pokemon_#{@target.index}"]
    return if !us || !ts
    
    strike_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::BULB_BASH_STRIKE)
    rocks_asset  = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::BULB_BASH_ROCKS)
    leaves_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::BULB_BASH_LEAVES)
    return if !strike_asset

    f_dir = (@user.index & 1) == 0 ? 1 : -1
    
    u_h = us.bitmap ? (us.bitmap.height / 2.0) : 40
    t_h = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    
    sx = us.x + (50 * f_dir) 
    sy = us.y - u_h
    ix = ts.x
    iy = ts.y - t_h

    # ── SISTEMA DE CLONES ──
    tu = Sprite.new(@viewport)
    if us.bitmap && !us.bitmap.disposed?
      tu.bitmap = us.bitmap; tu.x = us.x; tu.y = us.y
      tu.ox = us.ox; tu.oy = us.oy
      tu.zoom_x = us.zoom_x; tu.zoom_y = us.zoom_y if us.respond_to?(:zoom_x)
      tu.mirror = us.mirror if us.respond_to?(:mirror)
    end
    @tempSprites << tu
    up = addSprite(tu, PictureOrigin::BOTTOM)
    up.setZ(0, 600) # PRIORIDAD DE CAPA AÑADIDA

    tt = Sprite.new(@viewport)
    if ts.bitmap && !ts.bitmap.disposed?
      tt.bitmap = ts.bitmap; tt.x = ts.x; tt.y = ts.y
      tt.ox = ts.ox; tt.oy = ts.oy
      tt.zoom_x = ts.zoom_x; tt.zoom_y = ts.zoom_y if ts.respond_to?(:zoom_x)
      tt.mirror = ts.mirror if ts.respond_to?(:mirror)
    end
    @tempSprites << tt
    tp = addSprite(tt, PictureOrigin::BOTTOM)
    tp.setZ(0, 600) # PRIORIDAD DE CAPA AÑADIDA
    
    us.visible = false; ts.visible = false

    # 1. FÍSICAS DE PESO (Wind-up y Lunge)
    up.moveDelta(T_WINDUP, 4, -12 * f_dir, 0) 
    up.moveDelta(T_LUNGE, 3, 30 * f_dir, 0)
    up.moveDelta(T_IMPACT, 3, -8 * f_dir, 0)
    up.moveDelta(T_IMPACT + 10, 8, -10 * f_dir, 0) 

    # 2. EL IMPACTO (Estrella gigante)
    strike = addNewSprite(ix, iy, strike_asset, PictureOrigin::CENTER)
    strike.setZ(0, 760); strike.setVisible(0, false)
    apply_frame(strike, strike_asset, 0, 0) 
    
    strike.setZoom(0, 50)
    strike.setVisible(T_IMPACT, true)
    strike.setSE(T_IMPACT, VermeilBattleAnimations::BULB_BASH_SE, 100, 80) 
    strike.moveZoom(T_IMPACT, 3, 220) 
    strike.moveOpacity(T_IMPACT + 3, 4, 0)
    strike.setVisible(T_IMPACT + 7, false)

    # 3. EFECTO "SQUASH & STRETCH" EN EL ENEMIGO
    t_zx = ts.respond_to?(:zoom_x) ? ts.zoom_x * 100.0 : 100.0
    t_zy = ts.respond_to?(:zoom_y) ? ts.zoom_y * 100.0 : 100.0
    
    tp.moveZoomXY(T_IMPACT, 2, t_zx * 1.3, t_zy * 0.5) 
    tp.moveZoomXY(T_IMPACT + 2, 5, t_zx, t_zy)         

    tp.setTone(T_IMPACT, Tone.new(80, 50, 20, 0)) 
    tp.moveTone(T_IMPACT + 4, 10, Tone.new(0, 0, 0, 0))
    
    shake = 18
    tp.moveDelta(T_IMPACT, 2, shake * f_dir, 0)
    tp.moveDelta(T_IMPACT + 2, 3, -shake * 1.5 * f_dir, 0)
    tp.moveDelta(T_IMPACT + 5, 3, shake * f_dir, 0)
    tp.moveDelta(T_IMPACT + 8, 2, -shake * 0.5 * f_dir, 0)

    # 4. PARTÍCULAS DE TIERRA
    if rocks_asset
      12.times do |i|
        rock = addNewSprite(ix, ts.y, rocks_asset, PictureOrigin::CENTER)
        rock.setZ(0, 765); apply_frame(rock, rocks_asset, rand(4), 0) 
        rock.setVisible(0, false); rock.setVisible(T_IMPACT, true)
        rock.setZoom(0, 20 + rand(25))
        p_ang = (f_dir == 1 ? 0 : 180) + rand(120) - 60 
        ex = ix + (f_dir * (20 + rand(40))); ey = ts.y - (10 + rand(30)) 
        rock.moveXY(T_IMPACT, 6 + rand(6), ex, ey)
        rock.moveAngle(T_IMPACT, 12, rand(360) * (rand(2)==0 ? 1 : -1))
        rock.moveOpacity(T_IMPACT + 6, 6, 0); rock.setVisible(T_IMPACT + 12, false)
      end
    end

    # 5. HOJAS DAÑADAS
    if leaves_asset
      4.times do |i|
        leaf = addNewSprite(ix, iy, leaves_asset, PictureOrigin::CENTER)
        leaf.setZ(0, 762); apply_frame(leaf, leaves_asset, 10 + rand(5), 0) 
        leaf.setVisible(0, false); leaf.setVisible(T_IMPACT, true)
        ex = ix + (f_dir * -1 * (40 + rand(50))); ey = iy - (20 + rand(40))
        leaf.moveXY(T_IMPACT, 10 + rand(6), ex, ey)
        leaf.moveAngle(T_IMPACT, 15, rand(360))
        leaf.moveOpacity(T_IMPACT + 8, 7, 0); leaf.setVisible(T_IMPACT + 15, false)
      end
    end
  end
end

class Battle
  alias_method :vermeil_bulbbash_pbAnimation, :pbAnimation unless method_defined?(:vermeil_bulbbash_pbAnimation)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = VermeilBattleAnimations.resolve_move_id(move)
    if @showAnims && mid == :BULBBASH && @scene.respond_to?(:pbPlayVermeilBulbBash)
      if hitNum.to_i <= 0
        @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
        @scene.instance_variable_set(:@vermeil_ss_sequence_done,   false)
      end
      return if @scene.pbPlayVermeilBulbBash(user, targets)
    end
    
    if @scene && mid == :BULBBASH
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, false)
      @scene.instance_variable_set(:@vermeil_ss_sequence_done,   false)
      @scene.instance_variable_set(:@vermeil_ss_anim_active,     false)
      @scene.vermeil_ss_set_message_skin(false) if @scene.respond_to?(:vermeil_ss_set_message_skin)
      @scene.vermeil_ss_clear_message_window! if @scene.respond_to?(:vermeil_ss_clear_message_window!)
    end
    vermeil_bulbbash_pbAnimation(move, user, targets, hitNum)
  end
end

class Battle::Scene
  unless method_defined?(:pbPlayVermeilBulbBash)
    def pbPlayVermeilBulbBash(user, targets)
      target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
      return false if !user || !target

      @vermeil_ss_anim_active = true if respond_to?(:vermeil_ss_set_message_skin)
      vermeil_ss_set_message_skin(true) if respond_to?(:vermeil_ss_set_message_skin)
      vermeil_ss_clear_message_window! if respond_to?(:vermeil_ss_clear_message_window!)
      

      begin
        anim = Animation::VermeilCinematicBulbBash.new(@sprites, @viewport, user, target)
        loop do anim.update; pbUpdate; break if anim.animDone?; end
        anim.dispose
      ensure
        us = @sprites["pokemon_#{user.index}"] rescue nil
        ts = @sprites["pokemon_#{target.index}"] rescue nil
        us.visible = true if us; ts.visible = true if ts

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
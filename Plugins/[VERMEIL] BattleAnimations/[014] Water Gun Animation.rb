#===============================================================================
# [VERMEIL] BattleAnimations - Water Gun v12 - Flawless Alignment & UI
#===============================================================================

module VermeilBattleAnimations
  module_function
  WATER_GUN_ENERGY = ["Graphics/BattleParticlesAnimations/Energy1"]
  WATER_GUN_DROPS  = ["Graphics/BattleParticlesAnimations/Bubbles-Drops"]
  WATER_GUN_SE     = "Anim/PRSFX- Water Gun"

  def first_existing_asset(paths); paths.each { |p| return p if pbResolveBitmap(p) }; nil; end
  def resolve_move_id(move)
    return move.id if move.respond_to?(:id)
    d = GameData::Move.try_get(move); return d.id if d; move
  end
end

class Battle::Scene::Animation::VermeilCinematicWaterGun < Battle::Scene::Animation
  T_SHOOT  = 2
  T_TRAVEL = 4 
  T_END    = T_SHOOT + 12 + T_TRAVEL + 15

  def initialize(sprites, viewport, user, target)
    @user = user; @target = target; super(sprites, viewport)
  end

  def get_frame_info(path)
    @_sheet_cache ||= {}
    return @_sheet_cache[path] if @_sheet_cache[path]
    resolved = pbResolveBitmap(path)
    return nil if !resolved
    bmp = Bitmap.new(resolved)
    fw = bmp.height; fh = bmp.height
    if path.include?("Bubbles-Drops")
      fw = 32; fh = 32
    end
    cols = [1, (bmp.width / fw.to_f).round].max
    rows = [1, (bmp.height / fh.to_f).round].max
    count = cols * rows
    bmp.dispose
    info = { fw: fw, fh: fh, cols: cols, rows: rows, count: count }
    @_sheet_cache[path] = info
    return info
  end

  def apply_frame(sprite, path, frame_index, time = 0)
    info = get_frame_info(path)
    return if !info
    idx = frame_index % info[:count]
    col = idx % info[:cols]
    row = idx / info[:cols]
    sprite.setSrc(time, col * info[:fw], row * info[:fh])
    sprite.setSrcSize(time, info[:fw], info[:fh])
    if time == 0
      raw = @pictureSprites.last
      if raw && raw.respond_to?(:src_rect) && raw.src_rect
        raw.src_rect.set(col * info[:fw], row * info[:fh], info[:fw], info[:fh])
      end
    end
  end

  def animate_sheet_fluid(sprite, path, start_time, ticks_per_frame = 2)
    info = get_frame_info(path)
    return 0 if !info || info[:count] <= 1
    apply_frame(sprite, path, 0, 0)
    duration = info[:count] * ticks_per_frame
    duration.times do |j|
      frame_index = (j / ticks_per_frame).floor
      apply_frame(sprite, path, frame_index, start_time + j)
    end
    return duration
  end

  def createProcesses
    return if !@user || !@target
    us = @sprites["pokemon_#{@user.index}"]; ts = @sprites["pokemon_#{@target.index}"]
    return if !us || !ts
    
    energy_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::WATER_GUN_ENERGY)
    drops_asset  = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::WATER_GUN_DROPS)
    return if !energy_asset

    f_dir = (@user.index & 1) == 0 ? 1 : -1
    
    # --- ALINEACIÓN EXACTA BASADA EN SNIPE SHOT ---
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

    water_tones = [
      Tone.new(-120, -20, 180, 20),
      Tone.new(-160, -60, 220, 50),
      Tone.new(-80,   10, 150,  0),
      Tone.new(-140, -40, 200, 30)
    ]

    12.times do |i|
      t_start = T_SHOOT + i 
      t_hit   = t_start + T_TRAVEL

      orb = addNewSprite(sx, sy, energy_asset, PictureOrigin::CENTER)
      orb.setZ(0, 750); orb.setVisible(0, false)
      orb.setTone(0, water_tones[i % water_tones.length]) 
      orb.setAngle(0, angle)
      zx = 150 + rand(30); zy = 40 + rand(20)
      orb.setZoomXY(0, zx, zy) 
      orb.setVisible(t_start, true)
      
      if i == 0 || i == 6
        orb.setSE(t_start, VermeilBattleAnimations::WATER_GUN_SE, 90, 100 + (i * 2))
      end
      
      orb.moveXY(t_start, T_TRAVEL, ix, iy)
      animate_sheet_fluid(orb, energy_asset, t_start, 2)
      orb.setVisible(t_hit, false)

      if drops_asset
        3.times do |d|
          drop = addNewSprite(ix, iy, drops_asset, PictureOrigin::CENTER)
          drop.setZ(0, 760)
          apply_frame(drop, drops_asset, rand(4), 0) 
          drop.setVisible(0, false)
          drop.setTone(0, water_tones[rand(water_tones.length)]) 
          drop.setVisible(t_hit, true)
          
          center_ang = (f_dir == 1) ? 0 : 180
          p_ang = center_ang + rand(140) - 70 
          p_dist = 30 + rand(60)
          ex = ix + p_dist * Math.cos(p_ang * Math::PI / 180)
          ey = iy - p_dist * Math.sin(p_ang * Math::PI / 180)
          
          drop.moveXY(t_hit, 6 + rand(4), ex, ey)
          drop.setZoom(t_hit, 35 + rand(15))
          drop.moveOpacity(t_hit + 2, 4, 0)
          drop.setVisible(t_hit + 8, false)
        end
      end

      if i % 3 == 0
        tp.moveDelta(t_hit, 1, 4 * f_dir, 0)
        tp.moveDelta(t_hit + 1, 1, -4 * f_dir, 0)
      end
    end

    tp.moveTone(T_SHOOT + T_TRAVEL, 2, Tone.new(-60, -40, 120, 0)) 
    tp.moveTone(T_SHOOT + T_TRAVEL + 14, 8, Tone.new(0, 0, 0, 0))
  end
end

class Battle
  alias_method :vermeil_watergun_pbAnimation, :pbAnimation unless method_defined?(:vermeil_watergun_pbAnimation)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = VermeilBattleAnimations.resolve_move_id(move)
    if @showAnims && mid == :WATERGUN && @scene.respond_to?(:pbPlayVermeilWaterGun)
      if hitNum.to_i <= 0
        @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
        @scene.instance_variable_set(:@vermeil_ss_sequence_done,   false)
      end
      return if @scene.pbPlayVermeilWaterGun(user, targets)
    end
    if @scene && mid == :WATERGUN
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, false)
      @scene.instance_variable_set(:@vermeil_ss_sequence_done,   false)
      @scene.instance_variable_set(:@vermeil_ss_anim_active,     false)
      @scene.vermeil_ss_set_message_skin(false) if @scene.respond_to?(:vermeil_ss_set_message_skin)
      @scene.vermeil_ss_clear_message_window! if @scene.respond_to?(:vermeil_ss_clear_message_window!)
    end
    vermeil_watergun_pbAnimation(move, user, targets, hitNum)
  end
end

class Battle::Scene
  unless method_defined?(:pbPlayVermeilWaterGun)
    def pbPlayVermeilWaterGun(user, targets)
      target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
      return false if !user || !target

      @vermeil_ss_anim_active = true if respond_to?(:vermeil_ss_set_message_skin)
      vermeil_ss_set_message_skin(true) if respond_to?(:vermeil_ss_set_message_skin)
      vermeil_ss_clear_message_window! if respond_to?(:vermeil_ss_clear_message_window!)
      pbToggleDataboxes if respond_to?(:pbToggleDataboxes)

      begin
        anim = Animation::VermeilCinematicWaterGun.new(@sprites, @viewport, user, target)
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
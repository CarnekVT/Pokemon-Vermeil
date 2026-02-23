#===============================================================================
# [VERMEIL] BattleAnimations - Supersonic v2 - THE STABLE VERSION
# Basado en la arquitectura estable de Bulb Bash v3.
# Utiliza PRAS- Metal Sound para ondas y PRAS- Sound para notas.
#===============================================================================

module VermeilBattleAnimations
  module_function
  SUPERSONIC_WAVES = ["Graphics/Animations/PRAS- Metal Sound.png", "Graphics/Animations/PRAS- Metal Sound"]
  SUPERSONIC_NOTES = ["Graphics/Animations/PRAS- Sound.png", "Graphics/Animations/PRAS- Sound"]
  SUPERSONIC_SE    = "Anim/PRSFX- Supersonic" 

  def first_existing_asset(paths); paths.each { |p| return p if pbResolveBitmap(p) }; nil; end
  def resolve_move_id(move)
    return move.id if move.respond_to?(:id)
    d = GameData::Move.try_get(move); return d.id if d; move
  end
end

class Battle::Scene::Animation::VermeilCinematicSupersonic < Battle::Scene::Animation
  T_EMISSION = 2
  T_TRAVEL   = 6
  T_IMPACT   = T_EMISSION + T_TRAVEL
  T_END      = T_IMPACT + 20

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
    
    wave_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::SUPERSONIC_WAVES)
    note_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::SUPERSONIC_NOTES)
    return if !wave_asset

    f_dir = (@user.index & 1) == 0 ? 1 : -1
    
    # --- ALINEACIÓN SNIPE SHOT ---
    u_h = us.bitmap ? (us.bitmap.height / 2.0) : 40
    t_h = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    sx = us.x + (20 * f_dir); sy = us.y - u_h
    ix = ts.x; iy = ts.y - t_h

    # --- SISTEMA DE CLONES (Estabilidad Total) ---
    tu = Sprite.new(@viewport)
    if us.bitmap && !us.bitmap.disposed?
      tu.bitmap = us.bitmap; tu.x = us.x; tu.y = us.y
      tu.ox = us.ox; tu.oy = us.oy
      tu.zoom_x = us.zoom_x; tu.zoom_y = us.zoom_y
      tu.mirror = us.mirror
    end
    @tempSprites << tu
    up = addSprite(tu, PictureOrigin::BOTTOM)
    up.setZ(0, 600) # POR ENCIMA DE SOMBRAS

    tt = Sprite.new(@viewport)
    if ts.bitmap && !ts.bitmap.disposed?
      tt.bitmap = ts.bitmap; tt.x = ts.x; tt.y = ts.y
      tt.ox = ts.ox; tt.oy = ts.oy
      tt.zoom_x = ts.zoom_x; tt.zoom_y = ts.zoom_y
      tt.mirror = ts.mirror
    end
    @tempSprites << tt
    tp = addSprite(tt, PictureOrigin::BOTTOM)
    tp.setZ(0, 600) # POR ENCIMA DE SOMBRAS
    
    us.visible = false; ts.visible = false

    # 1. EMISIÓN (Vibración)
    up.moveDelta(T_EMISSION, 1, 4 * f_dir, 0); up.moveDelta(T_EMISSION + 1, 1, -4 * f_dir, 0)
    up.setSE(T_EMISSION, VermeilBattleAnimations::SUPERSONIC_SE)

    # 2. ONDAS DE SONIDO (Anillos que crecen)
    4.times do |i|
      t_s = T_EMISSION + (i * 2); t_h = t_s + T_TRAVEL
      wave = addNewSprite(sx, sy, wave_asset, PictureOrigin::CENTER)
      wave.setZ(0, 750); apply_frame(wave, wave_asset, 0, 0)
      wave.setOpacity(0, 0); wave.setVisible(t_s, true)
      
      wave.setZoom(t_s, 20); wave.moveZoom(t_s, T_TRAVEL, 150)
      wave.moveOpacity(t_s, 2, 180); wave.moveXY(t_s, T_TRAVEL, ix, iy)
      wave.moveOpacity(t_h - 2, 2, 0); wave.setVisible(t_h, false)
    end

    # 3. NOTAS MUSICALES (Decoración)
    if note_asset
      6.times do |i|
        t_s = T_EMISSION + rand(5)
        note = addNewSprite(sx, sy, note_asset, PictureOrigin::CENTER)
        note.setZ(0, 760); apply_frame(note, note_asset, 8 + rand(10), 0)
        note.setVisible(t_s, true); note.setZoom(t_s, 40 + rand(40))
        note.moveXY(t_s, T_TRAVEL + 4, ix + rand(60) - 30, iy + rand(60) - 30)
        note.moveOpacity(t_s + T_TRAVEL, 4, 0)
      end
    end

    # 4. REACCIÓN DE CONFUSIÓN
    tp.setTone(T_IMPACT, Tone.new(60, 60, -100, 0)) 
    tp.moveTone(T_IMPACT + 10, 10, Tone.new(0, 0, 0, 0))
    4.times do |i|
      tp.moveDelta(T_IMPACT + (i * 2), 1, rand(12) - 6, rand(10) - 5)
    end
  end
end

class Battle; alias_method :vermeil_supersonic_pbAnimation, :pbAnimation unless method_defined?(:vermeil_supersonic_pbAnimation)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = VermeilBattleAnimations.resolve_move_id(move)
    if @showAnims && mid == :SUPERSONIC && @scene.respond_to?(:pbPlayVermeilSupersonic)
      if hitNum.to_i <= 0
        @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
        @scene.instance_variable_set(:@vermeil_ss_sequence_done,   false)
      end
      return if @scene.pbPlayVermeilSupersonic(user, targets)
    end
    vermeil_supersonic_pbAnimation(move, user, targets, hitNum)
  end
end

class Battle::Scene; unless method_defined?(:pbPlayVermeilSupersonic)
  def pbPlayVermeilSupersonic(user, targets)
    target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
    return false if !user || !target

    @vermeil_ss_anim_active = true if respond_to?(:vermeil_ss_set_message_skin)
    vermeil_ss_set_message_skin(true) if respond_to?(:vermeil_ss_set_message_skin)
    vermeil_ss_clear_message_window! if respond_to?(:vermeil_ss_clear_message_window!)
    pbToggleDataboxes if respond_to?(:pbToggleDataboxes)

    begin
      anim = Animation::VermeilCinematicSupersonic.new(@sprites, @viewport, user, target)
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
      pbToggleDataboxes(true) if respond_to?(:pbToggleDataboxes)
      pbRefresh if respond_to?(:pbRefresh)
    end
    return true
  end
end; end
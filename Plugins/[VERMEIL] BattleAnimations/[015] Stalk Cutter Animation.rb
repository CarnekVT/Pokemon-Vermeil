#===============================================================================
# [VERMEIL] BattleAnimations - Stalk Cutter v1 - The Samurai Leaf Strike
# Utiliza PRAS- Slash (Teñido de verde) y PRAS- Grass (Hojas volando)
#===============================================================================

module VermeilBattleAnimations
  module_function
  STALK_CUTTER_SLASH  = ["Graphics/Animations/PRAS- Slash.png", "Graphics/Animations/PRAS- Slash"]
  STALK_CUTTER_LEAVES = ["Graphics/Animations/PRAS- Grass.png", "Graphics/Animations/PRAS- Grass"]
  STALK_CUTTER_SE     = "Anim/PRSFX- Slash" # Efecto de corte limpio

  def first_existing_asset(paths); paths.each { |p| return p if pbResolveBitmap(p) }; nil; end
  def resolve_move_id(move)
    return move.id if move.respond_to?(:id)
    d = GameData::Move.try_get(move); return d.id if d; move
  end
end

class Battle::Scene::Animation::VermeilCinematicStalkCutter < Battle::Scene::Animation
  T_LUNGE  = 2
  T_STRIKE = 5
  T_IMPACT = T_STRIKE + 2 # El impacto es casi inmediato
  T_END    = T_IMPACT + 15

  def initialize(sprites, viewport, user, target)
    @user = user; @target = target; super(sprites, viewport)
  end

  def get_frame_info(path)
    @_sheet_cache ||= {}
    return @_sheet_cache[path] if @_sheet_cache[path]

    resolved = pbResolveBitmap(path)
    return nil if !resolved
    bmp = Bitmap.new(resolved)
    
    fw = 192; fh = 192 # Tamaño estándar PRAS
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

  def animate_sheet_fluid(sprite, path, start_time, start_frame, num_frames, ticks_per_frame = 2)
    info = get_frame_info(path)
    return 0 if !info || info[:count] <= 1
    apply_frame(sprite, path, start_frame, 0)
    
    duration = num_frames * ticks_per_frame
    duration.times do |j|
      current_frame = start_frame + (j / ticks_per_frame).floor
      apply_frame(sprite, path, current_frame, start_time + j)
    end
    return duration
  end

  def createProcesses
    return if !@user || !@target
    us = @sprites["pokemon_#{@user.index}"]; ts = @sprites["pokemon_#{@target.index}"]
    return if !us || !ts
    
    slash_asset  = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::STALK_CUTTER_SLASH)
    leaves_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::STALK_CUTTER_LEAVES)
    return if !slash_asset

    f_dir = (@user.index & 1) == 0 ? 1 : -1
    
    # --- ALINEACIÓN PERFECTA ---
    u_h = us.bitmap ? (us.bitmap.height / 2.0) : 40
    t_h = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    sx = us.x + (40 * f_dir)
    sy = us.y - u_h
    ix = ts.x
    iy = ts.y - t_h

    up = addSprite(us, PictureOrigin::BOTTOM)
    tp = addSprite(ts, PictureOrigin::BOTTOM)

    # 1. EL LUNGE (DASH SAMURÁI)
    # El Pokémon avanza de forma súper rápida y seca
    up.moveDelta(T_LUNGE, 2, 16 * f_dir, 0)
    up.moveDelta(T_IMPACT + 4, 6, -16 * f_dir, 0) # Vuelve después del golpe

    # 2. EL CORTE (SLASH)
    slash = addNewSprite(ix, iy, slash_asset, PictureOrigin::CENTER)
    slash.setZ(0, 760); slash.setVisible(0, false)
    
    # Orientar el corte
    slash.setAngle(0, f_dir == 1 ? 0 : 180)
    slash.setZoom(0, 140) # Un tajo grande y visible
    
    # Tinte verde vibrante para convertir el tajo gris en energía Planta
    slash.setTone(0, Tone.new(-80, 150, -80, 20)) 
    
    slash.setVisible(T_STRIKE, true)
    slash.setSE(T_STRIKE, VermeilBattleAnimations::STALK_CUTTER_SE, 100, 100)
    
    # PRAS- Slash: Fila 1 (Frames 5 al 9) es un tajo limpio. A 2 ticks es rapidísimo.
    dur = animate_sheet_fluid(slash, slash_asset, T_STRIKE, 5, 5, 2)
    slash.setVisible(T_STRIKE + dur, false)

    # 3. IMPACTO DE PUNTO DÉBIL (Crítico visual)
    # Flash blanco puro de 2 frames
    tp.setTone(T_IMPACT, Tone.new(255, 255, 255, 255)) 
    tp.moveTone(T_IMPACT + 2, 6, Tone.new(0, 0, 0, 0))
    
    # Shake violento
    shake = 16
    tp.moveDelta(T_IMPACT, 1, shake * f_dir, 0)
    tp.moveDelta(T_IMPACT + 1, 2, -shake * 2 * f_dir, 0)
    tp.moveDelta(T_IMPACT + 3, 1, shake * f_dir, 0)

    # 4. HOJAS VOLANDO (Sangre verde)
    if leaves_asset
      6.times do |i|
        leaf = addNewSprite(ix, iy, leaves_asset, PictureOrigin::CENTER)
        leaf.setZ(0, 765)
        
        # PRAS- Grass: Fila 2 (Frames 10 a 14) son hojas sueltas perfectas
        leaf_frame = 10 + rand(5)
        apply_frame(leaf, leaves_asset, leaf_frame, 0) 
        
        leaf.setVisible(0, false)
        leaf.setVisible(T_IMPACT, true)
        
        # Vuelan en un arco hacia atrás
        c_ang = (f_dir == 1) ? 0 : 180
        p_ang = c_ang + rand(140) - 70 
        p_dist = 60 + rand(80)
        ex = ix + p_dist * Math.cos(p_ang * Math::PI / 180)
        ey = iy - p_dist * Math.sin(p_ang * Math::PI / 180)
        
        leaf.moveXY(T_IMPACT, 8 + rand(6), ex, ey)
        leaf.moveAngle(T_IMPACT, 14, rand(360) * (rand(2)==0 ? 1 : -1)) # Giran mientras caen
        leaf.moveOpacity(T_IMPACT + 6, 8, 0)
        leaf.setVisible(T_IMPACT + 14, false)
      end
    end
  end
end

# --- HOOKS DE ESSENTIALS ---
class Battle
  alias_method :vermeil_stalkcutter_pbAnimation, :pbAnimation unless method_defined?(:vermeil_stalkcutter_pbAnimation)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = VermeilBattleAnimations.resolve_move_id(move)
    # Importante: Asegúrate de tener :STALKCUTTER definido en tus PBS de movimientos
    if @showAnims && mid == :STALKCUTTER && @scene.respond_to?(:pbPlayVermeilStalkCutter)
      if hitNum.to_i <= 0
        @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
        @scene.instance_variable_set(:@vermeil_ss_sequence_done,   false)
      end
      return if @scene.pbPlayVermeilStalkCutter(user, targets)
    end
    
    if @scene && mid == :STALKCUTTER
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, false)
      @scene.instance_variable_set(:@vermeil_ss_sequence_done,   false)
      @scene.instance_variable_set(:@vermeil_ss_anim_active,     false)
      @scene.vermeil_ss_set_message_skin(false) if @scene.respond_to?(:vermeil_ss_set_message_skin)
      @scene.vermeil_ss_clear_message_window! if @scene.respond_to?(:vermeil_ss_clear_message_window!)
    end
    vermeil_stalkcutter_pbAnimation(move, user, targets, hitNum)
  end
end

class Battle::Scene
  unless method_defined?(:pbPlayVermeilStalkCutter)
    def pbPlayVermeilStalkCutter(user, targets)
      target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
      return false if !user || !target

      @vermeil_ss_anim_active = true if respond_to?(:vermeil_ss_set_message_skin)
      vermeil_ss_set_message_skin(true) if respond_to?(:vermeil_ss_set_message_skin)
      vermeil_ss_clear_message_window! if respond_to?(:vermeil_ss_clear_message_window!)
      

      begin
        anim = Animation::VermeilCinematicStalkCutter.new(@sprites, @viewport, user, target)
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
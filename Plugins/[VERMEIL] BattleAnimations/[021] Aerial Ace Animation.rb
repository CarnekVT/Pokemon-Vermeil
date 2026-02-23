#===============================================================================
# [VERMEIL] BattleAnimations - Aerial Ace (Gen 5/6 Anime Slash Style)
# Fix: Perfect Target Centering & Directional Slash Alignment.
#===============================================================================

module VermeilBattleAnimations
  module_function
  AA_SLASH  = ["Graphics/Animations/PRAS- Slash.png", "Graphics/Animations/PRAS- Slash"]
  AA_STRIKE = ["Graphics/Animations/PRAS- Strike.png", "Graphics/Animations/PRAS- Strike"]
  AA_SPARKS = ["Graphics/BattleParticlesAnimations/Energy1"]
  
  AA_SE_DASH  = "Anim/Wind1"
  AA_SE_SLASH = "Anim/PRSFX- Slash" 
  AA_SE_HIT   = "Anim/PRSFX- Focus Punch2"

  def first_existing_asset(paths); paths.each { |p| return p if pbResolveBitmap(p) }; nil; end
  def resolve_move_id(move)
    return move.id if move.respond_to?(:id); d = GameData::Move.try_get(move); return d.id if d; move
  end
end

class Battle::Scene::Animation::VermeilCinematicAerialAce < Battle::Scene::Animation
  T_START  = 2
  T_DASH   = 6
  T_STRIKE = 12
  T_END    = 45

  def initialize(sprites, viewport, user, target); @user = user; @target = target; super(sprites, viewport); end

  def get_frame_info(path)
    @_sheet_cache ||= {}; return @_sheet_cache[path] if @_sheet_cache[path]
    resolved = pbResolveBitmap(path); return nil if !resolved
    bmp = Bitmap.new(resolved); fw = 192; fh = 192
    if path.include?("Energy1")
      fw = bmp.height; fh = bmp.height
    end
    cols = [1, (bmp.width / fw.to_f).round].max; rows = [1, (bmp.height / fh.to_f).round].max
    info = { fw: fw, fh: fh, cols: cols, rows: rows, count: cols * rows }; bmp.dispose
    @_sheet_cache[path] = info; return info
  end

  def apply_frame(sprite, path, frame_index, time = 0)
    info = get_frame_info(path); return if !info
    idx = frame_index % info[:count]; col = idx % info[:cols]; row = idx / info[:cols]
    sprite.setSrc(time, col * info[:fw], row * info[:fh]); sprite.setSrcSize(time, info[:fw], info[:fh])
    if time == 0 && (raw = @pictureSprites.last) && raw.src_rect
      raw.src_rect.set(col * info[:fw], row * info[:fh], info[:fw], info[:fh])
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

  def make_red_anime_slash
    cw = Graphics.width; ch = Graphics.height
    # Diagonal ultra ancha para garantizar que cubra toda la pantalla desde cualquier punto
    diag = (Math.sqrt(cw * cw + ch * ch) * 2.5).to_i
    bmp  = Bitmap.new(diag, ch * 2)
    
    # Tonalidades simétricas centradas en "ch" (El origen en Y)
    bmp.fill_rect(0, ch - 80, diag, 160, Color.new(80, 0, 0, 255))
    bmp.fill_rect(0, ch - 60, diag, 120, Color.new(180, 0, 0, 255))
    bmp.fill_rect(0, ch - 30, diag,  60, Color.new(255, 40, 40, 255))
    bmp.fill_rect(0, ch - 10, diag,  20, Color.new(255, 200, 200, 255))
    
    s = Sprite.new(@viewport)
    s.bitmap = bmp
    s.ox = diag / 2
    s.oy = ch
    @tempSprites << s; s
  end

  def createProcesses
    return if !@user || !@target
    us, ts = @sprites["pokemon_#{@user.index}"], @sprites["pokemon_#{@target.index}"]
    slash_asset  = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::AA_SLASH)
    strike_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::AA_STRIKE)
    sparks_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::AA_SPARKS)
    f_dir = (@user.index & 1) == 0 ? 1 : -1

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, 600)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, 600)
    us.visible = false; ts.visible = false

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    c_x, c_y = us.x + (40 * f_dir), us.y - uh; i_x, i_y = ts.x - (10 * f_dir), ts.y - th

    orig_up_x = up.x; orig_up_y = up.y

    # 1. FONDO OSCURO
    bg = addNewSprite(0, 0, "Graphics/Battle animations/black_screen") rescue nil
    if bg
      bg.setZ(0, 550); bg.setOpacity(0, 0)
      bg.moveOpacity(T_START, 4, 200)
      bg.moveOpacity(T_END - 10, 8, 0)
    end

    # 2. EL DASH 
    up.setSE(T_DASH, VermeilBattleAnimations::AA_SE_DASH, 100, 130)
    up.moveColor(T_DASH, 2, Color.new(255, 255, 255, 255))
    up.moveDelta(T_DASH, 3, 150 * f_dir, -100) 
    up.moveOpacity(T_DASH, 3, 0)

    # 3. TAJO DIAGONAL ROJO (Anclado al centro del objetivo)
    slash_angle = 35 * f_dir
    diag_s = make_red_anime_slash
    diag = addSprite(diag_s, PictureOrigin::CENTER); diag.setZ(0, 580)
    # ¡AQUÍ ESTABA EL FIX! Anclamos el centro del fondo al pecho del rival
    diag.setXY(0, i_x, i_y)
    diag.setVisible(0, false); diag.setOpacity(0, 0)
    diag.setAngle(0, slash_angle) 
    
    diag.setVisible(T_STRIKE, true)
    diag.setOpacity(T_STRIKE, 255)
    diag.moveZoomXY(T_STRIKE, 4, 100, 15) 
    diag.moveOpacity(T_STRIKE + 6, 4, 0)

    # 4. EL IMPACTO EN EL ENEMIGO
    tp.setSE(T_STRIKE, VermeilBattleAnimations::AA_SE_SLASH, 100, 90)
    tp.setSE(T_STRIKE + 1, VermeilBattleAnimations::AA_SE_HIT, 100, 100)
    
    tp.moveColor(T_STRIKE, 2, Color.new(255, 255, 255, 255))
    tp.moveColor(T_STRIKE + 4, 6, Color.new(255, 255, 255, 0))
    
    6.times { |i| tp.moveDelta(T_STRIKE + i, 1, (i.even? ? 16 : -16) * f_dir, 0) }

    # 5. LUZ DEL CORTE
    if strike_asset
      hit = addNewSprite(i_x, i_y, strike_asset, PictureOrigin::CENTER); hit.setZ(0, 750)
      apply_frame(hit, strike_asset, 0, 0)
      hit.setBlendType(0, 1) 
      hit.setVisible(0, false); hit.setVisible(T_STRIKE, true)
      hit.setZoom(0, 80); hit.moveZoom(T_STRIKE, 3, 200)
      hit.moveOpacity(T_STRIKE + 3, 4, 0)
    end

    if slash_asset
      slash = addNewSprite(i_x, i_y, slash_asset, PictureOrigin::CENTER); slash.setZ(0, 755)
      apply_frame(slash, slash_asset, 5, 0) 
      slash.setBlendType(0, 1) 
      slash.setColor(0, Color.new(255, 200, 200, 100)) 
      slash.setVisible(0, false); slash.setVisible(T_STRIKE, true)
      slash.setAngle(0, slash_angle); slash.setZoom(0, 180)
      slash.moveOpacity(T_STRIKE + 4, 4, 0)
    end

    # 6. CHISPAS AMARILLAS 
    if sparks_asset
      12.times do |i|
        t_s = T_STRIKE
        sp = addNewSprite(i_x, i_y, sparks_asset, PictureOrigin::CENTER); sp.setZ(0, 760)
        apply_frame(sp, sparks_asset, 0, 0)
        sp.setBlendType(0, 1) 
        sp.setTone(0, Tone.new(255, 200, 0, 0)) 
        sp.setVisible(0, false); sp.setVisible(t_s, true)
        sp.setZoom(0, 20 + rand(20))
        
        pop_x = i_x + (rand(120) - 60) * f_dir
        pop_y = i_y + (rand(120) - 60)
        sp.moveXY(t_s, 6 + rand(4), pop_x, pop_y)
        sp.moveOpacity(t_s + 4, 6, 0)
      end
    end

    # 7. REGRESO DEL USUARIO
    up.setXY(T_STRIKE + 8, orig_up_x - (40 * f_dir), orig_up_y - 30)
    up.setSE(T_STRIKE + 8, VermeilBattleAnimations::AA_SE_DASH, 80, 150)
    up.moveOpacity(T_STRIKE + 8, 3, 255)
    up.moveDelta(T_STRIKE + 8, 4, 40 * f_dir, 30)
    up.moveColor(T_STRIKE + 8, 2, Color.new(255, 255, 255, 200))
    up.moveColor(T_STRIKE + 10, 4, Color.new(0, 0, 0, 0))

    up.setCallback(T_END, proc { us.visible = true; ts.visible = true })
  end
end

class Battle; alias_method :vermeil_aerialace_anim, :pbAnimation unless method_defined?(:vermeil_aerialace_anim)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = VermeilBattleAnimations.resolve_move_id(move)
    if @showAnims && mid == :AERIALACE && @scene.respond_to?(:pbPlayVermeilAerialAce)
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
      return if @scene.pbPlayVermeilAerialAce(user, targets)
    end
    vermeil_aerialace_anim(move, user, targets, hitNum)
  end
end

class Battle::Scene; unless method_defined?(:pbPlayVermeilAerialAce)
  def pbPlayVermeilAerialAce(user, targets)
    target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
    return false if !user || !target
    @vermeil_ss_anim_active = true; vermeil_ss_set_message_skin(true) rescue nil; vermeil_ss_clear_message_window! rescue nil
    pbToggleDataboxes if respond_to?(:pbToggleDataboxes)
    begin
      anim = Animation::VermeilCinematicAerialAce.new(@sprites, @viewport, user, target)
      loop do anim.update; pbUpdate; break if anim.animDone? end; anim.dispose
    ensure
      us, ts = @sprites["pokemon_#{user.index}"], @sprites["pokemon_#{target.index}"]
      us.visible = true if us; ts.visible = true if ts; @vermeil_ss_anim_active = false
      vermeil_ss_set_message_skin(false) rescue nil; pbToggleDataboxes(true) if respond_to?(:pbToggleDataboxes); pbRefresh if respond_to?(:pbRefresh)
    end; return true
  end
end; end
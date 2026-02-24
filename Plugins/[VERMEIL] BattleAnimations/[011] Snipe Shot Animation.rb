#===============================================================================
# [VERMEIL] BattleAnimations — Snipe Shot Cinematic v18 (The Masterpiece)
# Fixes: Clean Damage View (Hides NDS Message overlay during HP drain)
#===============================================================================

module VermeilBattleAnimations
  module_function

  SNIPE_PROJECTILE_ASSETS = ["Graphics/BattleParticlesAnimations/WaterProyectile"]
  SNIPE_TRAIL_ASSETS      = ["Graphics/BattleParticlesAnimations/Energy1"]
  SNIPE_SPLASH_ASSETS     = ["Graphics/BattleParticlesAnimations/WaterSplashShot"]
  SNIPE_DROPS_ASSETS      = ["Graphics/BattleParticlesAnimations/Bubbles-Drops"]
  SNIPE_DIAGONAL_ASSETS   = ["Graphics/Battle animations/snipe_diagonal_red"]

  SNIPE_SHOT_SE_THROW  = "Anim/Water2"
  SNIPE_SHOT_SE_IMPACT = "Anim/Water3"

  def first_existing_asset(paths)
    paths.each { |p| return p if pbResolveBitmap(p) }
    nil
  end if !respond_to?(:first_existing_asset)

  def resolve_move_id(move)
    return move.id if move.respond_to?(:id)
    d = GameData::Move.try_get(move); return d.id if d; move
  end if !respond_to?(:resolve_move_id)
end

class Battle::Scene::Animation::VermeilCinematicSnipeShot < Battle::Scene::Animation
  T_CHARGE_START = 8
  T_CHARGE_DUR = 25
  T_SHOT = T_CHARGE_START + T_CHARGE_DUR
  T_TRAVEL_DUR = 4 
  T_IMPACT = T_SHOT + T_TRAVEL_DUR
  T_IMPACT_EFFECT_DUR = 25
  T_END = T_IMPACT + T_IMPACT_EFFECT_DUR

  def initialize(sprites, viewport, user, target)
    @user = user; @target = target
    super(sprites, viewport)
  end

  def make_black_sprite
    bmp = Bitmap.new(Graphics.width, Graphics.height)
    bmp.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
    s = Sprite.new(@viewport); s.bitmap = bmp
    @tempSprites << s; s
  end

  # GARANTÍA DE LÍNEA ROJA (Por si falta el PNG)
  def make_diagonal_slash
    cw = Graphics.width; ch = Graphics.height
    diag = (Math.sqrt(cw * cw + ch * ch) * 1.15).to_i
    bmp  = Bitmap.new(diag, ch * 2)
    bmp.fill_rect(0, ch - 15, diag, 30, Color.new(140,   0,   0, 255))
    bmp.fill_rect(0, ch - 10, diag, 20, Color.new(210,  15,  15, 255))
    bmp.fill_rect(0, ch -  5, diag, 10, Color.new(255,  50,  50, 255))
    bmp.fill_rect(0, ch -  2, diag,  4, Color.new(255, 140, 140, 255))
    s = Sprite.new(@viewport)
    s.bitmap = bmp; s.ox = diag / 2; s.oy = ch
    s.x = cw / 2; s.y = ch / 2
    @tempSprites << s; s
  end

  def get_frame_info(path)
    @_sheet_cache ||= {}
    return @_sheet_cache[path] if @_sheet_cache[path]

    resolved = pbResolveBitmap(path)
    return nil if !resolved
    bmp = Bitmap.new(resolved)
    
    fw = bmp.height; fh = bmp.height
    if path.include?("WaterProyectile")
      fw = 80; fh = 80
    elsif path.include?("WaterSplashShot")
      fw = 64; fh = 64
    elsif path.include?("Bubbles-Drops")
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

  def animate_sheet_fluid(sprite, path, start_time, ticks_per_frame = 3)
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
    us = @sprites["pokemon_#{@user.index}"]
    ts = @sprites["pokemon_#{@target.index}"]
    return if !us || !ts

    proj_asset   = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::SNIPE_PROJECTILE_ASSETS)
    charge_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::SNIPE_TRAIL_ASSETS)
    splash_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::SNIPE_SPLASH_ASSETS)
    drops_asset  = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::SNIPE_DROPS_ASSETS)
    diag_asset   = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::SNIPE_DIAGONAL_ASSETS)

    # --- 1. Fondo Oscuro Puro (Aparece SÓLO en el impacto) ---
    bg = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
    bg.setZ(0, 715)
    bg.setOpacity(0, 0)
    bg.setOpacity(T_IMPACT, 255)
    bg.moveOpacity(T_IMPACT + 10, 15, 0)

    # --- 2. Sprites Temporales ---
    tu = Sprite.new(@viewport)
    tu.bitmap = us.bitmap; tu.x = us.x; tu.y = us.y
    tu.ox = us.ox; tu.oy = us.oy; tu.mirror = us.mirror
    @tempSprites << tu
    up = addSprite(tu, PictureOrigin::BOTTOM)
    up.setZ(0, 710)

    tt = Sprite.new(@viewport)
    tt.bitmap = ts.bitmap; tt.x = ts.x; tt.y = ts.y
    tt.ox = ts.ox; tt.oy = ts.oy; tt.mirror = ts.mirror
    @tempSprites << tt
    tp = addSprite(tt, PictureOrigin::BOTTOM)
    tp.setZ(0, 720)

    us.visible = false; ts.visible = false
    up.setCallback(T_END, proc { us.visible = true; ts.visible = true })

    # --- 3. Posiciones Centrales ---
    f_dir = (@user.index & 1) == 0 ? 1 : -1
    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40
    th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40

    c_x = us.x + (40 * f_dir)
    c_y = us.y - uh
    i_x = ts.x - (10 * f_dir)
    i_y = ts.y - th

    dx = i_x - c_x; dy = i_y - c_y
    slope = dx != 0 ? dy.to_f / dx : 0.0
    margin = 400
    ext_s_x = c_x - (margin * f_dir)
    ext_s_y = c_y - (margin * f_dir * slope)
    ext_e_x = i_x + (margin * f_dir)
    ext_e_y = i_y + (margin * f_dir * slope)
    angle = -Math.atan2(dy, dx) * 180 / Math::PI

    # --- 4. CARGA E IMPLOSIÓN DE ENERGÍA ---
    if charge_asset
      chg = addNewSprite(c_x, c_y, charge_asset, PictureOrigin::CENTER)
      chg.setZ(0, 715); chg.setVisible(0, false); chg.setOpacity(0, 0)
      apply_frame(chg, charge_asset, 0, 0)
      chg.setTone(0, Tone.new(-150, -50, 180, 0)) 
      
      chg.setVisible(T_CHARGE_START, true)
      chg.setSE(T_CHARGE_START, "Anim/PRSFX- Solar Beam1", 80, 100)
      chg.moveOpacity(T_CHARGE_START, T_CHARGE_DUR / 2, 255)
      chg.moveZoom(T_CHARGE_START, T_CHARGE_DUR, 150)
      chg.moveAngle(T_CHARGE_START, T_CHARGE_DUR, 720)
      chg.moveOpacity(T_SHOT - 2, 2, 0)
      chg.setVisible(T_SHOT, false)

      if drops_asset
        8.times do |i|
          spawn_t = T_CHARGE_START + (i * 2) 
          travel_dur = 12
          p_ang = rand(360)
          p_dist = 70 + rand(50) 
          start_px = c_x + p_dist * Math.cos(p_ang * Math::PI / 180)
          start_py = c_y + p_dist * Math.sin(p_ang * Math::PI / 180)
          
          p = addNewSprite(start_px, start_py, drops_asset, PictureOrigin::CENTER)
          p.setZ(0, 716)
          apply_frame(p, drops_asset, i % 4, 0)
          p.setVisible(0, false)
          p.setTone(0, Tone.new(-150, -50, 180, 0)) 
          
          p.setVisible(spawn_t, true)
          p.setOpacity(spawn_t, 0)
          p.moveOpacity(spawn_t, 3, 255)
          p.setZoom(spawn_t, 20)
          p.moveZoom(spawn_t, travel_dur, 60)
          p.moveXY(spawn_t, travel_dur, c_x, c_y)
          p.moveOpacity(spawn_t + travel_dur - 3, 3, 0)
          p.setVisible(spawn_t + travel_dur, false)
        end
      end
    end

    # --- 5. DISPARO ---
    if proj_asset
      pr = addNewSprite(ext_s_x, ext_s_y, proj_asset, PictureOrigin::CENTER)
      pr.setZ(0, 750); pr.setVisible(0, false)
      apply_frame(pr, proj_asset, 0, 0)
      pr.setAngle(0, angle)
      pr.setZoomXY(0, 200, 40)
      
      pr.setVisible(T_SHOT, true)
      pr.moveXY(T_SHOT, T_TRAVEL_DUR, ext_e_x, ext_e_y)
      pr.setSE(T_SHOT, VermeilBattleAnimations::SNIPE_SHOT_SE_THROW, 100, 100)
      pr.setVisible(T_IMPACT + 1, false)
    end

    # --- 6. IMPACTO MANGA ---
    tp.setSE(T_IMPACT, VermeilBattleAnimations::SNIPE_SHOT_SE_IMPACT, 100, 100)
    tp.setColor(T_IMPACT, Color.new(255, 255, 255, 255))
    tp.moveColor(T_IMPACT + 5, 1, Color.new(255, 255, 255, 255)) 
    tp.moveColor(T_IMPACT + 6, 12, Color.new(255, 255, 255, 0))

    if diag_asset
      slash = addNewSprite(Graphics.width / 2, Graphics.height / 2, diag_asset, PictureOrigin::CENTER)
    else
      slash_s = make_diagonal_slash
      slash = addSprite(slash_s, PictureOrigin::CENTER)
    end
    slash.setZ(0, 718)
    slash.setVisible(0, false); slash.setOpacity(0, 0)
    slash.setAngle(0, angle)
    slash.setVisible(T_IMPACT, true)
    slash.setOpacity(T_IMPACT, 255)
    slash.moveOpacity(T_IMPACT + 8, 12, 0)
    slash.setVisible(T_IMPACT + 20, false)

    shake = 16
    tp.moveDelta(T_IMPACT + 5, 1, shake * f_dir, 0)
    tp.moveDelta(T_IMPACT + 6, 2, shake * -2 * f_dir, 0)
    tp.moveDelta(T_IMPACT + 8, 2, shake * 2 * f_dir, 0)
    tp.moveDelta(T_IMPACT + 10, 1, shake * -f_dir, 0)

    # --- 7. EXPLOSIÓN PRINCIPAL ---
    if splash_asset
      splash = addNewSprite(i_x, i_y, splash_asset, PictureOrigin::CENTER)
      splash.setZ(0, 725)
      splash.setVisible(0, false)
      splash.setVisible(T_IMPACT, true)
      splash.setZoom(T_IMPACT, 150)
      dur = animate_sheet_fluid(splash, splash_asset, T_IMPACT, 3)
      splash.setVisible(T_IMPACT + dur, false)
    end

    # --- 8. GOTAS DE INERCIA ---
    if drops_asset
      10.times do |i|
        d = addNewSprite(i_x, i_y, drops_asset, PictureOrigin::CENTER)
        d.setZ(0, 716) 
        apply_frame(d, drops_asset, i % 4, 0)
        d.setVisible(0, false)
        
        d.setVisible(T_IMPACT, true)
        c_ang = (f_dir == 1) ? 0 : 180
        p_ang = c_ang + rand(80) - 40 
        p_dist = 120 + rand(80)
        p_ex = i_x + p_dist * Math.cos(p_ang * Math::PI / 180)
        p_ey = i_y - p_dist * Math.sin(p_ang * Math::PI / 180)
        
        d.moveXY(T_IMPACT, 10 + rand(5), p_ex, p_ey)
        d.setZoom(T_IMPACT, 60)
        d.moveOpacity(T_IMPACT + 6, 8, 0)
        d.setVisible(T_IMPACT + 15, false)
      end
    end

    up.moveDelta(T_SHOT, 2, -16 * f_dir, 0)
    up.moveDelta(T_SHOT + 2, 10, 16 * f_dir, 0)
  end
end

class Battle
  alias_method :vermeil_snipeshot_pbAnimation, :pbAnimation unless method_defined?(:vermeil_snipeshot_pbAnimation)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = VermeilBattleAnimations.resolve_move_id(move)
    if @showAnims && mid == :SNIPESHOT && @scene.respond_to?(:pbPlayVermeilSnipeShot)
      if hitNum.to_i <= 0
        @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
        @scene.instance_variable_set(:@vermeil_ss_sequence_done,   false)
      end
      return if @scene.pbPlayVermeilSnipeShot(user, targets)
    end

    # Cleanup if sequence got stuck (no "Hit N times" message)
    if @scene
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, false)
      @scene.instance_variable_set(:@vermeil_ss_sequence_done,   false)
      @scene.instance_variable_set(:@vermeil_ss_anim_active,     false)
      @scene.vermeil_ss_set_message_skin(false) if @scene.respond_to?(:vermeil_ss_set_message_skin)
      @scene.vermeil_ss_clear_message_window! if @scene.respond_to?(:vermeil_ss_clear_message_window!)
    end

    vermeil_snipeshot_pbAnimation(move, user, targets, hitNum)
  end
end

class Battle::Scene
  WS_DEFAULT_MESSAGE_ASSET = "Graphics/UI/Battle/overlay_message"
  WS_TRANSPARENT_MESSAGE_ASSET = "Graphics/UI/Battle/transparent_message"

  unless method_defined?(:vermeil_ss_is_final_message?)
    def vermeil_ss_is_final_message?(text)
      t = text.to_s.downcase
      return true if t.include?(" hit ") && t.include?(" time")
      return true if t.include?(" times!")
      return true if t.include?("super effective")
      return true if t.include?("not very effective")
      return true if t.include?("had no effect")
      return false
    end
  end

  unless method_defined?(:vermeil_ss_is_used_line?)
    def vermeil_ss_is_used_line?(text)
      t = text.to_s.downcase
      return t.include?("used") && t.include?("snipe shot")
    end
  end

  unless method_defined?(:vermeil_ss_is_effectiveness_line?)
    def vermeil_ss_is_effectiveness_line?(text)
      t = text.to_s.downcase
      return true if t.include?("super effective")
      return true if t.include?("not very effective")
      return true if t.include?("had no effect")
      return false
    end
  end

  unless method_defined?(:vermeil_ss_set_message_skin)
    def vermeil_ss_set_message_skin(use_transparent)
      return if !@sprites
      msg_box = @sprites["messageBox"]
      return if !msg_box || !msg_box.respond_to?(:setBitmap)
      asset = use_transparent ? WS_TRANSPARENT_MESSAGE_ASSET : WS_DEFAULT_MESSAGE_ASSET
      return if !pbResolveBitmap(asset)
      msg_box.setBitmap(asset)
    rescue
    end
  end

  unless method_defined?(:vermeil_ss_finalize_sequence_for_text!)
    def vermeil_ss_finalize_sequence_for_text!
      @vermeil_ss_sequence_active = false
      @vermeil_ss_sequence_done   = true
      @vermeil_ss_anim_active     = false
      vermeil_ss_set_message_skin(false)
      pbRefresh if respond_to?(:pbRefresh)
    end
  end

  unless method_defined?(:vermeil_ss_clear_message_window!)
    def vermeil_ss_clear_message_window!
      return if !@sprites
      msg_box = @sprites["messageBox"]
      msg_win = @sprites["messageWindow"]
      if msg_win
        msg_win.text = "" if msg_win.respond_to?(:text=)
        msg_win.visible = false if msg_win.respond_to?(:visible=)
      end
      if msg_box
        msg_box.visible = false if msg_box.respond_to?(:visible=)
      end
    end
  end

  unless method_defined?(:vermeil_ss_show_message_window!)
    def vermeil_ss_show_message_window!
      return if !@sprites
      msg_box = @sprites["messageBox"]
      msg_win = @sprites["messageWindow"]
      if msg_box
        msg_box.visible = true if msg_box.respond_to?(:visible=)
        msg_box.opacity = 255 if msg_box.respond_to?(:opacity=)
      end
      if msg_win
        msg_win.visible = true if msg_win.respond_to?(:visible=)
        msg_win.contents_opacity = 255 if msg_win.respond_to?(:contents_opacity=)
      end
    end
  end

  unless method_defined?(:pbPlayVermeilSnipeShot)
    def pbPlayVermeilSnipeShot(user, targets)
      target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
      return false if !user || !target

      @vermeil_ss_anim_active = true
      vermeil_ss_set_message_skin(true)
      vermeil_ss_clear_message_window!
      
      # Hide databoxes (HP bars) during animation
      

      begin
        anim = Animation::VermeilCinematicSnipeShot.new(@sprites, @viewport, user, target)
        loop do
          anim.update
          pbUpdate
          break if anim.animDone?
        end
        anim.dispose
      ensure
        @vermeil_ss_anim_active = false
        @vermeil_ss_sequence_active = false
        @vermeil_ss_sequence_done = true
        vermeil_ss_set_message_skin(false)
        # Show databoxes (HP bars) at end to display damage
        pbRefresh if respond_to?(:pbRefresh)
      end
      return true
    end
  end

  # ---------------------------------------------------------------------------
  # pbDisplayMessage — filter messages only during animation.
  # ---------------------------------------------------------------------------
  unless method_defined?(:vermeil_ss_pbDisplayMessage)
    alias_method :vermeil_ss_pbDisplayMessage, :pbDisplayMessage

    def pbDisplayMessage(msg, brief = false)
      if @vermeil_ss_anim_active
        # During animation, hide all messages but restore after
        return if @vermeil_ss_sequence_active
      end
      
      # Show all messages normally when animation completes
      if @vermeil_ss_sequence_active
        @vermeil_ss_sequence_active = false
        @vermeil_ss_sequence_done = true
        vermeil_ss_set_message_skin(false)
        pbRefresh if respond_to?(:pbRefresh)
      end
      
      vermeil_ss_pbDisplayMessage(msg, brief)
    end
  end

  # Hook 2: Si por alguna razón no hay mensaje y se salta directo al menú de comandos
  alias_method :vermeil_snipeshot_pbCommandMenu, :pbCommandMenu unless method_defined?(:vermeil_snipeshot_pbCommandMenu)
  def pbCommandMenu(*args)
    if @vermeil_ss_sequence_active
      @vermeil_ss_sequence_active = false
      @vermeil_ss_sequence_done = true
      vermeil_ss_set_message_skin(false)
      pbRefresh if respond_to?(:pbRefresh)
    end
    vermeil_snipeshot_pbCommandMenu(*args)
  end
end
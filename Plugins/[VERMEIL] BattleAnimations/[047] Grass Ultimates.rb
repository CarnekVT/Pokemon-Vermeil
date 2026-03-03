#===============================================================================
# [VERMEIL] BattleAnimations - Grass Ultimates v12.0 (FINAL)
# Includes: Solar Beam, Solar Blade, Frenzy Plant + Automatic Charging Turns
# Fix: Smooth Fade IN/OUT for the UI (Databoxes & Message Window) during Charge.
#===============================================================================

module VermeilBattleAnimations
  module_function
  def resolve_move_id(move)
    return move.id if move.respond_to?(:id)
    d = GameData::Move.try_get(move); return d.id if d; move
  end
end

class Battle::Scene::Animation::VermeilGrassUltimates < Battle::Scene::Animation
  
  HANDLED_MOVES = [:SOLARBEAM, :SOLARBLADE, :FRENZYPLANT, :SOLARCHARGE]
  BEHAVIOR = :cinematic

  def initialize(sprites, viewport, user, target, move_id)
    @user = user; @target = target; @move_id = move_id
    super(sprites, viewport)
  end

  def apply_pras_frame(sprite, path, col, row, time = 0, fw = 192, fh = 192)
    resolved = pbResolveBitmap(path); return if !resolved
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

  def make_black_sprite
    bmp = Bitmap.new(Graphics.width, Graphics.height)
    bmp.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
    s = Sprite.new(@viewport); s.bitmap = bmp
    @tempSprites << s; s
  end

  def make_solar_anime_slash
    cw = Graphics.width; ch = Graphics.height
    diag = (Math.sqrt(cw * cw + ch * ch) * 2.5).to_i
    bmp  = Bitmap.new(diag, ch * 2)
    
    bmp.fill_rect(0, ch - 80, diag, 160, Color.new(20, 100, 0, 255))
    bmp.fill_rect(0, ch - 60, diag, 120, Color.new(80, 200, 0, 255))
    bmp.fill_rect(0, ch - 30, diag,  60, Color.new(200, 255, 50, 255))
    bmp.fill_rect(0, ch - 10, diag,  20, Color.new(255, 255, 200, 255))
    
    s = Sprite.new(@viewport); s.bitmap = bmp; s.ox = diag / 2; s.oy = ch
    @tempSprites << s; s
  end

  def createProcesses
    us, ts = @sprites["pokemon_#{@user.index}"], @sprites["pokemon_#{@target.index}"]
    return if !us || !ts
    f_dir = (@user.index & 1) == 0 ? 1 : -1

    target_z = (ts.z rescue 300) + 20
    user_z   = target_z + 40

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, user_z)
    
    is_charge = (@move_id == :SOLARCHARGE)
    tp = is_charge ? nil : addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM)
    tp.setZ(0, target_z) if tp
    
    @us_orig_opac = us.opacity; @ts_orig_opac = ts.opacity
    us.opacity = 0; ts.opacity = 0 if !is_charge

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    orig_ux = us.x; orig_uy = us.y
    orig_tx = ts.x; orig_ty = ts.y
    i_x = ts.x; i_y = ts.y - th

    @end_frame = 35 

    case @move_id
    when :SOLARCHARGE
      # ANIMACIÓN DE CARGA AISLADA
      @end_frame = 30
      orbs_asset = "Graphics/Animations/PRAS- Orbs.png"
      solar_tone = Tone.new(100, 200, -100, 0)
      
      up.setSE(2, "Anim/PRSFX- Focus Energy", 100, 100)
      up.setSE(10, "Anim/Wind2", 100, 150)
      
      up.moveColor(8, 10, Color.new(200, 255, 100, 150))
      up.moveColor(18, 10, Color.new(0, 0, 0, 0))
      
      charge_y = orig_uy - uh - 10 
      
      if pbResolveBitmap(orbs_asset)
        25.times do |i|
          t_s = 2 + rand(15)
          orb = addNewSprite(orig_ux + (rand(600) - 300), charge_y + (rand(400) - 200), orbs_asset, PictureOrigin::CENTER)
          orb.setZ(0, user_z + 10)
          
          raw_orb = @pictureSprites.last; raw_orb.ox = 96; raw_orb.oy = 96 if raw_orb
          
          apply_pras_frame(orb, orbs_asset, rand(2) * 2, 0, 0)
          orb.setTone(0, solar_tone); orb.setBlendType(0, 1)
          orb.setVisible(0, false); orb.setVisible(t_s, true)
          orb.setZoom(0, 80 + rand(60))
          
          orb.moveXY(t_s, 6, orig_ux, charge_y)
          orb.moveZoom(t_s, 6, 10)
          orb.moveOpacity(t_s + 4, 2, 0)
        end
      end

    when :SOLARBEAM
      # SOLAR BEAM - Bolas Gigantes CENTRADAS (RZE Style) con Fondo Oscuro
      t_gather = 2; t_fire = 8; t_hit = 10; @end_frame = 30
      orbs_asset = "Graphics/Animations/PRAS- Orbs.png"
      strike_asset = "Graphics/Animations/PRAS- Strike.png"
      
      solar_tone = Tone.new(100, 200, -50, 0) 
      
      bg_dim = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
      bg_dim.setZ(0, target_z - 10)
      bg_dim.setOpacity(0, 0)
      bg_dim.moveOpacity(t_gather, 4, 200)
      bg_dim.moveOpacity(t_hit + 10, 6, 0)
      
      up.setSE(t_gather, "Anim/Absorb2", 100, 150)
      if pbResolveBitmap(orbs_asset)
        3.times do |i|
          orb = addNewSprite(orig_ux, orig_uy - (uh/2), orbs_asset, PictureOrigin::CENTER)
          orb.setZ(0, user_z + 10)
          raw_orb = @pictureSprites.last; raw_orb.ox = 96; raw_orb.oy = 96 if raw_orb
          
          apply_pras_frame(orb, orbs_asset, 2, 0, 0)
          orb.setTone(0, solar_tone); orb.setBlendType(0, 1)
          orb.setVisible(0, false); orb.setVisible(t_gather, true)
          orb.setZoom(0, 150) 
          
          ang = i * 120
          sx = orig_ux + (Math.cos(ang * Math::PI / 180) * 80)
          sy = orig_uy - (uh/2) + (Math.sin(ang * Math::PI / 180) * 80)
          
          orb.setXY(t_gather, sx, sy)
          orb.moveXY(t_gather, 4, orig_ux, orig_uy - (uh/2))
          orb.moveZoom(t_gather, 4, 10)
          orb.moveOpacity(t_gather + 3, 1, 0)
        end
      end
      
      up.setSE(t_fire, "Anim/Explosion", 90, 120) 
      up.moveXY(t_fire, 2, orig_ux - (15 * f_dir), orig_uy)
      up.moveXY(t_fire + 6, 6, orig_ux, orig_uy)
      
      if pbResolveBitmap(orbs_asset)
        angle = Math.atan2((orig_ty - (th/2)) - (orig_uy - (uh/2)), orig_tx - orig_ux) * 180 / Math::PI
        
        20.times do |i|
          t_l = t_fire + (i / 2)
          orb_beam = addNewSprite(orig_ux, orig_uy - (uh/2), orbs_asset, PictureOrigin::CENTER)
          orb_beam.setZ(0, target_z + 24 + i)
          raw_orb = @pictureSprites.last; raw_orb.ox = 96; raw_orb.oy = 96 if raw_orb
          
          apply_pras_frame(orb_beam, orbs_asset, 0, 0, 0)
          orb_beam.setTone(0, solar_tone); orb_beam.setBlendType(0, 1)
          orb_beam.setVisible(0, false); orb_beam.setVisible(t_l, true)
          
          orb_beam.setZoom(0, 250 + rand(50)) 
          orb_beam.setAngle(0, angle)
          
          orb_beam.moveXY(t_l, 3, orig_tx, orig_ty - (th/2))
          orb_beam.moveOpacity(t_l + 2, 2, 0)
        end
      end
      
      tp.setSE(t_hit, "Anim/PRSFX- Hyper Beam", 100, 100)
      tp.moveColor(t_hit, 3, Color.new(255, 255, 200, 255))
      tp.moveColor(t_hit + 4, 6, Color.new(0,0,0,0))
      
      10.times { |i| tp.moveXY(t_hit + i, 1, orig_tx + (i.even? ? 15 : -15), orig_ty) }
      tp.moveXY(t_hit + 10, 1, orig_tx, orig_ty)
      
      if pbResolveBitmap(strike_asset)
        10.times do |i|
          t_s = t_hit + (i % 4)
          spark = addNewSprite(orig_tx, orig_ty - (th/2), strike_asset, PictureOrigin::CENTER)
          spark.setZ(0, target_z + 30)
          raw_sp = @pictureSprites.last; raw_sp.ox = 96; raw_sp.oy = 96 if raw_sp
          
          apply_pras_frame(spark, strike_asset, 3, 0, 0) 
          spark.setTone(0, solar_tone); spark.setBlendType(0, 1)
          spark.setVisible(0, false); spark.setVisible(t_s, true)
          spark.setZoom(0, 100 + rand(100))
          spark.setAngle(0, rand(360))
          spark.moveXY(t_s, 5, orig_tx + (rand(200)-100), orig_ty - (th/2) + (rand(200)-100))
          spark.moveOpacity(t_s + 3, 3, 0)
        end
      end

    when :SOLARBLADE
      # SOLAR BLADE - 3 Tajos con ORBES DE ENERGÍA como daño
      t_dash = 2; t_hit1 = 8; t_hit2 = 13; t_hit3 = 18; t_return = 26; @end_frame = 35
      slash_asset = "Graphics/Animations/PRAS- Slash.png"
      orbs_asset = "Graphics/Animations/PRAS- Orbs.png" 
      
      solar_tone = Tone.new(100, 200, -100, 0)
      
      bg_dim = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
      bg_dim.setZ(0, target_z - 10)
      bg_dim.setOpacity(0, 0)
      bg_dim.moveOpacity(t_dash, 4, 220)
      bg_dim.moveOpacity(t_return, 6, 0)
      
      up.setSE(t_dash, "Anim/Wind1", 100, 130)
      up.moveColor(t_dash, 2, Color.new(255, 255, 200, 255))
      up.moveXY(t_dash, 3, orig_ux + (150 * f_dir), orig_uy - 100)
      up.moveOpacity(t_dash, 3, 0)
      
      do_slash = ->(t_hit, angle, shake_x, shake_y) {
        
        diag_s = make_solar_anime_slash
        diag = addSprite(diag_s, PictureOrigin::CENTER); diag.setZ(0, 580)
        diag.setXY(0, i_x, i_y)
        diag.setVisible(0, false); diag.setOpacity(0, 0)
        diag.setAngle(0, angle) 
        
        diag.setVisible(t_hit, true)
        diag.setOpacity(t_hit, 255)
        diag.moveZoomXY(t_hit, 4, 100, 20) 
        diag.moveOpacity(t_hit + 4, 2, 0)

        tp.setSE(t_hit, "Anim/PRSFX- Slash", 100, 90)
        tp.setSE(t_hit, "Anim/PRSFX- Focus Punch2", 100, 110)
        
        tp.moveColor(t_hit, 2, Color.new(200, 255, 100, 255))
        tp.moveColor(t_hit + 3, 3, Color.new(0, 0, 0, 0))
        
        tp.moveXY(t_hit, 2, orig_tx + shake_x, orig_ty + shake_y)
        tp.moveXY(t_hit + 2, 2, orig_tx, orig_ty)

        if pbResolveBitmap(slash_asset)
          slash = addNewSprite(i_x, i_y, slash_asset, PictureOrigin::CENTER); slash.setZ(0, 755)
          raw_slash = @pictureSprites.last; raw_slash.ox = 96; raw_slash.oy = 96 if raw_slash

          slash.setBlendType(0, 1); slash.setTone(0, solar_tone) 
          slash.setVisible(0, false); slash.setVisible(t_hit, true)
          slash.setAngle(0, angle); slash.setZoom(0, 220)
          
          5.times { |f| apply_pras_frame(slash, slash_asset, f, 0, t_hit + f) }
          slash.moveOpacity(t_hit + 4, 2, 0)
        end
        
        if pbResolveBitmap(orbs_asset)
          8.times do |i|
            sp = addNewSprite(i_x, i_y, orbs_asset, PictureOrigin::CENTER); sp.setZ(0, 760)
            raw_sp = @pictureSprites.last; raw_sp.ox = 96; raw_sp.oy = 96 if raw_sp
            
            apply_pras_frame(sp, orbs_asset, 2, 0, 0) 
            sp.setBlendType(0, 1); sp.setTone(0, solar_tone) 
            sp.setVisible(0, false); sp.setVisible(t_hit, true)
            sp.setZoom(0, 80 + rand(60))
            
            pop_x = i_x + (rand(160) - 80) * f_dir
            pop_y = i_y + (rand(160) - 80)
            sp.moveXY(t_hit, 4 + rand(2), pop_x, pop_y)
            sp.moveOpacity(t_hit + 2, 4, 0)
          end
        end
      }

      ang1 = f_dir == 1 ? 45 : 225
      do_slash.call(t_hit1, ang1, 16 * f_dir, 16)
      
      ang2 = f_dir == 1 ? 135 : 315
      do_slash.call(t_hit2, ang2, -16 * f_dir, 16)
      
      ang3 = f_dir == 1 ? 90 : 270
      do_slash.call(t_hit3, ang3, 0, 25)

      up.setXY(t_return, orig_ux - (40 * f_dir), orig_uy - 30)
      up.setSE(t_return, "Anim/Wind1", 80, 150)
      up.moveOpacity(t_return, 3, 255)
      up.moveXY(t_return, 4, orig_ux, orig_uy)
      up.moveColor(t_return, 2, Color.new(200, 255, 100, 200))
      up.moveColor(t_return + 2, 4, Color.new(0, 0, 0, 0))

    when :FRENZYPLANT
      # FRENZY PLANT
      t_quake = 2; t_erupt = 10; t_crush = 22; @end_frame = 45
      frenzy_asset = "Graphics/Animations/PRAS- Frenzy Plant.png"
      rock_asset = "Graphics/Animations/PRAS- Rock.png"
      
      root_y = orig_ty - 35
      root_mul = (f_dir == -1) ? 1.5 : 1.0
      
      up.setSE(t_quake, "Anim/Earthquake", 100, 80)
      
      8.times { |i| up.moveXY(t_quake + i, 1, orig_ux, orig_uy + (i.even? ? 6 : -6)) }
      up.moveXY(t_quake + 8, 1, orig_ux, orig_uy)
      
      if pbResolveBitmap(frenzy_asset)
        roots_config = [
          [2, -60, -1, 0], 
          [3, 60,  -1, 2], 
          [2, -30,  1, 4], 
          [3, 30,   1, 6]  
        ]
        
        roots_config.each do |cfg|
          row = cfg[0]; x_off = cfg[1]; z_mod = cfg[2]; delay = cfg[3]
          t_spawn = t_erupt + delay
          
          vine = addNewSprite(orig_tx + x_off, root_y + (z_mod == -1 ? -10 : 10), frenzy_asset, PictureOrigin::CENTER)
          vine.setZ(0, target_z + (z_mod == -1 ? -5 : 50)) 
          apply_pras_frame(vine, frenzy_asset, 0, row, 0)
          vine.setVisible(0, false); vine.setVisible(t_spawn, true)
          
          v_zoom = (z_mod == -1 ? 220 : 280) * root_mul
          vine.setZoomXY(0, x_off < 0 ? v_zoom : -v_zoom, v_zoom)
          
          up.setSE(t_spawn, "Anim/PRSFX- Wood Hammer", 90, 110 + rand(20))
          5.times { |f| apply_pras_frame(vine, frenzy_asset, f, row, t_spawn + f) }
          vine.moveOpacity(t_crush + 8, 6, 0)
          
          if pbResolveBitmap(rock_asset)
            4.times do |r|
              rock = addNewSprite(orig_tx + x_off, orig_ty, rock_asset, PictureOrigin::CENTER)
              rock.setZ(0, target_z + 60 + r)
              raw_rk = @pictureSprites.last; raw_rk.ox = 96; raw_rk.oy = 96 if raw_rk
              
              apply_pras_frame(rock, rock_asset, rand(4), 1, 0) 
              rock.setVisible(0, false); rock.setVisible(t_spawn, true)
              rock.setZoom(0, 10 + rand(15)) 
              
              rock.moveXY(t_spawn, 8, orig_tx + x_off + (x_off < 0 ? -100 : 100) + rand(50), orig_ty - 60 - rand(60))
              rock.moveAngle(t_spawn, 8, rand(720) * (x_off < 0 ? -1 : 1))
              rock.moveOpacity(t_spawn + 4, 4, 0)
            end
          end
        end
      end
      
      tp.setSE(t_crush, "Anim/Earth1", 100, 80)
      tp.setSE(t_crush, "Anim/Super Damage", 100, 100)
      tp.setSE(t_crush, "Anim/PRSFX- Crush Claw", 100, 90)
      
      tp.moveZoomXY(t_crush, 3, 140, 30) 
      tp.moveZoomXY(t_crush + 3, 4, 100, 100) 
      
      tp.moveColor(t_crush, 3, Color.new(50, 150, 50, 220)) 
      tp.moveColor(t_crush + 5, 4, Color.new(0,0,0,0))
      
      14.times { |i| tp.moveXY(t_crush + i, 1, orig_tx + (i.even? ? 15 : -15), orig_ty + (i.even? ? 10 : -10)) }
      tp.moveXY(t_crush + 14, 1, orig_tx, orig_ty)

    end

    up.setXY(@end_frame - 1, orig_ux, orig_uy)
    up.setZoom(@end_frame - 1, 100)
    up.setZ(@end_frame - 1, user_z)
    
    if tp
      tp.setXY(@end_frame - 1, orig_tx, orig_ty)
      tp.setZoomXY(@end_frame - 1, 100, 100)
    end
    
    up.setCallback(@end_frame, proc { 
      us.opacity = @us_orig_opac
      ts.opacity = @ts_orig_opac if ts
      us.visible = true
      ts.visible = true if ts 
    })
  end
end

#===============================================================================
# INTERCEPTOR AISLADO DE FASE DE CARGA (Turno 1 vs Turno 2)
#===============================================================================

class Battle::Move
  alias_method :vermeil_pbShowAnimation, :pbShowAnimation unless method_defined?(:vermeil_pbShowAnimation)
  
  def pbShowAnimation(id, user, targets, hitNum = 0, showAnimation = true)
    if [:SOLARBEAM, :SOLARBLADE].include?(@id) && defined?(@damagingTurn) && !@damagingTurn
      if @battle.showAnims && @battle.scene.respond_to?(:pbPlayVermeilGrassUltimates)
        @battle.scene.pbPlayVermeilGrassUltimates(user, user, :SOLARCHARGE)
      end
      return
    end
    
    vermeil_pbShowAnimation(id, user, targets, hitNum, showAnimation)
  end
end

class Battle
  alias_method :vermeil_grass_ults_pbAnimation, :pbAnimation unless method_defined?(:vermeil_grass_ults_pbAnimation)
  
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = VermeilBattleAnimations.resolve_move_id(move)
    
    if @showAnims && [:SOLARBEAM, :SOLARBLADE, :FRENZYPLANT].include?(mid) && @scene.respond_to?(:pbPlayVermeilGrassUltimates)
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
      return if @scene.pbPlayVermeilGrassUltimates(user, targets, mid)
    end
    
    vermeil_grass_ults_pbAnimation(move, user, targets, hitNum)
  end
end

class Battle::Scene
  unless method_defined?(:pbPlayVermeilGrassUltimates)
    def pbPlayVermeilGrassUltimates(user, targets, anim_id)
      target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
      return false if !user || (!target && anim_id != :SOLARCHARGE)
      
      target = user if anim_id == :SOLARCHARGE 
      
      @vermeil_ss_anim_active = true
      vermeil_ss_set_message_skin(true) if respond_to?(:vermeil_ss_set_message_skin)
      vermeil_ss_clear_message_window! if respond_to?(:vermeil_ss_clear_message_window!)
      
      ui_sprites = []
      
      # ===== FADE OUT SMOOTH DE LA UI DURANTE LA CARGA =====
      if anim_id == :SOLARCHARGE
        @sprites.each do |key, sprite|
          next if !sprite || !sprite.respond_to?(:opacity=) || !sprite.visible
          if key.to_s.downcase.start_with?("databox") || ["messagewindow", "messagebox"].include?(key.to_s.downcase)
            ui_sprites << sprite
          end
        end
        
        # Desvanece la UI en 10 frames para que sea muy smooth
        10.times do
          ui_sprites.each { |s| s.opacity -= 26 }
          pbUpdate
        end
        ui_sprites.each { |s| s.visible = false; s.opacity = 255 }
      end
      
      begin
        anim = Animation::VermeilGrassUltimates.new(@sprites, @viewport, user, target, anim_id)
        loop do 
          anim.update
          pbUpdate
          break if anim.animDone?
        end
        anim.dispose
      ensure
        # ===== FADE IN SMOOTH DE LA UI DESPUÉS DE LA CARGA =====
        if anim_id == :SOLARCHARGE
          ui_sprites.each { |s| s.visible = true; s.opacity = 0 }
          
          # Aparece la UI gradualmente
          10.times do
            ui_sprites.each { |s| s.opacity += 26 }
            pbUpdate
          end
          ui_sprites.each { |s| s.opacity = 255 }
        end
        
        @vermeil_ss_anim_active = false
        vermeil_ss_set_message_skin(false) if respond_to?(:vermeil_ss_set_message_skin)
        pbRefresh if respond_to?(:pbRefresh)
      end
      return true
    end
  end
end
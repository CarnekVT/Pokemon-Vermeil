#===============================================================================
# [VERMEIL] BattleAnimations - Signature Hammers
# Includes: Wood Hammer, Dragon Hammer, Gigaton Hammer
# Concept: Refined Particles, Dynamic Impacts, and Gigaton Suspended Smash.
# Update: Fixed Gigaton Hammer approach (Perfect dash without flying off-screen).
#===============================================================================

class Battle::Scene::Animation::VermeilSignatureHammers < Battle::Scene::Animation
  
  HANDLED_MOVES = [:WOODHAMMER, :DRAGONHAMMER, :GIGATONHAMMER]
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

  def createProcesses
    us, ts = @sprites["pokemon_#{@user.index}"], @sprites["pokemon_#{@target.index}"]
    return if !us || !ts
    f_dir = (@user.index & 1) == 0 ? 1 : -1

    orig_tz = (ts.z rescue 300) + 10
    orig_uz = orig_tz + 40

    # AISLAMIENTO CINEMÁTICO 
    bg_z = 90000
    target_z = bg_z + 10
    user_z   = bg_z + 40

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, user_z)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, target_z)
    us.visible = false; ts.visible = false

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    i_x = ts.x; i_y = ts.y - th; orig_ux = us.x; orig_uy = us.y; orig_tx = ts.x; orig_ty = ts.y

    dist_x = (f_dir == 1) ? 50 : 100 
    dist_y = (f_dir == 1) ? 10 : -15 
    dash_x = orig_tx - (dist_x * f_dir)
    dash_y = orig_ty + dist_y
    zoom_target = (f_dir == 1) ? 75 : 130 

    @end_frame = 55

    # ASSETS
    wood_asset   = "Graphics/Animations/PRAS- Wood Hammer.png"
    dragon_asset = "Graphics/Animations/PRAS- Dragon Tail.png"
    metal_asset  = "Graphics/Animations/PRAS- Metal Burst.png"
    pummel_asset = "Graphics/Animations/PRAS- All Out Pummeling.png"
    spark_asset  = "Graphics/Animations/PRAS- Strike.png"

    case @move_id
    when :WOODHAMMER
      t_charge = 6
      t_imp = 10
      @end_frame = 45

      up.setZ(0, target_z - 5) if f_dir == -1
      up.setSE(0, "Anim/Wind1", 100, 80)
      
      up.moveXY(0, t_imp, dash_x, dash_y) 
      up.moveZoom(0, t_imp, zoom_target)
      
      tp.setSE(t_imp, "Anim/Wind 1", 100, 90)
      tp.setSE(t_imp, "Anim/PRSFX- Focus Punch2", 100, 110)
      tp.moveColor(t_imp, 2, Color.new(50, 255, 50, 200)); tp.moveColor(t_imp + 6, 6, Color.new(0,0,0,0))
      
      tp.moveZoomXY(t_imp, 2, 130, 60); tp.moveXY(t_imp, 2, orig_tx, orig_ty + 30)
      tp.moveZoomXY(t_imp + 6, 6, 100, 100); tp.moveXY(t_imp + 6, 6, orig_tx, orig_ty)
      10.times { |i| tp.moveDelta(t_imp + i, 1, (i.even? ? 15 : -15) * f_dir, 0) }

      if pbResolveBitmap(wood_asset)
        16.times do |i|
          is_log = i.even?
          shard = addNewSprite(i_x, i_y, wood_asset, PictureOrigin::CENTER); shard.setZ(0, target_z + 17)
          apply_pras_frame(shard, wood_asset, is_log ? 0 : 1, 0, 0) 
          shard.setVisible(0, false); shard.setVisible(t_imp, true)
          
          shard.setZoom(0, is_log ? (30 + rand(20)) : (20 + rand(15)))
          
          ang = rand(360) * Math::PI / 180
          dist_s = 80 + rand(100)
          
          shard.moveXY(t_imp, 6 + rand(4), i_x + Math.cos(ang)*dist_s, i_y + Math.sin(ang)*dist_s)
          shard.moveAngle(t_imp, 10, rand(720) * (f_dir)) 
          shard.moveOpacity(t_imp + 6, 4, 0)
        end
      end

      up.moveXY(t_imp + 10, 6, orig_ux, orig_uy)
      up.moveZoom(t_imp + 10, 6, 100)
      up.setZ(t_imp + 10, orig_uz)

    when :DRAGONHAMMER
      t_charge = 4
      t_imp = 8    
      @end_frame = 45
      
      bg = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
      bg.setZ(0, bg_z); bg.setOpacity(0, 0); bg.moveOpacity(0, 4, 180)

      up.setZ(0, target_z - 5) if f_dir == -1
      up.setSE(0, "Anim/PRSFX- Dragon Tail", 100, 100)
      
      up.moveXY(0, t_charge, dash_x, dash_y - 120) 
      up.moveZoom(0, t_charge, zoom_target)
      up.moveTone(0, t_charge, Tone.new(150, -50, 255, 100)) 

      up.setSE(t_charge, "Anim/Wind1", 100, 180)
      up.moveXY(t_charge, t_imp - t_charge, dash_x + (20 * f_dir), dash_y)

      tp.setSE(t_imp, "Anim/PRSFX- Focus Punch2", 100, 90)
      tp.setSE(t_imp + 2, "Anim/Earth1", 100, 110)
      
      flash = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
      flash.setZ(0, 99999); flash.setTone(0, Tone.new(150, 50, 255, 0))
      flash.setOpacity(0, 0); flash.moveOpacity(t_imp, 1, 255); flash.moveOpacity(t_imp + 3, 6, 0)

      tp.moveColor(t_imp, 2, Color.new(200, 100, 255, 255)); tp.moveColor(t_imp + 6, 6, Color.new(0,0,0,0))
      
      tp.moveZoomXY(t_imp, 2, 140, 60); tp.moveXY(t_imp, 2, orig_tx, orig_ty + 40)
      tp.moveZoomXY(t_imp + 8, 6, 100, 100); tp.moveXY(t_imp + 8, 6, orig_tx, orig_ty)
      14.times { |i| tp.moveDelta(t_imp + i, 1, 0, (i.even? ? 15 : -15)) }

      if pbResolveBitmap(dragon_asset)
        18.times do |i|
          shard = addNewSprite(i_x, i_y, dragon_asset, PictureOrigin::CENTER); shard.setZ(0, target_z + 17)
          apply_pras_frame(shard, dragon_asset, rand(5), rand(2), 0)
          shard.setBlendType(0, 1)
          shard.setVisible(0, false); shard.setVisible(t_imp, true)
          shard.setZoom(0, 40 + rand(40))
          
          ang = rand(360) * Math::PI / 180
          dist_s = 100 + rand(120)
          shard.moveXY(t_imp, 6 + rand(4), i_x + Math.cos(ang)*dist_s, i_y + Math.sin(ang)*dist_s)
          shard.moveAngle(t_imp, 10, rand(720) * (i.even? ? 1 : -1)) 
          shard.moveOpacity(t_imp + 4, 6, 0)
        end
      end

      bg.moveOpacity(t_imp + 10, 8, 0)
      up.moveTone(t_imp + 10, 6, Tone.new(0,0,0,0))
      up.moveXY(t_imp + 12, 6, orig_ux, orig_uy)
      up.moveZoom(t_imp + 12, 6, 100)
      up.setZ(t_imp + 12, orig_uz)

    when :GIGATONHAMMER
      # GIGATON HAMMER
      bg = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
      bg.setZ(0, bg_z); bg.setOpacity(0, 0); bg.moveOpacity(0, 6, 200)

      up.setZ(0, user_z); tp.setZ(0, target_z)
      
      t_lift = 4
      t_hang = t_lift + 16 
      t_imp = t_hang + 3   
      @end_frame = t_imp + 40

      up.setSE(0, "Anim/Earth1", 100, 80)
      up.setZ(0, target_z - 5) if f_dir == -1
      
      # FIX: Restablecido el acercamiento (dash_x) pero anulado el salto exagerado (limitado a dash_y - 10)
      jump_y = dash_y - 10 
      up.moveXY(0, t_lift, dash_x, jump_y)
      up.moveZoom(0, t_lift, zoom_target)

      if pbResolveBitmap(pummel_asset)
        g_hammer = addNewSprite(i_x, i_y - 200, pummel_asset, PictureOrigin::CENTER)
        g_hammer.setZ(0, target_z + 15)
        
        apply_pras_frame(g_hammer, pummel_asset, 1, 0, 0) 
        g_hammer.setTone(0, Tone.new(200, -50, 100, 100)) 
        g_hammer.setAngle(0, 180) 
        g_hammer.setVisible(0, false); g_hammer.setVisible(t_lift, true)
        g_hammer.setZoom(0, 400)

        up.setSE(t_lift, "Anim/Wind1", 80, 150)
        16.times do |i| 
          g_hammer.moveDelta(t_lift + i, 1, (i.even? ? 6 : -6), 0)
        end
        
        up.setSE(t_hang, "Anim/Wind2", 100, 150)
        g_hammer.moveXY(t_hang, t_imp - t_hang, i_x, i_y)
        g_hammer.moveOpacity(t_imp + 4, 4, 0)
      end

      tp.setSE(t_imp, "Anim/PRSFX- Focus Punch2", 100, 80)
      tp.setSE(t_imp + 2, "Anim/Earth1", 100, 100)
      tp.setSE(t_imp + 4, "Anim/PRSFX- Focus Punch2", 100, 90)
      
      flash = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
      flash.setZ(0, 99999); flash.setTone(0, Tone.new(255, 200, 255, 0)) 
      flash.setOpacity(0, 0); flash.moveOpacity(t_imp, 1, 255); flash.moveOpacity(t_imp + 3, 10, 0)

      tp.moveColor(t_imp, 3, Color.new(255, 100, 200, 255)); tp.moveColor(t_imp + 10, 8, Color.new(0,0,0,0))
      
      tp.moveZoomXY(t_imp, 2, 160, 40); tp.moveXY(t_imp, 2, orig_tx, orig_ty + 50)
      tp.moveZoomXY(t_imp + 12, 8, 100, 100); tp.moveXY(t_imp + 12, 8, orig_tx, orig_ty)
      18.times { |i| tp.moveDelta(t_imp + i, 1, (i.even? ? 20 : -20), (i.even? ? 10 : -10)) }

      if pbResolveBitmap(metal_asset)
        24.times do |i|
          shard = addNewSprite(i_x, i_y, metal_asset, PictureOrigin::CENTER)
          shard.setZ(0, target_z + 20)
          apply_pras_frame(shard, metal_asset, rand(5), rand(3), 0)
          shard.setBlendType(0, 0)
          shard.setVisible(0, false); shard.setVisible(t_imp + rand(3), true)
          shard.setZoom(0, 60 + rand(60))
          
          shard.setTone(0, Tone.new(150, -50, 150, 150)) if i.even? 
          
          ang = rand(360) * Math::PI / 180
          dist_s = 150 + rand(250)
          shard.moveXY(t_imp, 8 + rand(8), i_x + Math.cos(ang)*dist_s, i_y + Math.sin(ang)*dist_s)
          shard.moveAngle(t_imp, 15, rand(1080) * (i.even? ? 1 : -1)) 
          shard.moveOpacity(t_imp + 6, 8, 0)
        end
      end
      
      if pbResolveBitmap(spark_asset)
        10.times do |i|
           spp = addNewSprite(i_x, i_y, spark_asset, PictureOrigin::CENTER)
           spp.setZ(0, target_z + 21)
           apply_pras_frame(spp, spark_asset, rand(3), 0, 0)
           spp.setBlendType(0, 1); spp.setTone(0, Tone.new(255, 100, 200, 0))
           spp.setVisible(0, false); spp.setVisible(t_imp, true)
           spp.setZoom(0, 80 + rand(50))
           ang = rand(360) * Math::PI / 180
           dist_s = 100 + rand(150)
           spp.moveXY(t_imp, 6 + rand(6), i_x + Math.cos(ang)*dist_s, i_y + Math.sin(ang)*dist_s)
           spp.moveOpacity(t_imp + 4, 6, 0)
        end
      end

      bg.moveOpacity(t_imp + 15, 10, 0)
      up.moveXY(t_imp + 15, 8, orig_ux, orig_uy)
      up.moveZoom(t_imp + 15, 8, 100)
      up.setZ(t_imp + 15, orig_uz)
    end

    up.setXY(@end_frame - 1, orig_ux, orig_uy)
    up.setZoom(@end_frame - 1, 100)
    up.setZ(@end_frame - 1, orig_uz)
    
    tp.setXY(@end_frame - 1, orig_tx, orig_ty)
    tp.setZoom(@end_frame - 1, 100)
    tp.setZ(@end_frame - 1, orig_tz)
    
    up.setCallback(@end_frame, proc { us.visible = true; ts.visible = true })
  end
end
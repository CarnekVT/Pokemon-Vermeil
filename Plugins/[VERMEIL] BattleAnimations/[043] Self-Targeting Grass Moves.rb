#===============================================================================
# [VERMEIL] BattleAnimations - Self-Targeting Grass Moves v3.1 (ULTRA FAST & ROBUST)
# Includes: Synthesis, Spiky Shield, Growth, Ingrain
#===============================================================================

class Battle::Scene::Animation::VermeilSelfTargetGrass < Battle::Scene::Animation
  
  HANDLED_MOVES = [:SYNTHESIS, :SPIKYSHIELD, :GROWTH, :INGRAIN]
  BEHAVIOR = :self_targeting

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

  def createProcesses
    us = @sprites["pokemon_#{@user.index}"]
    return if !us
    
    f_dir = (@user.index & 1) == 0 ? 1 : -1
    user_z = (us.z rescue 300) + 20

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM)
    up.setZ(0, user_z)
    
    @us_orig_opac = us.opacity
    us.opacity = 0
    us.visible = false

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40
    orig_ux = us.x; orig_uy = us.y

    # DEFINICIÓN ESTRICTA DE TODOS LOS RECURSOS PARA EVITAR QUE SEAN INVISIBLES
    ing_asset     = "Graphics/Animations/PRAS- Ingrain.png"
    frenzy_asset  = "Graphics/Animations/PRAS- Frenzy Plant.png"
    orbs_asset    = "Graphics/Animations/PRAS- Orbs.png"
    protect_asset = "Graphics/Animations/PRAS- Protect.png"
    spike_asset   = "Graphics/Animations/PRAS- Spike Cannon.png"

    case @move_id
    when :SYNTHESIS
      # SYNTHESIS (Tiempo de espera reducido al mínimo)
      t_start = 0; @end_frame = 15
      up.setSE(0, "Anim/Recovery", 100, 130)
      up.moveColor(t_start, 4, Color.new(200, 255, 100, 180))
      up.moveColor(t_start + 6, 4, Color.new(0,0,0,0))
      
      if pbResolveBitmap(orbs_asset)
        8.times do |i|
          delay = t_start
          ang = (i * 45) * 3.14159 / 180.0
          rad = 120 + rand(20)
          
          start_x = orig_ux + Math.cos(ang) * rad
          start_y = (orig_uy - uh/2) + Math.sin(ang) * rad
          
          light = addNewSprite(start_x, start_y, orbs_asset, PictureOrigin::CENTER)
          light.setZ(0, user_z + 100) 
          apply_pras_frame(light, orbs_asset, rand(3), 0, 0)
          light.setTone(0, Tone.new(50, 200, -50, 0)) 
          light.setVisible(0, false); light.setVisible(delay, true)
          light.setZoom(0, 60)
          
          light.moveXY(delay, 6, orig_ux, orig_uy - (uh/2))
          light.moveOpacity(delay + 4, 2, 0)
        end
      end
      
    when :SPIKYSHIELD
      # SPIKY SHIELD: END FRAME 20 (balanced speed)
      t_start = 0; @end_frame = 20
      up.setSE(t_start, "Anim/PRSFX- Spiky Shield2", 100, 120)
      
      if pbResolveBitmap(protect_asset)
        shield = addNewSprite(orig_ux, orig_uy - (uh/2), protect_asset, PictureOrigin::CENTER)
        shield.setZ(0, user_z + 100)
        apply_pras_frame(shield, protect_asset, 0, 0, 0) 
        shield.setTone(0, Tone.new(-100, 150, -100, 0)) 
        shield.setVisible(0, false); shield.setVisible(t_start, true)
        shield.setZoom(0, 50); shield.moveZoom(t_start, 2, 180)
        
        3.times do |i|
           apply_pras_frame(shield, protect_asset, i, 0, t_start + (i*2))
        end
        shield.moveOpacity(t_start + 6, 2, 0)
      end
      
      if pbResolveBitmap(spike_asset)
        8.times do |i|
          spike = addNewSprite(orig_ux, orig_uy - (uh/2), spike_asset, PictureOrigin::CENTER)
          spike.setZ(0, user_z + 105)
          apply_pras_frame(spike, spike_asset, 0, 0, 0)
          spike.setVisible(0, false); spike.setVisible(t_start, true)
          
          ang = (i * 45)
          spike.setAngle(0, ang)
          spike.setZoom(0, 150)
          
          rad = 140
          dest_x = orig_ux + Math.cos(ang * 3.14159 / 180) * rad
          dest_y = (orig_uy - uh/2) + Math.sin(ang * 3.14159 / 180) * rad
          
          spike.moveXY(t_start, 4, dest_x, dest_y)
          spike.moveOpacity(t_start + 3, 2, 0)
        end
      end
      
      up.moveTone(t_start, 2, Tone.new(-50, 100, -50, 50))
      up.moveTone(t_start + 4, 2, Tone.new(0,0,0,0))

    when :GROWTH
      t_start = 0; t_absorb = 6; t_burst = 10; @end_frame = 20
      up.setSE(0, "Anim/PRSFX- Focus Energy", 100, 150)
      
      if pbResolveBitmap(orbs_asset)
        8.times do |i|
          ang = (i * 45) * 3.14159 / 180.0
          rad = 100
          start_x = orig_ux + Math.cos(ang) * rad
          start_y = (orig_uy - uh/2) + Math.sin(ang) * rad
          
          orb = addNewSprite(start_x, start_y, orbs_asset, PictureOrigin::CENTER)
          orb.setZ(0, user_z + 100)
          apply_pras_frame(orb, orbs_asset, rand(3), 0, 0)
          orb.setTone(0, Tone.new(50, 200, -50, 0))
          orb.setVisible(0, false); orb.setVisible(t_start, true)
          orb.setZoom(0, 50)
          
          orb.moveXY(t_start, t_absorb, orig_ux, orig_uy - (uh/2))
          orb.moveOpacity(t_absorb - 2, 2, 0)
        end
      end
      
      up.setSE(t_burst, "Anim/PRSFX- Stat Up", 100, 100)
      up.moveTone(t_burst, 2, Tone.new(60, 150, 60, 80))
      up.moveTone(t_burst + 6, 2, Tone.new(0,0,0,0))
      up.moveZoom(t_burst, 2, 110)
      up.moveZoom(t_burst + 4, 2, 100)
      
      if pbResolveBitmap(orbs_asset)
        25.times do |i|
          t_s = t_burst + rand(2)
          start_x = orig_ux + (rand(30) - 15)
          start_y = orig_uy - (uh/2) + (rand(10) - 5) 
          
          sp = addNewSprite(start_x, start_y, orbs_asset, PictureOrigin::CENTER)
          sp.setZ(0, user_z + 105)
          apply_pras_frame(sp, orbs_asset, rand(3), 0, 0)
          sp.setTone(0, Tone.new(-50, 200, -50, 0))
          sp.setVisible(0, false); sp.setVisible(t_s, true); sp.setZoom(0, 30 + rand(20))

          offset_x = start_x - orig_ux
          end_x = start_x + (offset_x * 4.5) 
          end_y = start_y - 120 - rand(30) 
          
          dur = 4 + rand(3) 
          sp.moveXY(t_s, dur, end_x, end_y) 
          sp.moveOpacity(t_s + (dur - 2), 2, 0) 
        end
      end

    when :INGRAIN
      t_start = 0; @end_frame = 18
      up.setSE(t_start, "Anim/PRSFX- Wrap", 100, 120)
      
      up.moveTone(t_start, 3, Tone.new(-50, 100, -50, 50))
      up.moveTone(t_start + 8, 4, Tone.new(0,0,0,0))
      
      # SISTEMA INFALIBLE: Si PRAS- Ingrain no carga por algún motivo, usa Frenzy Plant
      real_ing_asset = pbResolveBitmap(ing_asset) ? ing_asset : frenzy_asset
      
      if pbResolveBitmap(real_ing_asset)
        # Efectos en el suelo (base del Pokémon) - calcular posición de los pies
        ground_y = orig_uy + (uh * 0.5)
        
        root1 = addNewSprite(orig_ux - 20, ground_y, real_ing_asset, PictureOrigin::BOTTOM)
        root2 = addNewSprite(orig_ux + 20, ground_y, real_ing_asset, PictureOrigin::BOTTOM)
        
        root1.setZ(0, user_z + 100); root2.setZ(0, user_z + 101)
        
        # Frenzy Plant usa la fila 3, Ingrain usa filas 0 y 1
        row_1 = (real_ing_asset == frenzy_asset) ? 3 : 0
        row_2 = (real_ing_asset == frenzy_asset) ? 3 : 1
        
        apply_pras_frame(root1, real_ing_asset, 0, row_1, 0) 
        apply_pras_frame(root2, real_ing_asset, 0, row_2, 0) 
        
        root1.setZoom(0, 180)
        root2.setZoomXY(0, -180, 180) 
        
        root1.setVisible(0, false); root1.setVisible(t_start, true)
        root2.setVisible(0, false); root2.setVisible(t_start, true)
        
        4.times do |i|
          apply_pras_frame(root1, real_ing_asset, i, row_1, t_start + (i*2))
          apply_pras_frame(root2, real_ing_asset, i, row_2, t_start + (i*2))
        end
        
        root1.moveOpacity(t_start + 10, 3, 0)
        root2.moveOpacity(t_start + 10, 3, 0)
      end
      
      if pbResolveBitmap(orbs_asset)
        12.times do |i|
          delay = t_start + rand(4)
          e = addNewSprite(orig_ux + (rand(50)-25), orig_uy, orbs_asset, PictureOrigin::CENTER)
          e.setZ(0, user_z + 105)
          apply_pras_frame(e, orbs_asset, rand(3), 0, 0)
          e.setTone(0, Tone.new(0, 200, 0, 0))
          e.setVisible(0, false); e.setVisible(delay, true)
          e.setZoom(0, 40)
          
          e.moveXY(delay, 6, orig_ux + (rand(20)-10), orig_uy - uh - 40)
          e.moveOpacity(delay + 3, 3, 0)
        end
      end
    end

    up.setXY(@end_frame - 1, orig_ux, orig_uy)
    
    up.setCallback(@end_frame, proc { 
      us.opacity = @us_orig_opac
      us.visible = true
    })
  end
end
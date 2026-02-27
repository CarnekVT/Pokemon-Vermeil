#===============================================================================
# [VERMEIL] Common Animations (Stat Up/Down & Health Up/Down)
# Replaces default DB animations with High-Quality Cinematic Engine counterparts.
# Updates: Snappy timing (@end_frame reduced to 20 to remove text delay).
#===============================================================================

class Battle::Scene::Animation::VermeilCommonAnimations < Battle::Scene::Animation
  def initialize(sprites, viewport, target, anim_name)
    @target = target
    @anim_name = anim_name
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
    return if !@target
    ts = @sprites["pokemon_#{@target.index}"]
    return if !ts

    target_z = (ts.z rescue 300) + 10
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, target_z)
    ts.visible = false

    th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    orig_tx = ts.x
    orig_ty = ts.y

    # TIEMPO OPTIMIZADO: Reducido de 35 a 20 para que el texto aparezca de inmediato
    @end_frame = 20

    energy  = "Graphics/BattleParticlesAnimations/Energy1" 
    status  = "Graphics/Animations/PRAS- Status.png"
    stats   = "Graphics/Animations/PRAS- Stats.png"

    case @anim_name
    when "StatUp"
      # STAT UP
      tp.setSE(0, "Anim/PRSFX- Stat Up", 100, 100)
      tp.moveTone(0, 4, Tone.new(60, 10, -50, 20)); tp.moveTone(12, 6, Tone.new(0,0,0,0))
      
      if pbResolveBitmap(energy)
        20.times do |i|
          t_s = rand(10)
          
          start_x = orig_tx + (rand(20) - 10)
          start_y = orig_ty - 15 + (rand(10) - 5) 
          
          z_layer = (i.even?) ? target_z + 15 : target_z - 5

          sp = addNewSprite(start_x, start_y, energy, PictureOrigin::CENTER); sp.setZ(0, z_layer)
          sp.setBlendType(0, 0); sp.setTone(0, Tone.new(255, 80, -150, 0)) 
          sp.setVisible(0, false); sp.setVisible(t_s, true); sp.setZoom(0, 30 + rand(40))

          offset_x = start_x - orig_tx
          end_x = start_x + (offset_x * 5.5) 
          end_y = start_y - 120 - rand(40)
          
          dur = 6 + rand(4) 
          sp.moveXY(t_s, dur, end_x, end_y) 
          sp.moveOpacity(t_s + (dur - 3), 3, 0) 
        end
      end
      
      if pbResolveBitmap(stats)
        arrow = addNewSprite(orig_tx, orig_ty - th, stats, PictureOrigin::CENTER); arrow.setZ(0, target_z + 30)
        apply_pras_frame(arrow, stats, 5, 2, 0) 
        arrow.setTone(0, Tone.new(255, 120, 0, 0))
        arrow.setVisible(0, false); arrow.setVisible(0, true)
        arrow.setZoom(0, 50); arrow.moveZoom(0, 4, 130)
        arrow.moveXY(0, 10, orig_tx, orig_ty - th - 40)
        arrow.moveOpacity(7, 3, 0)
      end

    when "StatDown"
      # STAT DOWN 
      tp.setSE(0, "Anim/PRSFX- Stat Down", 100, 100) rescue tp.setSE(0, "Anim/Wind1", 100, 80)
      tp.moveTone(0, 4, Tone.new(-150, -100, 40, 80)); tp.moveTone(12, 6, Tone.new(0,0,0,0))
      
      if pbResolveBitmap(energy)
        20.times do |i|
          t_s = rand(10)
          
          start_x = orig_tx + (rand(20) - 10)
          start_y = orig_ty - (th * 2) + (rand(10) - 5)
          
          z_layer = (i.even?) ? target_z + 15 : target_z - 5

          sp = addNewSprite(start_x, start_y, energy, PictureOrigin::CENTER); sp.setZ(0, z_layer)
          sp.setBlendType(0, 0); sp.setTone(0, Tone.new(-50, 150, 255, 0)) 
          sp.setVisible(0, false); sp.setVisible(t_s, true); sp.setZoom(0, 30 + rand(40))

          offset_x = start_x - orig_tx
          end_x = start_x + (offset_x * 5.5) 
          end_y = start_y + 120 + rand(40) 
          
          dur = 6 + rand(4) 
          sp.moveXY(t_s, dur, end_x, end_y) 
          sp.moveOpacity(t_s + (dur - 3), 3, 0) 
        end
      end
      
      if pbResolveBitmap(stats)
        arrow = addNewSprite(orig_tx, orig_ty - th - 30, stats, PictureOrigin::CENTER); arrow.setZ(0, target_z + 30)
        apply_pras_frame(arrow, stats, 5, 2, 0) 
        arrow.setTone(0, Tone.new(-50, 150, 255, 0)) 
        arrow.setAngle(0, 180) 
        arrow.setVisible(0, false); arrow.setVisible(0, true)
        arrow.setZoom(0, 50); arrow.moveZoom(0, 4, 130)
        arrow.moveXY(0, 10, orig_tx, orig_ty - th + 20) 
        arrow.moveOpacity(7, 3, 0)
      end

    when "HealthUp"
      # HEALTH UP 
      tp.setSE(0, "Anim/PRSFX- Healing Pulse", 100, 100)
      tp.moveColor(0, 4, Color.new(50, 255, 50, 80)); tp.moveColor(10, 6, Color.new(0,0,0,0))

      if pbResolveBitmap(status)
        12.times do |i|
          t_s = rand(10)
          start_x = orig_tx + (rand(70) - 35) 
          start_y = orig_ty - rand(th * 2)        
          
          s = addNewSprite(start_x, start_y, status, PictureOrigin::CENTER); s.setZ(0, target_z + 25)
          apply_pras_frame(s, status, 4, 4, 0) 
          s.setTone(0, Tone.new(0, 255, 100, 0))
          s.setVisible(0, false); s.setVisible(t_s, true)
          s.setZoom(0, 60 + rand(50)) 
          
          s.moveXY(t_s, 8, start_x, start_y - 60 - rand(30))
          s.moveOpacity(t_s + 4, 4, 0)
        end
      end

    when "HealthDown"
      # HEALTH DOWN 
      tp.setSE(0, "Anim/Poison1", 100, 100)
      tp.moveColor(0, 4, Color.new(120, 0, 150, 80)); tp.moveColor(10, 6, Color.new(0,0,0,0))

      if pbResolveBitmap(energy)
        12.times do |i|
          t_s = rand(10)
          start_x = orig_tx + (rand(70) - 35) 
          start_y = orig_ty - rand(th * 2)        
          
          s = addNewSprite(start_x, start_y, energy, PictureOrigin::CENTER); s.setZ(0, target_z + 25)
          s.setTone(0, Tone.new(-100, -100, -100, 100)) 
          s.setVisible(0, false); s.setVisible(t_s, true)
          s.setZoom(0, 30 + rand(40)) 
          
          dur = 6 + rand(4)
          s.moveXY(t_s, dur, start_x, start_y + 60 + rand(30)) 
          s.moveOpacity(t_s + (dur - 3), 3, 0)
        end
      end

    when "SnapTrap"
      # SNAP TRAP (common residual de atrapado)
      fangs = "Graphics/Animations/PRAS- Elemental Fangs.png"
      return if !pbResolveBitmap(fangs)
      @end_frame = 30
      i_y = orig_ty - th
      t_spawn = 1
      t_snap  = 7
      bot_x = orig_tx

      jaw_top = addNewSprite(orig_tx, i_y - 72, fangs, PictureOrigin::CENTER)
      jaw_top.setZ(0, target_z + 20)
      apply_pras_frame(jaw_top, fangs, 0, 0, 0)
      jaw_top.setVisible(0, false); jaw_top.setVisible(t_spawn, true); jaw_top.setZoom(0, 125)

      jaw_bot = addNewSprite(bot_x, i_y + 74, fangs, PictureOrigin::CENTER)
      jaw_bot.setZ(0, target_z + 21)
      apply_pras_frame(jaw_bot, fangs, 0, 0, 0)
      jaw_bot.setVisible(0, false); jaw_bot.setVisible(t_spawn, true); jaw_bot.setZoomXY(0, 125, -125)

      tp.setSE(t_snap, "Anim/PRSFX- Bite", 100, 120)
      jaw_top.moveXY(t_snap, 2, orig_tx, i_y - 18)
      jaw_bot.moveXY(t_snap, 2, bot_x, i_y + 18)

      2.times do |i|
        t_chew = t_snap + 2 + (i * 4)
        tp.setSE(t_chew, "Anim/PRSFX- Cut", 100, 140)
        jaw_top.moveXY(t_chew, 2, orig_tx, i_y - 40)
        jaw_bot.moveXY(t_chew, 2, bot_x, i_y + 40)
        jaw_top.moveXY(t_chew + 2, 2, orig_tx, i_y - 12)
        jaw_bot.moveXY(t_chew + 2, 2, bot_x, i_y + 12)
        tp.moveColor(t_chew + 1, 2, Color.new(255, 50, 50, 190))
        tp.moveColor(t_chew + 3, 2, Color.new(0, 0, 0, 0))
      end

      jaw_top.moveOpacity(t_snap + 12, 4, 0)
      jaw_bot.moveOpacity(t_snap + 12, 4, 0)

    when "SpikyShield"
      # SPIKY SHIELD (common residual de protegido)
      protect = "Graphics/Animations/PRAS- Protect.png"
      spikes = "Graphics/Animations/PRAS- Spike Cannon.png"
      return if !pbResolveBitmap(protect)
      @end_frame = 20
      i_y = orig_ty - th
      t_start = 1
      
      # Sonido de Spiky Shield
      tp.setSE(t_start, "Anim/PRSFX- Spiky Shield2", 100, 120)
      
      # Escudo un poco más arriba
      shield_y = i_y - 20
      
      shield = addNewSprite(orig_tx, shield_y, protect, PictureOrigin::CENTER)
      shield.setZ(0, target_z + 20)
      apply_pras_frame(shield, protect, 0, 0, 0)
      shield.setTone(0, Tone.new(-100, 150, -100, 0))
      shield.setVisible(0, false); shield.setVisible(t_start, true)
      shield.setZoom(0, 50); shield.moveZoom(t_start, 4, 180)
      
      5.times do |i|
         apply_pras_frame(shield, protect, i, 0, t_start + (i*2))
      end
      shield.moveOpacity(t_start + 20, 8, 0)
      
      # 8 púas cardinales
      if pbResolveBitmap(spikes)
        8.times do |i|
          spike = addNewSprite(orig_tx, shield_y, spikes, PictureOrigin::CENTER)
          spike.setZ(0, target_z + 25)
          apply_pras_frame(spike, spikes, 0, 0, 0)
          spike.setVisible(0, false); spike.setVisible(t_start + 2, true)
          
          ang = (i * 45)
          spike.setAngle(0, ang)
          spike.setZoom(0, 150)
          
          rad = 120
          dest_x = orig_tx + Math.cos(ang * 3.14159 / 180) * rad
          dest_y = shield_y + Math.sin(ang * 3.14159 / 180) * rad
          
          spike.moveXY(t_start + 2, 6, dest_x, dest_y)
          spike.moveOpacity(t_start + 10, 4, 0)
        end
      end
      
      tp.moveTone(t_start, 4, Tone.new(-50, 100, -50, 50))
      tp.moveTone(t_start + 10, 6, Tone.new(0,0,0,0))
    when "LeechSeed"
      # LEECH SEED (Common residual de drenado)
      magic = "Graphics/Animations/PRAS- Magical Leaf.png"
      return if !pbResolveBitmap(magic)
      @end_frame = 40
      i_y = orig_ty - th
      t_start = 1
      t_hit = 10
      
      # Sonido de Leech Seed
      tp.setSE(t_hit, "Anim/PRSFX- Leech Seed", 100, 120)
      tp.setSE(t_hit, "Anim/Absorb2", 100, 100)
      
      # Semilla volando
      seed = addNewSprite(orig_tx, orig_ty - th - 30, magic, PictureOrigin::CENTER)
      seed.setZ(0, target_z + 20)
      apply_pras_frame(seed, magic, 0, 0, 0)
      seed.setTone(0, Tone.new(100, 50, -50, 0))
      seed.setVisible(0, false); seed.setVisible(t_start, true)
      seed.setZoom(0, 50)
      
      # Trayectoria hacia el objetivo - corregir para que vaya a la base (suelo)
      seed.moveXY(t_start, t_hit - t_start, orig_tx, orig_ty + (th * 0.3))
      seed.moveOpacity(t_hit, 1, 0)
      
      # Raíces brotando en el objetivo - corregir para que aparezca en el suelo
      frenzy = "Graphics/Animations/PRAS- Frenzy Plant.png"
      if pbResolveBitmap(frenzy)
        # Efectos en el suelo (base del Pokémon)
        root_y = orig_ty + (th * 0.3)
        root1 = addNewSprite(orig_tx - 20, root_y, frenzy, PictureOrigin::BOTTOM)
        root2 = addNewSprite(orig_tx + 20, root_y, frenzy, PictureOrigin::BOTTOM)
        root1.setZ(0, target_z + 15); root2.setZ(0, target_z + 16)
        
        apply_pras_frame(root1, frenzy, 0, 3, 0)
        apply_pras_frame(root2, frenzy, 0, 3, 0)
        root2.setZoomXY(0, -100, 100)
        
        root1.setTone(0, Tone.new(-30, 50, -30, 0))
        root2.setTone(0, Tone.new(-30, 50, -30, 0))
        
        root1.setVisible(0, false); root1.setVisible(t_hit, true)
        root2.setVisible(0, false); root2.setVisible(t_hit, true)
        
        4.times do |i|
          apply_pras_frame(root1, frenzy, i, 3, t_hit + (i*2))
          apply_pras_frame(root2, frenzy, i, 3, t_hit + (i*2))
        end
        
        # Efecto de drenado (Energy1 hacia quien usa leech seed)
        drain_energy = "Graphics/BattleParticlesAnimations/Energy1"
        if pbResolveBitmap(drain_energy)
          15.times do |i|
            t_s = t_hit + 4 + i
            p = addNewSprite(orig_tx, orig_ty - th/2, drain_energy, PictureOrigin::CENTER)
            p.setZ(0, target_z + 25)
            p.setTone(0, Tone.new(-50, 150, -50, 0))
            p.setVisible(0, false); p.setVisible(t_s, true); p.setZoom(t_s, 20 + rand(20))
            
            # Sale del objetivo
            pop_x = orig_tx + (rand(80) - 40); pop_y = orig_ty + (rand(80) - 40)
            p.moveXY(t_s, 4, pop_x, pop_y)
            
            # Hacia arriba (simulando drenado al cielo/early grass)
            p.moveXY(t_s + 4, 8, pop_x, pop_y - 100)
            p.moveZoom(t_s + 4, 8, 10)
            p.moveOpacity(t_s + 10, 3, 0)
          end
        end
        
        # Color del objetivo se vuelve verde
        tp.moveColor(t_hit, 6, Color.new(50, 200, 50, 150))
        tp.moveColor(t_hit + 15, 8, Color.new(0, 0, 0, 0))
        
        root1.moveOpacity(t_hit + 18, 6, 0)
        root2.moveOpacity(t_hit + 18, 6, 0)
      end
    end

    # Restore sprite at end
    tp.setXY(@end_frame - 1, orig_tx, orig_ty)
    tp.setCallback(@end_frame, proc { ts.visible = true })
  end
end

#===============================================================================
# INTERCEPTOR: Desvía el llamado de animaciones de la DB al sistema Vermeil
#===============================================================================
class Battle::Scene
  # Protección anti-bucles infinitos con otros plugins (Ej: Gen 9 Pack)
  if !method_defined?(:vermeil_core_pbCommonAnimation)
    alias vermeil_core_pbCommonAnimation pbCommonAnimation
  end

  def pbCommonAnimation(animName, user = nil, targets = nil)
    custom_anims = ["StatUp", "StatDown", "HealthUp", "HealthDown", "SnapTrap", "SpikyShield", "LeechSeed"]
    
    if custom_anims.include?(animName)
      target = user || (targets.is_a?(Array) ? targets[0] : targets)
      return if !target
      need_slide_ui = (animName == "SnapTrap")
      
      # Evitar que los textos parpadeen y ocultar databoxes temporalmente
      vermeil_engine_clear_message_window! if respond_to?(:vermeil_engine_clear_message_window!)
      vermeil_slide_databoxes_out if need_slide_ui && respond_to?(:vermeil_slide_databoxes_out)
      
      begin
        anim = Battle::Scene::Animation::VermeilCommonAnimations.new(@sprites, @viewport, target, animName)
        loop do 
          anim.update
          pbUpdate
          break if anim.animDone? 
        end
        anim.dispose
      ensure
        ts = @sprites["pokemon_#{target.index}"] rescue nil
        ts.visible = true if ts
        vermeil_slide_databoxes_in if need_slide_ui && respond_to?(:vermeil_slide_databoxes_in)
      end
      return
    end
    
    # Si es otra animación (ej: Confusion, Sleep), usa la normal de Essentials
    vermeil_core_pbCommonAnimation(animName, user, targets)
  end
end

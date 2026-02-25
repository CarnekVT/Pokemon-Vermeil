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
      # 📈 STAT UP
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
      # 📉 STAT DOWN 
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
      # 💚 HEALTH UP 
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
      # 💔 HEALTH DOWN 
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
    end

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
    custom_anims = ["StatUp", "StatDown", "HealthUp", "HealthDown"]
    
    if custom_anims.include?(animName)
      target = user || (targets.is_a?(Array) ? targets[0] : targets)
      return if !target
      
      # Evitar que los textos parpadeen y ocultar databoxes temporalmente
      vermeil_engine_clear_message_window! if respond_to?(:vermeil_engine_clear_message_window!)
      
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
      end
      return
    end
    
    # Si es otra animación (ej: Confusion, Sleep), usa la normal de Essentials
    vermeil_core_pbCommonAnimation(animName, user, targets)
  end
end
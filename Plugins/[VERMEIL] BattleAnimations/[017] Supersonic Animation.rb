#===============================================================================
# [VERMEIL] BattleAnimations - Supersonic Rework (CINEMATIC)
# Concept: Center-originating soundwaves, accurate PRAS frame mapping.
# Fixed: Missing time=0 src_rect initialization that caused invisible sprites.
#===============================================================================

module VermeilSupersonicAssets
  WAVES = "Graphics/Animations/PRAS- Supersonic.png"
  NOTES = "Graphics/Animations/PRAS- Sound.png"
end

class Battle::Scene::Animation::VermeilCinematicSupersonic < Battle::Scene::Animation
  include VermeilSupersonicAssets
  
  HANDLED_MOVES = [:SUPERSONIC]
  BEHAVIOR = :cinematic

  def initialize(sprites, viewport, user, target, move_id = :SUPERSONIC)
    @user = user
    @target = target
    @move_id = move_id
    super(sprites, viewport)
  end

  def apply_pras_frame(sprite, path, col, row, time = 0, fw = 192, fh = 192)
    resolved = pbResolveBitmap(path); return if !resolved
    sprite.setSrc(time, col * fw, row * fh); sprite.setSrcSize(time, fw, fh)
    if time == 0 && (raw = @pictureSprites.last) && raw.respond_to?(:src_rect) && raw.src_rect
      raw.src_rect.set(col * fw, row * fh, fw, fh)
    end
  end

  def resolve_bitmap(path, fallback)
    return pbResolveBitmap(path) ? path : fallback
  end

  def createProcesses
    us = @sprites["pokemon_#{@user.index}"]
    ts = @sprites["pokemon_#{@target.index}"]
    return if !us || !ts

    user_pic = addSprite(us, PictureOrigin::BOTTOM)
    target_pic = addSprite(ts, PictureOrigin::BOTTOM)
    f_dir = (@user.index & 1) == 0 ? 1 : -1

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40
    th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40

    # Nace del centro del lanzador
    start_x = us.x
    start_y = us.y - uh
    
    # Impacta en el centro del objetivo
    end_x = ts.x
    end_y = ts.y - th

    waves_asset = resolve_bitmap(WAVES, "Graphics/Animations/PRAS- Supersonic")
    notes_asset = resolve_bitmap(NOTES, "Graphics/Animations/PRAS- Sound")

    t_emission = 2
    t_travel = 8
    t_impact = t_emission + t_travel
    @end_frame = t_impact + 20

    user_pic.setSE(0, "Anim/PRSFX- Supersonic", 100, 100)
    user_pic.moveDelta(0, 4, -4 * f_dir, 0)
    user_pic.moveDelta(4, 4, 4 * f_dir, 0)

    # 1. ONDAS SUPERSONICAS (PRAS- Supersonic)
    3.times do |i|
      t = t_emission + (i * 3)
      wave = addNewSprite(start_x, start_y, waves_asset, PictureOrigin::CENTER)
      wave.setZ(0, (ts.z rescue 300) + 10 + i)
      
      # FIX: INICIALIZAR EL RECORTE EN EL FRAME 0 ES OBLIGATORIO
      apply_pras_frame(wave, waves_asset, 0, 0, 0) 
      
      wave.setVisible(0, false)
      wave.setOpacity(0, 0)
      wave.setZoom(0, 40)
      
      wave.setVisible(t, true)
      wave.moveOpacity(t, 2, 255)
      wave.moveXY(t, t_travel, end_x, end_y)
      wave.moveZoom(t, t_travel, 180) # Se expanden bastante
      
      # Animación PRAS (Fila 0 fija, recorremos las columnas 0 a 4)
      5.times do |f| 
        apply_pras_frame(wave, waves_asset, f, 0, t + (f * 2)) 
      end
      
      wave.moveOpacity(t + t_travel - 2, 4, 0)
      wave.setVisible(t + t_travel + 2, false)
    end

    # 2. NOTAS MUSICALES (PRAS- Sound)
    if notes_asset
      note_offsets = [[-24, -30], [30, -15], [-15, 25], [20, 20]]
      note_offsets.each_with_index do |ofs, i|
        t = t_impact + i
        note = addNewSprite(end_x, end_y, notes_asset, PictureOrigin::CENTER)
        note.setZ(0, (ts.z rescue 300) + 20 + i)
        
        # Seleccionamos aleatoriamente la fila 1 (Notas Rosas) o Fila 6 (Notas Amarillas)
        row_to_use = [1, 6].sample
        
        # FIX: INICIALIZAR EL RECORTE EN EL FRAME 0
        apply_pras_frame(note, notes_asset, 0, row_to_use, 0) 
        
        note.setVisible(0, false)
        note.setOpacity(0, 0)
        note.setZoom(0, 30)

        note.setVisible(t, true)
        note.moveOpacity(t, 2, 255)
        note.moveDelta(t, 8, ofs[0] * f_dir, ofs[1])
        note.moveZoom(t, 8, 90)
        
        # Balanceo de las notas
        note.moveAngle(t, 4, (f_dir * 30))
        note.moveAngle(t + 4, 4, -(f_dir * 15))
        
        # Animación PRAS de notas
        5.times do |f| 
          apply_pras_frame(note, notes_asset, f, row_to_use, t + (f * 2)) 
        end
        
        note.moveOpacity(t + 6, 4, 0)
        note.setVisible(t + 10, false)
      end
    end

    # 3. IMPACTO EN EL RIVAL (Confusión)
    target_pic.moveDelta(t_impact, 2, 8 * f_dir, 0)
    target_pic.moveDelta(t_impact + 2, 2, -16 * f_dir, 0)
    target_pic.moveDelta(t_impact + 4, 2, 16 * f_dir, 0)
    target_pic.moveDelta(t_impact + 6, 2, -8 * f_dir, 0)
  end
end
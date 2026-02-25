#===============================================================================
# [VERMEIL] BattleAnimations - Sticky Web Cast Rework v17 (HAZARD)
# Concept: Sequential parabolic silk balls expanding into bright webs on top.
# Update: Trimmed dead frames. Snappy ending right after the last web expands.
#===============================================================================

module VermeilStickyWebAssets
  WEB_SHEET = "Graphics/Animations/PRAS- Sticky Web.png" 
end

class Battle::Scene::Animation::VermeilStickyWebCast < Battle::Scene::Animation
  include VermeilStickyWebAssets

  HANDLED_MOVES = [:STICKYWEB]
  BEHAVIOR = :hazard 

  def initialize(sprites, viewport, user, anchor_x, anchor_y, side_index)
    @user = user
    @anchor_x = anchor_x
    @anchor_y = anchor_y
    @side_index = side_index
    super(sprites, viewport)
  end

  def apply_pras_frame(sprite, path, col, row, time = 0, fw = 192, fh = 192)
    resolved = pbResolveBitmap(path); return if !resolved
    sprite.setSrc(time, col * fw, row * fh); sprite.setSrcSize(time, fw, fh)
    if time == 0 && (raw = @pictureSprites.last) && raw.respond_to?(:src_rect) && raw.src_rect
      raw.src_rect.set(col * fw, row * fh, fw, fh)
    end
  end

  def createProcesses
    us = @sprites["pokemon_#{@user.index}"]
    return if !us

    user_pic = addSprite(us, PictureOrigin::BOTTOM)
    f_dir = (@user.index & 1) == 0 ? 1 : -1
    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40
    
    start_x = us.x + (30 * f_dir)
    start_y = us.y - (uh * 0.8)
    
    ground_center_x = @anchor_x
    ground_y = @anchor_y 
    
    air_z = (us.z rescue 300) + 150 

    # TIEMPO OPTIMIZADO: Reducido de 75 a 55 para eliminar la pausa vacía
    @end_frame = 55 
    web_sheet = VermeilStickyWebAssets::WEB_SHEET
    
    t_throw_start = 2
    t_travel_time = 10  
    t_frame_speed = 2   
    delay_between_shots = 8 

    silk_tone = Tone.new(200, 200, 200, 20)
    
    offsets = [-70, 0, 70] 

    3.times do |i|
      target_x = ground_center_x + offsets[i]
      target_y = ground_y + (rand(12) - 6) 

      t_start_i = t_throw_start + (i * delay_between_shots)
      t_land_i  = t_start_i + t_travel_time

      user_pic.setSE(t_start_i, "Anim/Throw", 100, 130)
      user_pic.moveDelta(t_start_i, 3, 8 * f_dir, -7)
      user_pic.moveDelta(t_start_i + 3, 3, -8 * f_dir, 7)

      # 1. BOLA DE SEDA
      ball = addNewSprite(start_x, start_y, web_sheet, PictureOrigin::CENTER)
      ball.setZ(0, air_z)
      apply_pras_frame(ball, web_sheet, 0, 0, 0)
      ball.setZoom(0, 60) 
      ball.setTone(0, silk_tone) 
      ball.setVisible(0, false); ball.setVisible(t_start_i, true)
      
      mid_x = start_x + (target_x - start_x) / 2
      mid_y = [start_y, target_y].min - 50 - rand(20)
      half_t = t_travel_time / 2
      
      ball.moveXY(t_start_i, half_t, mid_x, mid_y)
      ball.moveXY(t_start_i + half_t, half_t, target_x, target_y)
      ball.moveAngle(t_start_i, t_travel_time, 720 * (i.even? ? 1 : -1))

      ball.setVisible(t_land_i, false)
      ball.setSE(t_land_i, "Anim/PRSFX- String Shot2", 90, 110)

      # 2. IMPACTO RÁPIDO
      impact = addNewSprite(target_x, target_y, web_sheet, PictureOrigin::CENTER)
      impact.setZ(0, air_z + 1)
      apply_pras_frame(impact, web_sheet, 0, 1, 0)
      impact.setTone(0, silk_tone)
      impact.setVisible(0, false); impact.setVisible(t_land_i, true)
      impact.moveOpacity(t_land_i + 3, 3, 0)

      # 3. EXPANSIÓN ANIMADA SECUENCIAL Y POR ENCIMA
      5.times do |f|
        web = addNewSprite(target_x, target_y, web_sheet, PictureOrigin::CENTER)
        web.setZ(0, air_z) 
        web.setTone(0, silk_tone) 
        web.setZoom(0, 85) 
        
        apply_pras_frame(web, web_sheet, f, 2, 0)
        
        t_show = t_land_i + (f * t_frame_speed)
        
        web.setVisible(0, false)
        web.setVisible(t_show, true)
        
        if f < 4
          web.setVisible(t_show + t_frame_speed, false)
        else
          # Desvanecimiento sincronizado con el nuevo final rápido (inicia en frame 45, termina en 55)
          web.moveOpacity(@end_frame - 10, 10, 0)
        end
      end
    end
  end
end
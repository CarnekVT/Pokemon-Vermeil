#===============================================================================
# [VERMEIL] BattleAnimations - Grass Shields v1.0
# Includes: Flower Shield
#===============================================================================

class Battle::Scene::Animation::VermeilGrassShields < Battle::Scene::Animation
  HANDLED_MOVES = [:FLOWERSHIELD]
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

    protect_asset = "Graphics/Animations/PRAS- Protect.png"
    leaf_asset    = "Graphics/Animations/PRAS- Grass.png"
    status_asset  = "Graphics/Animations/PRAS- Status.png"

    case @move_id
    when :FLOWERSHIELD
      t_start = 2; @end_frame = 35
      up.setSE(t_start, "Anim/PRSFX- Focus Energy", 100, 150)
      
      shield_y = orig_uy - (uh/2)
      
      # The Base Shield
      if pbResolveBitmap(protect_asset)
        shield = addNewSprite(orig_ux, shield_y, protect_asset, PictureOrigin::CENTER)
        shield.setZ(0, user_z + 20)
        apply_pras_frame(shield, protect_asset, 0, 0, 0) 
        shield.setTone(0, Tone.new(150, 50, 150, 0)) # Pink floral tone
        shield.setVisible(0, false); shield.setVisible(t_start, true)
        shield.setZoom(0, 50); shield.moveZoom(t_start, 4, 180)
        
        5.times { |i| apply_pras_frame(shield, protect_asset, i, 0, t_start + (i*2)) }
        shield.moveOpacity(t_start + 15, 6, 0)
      end
      
      # Swirling Petals
      if pbResolveBitmap(leaf_asset)
        15.times do |i|
          petal = addNewSprite(orig_ux, shield_y, leaf_asset, PictureOrigin::CENTER)
          petal.setZ(0, user_z + 25)
          apply_pras_frame(petal, leaf_asset, rand(3), 0, 0)
          petal.setTone(0, Tone.new(200, 50, 150, 0))
          petal.setVisible(0, false); petal.setVisible(t_start + rand(6), true)
          petal.setZoom(0, 40 + rand(30))
          
          ang = rand(360) * 3.14159 / 180
          dist = 100 + rand(50)
          dest_x = orig_ux + Math.cos(ang) * dist
          dest_y = shield_y + Math.sin(ang) * dist
          
          petal.moveXY(t_start, 12, dest_x, dest_y)
          petal.moveAngle(t_start, 12, rand(720))
          petal.moveOpacity(t_start + 8, 4, 0)
        end
      end
      
      # Defense Up particles
      up.setSE(t_start + 12, "Anim/PRSFX- Stat Up", 100, 100)
      up.moveTone(t_start + 12, 4, Tone.new(100, 50, 100, 80))
      up.moveTone(t_start + 20, 6, Tone.new(0,0,0,0))
      
      if pbResolveBitmap(status_asset)
        8.times do |i|
          t_s = t_start + 12 + rand(4)
          start_x = orig_ux + (rand(60) - 30)
          start_y = shield_y + (rand(40) - 20)
          
          s = addNewSprite(start_x, start_y, status_asset, PictureOrigin::CENTER)
          s.setZ(0, user_z + 30); apply_pras_frame(s, status_asset, 0, 0, 0) # Stat up arrows
          s.setTone(0, Tone.new(255, 100, 200, 0))
          s.setVisible(0, false); s.setVisible(t_s, true)
          s.setZoom(0, 60 + rand(30))
          
          s.moveXY(t_s, 8, start_x, start_y - 60 - rand(40))
          s.moveOpacity(t_s + 4, 4, 0)
        end
      end
    end

    up.setCallback(@end_frame, proc { 
      us.opacity = @us_orig_opac; us.visible = true
    })
  end
end
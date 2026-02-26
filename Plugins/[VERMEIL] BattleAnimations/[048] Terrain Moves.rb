#===============================================================================
# [VERMEIL] BattleAnimations - Terrain Moves v1.0
# Includes: Grassy Terrain, Electric Terrain, Misty Terrain, Psychic Terrain
#===============================================================================

class Battle::Scene::Animation::VermeilTerrains < Battle::Scene::Animation
  
  HANDLED_MOVES = [:GRASSYTERRAIN, :ELECTRICTERRAIN, :MISTYTERRAIN, :PSYCHICTERRAIN]
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

  def createProcesses
    us = @sprites["pokemon_#{@user.index}"]
    return if !us
    
    f_dir = (@user.index & 1) == 0 ? 1 : -1
    user_z = (us.z rescue 300) + 20

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM)
    up.setZ(0, user_z)
    
    @us_orig_opac = us.opacity
    us.opacity = 0

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40
    orig_ux = us.x; orig_uy = us.y

    @end_frame = 40

    case @move_id
    when :GRASSYTERRAIN
      # Placeholder
    when :ELECTRICTERRAIN
      # Placeholder
    when :MISTYTERRAIN
      # Placeholder
    when :PSYCHICTERRAIN
      # Placeholder
    end

    up.setXY(@end_frame - 1, orig_ux, orig_uy)
    up.setCallback(@end_frame, proc { 
      us.opacity = @us_orig_opac
      us.visible = true
    })
  end
end

#===============================================================================
# Playback method and registration for terrain moves
#===============================================================================

class Battle::Scene
  def pbPlayVermeilTerrainAnimation(user, target, move_id)
    return if !user || !target
    user_sprite = @sprites["pokemon_#{user.index}"]
    return if !user_sprite
    
    StatusParticles.set_cinematic_mode_all(true) if defined?(StatusParticles)
    
    pbSaveShadows do
      anim = Animation::VermeilTerrains.new(@sprites, @viewport, user, target, move_id)
      loop do
        anim.update
        pbUpdate
        break if anim.animDone?
      end
      anim.dispose
    end
    
    StatusParticles.set_cinematic_mode_all(false) if defined?(StatusParticles)
  end
end

class Battle
  alias_method :vermeil_terrains_pbAnimation, :pbAnimation unless method_defined?(:vermeil_terrains_pbAnimation)

  def pbAnimation(move, user, targets, hitNum = 0)
    move_id = move.respond_to?(:id) ? move.id : move
    terrain_moves = [:GRASSYTERRAIN, :ELECTRICTERRAIN, :MISTYTERRAIN, :PSYCHICTERRAIN]
    
    if @showAnims && terrain_moves.include?(move_id) && @scene.respond_to?(:pbPlayVermeilTerrainAnimation)
      target = user  # Self/Field targeting
      @scene.pbPlayVermeilTerrainAnimation(user, target, move_id)
      return
    end
    vermeil_terrains_pbAnimation(move, user, targets, hitNum)
  end
end
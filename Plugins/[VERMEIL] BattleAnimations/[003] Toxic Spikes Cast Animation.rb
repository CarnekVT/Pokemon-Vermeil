#===============================================================================
# [VERMEIL] BattleAnimations - Toxic Spikes Cast Rework (HAZARD)
# Concept: Snappy execution, auto-discovery engine, trimmed dead frames.
# Fixed: Toxic particles perfectly synced to spawn AFTER spikes hit the ground.
#===============================================================================

module VermeilToxicSpikesAssets
  SPIKES_ASSET = "Graphics/UI/Battle/hazards/toxic_spikes"
  PARTICLE_ASSET = "Graphics/Pictures/StatusParticles/toxic"
end

class Battle::Scene::Animation::VermeilToxicSpikesCast < Battle::Scene::Animation
  include VermeilToxicSpikesAssets
  
  # === AUTO-REGISTRO ===
  HANDLED_MOVES = [:TOXICSPIKES]
  BEHAVIOR = :hazard
  # =====================

  def initialize(sprites, viewport, user, anchor_x, anchor_y, side_index)
    @user = user
    @anchor_x = anchor_x
    @anchor_y = anchor_y
    @side_index = side_index
    super(sprites, viewport)
  end

  def resolve_bitmap(path, fallback)
    return pbResolveBitmap(path) ? path : fallback
  end

  def createProcesses
    us = @sprites["pokemon_#{@user.index}"]
    return if !us
    
    user_pic = addSprite(us, PictureOrigin::BOTTOM)
    f_dir = (@user.index & 1) == 0 ? 1 : -1
    t_scale = (@side_index == 0) ? 1.15 : 1.0

    spike_asset = resolve_bitmap(SPIKES_ASSET, "Graphics/UI/Battle/hazards/toxic-spikes")
    particle_asset = resolve_bitmap(PARTICLE_ASSET, "Graphics/Pictures/StatusParticles/poison")
    
    # Animación de lanzamiento
    user_pic.setSE(2, "Anim/PRSFX- Toxic Spikes1", 82, 105) rescue nil
    user_pic.moveDelta(0, 5, 10 * f_dir, -8)
    user_pic.moveDelta(5, 5, -10 * f_dir, 8)

    # Tiempo ajustado para que las partículas terminen de flotar (antes 40)
    @end_frame = 45

    offsets = [[-58, 8], [-36, 2], [-14, 10], [10, 1], [34, 9], [56, 4]]
    offsets.each_with_index do |(ox, oy), i|
      spike = addNewSprite(us.x, us.y - 56, spike_asset, PictureOrigin::CENTER)
      spike.setZ(0, 96 + i)
      spike.setOpacity(0, 0)
      spike.setVisible(0, false)
      spike.setZoom(0, 78 + (@side_index == 0 ? 20 : 0))

      start_t = 4 + (i * 2)
      spike.setVisible(start_t, true)
      spike.moveOpacity(start_t, 2, 255)
      spike.moveXY(start_t, 9, (@anchor_x + (ox * 0.4)).round, @anchor_y - 86)
      spike.moveXY(start_t + 9, 10, (@anchor_x + (ox * t_scale)).round, @anchor_y + oy)
      spike.moveAngle(start_t, 19, (f_dir * 540) + (i * 30))

      spike.moveDelta(start_t + 19, 2, 0, -8)
      spike.moveDelta(start_t + 21, 3, 0, 8)
      # La púa de en medio (i=2) toca el suelo en el frame 24
      spike.setSE(start_t + 20, "Anim/PRSFX- Toxic Spikes2", 90, 98) if i == 2
      spike.moveOpacity(start_t + 28, 6, 0) 
    end

    if particle_asset
      4.times do |i|
        p = addNewSprite(@anchor_x + ((i - 2) * 14), @anchor_y - 10, particle_asset, PictureOrigin::CENTER)
        p.setZ(0, 104 + i)
        p.setVisible(0, false)
        p.setOpacity(0, 0)
        p.setZoom(0, 56 + (i % 2) * 6)
        
        # FIX: Las partículas ahora nacen a partir del frame 26 (cuando ya hay púas en el suelo)
        t = 26 + (i * 3) 
        
        p.setVisible(t, true)
        p.moveOpacity(t, 2, 150)
        p.moveDelta(t, 7, (i.even? ? -7 : 7), -18)
        p.moveOpacity(t + 4, 6, 0)
      end
    end
  end
end
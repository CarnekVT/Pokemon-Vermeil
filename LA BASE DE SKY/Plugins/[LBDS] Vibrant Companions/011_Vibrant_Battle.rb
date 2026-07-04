#===============================================================================
# VIBRANT COMPANIONS - BATTLE ANIMATIONS
#===============================================================================

#-------------------------------------------------------------------------------
# Interceptamos la creación de la animación de envío del jugador
#-------------------------------------------------------------------------------
class Battle::Scene::Animation::PokeballPlayerSendOut < Battle::Scene::Animation
  
  alias vibrant_createProcesses createProcesses unless private_method_defined?(:vibrant_createProcesses)
  
  def createProcesses
    # Verificamos si el sistema está activo, si es el inicio de la batalla,
    # si es el primer Pokémon y si la opción está habilitada.
    is_vibrant_active = defined?(VibrantCompanions) && 
                        VibrantCompanions::Manager.toggled? && 
                        VibrantCompanions::Settings::SLIDE_INTO_BATTLE
                        
    if is_vibrant_active && @showingTrainer && @battler.index == 0
      createVibrantFollowerProcesses
    else
      vibrant_createProcesses
    end
  end

  def createVibrantFollowerProcesses
    delay = 0
    delay = 5 if @showingTrainer
    batSprite = @sprites["pokemon_#{@battler.index}"]
    shaSprite = @sprites["shadow_#{@battler.index}"]
    
    # Animación del Pokémon deslizándose
    battler = addSprite(batSprite, PictureOrigin::BOTTOM)
    battler.setVisible(delay, true)
    battler.setZoomXY(delay, 100, 100)
    battler.setColor(delay, Color.new(0, 0, 0, 0))
    battler.setDelta(0, -240, 0)
    battler.moveDelta(delay, 12, 240, 0)
    battler.setCallback(delay + 12, [batSprite, :pbPlayIntroAnimation])
    
    # Animación de la sombra deslizándose junto al Pokémon
    if @shadowVisible
      shadow = addSprite(shaSprite, PictureOrigin::CENTER)
      if batSprite.respond_to?(:shadowVisible) && batSprite.shadowVisible
        if batSprite.respond_to?(:substitute) && batSprite.substitute
          shadow_size = 1
        else
          pkmn = batSprite.pkmn
          if pkmn
            metrics = GameData::SpeciesMetrics.get_species_form(pkmn.species, pkmn.form, pkmn.female?)
            shadow_size = metrics.shadow_size
            shadow_size -= 1 if shadow_size > 0
          else
            shadow_size = 1
          end
        end
        zoomX = 100 * (1 + shadow_size * 0.1)
        zoomY = 100 * (1 * 0.25 + (shadow_size * 0.025))
        shadow.setZoomXY(delay, zoomX, zoomY)
      end
      shadow.setVisible(delay, true)
      shadow.setDelta(0, -Graphics.width / 2, 0)
      shadow.moveDelta(delay, 12, Graphics.width / 2, 0)
    end
  end
end

#-------------------------------------------------------------------------------
# Evitamos que lance la Poké Ball
#-------------------------------------------------------------------------------
class Battle::Scene::Animation::PlayerFade < Battle::Scene::Animation
  
  alias vibrant_createProcesses createProcesses unless private_method_defined?(:vibrant_createProcesses)
  
  def createProcesses
    is_vibrant_active = defined?(VibrantCompanions) && 
                        VibrantCompanions::Manager.toggled? && 
                        VibrantCompanions::Settings::SLIDE_INTO_BATTLE
                        
    # Si el plugin está activo y es el inicio de la batalla
    if is_vibrant_active && @fullAnim
      spriteNameBase = "player"
      i = 1
      while @sprites[spriteNameBase + "_#{i}"]
        pl = @sprites[spriteNameBase + "_#{i}"]
        current_i = i
        i += 1
        next if !pl.visible || pl.x < 0
        
        trainer = addSprite(pl, PictureOrigin::BOTTOM)
        trainer.moveDelta(0, 16, -Graphics.width / 2, 0)
        
        # Animamos el sprite solo si no es el jugador principal.
        # Esto permite que los NPCs aliados sí lancen sus Poké Balls.
        if current_i > 1 && pl.bitmap && !pl.bitmap.disposed? && pl.bitmap.width >= pl.bitmap.height * 2
          size = pl.src_rect.width
          trainer.setSrc(0, size, 0)
          trainer.setSrc(5, size * 2, 0)
          trainer.setSrc(7, size * 3, 0)
          trainer.setSrc(9, size * 4, 0)
        end
        
        trainer.setVisible(16, false)
      end
      
      # Movemos y desvanecemos la barra de equipo y las Poké Balls de la UI
      delay = 3
      if @sprites["partyBar_0"]&.visible
        partyBar = addSprite(@sprites["partyBar_0"])
        partyBar.moveDelta(delay, 16, -Graphics.width / 4, 0) if @fullAnim
        partyBar.moveOpacity(delay, 12, 0)
        partyBar.setVisible(delay + 12, false)
        partyBar.setOpacity(delay + 12, 255)
      end
      
      Battle::Scene::NUM_BALLS.times do |j|
        next if !@sprites["partyBall_0_#{j}"] || !@sprites["partyBall_0_#{j}"].visible
        partyBall = addSprite(@sprites["partyBall_0_#{j}"])
        partyBall.moveDelta(delay + (2 * j), 16, -Graphics.width, 0) if @fullAnim
        partyBall.moveOpacity(delay, 12, 0)
        partyBall.setVisible(delay + 12, false)
        partyBall.setOpacity(delay + 12, 255)
      end
      
    else
      vibrant_createProcesses
    end
  end
end

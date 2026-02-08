#===============================================================================
# Disable Sliding Background Plugin
#===============================================================================
module Battle::Scene::Animation::IntroDisableSlide
  def makeSlideSprite(spriteName, deltaMult, appearTime, origin = nil)
    # Añadir el sprite a la escena para que sea visible, pero NO animarlo
    if @sprites[spriteName]
      addSprite(@sprites[spriteName], origin)
    end
    return # Salir siempre antes de aplicar movimiento
  end
end

class Battle::Scene::Animation::Intro
  prepend Battle::Scene::Animation::IntroDisableSlide
end
#===============================================================================
# [BEZIER] Autosurf
#===============================================================================
# Versión adaptada para Pokémon Essentials 21.1
# Este script permite surfear de forma automática cuando se entra en contacto
# con un terrain tag surfeable.
#===============================================================================

#-------------------------------------------------------------------------------
# Configuración
#-------------------------------------------------------------------------------
# Poner a true si Surf se activa con las medallas
AUTOSURF_USEBADGES = false

# Poner a true si Surf se activa con un objeto
AUTOSURF_USEITEM = false

# Objeto que permite hacer autosurf (si AUTOSURF_USEITEM = true)
AUTOSURF_ITEM_KEY = :SURFBOARD

#-------------------------------------------------------------------------------
# Función principal de autosurf
#-------------------------------------------------------------------------------
def pbAutoSurf
  x = $game_player.x
  y = $game_player.y
  facing_terrain = $game_player.pbFacingTerrainTag
  
  # Verificar que no está ya surfeando y que el terreno es surfeable
  if !$PokemonGlobal.surfing && facing_terrain && facing_terrain.can_surf_freely
    # Cancela el Surf si está activo por medallas y no se cumple la condición
    if AUTOSURF_USEBADGES
      if defined?(Settings::HIDDENMOVE_BADGES) && Settings::HIDDENMOVE_BADGES
        badge_required = Settings::BADGEFORSURF || 0
        return if $Trainer.badges[badge_required].nil? || !$Trainer.badges[badge_required]
      else
        return if !$Trainer.badges.include?(true)  # Fallback genérico
      end
    end
    
    # Cancela el Surf si está activo por objeto pero no se posee el objeto
    if AUTOSURF_USEITEM
      return if !$PokemonBag.pbQuantity(AUTOSURF_ITEM_KEY) || $PokemonBag.pbQuantity(AUTOSURF_ITEM_KEY) <= 0
    end
    
    # Compatibilidad con PokémonFollow para hacer desaparecer al pokémon
    if defined?($PokemonTemp) && $PokemonTemp && 
       defined?($PokemonTemp.dependentEvents) && $PokemonTemp.dependentEvents &&
       $PokemonTemp.dependentEvents.respond_to?(:check_surf)
      $PokemonTemp.dependentEvents.check_surf(true)
    end
    
    pbStartSurfing
    return true
  end
  return false
end

#-------------------------------------------------------------------------------
# Interceptar el movimiento del player para usar autosurf cuando no puede pasar
#-------------------------------------------------------------------------------
class Game_Player < Game_Character
  alias_method :bezier_move_generic, :move_generic
  
  def move_generic(dir, turn_enabled = true)
    # Si no es pasable en esa dirección, intentar autosurf antes de hacer nada
    unless can_move_in_direction?(dir)
      # Aquí es donde intentamos surfear
      if pbAutoSurf
        # Si el autosurf funcionó, no hacer el movimiento normal
        if turn_enabled
          case dir
          when 2 then turn_down
          when 4 then turn_left
          when 6 then turn_right
          when 8 then turn_up
          end
        end
        return
      end
    end
    
    # Si es pasable o autosurf no funcionó, hacer el movimiento normal
    bezier_move_generic(dir, turn_enabled)
  end
end

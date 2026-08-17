#===============================================================================
# Añade una entrada a Battle::TRAPPING_MOVE_COMMON_ANIMATATIONS para movimientos
# de cepo que no tenían la suya. Se reproduce al final de ronda en
# pbEORTrappingDamage, igual que Fire Spin/Clamp/Wrap... (los "torbellino").
# Cepo (SnapTrap) usa FunctionCode = BindTarget. Si la animación común
# "Common:SnapTrap" no existe en los datos, no se reproduce (sin errores).
#===============================================================================

class Battle
  TRAPPING_MOVE_COMMON_ANIMATIONS[:SNAPTRAP] = "SnapTrap"
end

#===============================================================================
# Mode 7 (2.5D) - Desactivar Reflejos 2D en 3D
#===============================================================================
class Sprite_Reflection < RPG::Sprite
  alias_method :_ZBOX_M7_orig_update, :update unless method_defined?(:_ZBOX_M7_orig_update)

  def update
    _ZBOX_M7_orig_update
    
    # Si la cámara 3D está activa, ocultamos forzosamente el sprite de reflejo
    # para evitar que las coordenadas proyectadas lo dibujen por error.
    if $scene.is_a?(Scene_Map) && Mode7.active_now?
      self.visible = false
    end
  end
end
#===============================================================================
# [ZBOX] Nueva Pokédex - Controlador de Pantalla y Alias de Entrada
#===============================================================================
class NewPokedex_Screen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen(dex_id = 0)
    @scene.pbStartScene(dex_id)
    @scene.pbMain
    @scene.pbEndScene
  end
end

def pbOpenNewPokedex(dex_id = 0)
  scene = NewPokedex_Scene.new
  screen = NewPokedex_Screen.new(scene)
  screen.pbStartScreen(dex_id)
end

# Reemplazo transparente de la llamada estándar de Pokédex si se desea
def pbShowPokedex(dex_id = -1)
  dex_to_open = (dex_id >= 0) ? dex_id : (NewPokedex.enabled_dex_list.first || 0)
  pbOpenNewPokedex(dex_to_open)
end

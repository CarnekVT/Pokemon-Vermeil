# encoding: UTF-8
# Punto de entrada único: la escena completa del plugin (main.rb).
# La antigua NewPokedex_Scene queda disponible como interfaz de compatibilidad,
# pero ya no reemplaza las fichas, ubicaciones ni el visor de formas.
class NewPokedex_Screen
  def initialize(_scene = nil)
  end

  def pbStartScreen(dex_id = -1)
    pbOpenNewPokedex(dex_id)
  end
end

def pbOpenNewPokedex(dex_id = -1)
  return if !defined?(NuevaPokedex) || !NuevaPokedex.enabled?
  regions = NuevaPokedex.accessible_regions
  return if regions.empty?
  region = (dex_id && regions.include?(dex_id.to_i)) ? dex_id.to_i : regions.first
  scene = PokemonPokedexNueva_Scene.new(region)
  screen = PokemonPokedexNuevaScreen.new(scene)
  screen.pbStartScreen
end

# Las llamadas externas pbShowPokedex usan la misma UI completa que el menú.
def pbShowPokedex(dex_id = -1)
  pbOpenNewPokedex(dex_id)
end

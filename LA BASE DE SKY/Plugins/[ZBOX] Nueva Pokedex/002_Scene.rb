# encoding: UTF-8
# Adaptador de compatibilidad de la API anterior.
# La escena completa y única es PokemonPokedexNueva_Scene (main.rb).
# Nunca dibujar una segunda UI simplificada encima de la original.
class NewPokedex_Scene
  def initialize
    @inner = nil
  end

  def pbStartScene(dex_id = -1)
    return unless defined?(NuevaPokedex)
    regions = NuevaPokedex.accessible_regions
    region = regions.include?(dex_id) ? dex_id : regions.first
    return if region.nil?
    @inner = PokemonPokedexNueva_Scene.new(region)
    @inner.pbStartScene
  end

  def pbMain
    @inner.pbPokedex if @inner
  end

  def pbEndScene
    @inner.pbEndScene if @inner
    @inner = nil
  end
end

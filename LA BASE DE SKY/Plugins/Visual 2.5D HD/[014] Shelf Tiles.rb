#===============================================================================
# Visual 2.5D HD - Tiles Shelf
#-------------------------------------------------------------------------------
# Terrain tag :Shelf (21). Tapa tumbada a la base de su prioridad.
# El 21 no es altura y solo afecta a la capa que lo lleva.
# pri 1+21 = ras de suelo; pri 5+21 = cierra con el vertical pri 4.
# Logica: [001] Settings.rb, [003] Tile Depth.rb, [012] MakerStudio Bridge.rb.
#===============================================================================
GameData::TerrainTag.register({ :id => :Shelf, :id_number => 21 })
#===============================================================================
# [VERMEIL] Visual 2.5D - 011_InteriorWalls.rb
# Reglas de interiores para SKY. La geometria principal vive en 003/010; este
# modulo deja utilidades publicas de diagnostico para no volver a forzar affine.
#===============================================================================
module Mode7
  class << self
    def interior_sky?
      return indoor_map? && sky_mode?
    end
  end
end

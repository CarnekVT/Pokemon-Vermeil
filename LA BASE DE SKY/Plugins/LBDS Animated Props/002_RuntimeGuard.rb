# LBDS Animated Props v0.1.2 — guardia de compatibilidad y diagnóstico.
# Este script se carga después de 001_Animated_Props.rb.
# Protege también instalaciones donde el archivo principal antiguo continuó
# compilado, siempre que el gestor sí haya recompilado este script adicional.
if defined?(LBDSAnimatedProps)
  module LBDSAnimatedProps
    RUNTIME_GUARD_VERSION = '0.1.2'
    # Never index a nil lookup: terrain/overworld plugins can call this during
    # setup, load, or from an old save before instance variables exist.
    def self.cell_at(map, x, y)
      return nil if !map
      lookup = if map.respond_to?(:lbds_props_lookup_ensure)
                 map.lbds_props_lookup_ensure
               elsif map.respond_to?(:lbds_props_lookup)
                 map.lbds_props_lookup
               end
      return nil unless lookup.is_a?(Hash)
      cell = lookup[[x, y]]
      return cell if cell.is_a?(Hash)
      nil
    end
  end
  warn '[LBDS Animated Props] RuntimeGuard 0.1.2 cargado'
else
  warn '[LBDS Animated Props] ADVERTENCIA: falta el modulo principal; revisa la instalacion.'
end

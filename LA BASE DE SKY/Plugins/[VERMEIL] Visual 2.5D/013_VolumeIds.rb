#===============================================================================
# [VERMEIL] Visual 2.5D - 013_VolumeIds.rb
# Metadata visual de volumen escrita por el mod de Maker Studio.
# No modifica MapXXX.rxdata, terrain tags, prioridad ni pasabilidad.
#===============================================================================
module Mode7
  module VolumeIds
    FILE_PATH = File.join("Plugins", "[VERMEIL] Visual 2.5D", "volume_ids.json")

    @mtime = :unloaded
    @maps = {}

    class << self
      def refresh
        mtime = File.exist?(FILE_PATH) ? File.mtime(FILE_PATH) : nil
        return if @mtime == mtime
        @mtime = mtime
        data = JSON.parse(File.read(FILE_PATH))
        @maps = data.is_a?(Hash) && data["maps"].is_a?(Hash) ? data["maps"] : {}
      rescue Exception
        # ponytail: registro opcional; mapa sin metadata conserva ruta legacy.
        @maps = {}
      end

      def id_for(map_id, x, y)
        cells = @maps[map_id.to_s]
        return nil if !cells.is_a?(Hash)
        id = cells["#{x},#{y}"]
        id = id.to_s.strip if !id.nil?
        id && !id.empty? ? id : nil
      end
    end
  end
end

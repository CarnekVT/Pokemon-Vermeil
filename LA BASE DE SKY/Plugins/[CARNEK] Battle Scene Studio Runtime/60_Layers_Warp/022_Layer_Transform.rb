#===============================================================================
# Battle Scene Studio v0.8.13
# Independent layer X/Y scale authority.
#
# IMPORTANT: this authority is intentionally implemented with prepend + super.
# v0.8.11 aliased BSS070EBDXRoom#position after older prepend modules were
# already active. Ruby's method lookup then formed a cycle between 018, 019 and
# 022, producing SystemStackError (stack level too deep). There are no aliases
# in this authority; position enters the previous chain exactly once.
#===============================================================================
module BSS091LayerTransformAuthority
  VERSION = "0.8.13"

  def position
    ret = super
    begin
      bg = @sprites && @sprites["bg"]
      if bg && @data.is_a?(Hash)
        @data.each do |raw_key, data|
          key = raw_key.to_s
          next if key !~ /^img\d+/i
          next if !data.is_a?(Hash)
          sp = @sprites[key]
          next if !sp || (sp.disposed? rescue true)
          # Mesh-warped layers are projected by BSS093WarpMeshAuthority. Keep the
          # hidden source sprite untouched here except for its authored metadata.
          warp = data[:warp]
          next if warp.is_a?(Hash) && warp[:enabled] == true

          general = if data.has_key?(:zoom)
                      data[:zoom].to_f
                    elsif sp.respond_to?(:param) && !sp.param.nil?
                      sp.param.to_f
                    else
                      1.0
                    end
          sx = data.has_key?(:zoom_x) ? data[:zoom_x].to_f : general
          sy = data.has_key?(:zoom_y) ? data[:zoom_y].to_f : general

          if data[:flat]
            sp.zoom_x = bg.zoom_x.to_f * sx if sp.respond_to?(:zoom_x=)
            sp.zoom_y = bg.zoom_y.to_f * sy if sp.respond_to?(:zoom_y=)
          else
            perspective = bg.zoom_x.to_f
            sp.zoom_x = perspective * sx if sp.respond_to?(:zoom_x=)
            sp.zoom_y = perspective * sy if sp.respond_to?(:zoom_y=)
          end
        end
      end
    rescue
      # Transform authoring must never interrupt battle world updates.
    end
    ret
  end
end

begin
  if defined?(BSS070EBDXRoom) && !(BSS070EBDXRoom.ancestors.include?(BSS091LayerTransformAuthority) rescue false)
    BSS070EBDXRoom.prepend(BSS091LayerTransformAuthority)
  end
rescue => e
  echoln("[BSS091] Layer transform authority install skipped: #{e.class}: #{e.message}") if defined?(echoln)
end

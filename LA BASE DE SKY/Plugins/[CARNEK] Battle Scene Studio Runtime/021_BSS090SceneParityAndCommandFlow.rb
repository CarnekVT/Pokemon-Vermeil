#===============================================================================
# Battle Scene Studio v0.8.10
# JSON scene schema parity + non-invasive Enhanced UI command flow.
#
# EBDX's original Ruby environment definitions use String keys for top-level
# room entries ("backdrop", "trees", "img001"...) and Symbol keys inside each
# drawable definition (:bitmap, :x, :flat, :elements...). JSON can only provide
# String keys. Without normalizing that boundary the editor renders the complete
# scene while runtime silently ignores img/trees/grass properties.
#
# This final authority converts only the nested EBDX property hashes to Symbols,
# preserving the top-level room keys expected by BattleSceneRoom.
#
# It also returns Enhanced Battle UI prompt state to the plugin that owns it.
# BSS keeps only layer/Z integration; it never rewrites prompt.battler/window from
# CommandMenu/FightMenu selection indices during pbUpdate.
#===============================================================================

module BSS090
  VERSION = "0.8.10"
  module_function

  def deep_symbolize(value)
    case value
    when Hash
      out = {}
      value.each do |k,v|
        key = k.is_a?(String) ? k.to_sym : k
        out[key] = deep_symbolize(v)
      end
      out
    when Array
      value.map { |v| deep_symbolize(v) }
    else
      value
    end
  end

  # Keep the room-level API source-faithful: top-level keys are Strings, while
  # individual EBDX object definitions use Symbol properties just like the
  # original Environments.rb data supplied with EBDX.
  def normalize_scene_data(data)
    return data unless data.is_a?(Hash)
    out = {}
    data.each do |k,v|
      key = k.to_s
      out[key] = v.is_a?(Hash) ? deep_symbolize(v) : (v.is_a?(Array) ? deep_symbolize(v) : v)
    end
    out
  rescue
    data
  end
end

module BSS090SceneSchemaAuthority
  def custom_environment(name)
    data = super
    BSS090.normalize_scene_data(data)
  end
end

begin
  if defined?(BSS070EBDXCore)
    sc = class << BSS070EBDXCore; self; end
    sc.prepend(BSS090SceneSchemaAuthority) unless sc.ancestors.include?(BSS090SceneSchemaAuthority)
  end
rescue => e
  BSS064.log("BSS090 scene schema install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

#-------------------------------------------------------------------------------
# Enhanced Battle UI authority
#-------------------------------------------------------------------------------
# v0.8.5 tried to infer a battler from CommandMenu/FightMenu. Those objects own
# command/move selection indices, not battlers. v0.8.7 also refreshed the prompt
# every pbUpdate and copied those menu indices into prompt.battler. Besides the
# earlier NoMethodError, this can continuously overwrite Enhanced UI state while
# its own command loop is waiting for input. BSS must only keep its visual layer
# above the BattleBox and otherwise delegate prompt lifecycle untouched.
#-------------------------------------------------------------------------------
if defined?(BSS085StableWorldAuthority)
  module BSS085StableWorldAuthority
    def bss085_enhanced_prompt_guard
      bss085_enhanced_ui_layers if respond_to?(:bss085_enhanced_ui_layers)
      true
    rescue
      true
    end

    def pbRefreshUIPrompt(*args, &block)
      ret = super
      bss085_enhanced_ui_layers if respond_to?(:bss085_enhanced_ui_layers)
      ret
    end
  end
end

if defined?(BSS087EnhancedUIAuthority)
  module BSS087EnhancedUIAuthority
    def bss087_refresh_enhanced_now
      # Do not alter prompt.window, prompt.battler, visibility or menu indices.
      # Enhanced Battle UI is the sole state/input authority for those values.
      bss087_enforce_enhanced_ui_z if respond_to?(:bss087_enforce_enhanced_ui_z)
      true
    rescue
      true
    end
  end
end

# Extra invariant for JSON rooms created in MakerStudio: normalize again at the
# room constructor boundary. This also protects callers that bypass
# BSS070EBDXCore.custom_environment and instantiate a room from external data.
module BSS090RoomSchemaGuard
  def initialize(viewport, scene, data)
    super(viewport, scene, BSS090.normalize_scene_data(data))
  end

  def refresh(*args)
    if args[0].is_a?(Hash)
      args = args.clone
      args[0] = BSS090.normalize_scene_data(args[0])
    end
    super(*args)
  end
end

begin
  if defined?(BSS070EBDXRoom) && !BSS070EBDXRoom.ancestors.include?(BSS090RoomSchemaGuard)
    BSS070EBDXRoom.prepend(BSS090RoomSchemaGuard)
  end
rescue => e
  BSS064.log("BSS090 room schema install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

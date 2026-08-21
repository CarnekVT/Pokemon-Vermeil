#===============================================================================
# Input Studio Runtime v0.2.0
# Reads Data/CarnekStudio/input_extensions.json as an additive layer.
# The original Input module/constants are never rewritten.
#===============================================================================
module CarnekStudio
  module InputActions
    module_function

    EXTENSION_FILE = "input_extensions.json"
    LEGACY_FILE    = "input_actions.json"

    def data
      return @data if @data
      @data = CarnekStudio.load_json(EXTENSION_FILE, nil)
      @data ||= CarnekStudio.load_json(LEGACY_FILE, {"actions" => []})
      @data ||= {"actions" => []}
      @data
    end

    def reload
      @data = nil
      data
    end

    def actions
      data["actions"] || []
    end

    def action(id, context = :global)
      wanted = context.to_s
      actions.reverse_each.find do |a|
        next false if a.key?("enabled") && !a["enabled"]
        next false unless a["id"].to_s == id.to_s
        ctx = (a["context"] || "global").to_s
        ctx == "global" || ctx == wanted
      end
    end

    def source_constant(expr)
      name = expr.to_s.sub(/^Input::/, "")
      return nil if name.empty? || !defined?(Input)
      Input.const_get(name)
    rescue
      nil
    end

    def scancode(value)
      value.to_s.sub(/^:/, "").to_sym
    rescue
      nil
    end

    def normalized_binding(binding)
      return {"type" => "source", "value" => binding.to_s} unless binding.is_a?(Hash)
      {"type" => (binding["type"] || "source").to_s, "value" => binding["value"].to_s}
    end

    def binding_state(binding, mode)
      b = normalized_binding(binding)
      case b["type"]
      when "scancode"
        key = scancode(b["value"])
        return false if key.nil?
        case mode
        when :press
          return Input.respond_to?(:pressex?) ? Input.pressex?(key) : false
        when :repeat
          return Input.respond_to?(:repeatex?) ? Input.repeatex?(key) : (Input.respond_to?(:triggerex?) ? Input.triggerex?(key) : false)
        else
          return Input.respond_to?(:triggerex?) ? Input.triggerex?(key) : false
        end
      else
        key = source_constant(b["value"])
        return false if key.nil?
        case mode
        when :press  then return Input.press?(key)
        when :repeat then return Input.repeat?(key)
        else              return Input.trigger?(key)
        end
      end
    rescue => e
      PBDebug.log("[CarnekStudio] Input binding #{binding.inspect}: #{e.message}") if defined?(PBDebug)
      false
    end

    def state?(id, context = :global, mode = :trigger)
      a = action(id, context)
      return false unless a
      (a["bindings"] || []).any? { |binding| binding_state(binding, mode) }
    end

    def bindings(id, context = :global)
      a = action(id, context)
      a ? (a["bindings"] || []) : []
    end
  end
end

module Input
  def self.action?(id, context = :global)
    CarnekStudio::InputActions.state?(id, context, :trigger)
  end

  def self.action_trigger?(id, context = :global)
    CarnekStudio::InputActions.state?(id, context, :trigger)
  end

  def self.action_press?(id, context = :global)
    CarnekStudio::InputActions.state?(id, context, :press)
  end

  def self.action_repeat?(id, context = :global)
    CarnekStudio::InputActions.state?(id, context, :repeat)
  end

  def self.action_bindings(id, context = :global)
    CarnekStudio::InputActions.bindings(id, context)
  end
end

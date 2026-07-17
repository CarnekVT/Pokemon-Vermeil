module UI_Editor
  extend MiolUtils
  class ControlEditor

    @is_active = false
    @scene     = nil
    @mode      = :none
    
    class << self
    attr_accessor :last_scene, :mode, :scene
      def active(original_scene)
        return if @is_active
        @is_active = true
        @scene = original_scene
        echoln "---#{pbGetGreeting}---"
        UI_Editor.echo_color("---Abriendo UI Editor en #{original_scene.class}---","cian")
      end

      def active?; @is_active; end
      def mode; @mode; end
      def scene; @scene; end

      def close
        @is_active = false
        @scene     = nil
        @mode      = :none
      end

      def mode=(value)
        @mode = value
      end
    end
  end
    
end

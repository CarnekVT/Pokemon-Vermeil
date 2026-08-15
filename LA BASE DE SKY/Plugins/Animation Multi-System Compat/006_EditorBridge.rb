#===============================================================================
# Editor bridge.
#
# Adds no behaviour unless explicitly used. Provides:
#   - AnimationMultisystem.scan!            (index EBDX definitions from source)
#   - AnimationMultisystem.report(move_id)  (human summary incl. unsupported)
#   - AnimationMultisystem.animations_for_move(move_id)
#   - AnimationEditor::AnimationSelector#multisystem_animations_for (added if the
#     editor class exists) so the editor can surface multi-system animations
#     without us overriding any of its methods.
#===============================================================================
module AnimationMultisystem
  module EditorBridge
    module_function

    def scan!
      EBDXSourceParser.scan
    end

    # Returns an array of playable animation objects for a move id.
    def animations_for_move(move_id)
      Loader.for_move(move_id)
    end

    def animations_for_common(name)
      Loader.for_common(name)
    end

    # Builds a plain-text report describing what was understood and what was not,
    # for a given move. Explicitly surfaces unsupported commands instead of
    # hiding them.
    def report(move_id)
      lines = []
      lines << "Animation Multi-System report for #{move_id}"
      anims = Loader.for_move(move_id)
      if anims.empty?
        lines << "  (no multi-system animation registered)"
      end
      anims.group_by(&:source_system).each do |sys, group|
        group.each do |anim|
          lines << "  [#{sys}] #{anim.name} (fps #{anim.fps}, #{anim.particles.length} particles)"
          anim.audio_events.each { |a| lines << "      SE @#{a[:frame]}: #{a[:name]} vol#{a[:volume]} pitch#{a[:pitch]}" }
          anim.unsupported.each do |u|
            lines << "      UNSUPPORTED: #{u[:context]}#{u[:detail].empty? ? '' : ' (' + u[:detail] + ')'}"
          end
          anim.warnings.each { |w| lines << "      note: #{w}" }
        end
      end
      lines.join("\n")
    end

    # Add a helper to the editor selector if it is loaded, without overriding
    # any of its existing behaviour.
    def install
      return if !defined?(AnimationEditor::AnimationSelector)
      cls = AnimationEditor::AnimationSelector
      return if cls.method_defined?(:multisystem_animations_for)
      cls.class_eval do
        def multisystem_animations_for(move_id)
          AnimationMultisystem.animations_for_move(move_id)
        rescue
          []
        end
      end
    rescue
      nil
    end
  end

  # Convenience accessors.
  def self.scan!;  EditorBridge.scan!; end
  def self.report(move_id); EditorBridge.report(move_id); end
  def self.animations_for_move(move_id); EditorBridge.animations_for_move(move_id); end
  def self.animations_for_common(name); EditorBridge.animations_for_common(name); end

  # Index EBDX definitions when the game loads (non-blocking, best-effort).
  if defined?(EventHandlers)
    EventHandlers.add(:on_game_load, :animation_multisystem_scan, proc {
      EditorBridge.scan!
      EditorBridge.install
    })
  end
end

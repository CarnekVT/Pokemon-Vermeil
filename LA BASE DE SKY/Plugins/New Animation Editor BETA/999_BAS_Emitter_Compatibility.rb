#===============================================================================
# Battle Animation Studio / New Animation Editor emitter compatibility
#-------------------------------------------------------------------------------
# Accepts PE21.1-era emitter PBS and compiled animation data, then normalizes it
# to the modern emitter model. Saving always writes the modern canonical schema.
#===============================================================================
module GameData
  class Animation
    LEGACY_ANGLE_OVERRIDES = {
      "None"                => :none,
      "InitialAngleToFocus" => :initial_angle_to_focus,
      "AlwaysPointAtFocus"  => :always_point_at_focus
    } unless const_defined?(:LEGACY_ANGLE_OVERRIDES)
    ANGLE_OVERRIDES = LEGACY_ANGLE_OVERRIDES unless const_defined?(:ANGLE_OVERRIDES)

    LEGACY_PBS_EMITTER_KEYS = {
      "AngleOverride"      => "InitialAngle",
      "SetEmitX"           => "SetSpawnX",
      "MoveEmitX"          => "MoveSpawnX",
      "SetEmitXRange"      => "SetSpawnXRange",
      "MoveEmitXRange"     => "MoveSpawnXRange",
      "SetEmitY"           => "SetSpawnY",
      "MoveEmitY"          => "MoveSpawnY",
      "SetEmitYRange"      => "SetSpawnYRange",
      "MoveEmitYRange"     => "MoveSpawnYRange",
      "SetEmitAngle"       => "SetEmitDirection",
      "MoveEmitAngle"      => "MoveEmitDirection",
      "SetEmitAngleRange"  => "SetEmitDirectionRange",
      "MoveEmitAngleRange" => "MoveEmitDirectionRange",
      "SetPeriodX"         => "SetEmitPeriodX",
      "MovePeriodX"        => "MoveEmitPeriodX",
      "SetPeriodXRange"    => "SetEmitPeriodXRange",
      "MovePeriodXRange"   => "MoveEmitPeriodXRange",
      "SetPeriodY"         => "SetEmitPeriodY",
      "MovePeriodY"        => "MoveEmitPeriodY",
      "SetPeriodYRange"    => "SetEmitPeriodYRange",
      "MovePeriodYRange"   => "MoveEmitPeriodYRange",
      "SetPeriodZ"         => "SetEmitPeriodZ",
      "MovePeriodZ"        => "MoveEmitPeriodZ",
      "SetPeriodZRange"    => "SetEmitPeriodZRange",
      "MovePeriodZRange"   => "MoveEmitPeriodZRange",
      "SetRadiusXRange"    => "SetEmitRadiusXRange",
      "MoveRadiusXRange"   => "MoveEmitRadiusXRange",
      "SetRadiusYRange"    => "SetEmitRadiusYRange",
      "MoveRadiusYRange"   => "MoveEmitRadiusYRange",
      "SetRadiusZRange"    => "SetEmitRadiusZRange",
      "MoveRadiusZRange"   => "MoveEmitRadiusZRange",
      "SetClockwise"       => "SetEmitClockwise",
      "SetZoomRange"       => "SetEmitZoomRange",
      "MoveZoomRange"      => "MoveEmitZoomRange",
      "SetZoomXRange"      => "SetEmitZoomXRange",
      "MoveZoomXRange"     => "MoveEmitZoomXRange",
      "SetZoomYRange"      => "SetEmitZoomYRange",
      "MoveZoomYRange"     => "MoveEmitZoomYRange"
    }.freeze

    LEGACY_PARTICLE_EMITTER_KEYS = {
      :emit_x           => :spawn_x,
      :emit_x_range     => :spawn_x_range,
      :emit_y           => :spawn_y,
      :emit_y_range     => :spawn_y_range,
      :emit_angle       => :emit_direction,
      :emit_angle_range => :emit_direction_range
    }.freeze

    LEGACY_INITIAL_ANGLES = {
      :initial_angle_to_focus => :particle_to_focus,
      :always_point_at_focus  => :always_particle_to_focus,
      "InitialAngleToFocus"   => :particle_to_focus,
      "AlwaysPointAtFocus"    => :always_particle_to_focus,
      "None"                  => :none
    }.freeze

    def self.normalize_legacy_pbs_property(key, raw_value)
      original_key = key
      key = LEGACY_PBS_EMITTER_KEYS[key] || key
      if original_key == "AngleOverride"
        replacements = {
          "InitialAngleToFocus" => "ParticleToFocus",
          "AlwaysPointAtFocus"  => "AlwaysParticleToFocus"
        }
        raw_value = replacements[raw_value.to_s.strip] || raw_value
      end
      return key, raw_value
    end

    def self.normalize_legacy_emitter_particle!(particle)
      return particle if !particle.is_a?(Hash)
      LEGACY_PARTICLE_EMITTER_KEYS.each_pair do |old_key, new_key|
        next if !particle.key?(old_key)
        particle[new_key] = particle[old_key] if !particle.key?(new_key)
        particle.delete(old_key)
      end
      if particle.key?(:angle_override)
        old_angle = particle.delete(:angle_override)
        if !particle.key?(:initial_angle)
          particle[:initial_angle] = LEGACY_INITIAL_ANGLES[old_angle] || old_angle || :none
        end
      elsif particle[:initial_angle] && LEGACY_INITIAL_ANGLES[particle[:initial_angle]]
        particle[:initial_angle] = LEGACY_INITIAL_ANGLES[particle[:initial_angle]]
      end
      return particle
    end

    def self.normalize_legacy_animation_hash!(hash)
      return hash if !hash.is_a?(Hash)
      particles = hash[:particles]
      particles.each { |particle| normalize_legacy_emitter_particle!(particle) } if particles.is_a?(Array)
      return hash
    end

    alias __bas_emitter_compat_initialize initialize unless method_defined?(:__bas_emitter_compat_initialize)
    def initialize(hash)
      self.class.normalize_legacy_animation_hash!(hash)
      __bas_emitter_compat_initialize(hash)
      normalize_legacy_emitter_particles!
    end

    alias __bas_emitter_compat_particles particles unless method_defined?(:__bas_emitter_compat_particles)
    def particles
      ret = __bas_emitter_compat_particles
      ret.each { |particle| self.class.normalize_legacy_emitter_particle!(particle) } if ret.is_a?(Array)
      return ret
    end

    alias __bas_emitter_compat_clone_as_hash clone_as_hash unless method_defined?(:__bas_emitter_compat_clone_as_hash)
    def clone_as_hash
      normalize_legacy_emitter_particles!
      return __bas_emitter_compat_clone_as_hash
    end

    def normalize_legacy_emitter_particles!
      @particles.each { |particle| self.class.normalize_legacy_emitter_particle!(particle) } if @particles.is_a?(Array)
      return self
    end

    class << self
      alias __bas_emitter_compat_load load unless method_defined?(:__bas_emitter_compat_load)
      def load
        __bas_emitter_compat_load
        DATA.each_value do |animation|
          animation.normalize_legacy_emitter_particles! if animation.respond_to?(:normalize_legacy_emitter_particles!)
        end
      end
    end
  end
end

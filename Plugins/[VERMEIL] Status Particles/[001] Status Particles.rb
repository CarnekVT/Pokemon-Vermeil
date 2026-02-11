#===============================================================================
# Status Particles (Battle)
#===============================================================================
module StatusParticles
  @@emitters = []
  @@suppressed = false
  @@suppress_depth = 0

  def self.suppressed?
    return @@suppressed
  end

  def self.with_suppressed
    @@suppress_depth += 1
    @@suppressed = true
    yield
  ensure
    @@suppress_depth -= 1
    @@suppressed = (@@suppress_depth > 0)
  end

  def self.register_emitter(emitter)
    @@emitters << emitter
  end

  def self.unregister_emitter(emitter)
    @@emitters.delete(emitter)
  end

  def self.dispose_all
    @@emitters.each { |e| e.dispose }
    @@emitters.clear
  end

  ASSET_DIR = "Graphics/Pictures/StatusParticles/"

  ICON_FILES = {
    :SLEEP      => "sleep",
    :FROZEN     => "freeze",
    :BURN       => "burn",
    :POISON     => "poison",
    :TOXIC      => "toxic",
    :PARALYSIS  => "paralysis",
    :CONFUSION  => "confusion",
    :INFATUATION => "infatuation"
  }

  STYLE_BY_STATUS = {
    :SLEEP       => :sleep_z,
    :FROZEN      => :freeze_flakes,
    :BURN        => :burn_embers,
    :POISON      => :poison_bubbles,
    :TOXIC       => :toxic_bubbles,
    :PARALYSIS   => :paralysis_sparks,
    :CONFUSION   => :confusion_orbit,
    :INFATUATION => :infatuation_hearts
  }

  PARTICLE_COUNTS = {
    :sleep_z          => 2,
    :freeze_flakes    => 3,
    :burn_embers      => 3,
    :poison_bubbles   => 2,
    :toxic_bubbles    => 3,
    :paralysis_sparks => 1,
    :confusion_orbit  => 3,
    :infatuation_hearts => 2
  }

  # Stored for future use (not displayed right now).
  FUTURE_EFFECTS = [
    :CURSE, :LEECHSEED, :NIGHTMARE, :TRAP, :BIND, :TAUNT, :ENCORE, :TORMENT,
    :DISABLE, :HEALBLOCK, :PERISH, :YAWN, :INGRAIN, :CHARGE, :MIST,
    :REFLECT, :LIGHTSCREEN, :AURORA_VEIL
  ]

  # These are intentionally excluded from future storage.
  IGNORED_EFFECTS = [:PROTECT, :AQUA_RING, :RAGE, :SAFEGUARD]

  def self.status_key(battler, type = :main)
    return nil if !battler || battler.fainted?
    case type
    when :main
      st = battler.status
      if st && st != :NONE
        case st
        when :SLEEP, :DROWSY
          return :SLEEP
        when :FROZEN, :FROSTBITE
          return :FROZEN
        when :BURN
          return :BURN
        when :PARALYSIS
          return :PARALYSIS
        when :POISON
          return (battler.statusCount && battler.statusCount > 0) ? :TOXIC : :POISON
        end
      end
    when :confusion
      return :CONFUSION if battler.effects && battler.effects[PBEffects::Confusion].to_i > 0
    when :attraction
      return :INFATUATION if battler.effects && battler.effects[PBEffects::Attract] && battler.effects[PBEffects::Attract] >= 0
    end
    return nil
  end

  def self.style_for(status_key)
    return STYLE_BY_STATUS[status_key] || :confusion_orbit
  end

  def self.particle_count_for(style)
    return PARTICLE_COUNTS[style] || 3
  end

  def self.asset_name(status_key)
    return ICON_FILES[status_key]
  end
end

#===============================================================================
# Status particles emitter
#===============================================================================
class StatusParticles::Emitter
  ICON_BOB_RATE       = 0.12
  ICON_BOB_AMT        = 4
  PARTICLE_BOB_RATE   = 0.08
  PARTICLE_BOB_AMT    = 2
  PARTICLE_RADIUS_MIN = 12
  PARTICLE_RADIUS_MAX = 22
  ANCHOR_Y_OFFSET     = 6
  PLAYER_SIDE_Y_OFFSET = 18
  FADE_IN_FRAMES      = 10
  FADE_OUT_FRAMES     = 10

  def initialize(viewport, battler_sprite, type = :main)
    @viewport = viewport
    @battler_sprite = battler_sprite
    @type = type
    @sprites = []
    @particle_data = []
    @status_key = nil
    @style = :confusion_orbit
    @bitmap = nil
    @bitmap_name = nil
  end

  def dispose
    @sprites.each { |s| s.dispose }
    @sprites.clear
    @particle_data.clear
    dispose_bitmap
  end

  def update
    refresh_status
    if StatusParticles.suppressed?
      hide_all
      return
    end
    update_particles
  end

  private

  def refresh_status
    if !Settings::SHOW_STATUS_PARTICLES
      clear_status
      return
    end
    battler = @battler_sprite.status_particle_battler
    status_key = StatusParticles.status_key(battler, @type)
    if status_key != @status_key
      @status_key = status_key
      setup_for_status
    end
  end

  def clear_status
    @status_key = nil
    dispose_bitmap
    hide_all
  end

  def setup_for_status
    if @status_key.nil?
      hide_all
      return
    end
    @style = StatusParticles.style_for(@status_key)
    ensure_bitmap
    ensure_particle_count(StatusParticles.particle_count_for(@style))
    reset_particles
  end

  def ensure_bitmap
    name = StatusParticles.asset_name(@status_key)
    return if name == @bitmap_name
    dispose_bitmap
    @bitmap_name = name
    if name
      path = pbResolveBitmap("#{StatusParticles::ASSET_DIR}#{name}")
      @bitmap = path ? Bitmap.new(path) : build_fallback_bitmap(@status_key)
    else
      @bitmap = build_fallback_bitmap(@status_key)
    end
    @sprites.each do |s|
      s.bitmap = @bitmap
      s.ox = (@bitmap ? @bitmap.width / 2 : 0)
      s.oy = (@bitmap ? @bitmap.height / 2 : 0)
      s.mirror = false
    end
  end

  def dispose_bitmap
    if @bitmap && !@bitmap.disposed?
      @bitmap.dispose
    end
    @bitmap = nil
    @bitmap_name = nil
  end

  def build_fallback_bitmap(status_key)
    color = case status_key
    when :SLEEP      then Color.new(140, 180, 255)
    when :FROZEN     then Color.new(120, 200, 255)
    when :BURN       then Color.new(255, 120, 80)
    when :POISON     then Color.new(190, 80, 200)
    when :TOXIC      then Color.new(150, 40, 180)
    when :PARALYSIS  then Color.new(255, 230, 80)
    when :CONFUSION  then Color.new(255, 180, 80)
    when :INFATUATION then Color.new(255, 120, 160)
    else Color.new(255, 255, 255)
    end
    bmp = Bitmap.new(16, 16)
    16.times do |y|
      16.times do |x|
        next if (x - 7.5) * (x - 7.5) + (y - 7.5) * (y - 7.5) > 49
        bmp.set_pixel(x, y, color)
      end
    end
    return bmp
  end

  def ensure_particle_count(count)
    while @sprites.length > count
      s = @sprites.pop
      s.dispose
    end
    while @sprites.length < count
      s = RPG::Sprite.new(@viewport)
      s.bitmap = @bitmap
      s.ox = (@bitmap ? @bitmap.width / 2 : 0)
      s.oy = (@bitmap ? @bitmap.height / 2 : 0)
      @sprites << s
    end
  end

  def reset_particles
    @particle_data = @sprites.map do
      {
        :angle  => rand * Math::PI * 2,
        :radius => (@style == :confusion_orbit) ? rand(30..45) : rand(PARTICLE_RADIUS_MIN..PARTICLE_RADIUS_MAX),
        :speed  => (rand * 0.03) + 0.02,
        :seed   => rand(0.0..10.0),
        :life   => (@style == :paralysis_sparks) ? rand(40..60) : rand(50..90),
        :age    => rand(0..40),
        :side_toggle => [true, false].sample
      }
    end
  end

  def update_particles
    visible = particle_visible?
    if !visible || @status_key.nil? || !@bitmap
      hide_all
      return
    end
    anchor_x, anchor_y = anchor_position
    
    # Calculate center Y for centering particles on the battler
    bm = @battler_sprite.bitmap
    if bm
      visual_top = @battler_sprite.y - (@battler_sprite.oy * @battler_sprite.zoom_y)
      visual_height = bm.height * @battler_sprite.zoom_y
      center_y = visual_top + (visual_height / 2)
    else
      center_y = @battler_sprite.y - 32
    end

    # Player side scaling (x1.5)
    is_player = @battler_sprite.index && @battler_sprite.index.even?
    scale = is_player ? 1.5 : 1.0

    frame = Graphics.frame_count
    @sprites.each_with_index do |s, i|
      s.z = @battler_sprite.z + 5
      s.opacity = @battler_sprite.opacity
      s.visible = true
      s.zoom_x = scale
      s.zoom_y = scale
      update_style_particle(s, i, anchor_x, anchor_y, center_y, frame)
    end
  end

  def particle_visible?
    return false if !@battler_sprite || @battler_sprite.disposed?
    return false if @battler_sprite.vanishMode && @battler_sprite.vanishMode > 0
    return false if !@battler_sprite.visible
    return false if @battler_sprite.opacity <= 0
    return true
  end

  def hide_all
    @sprites.each { |s| s.visible = false }
  end

  def anchor_position
    bm = @battler_sprite.bitmap
    base_x = @battler_sprite.x
    if bm
      base_y = @battler_sprite.y - (@battler_sprite.oy * @battler_sprite.zoom_y)
    else
      base_y = @battler_sprite.y - 64
    end
    y = base_y + ANCHOR_Y_OFFSET
    y += PLAYER_SIDE_Y_OFFSET if @battler_sprite.index && @battler_sprite.index.even?
    return [base_x, y]
  end

  def update_style_particle(sprite, i, anchor_x, anchor_y, center_y, frame)
    data = @particle_data[i]
    data[:age] += 1
    life = data[:life]
    if data[:age] >= life
      data[:age] = 0
      
      if @style == :paralysis_sparks
        data[:life] = rand(40..60)
        data[:side_toggle] = !data[:side_toggle]
        # Alternate sides: 0 (Right) or PI (Left)
        data[:angle] = data[:side_toggle] ? 0 : Math::PI
      else
        data[:life] = rand(50..90)
        data[:angle] = rand * Math::PI * 2
      end
      
      data[:seed] = rand(0.0..10.0)
    end
    alpha = particle_alpha(data[:age], data[:life])
    case @style
    when :confusion_orbit
      data[:angle] += data[:speed]
      sprite.x = anchor_x + Math.cos(data[:angle]) * data[:radius]
      sprite.y = anchor_y + Math.sin(data[:angle]) * data[:radius] * 0.6
      sprite.y += Math.sin(frame * PARTICLE_BOB_RATE + i) * PARTICLE_BOB_AMT
      sprite.opacity = @battler_sprite.opacity * alpha
    when :sleep_z
      t = data[:age]
      x = anchor_x + Math.sin((t + data[:seed]) * 0.08) * 10 + (i * 8)
      y = anchor_y - (t * 0.9 % 60)
      sprite.x = x
      sprite.y = y
      sprite.opacity = @battler_sprite.opacity * alpha
    when :poison_bubbles, :toxic_bubbles
      speed = (@style == :toxic_bubbles) ? 0.9 : 0.7
      drift = (@style == :toxic_bubbles) ? 20 : 16
      t = data[:age]
      x = anchor_x + Math.sin((t + data[:seed]) * 0.06) * drift + (i - 1) * 10
      y = anchor_y + 10 - (t * speed % 70)
      sprite.x = x
      sprite.y = y
      sprite.opacity = @battler_sprite.opacity * alpha
    when :burn_embers
      t = data[:age]
      radius = data[:radius]
      angle = data[:angle] + (t * 0.05)
      x = anchor_x + Math.cos(angle) * radius
      y = center_y + Math.sin(angle) * radius * 0.8
      y -= t * 0.5
      sprite.x = x
      sprite.y = y
      sprite.opacity = @battler_sprite.opacity * alpha
    when :freeze_flakes
      radius = 24 + (i * 12)
      angle = data[:angle]
      x = anchor_x + Math.cos(angle) * radius * 1.3
      y = center_y + Math.sin(angle) * radius * 0.8
      sprite.x = x
      sprite.y = y
      sprite.opacity = @battler_sprite.opacity * (alpha * 0.9)
    when :paralysis_sparks
      radius = 24
      angle = data[:angle]
      direction = data[:side_toggle] ? 1 : -1
      curve = Math.sin(data[:age] * 0.08) * 6
      sprite.x = anchor_x + Math.cos(angle) * radius + (direction * data[:age] * 0.2)
      sprite.y = center_y + Math.sin(angle) * radius * 0.4 + (data[:side_toggle] ? -curve : curve)
      sprite.mirror = !data[:side_toggle]
      sprite.opacity = @battler_sprite.opacity * alpha
    when :infatuation_hearts
      t = data[:age]
      side_offset = (i.even? ? -1 : 1) * 28
      x = anchor_x + side_offset + Math.sin((t + data[:seed]) * 0.07) * 8
      y = center_y - (t * 0.6 % 50) + 10
      sprite.x = x
      sprite.y = y
      sprite.opacity = @battler_sprite.opacity * alpha
    else
      data[:angle] += data[:speed]
      sprite.x = anchor_x + Math.cos(data[:angle]) * data[:radius]
      sprite.y = anchor_y + Math.sin(data[:angle]) * data[:radius] * 0.6
      sprite.opacity = @battler_sprite.opacity * alpha
    end
  end

  def particle_alpha(age, life)
    return 1.0 if life <= (FADE_IN_FRAMES + FADE_OUT_FRAMES)
    if age < FADE_IN_FRAMES
      return age.to_f / FADE_IN_FRAMES
    end
    if age > (life - FADE_OUT_FRAMES)
      return (life - age).to_f / FADE_OUT_FRAMES
    end
    return 1.0
  end
end

#===============================================================================
# Battler sprite hooks (order-independent)
#===============================================================================
module StatusParticles
  module PrependHooks
    def dispose
      if @status_particle_emitters
        @status_particle_emitters.each do |emitter|
          StatusParticles.unregister_emitter(emitter)
          emitter.dispose
        end
      end
      @status_particle_emitters = nil
      super
    end

    def update
      super
      @status_particle_emitters&.each { |e| e.update }
    end
  end

  def self.install
    return if @installed
    return if !defined?(Battle::Scene::BattlerSprite)

    Battle::Scene::BattlerSprite.class_eval do
      def status_particle_battler
        return @battler
      end

      unless method_defined?(:status_particles_initialize)
        alias_method :status_particles_initialize, :initialize
        def initialize(*args)
          status_particles_initialize(*args)
          @status_particle_emitters = []
          [:main, :confusion, :attraction].each do |type|
            emitter = StatusParticles::Emitter.new(self.viewport, self, type)
            @status_particle_emitters << emitter
            StatusParticles.register_emitter(emitter)
          end
        end
      end
    end
    
    Battle::Scene::BattlerSprite.prepend(PrependHooks) unless Battle::Scene::BattlerSprite.ancestors.include?(PrependHooks)

    if defined?(Battle::Scene)
      Battle::Scene.class_eval do
        unless method_defined?(:status_particles_pbEndBattle)
          alias_method :status_particles_pbEndBattle, :pbEndBattle
          def pbEndBattle(*args)
            StatusParticles.dispose_all
            status_particles_pbEndBattle(*args)
          end
        end

        unless method_defined?(:status_particles_pbAnimationCore)
          alias_method :status_particles_pbAnimationCore, :pbAnimationCore
          def pbAnimationCore(*args)
            # return status_particles_pbAnimationCore(*args) if StatusParticles.suppressed?
            # StatusParticles.with_suppressed { status_particles_pbAnimationCore(*args) }
            status_particles_pbAnimationCore(*args)
          end
        end

        unless method_defined?(:status_particles_pbCommonAnimation)
          alias_method :status_particles_pbCommonAnimation, :pbCommonAnimation
          def pbCommonAnimation(*args)
            # Desactivar animaciones comunes de estado para evitar superposición con partículas
            if ["Sleep", "Frozen", "Burn", "Poison", "Toxic", "Paralysis", "Confusion", "Attract"].include?(args[0])
              return
            end
            # return status_particles_pbCommonAnimation(*args) if StatusParticles.suppressed?
            # StatusParticles.with_suppressed { status_particles_pbCommonAnimation(*args) }
            status_particles_pbCommonAnimation(*args)
          end
        end
      end
    end
    @installed = true
  end
end

StatusParticles.install
TracePoint.new(:class) do |tp|
  StatusParticles.install
  tp.disable if StatusParticles.instance_variable_get(:@installed)
end.enable

EventHandlers.add(:on_end_battle, :status_particles_cleanup,
  proc { StatusParticles.dispose_all }
)

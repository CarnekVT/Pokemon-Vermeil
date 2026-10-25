# encoding: UTF-8
# Vermeil: unobtrusive clock for the unmodified Pokémon Essentials pause menu.
# Reads the SAME source as Lighting Studio (internal save clock or system time).
module VermeilPauseClock
  module_function
  def time_string
    if defined?(LightingStudioDayNight)
      hour = LightingStudioDayNight.current_hour.to_f % 24.0
      minutes = (hour * 60).floor % 1440
      return format("%02d:%02d", minutes / 60, minutes % 60)
    end
    Time.now.strftime("%H:%M")
  end
end

module VermeilPauseClockScene
  def pbStartScene
    super
    @vermeil_clock_sprite = Sprite.new(@viewport)
    @vermeil_clock_sprite.bitmap = Bitmap.new(112, 30)
    @vermeil_clock_sprite.x = 8
    @vermeil_clock_sprite.y = 8
    @vermeil_clock_sprite.z = 20
    @vermeil_clock_last = nil
    vermeil_refresh_clock
  end

  def vermeil_refresh_clock
    return unless @vermeil_clock_sprite && !@vermeil_clock_sprite.disposed?
    value = VermeilPauseClock.time_string
    return if value == @vermeil_clock_last
    @vermeil_clock_last = value
    bmp = @vermeil_clock_sprite.bitmap
    bmp.clear
    bmp.fill_rect(0, 0, 112, 30, Color.new(12, 20, 34, 200))
    bmp.fill_rect(2, 2, 108, 26, Color.new(35, 52, 72, 220))
    pbSetSystemFont(bmp)
    pbDrawTextPositions(bmp, [[_INTL("Hora"), 9, 7, 0, Color.new(170, 207, 232), Color.new(15, 22, 32)],
                              [value, 104, 7, 1, Color.new(255, 242, 196), Color.new(15, 22, 32)]])
  end

  def pbShowCommands(commands)
    # The original menu owns the loop. Its Window_CommandPokemon#update is
    # already called every frame; attach the minute refresh to that window
    # only while the pause scene exists rather than replacing the vanilla UI.
    @sprites["cmdwindow"].instance_variable_set(:@vermeil_pause_clock_owner, self)
    super
  ensure
    @sprites["cmdwindow"].instance_variable_set(:@vermeil_pause_clock_owner, nil) if @sprites && @sprites["cmdwindow"]
  end

  def pbEndScene
    @vermeil_clock_sprite.bitmap.dispose if @vermeil_clock_sprite && !@vermeil_clock_sprite.bitmap.disposed?
    @vermeil_clock_sprite.dispose if @vermeil_clock_sprite && !@vermeil_clock_sprite.disposed?
    @vermeil_clock_sprite = nil
    super
  end
end

module VermeilPauseClockWindowUpdate
  def update(*args)
    result = super
    owner = instance_variable_get(:@vermeil_pause_clock_owner)
    owner.vermeil_refresh_clock if owner
    result
  end
end

PokemonPauseMenu_Scene.prepend(VermeilPauseClockScene) unless
  PokemonPauseMenu_Scene.ancestors.include?(VermeilPauseClockScene)
Window_CommandPokemon.prepend(VermeilPauseClockWindowUpdate) unless
  Window_CommandPokemon.ancestors.include?(VermeilPauseClockWindowUpdate)

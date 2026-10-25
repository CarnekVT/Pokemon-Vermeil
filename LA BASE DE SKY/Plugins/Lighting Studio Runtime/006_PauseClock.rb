# encoding: UTF-8
# Vermeil: a small pause-menu clock positioned BELOW the vanilla location sign.
# Uses the same saved internal time or system clock selected in Lighting Studio.
module VermeilPauseClock
  WIDTH = 146
  HEIGHT = 34
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
    @vermeil_clock_sprite.bitmap = Bitmap.new(VermeilPauseClock::WIDTH, VermeilPauseClock::HEIGHT)
    @vermeil_clock_sprite.z = 20
    @vermeil_clock_last = nil
    vermeil_layout_clock
    vermeil_refresh_clock
  end

  # Location signs are created AFTER pbStartScene by the vanilla pause menu.
  # Keep our widget directly underneath instead of covering the map name.
  def pbShowLocationSign
    result = super
    vermeil_layout_clock
    result
  end

  def vermeil_layout_clock
    sprite = @vermeil_clock_sprite
    return unless sprite && !sprite.disposed?
    location = @sprites && @sprites["location"]
    if location && !location.disposed?
      x = location.respond_to?(:x) ? location.x + 4 : 8
      top = location.respond_to?(:y) ? location.y : 8
      height = location.respond_to?(:height) ? location.height : 54
      y = top + height + 5
    else
      x = 8
      y = 8
    end
    sprite.x = [[x.to_i, 0].max, [Graphics.width - VermeilPauseClock::WIDTH, 0].max].min
    sprite.y = [[y.to_i, 0].max, [Graphics.height - VermeilPauseClock::HEIGHT, 0].max].min
  end

  def vermeil_refresh_clock
    sprite = @vermeil_clock_sprite
    return unless sprite && !sprite.disposed?
    vermeil_layout_clock
    value = VermeilPauseClock.time_string
    return if value == @vermeil_clock_last
    @vermeil_clock_last = value
    bmp = sprite.bitmap
    bmp.clear
    # Quiet gray card, visually close to the vanilla location sign.
    bmp.fill_rect(0, 0, 146, 34, Color.new(52, 61, 79, 225))
    bmp.fill_rect(2, 2, 142, 30, Color.new(216, 221, 218, 245))
    bmp.fill_rect(4, 4, 138, 26, Color.new(188, 198, 195, 245))
    pbSetSystemFont(bmp)
    bmp.font.size = 20
    label = _INTL("Hora") + "  " + value
    bmp.font.color = Color.new(240, 244, 239)
    bmp.draw_text(1, 5, 146, 25, label, 1)
    bmp.font.color = Color.new(38, 49, 61)
    bmp.draw_text(0, 4, 146, 25, label, 1)
  end

  def pbShowMenu
    super
    @vermeil_clock_sprite.visible = true if @vermeil_clock_sprite && !@vermeil_clock_sprite.disposed?
  end

  def pbHideMenu
    super
    @vermeil_clock_sprite.visible = false if @vermeil_clock_sprite && !@vermeil_clock_sprite.disposed?
  end

  def pbShowCommands(commands)
    # Refresh at minute changes without modifying the vanilla menu input loop.
    @sprites["cmdwindow"].instance_variable_set(:@vermeil_pause_clock_owner, self)
    super
  ensure
    @sprites["cmdwindow"].instance_variable_set(:@vermeil_pause_clock_owner, nil) if @sprites && @sprites["cmdwindow"]
  end

  def pbEndScene
    if @vermeil_clock_sprite && !@vermeil_clock_sprite.disposed?
      bitmap = @vermeil_clock_sprite.bitmap
      @vermeil_clock_sprite.dispose
      bitmap.dispose if bitmap && !bitmap.disposed?
    end
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

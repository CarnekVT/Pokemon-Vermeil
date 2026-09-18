class Spriteset_Global
  attr_reader :playersprite

  # Igual que en Spriteset_Map: lazy init para que los plugins puedan modificar
  # Settings::SCREEN_WIDTH/HEIGHT antes de la creación del viewport.
  @@viewport2 = nil

  def self.ensure_viewport
    if !@@viewport2 || @@viewport2.disposed?
      @@viewport2 = Viewport.new(0, 0, Settings::SCREEN_WIDTH, Settings::SCREEN_HEIGHT)
      @@viewport2.z = 200
    end
  end

  def initialize
    self.class.ensure_viewport
    @map_id = $game_map&.map_id || 0
    @follower_sprites = FollowerSprites.new(Spriteset_Map.viewport)
    @playersprite = Sprite_Character.new(Spriteset_Map.viewport, $game_player)
    @weather = RPG::Weather.new(Spriteset_Map.viewport)
    @picture_sprites = []
    @active_picture_sprites = {}
    (1..100).each do |i|
      picture = $game_screen.pictures[i]
      sprite = Sprite_Picture.new(@@viewport2, picture)
      @picture_sprites.push(sprite)
      if picture.name != ""
        sprite.update
        @active_picture_sprites[i] = sprite
      end
    end
    # El bucle anterior ya ha sincronizado los 100 sprites con el estado actual
    # de las pictures, asi que cualquier marca pendiente sobra.
    Game_Picture.changed_picture_numbers.clear
    @timer_sprite = Sprite_Timer.new
    update
  end

  def dispose
    @follower_sprites.dispose
    @follower_sprites = nil
    @playersprite.dispose
    @playersprite = nil
    @weather.dispose
    @weather = nil
    @picture_sprites.each { |sprite| sprite.dispose }
    @picture_sprites.clear
    @active_picture_sprites.clear
    @timer_sprite.dispose
    @timer_sprite = nil
  end

  def update
    @follower_sprites.update
    @playersprite.update
    if @weather.type != $game_screen.weather_type
      @weather.fade_in($game_screen.weather_type, $game_screen.weather_max, $game_screen.weather_duration)
    end
    if @map_id != $game_map.map_id
      offsets = $map_factory.getRelativePos(@map_id, 0, 0, $game_map.map_id, 0, 0)
      if offsets == [0, 0]
        @weather.ox_offset = 0
        @weather.oy_offset = 0
      else
        @weather.ox_offset += offsets[0] * Game_Map::TILE_WIDTH
        @weather.oy_offset += offsets[1] * Game_Map::TILE_HEIGHT
      end
      @map_id = $game_map.map_id
    end
    @weather.ox = ($game_map.display_x / Game_Map::X_SUBPIXELS).round
    @weather.oy = ($game_map.display_y / Game_Map::Y_SUBPIXELS).round
    @weather.update
    changed_pictures = Game_Picture.changed_picture_numbers
    changed_pictures.each_key do |number|
      sprite = @picture_sprites[number - 1]
      next if !sprite
      sprite.update
      if sprite.picture.name == ""
        @active_picture_sprites.delete(number)
      else
        @active_picture_sprites[number] = sprite
      end
    end
    @active_picture_sprites.each do |number, sprite|
      sprite.update if !changed_pictures.key?(number)
    end
    changed_pictures.clear
    @timer_sprite.update
  end
end

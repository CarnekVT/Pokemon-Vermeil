#===============================================================================
# VIBRANT COMPANIONS - ARTIFICIAL INTELLIGENCE
#===============================================================================

module VibrantCompanions
  module Emotes
    IDS = {
      Exclamation: 3, Question: 4, Heart: 9, Happy: 10,
      Smile: 11, Music: 12, Ellipsis: 13, Sad: 14,
      Mad: 15, Angry: 16, Poison: 17
    }

    def self.show(event, type)
      anim_id = IDS[type] || 0
      return if anim_id == 0
      event.animation_id = anim_id
    end
  end

  module AI
    def self.update
      # Usamos variables de instancia del módulo en lugar de variables de clase (@@)
      @idle_timer ||= 0.0
      @wander_timer ||= 0.0

      return if $game_temp.in_menu || $game_temp.message_window_showing
      follower = $game_temp.followers.get_follower_by_name("VibrantFollower_0")
      return unless follower && follower.is_a?(Game_PokemonFollower)
      return if follower.move_route_forcing 

      player = $game_player
      dist = (follower.x - player.x).abs + (follower.y - player.y).abs
      player_moving = player.moving? || Input.dir4 != 0
      dt = Graphics.delta

      case follower.vibrant_state
      
      when :following
        if player_moving
          @idle_timer = 0.0
        elsif Settings.enable_wandering?
          @idle_timer += dt
          if @idle_timer > Settings::IDLE_START_TIME
            follower.vibrant_state = :wandering
            follower.force_speed([player.move_speed - 1, 2].max)
            @wander_timer = 0.0
          end
        end

      when :wandering
        if player_moving || dist > Settings::WANDER_RADIUS + 1
          follower.vibrant_state = :returning
          Emotes.show(follower, :Exclamation)
          follower.force_speed([player.move_speed + 1, 5].min)
        else
          @wander_timer += dt
          if !follower.moving? && @wander_timer >= Settings::WANDER_STEP_DELAY
            @wander_timer = 0.0
            if dist < Settings::WANDER_RADIUS
              follower.move_random
            else
              follower.turn_toward_player
              follower.move_toward_player if rand(2) == 0
            end
            if rand(100) < 10
              Emotes.show(follower, [:Ellipsis, :Smile, :Question, :Music].sample)
            end
          end
        end

      when :returning
        if dist > 8
          follower.moveto(player.x, player.y)
          follower.vibrant_state = :following
          @idle_timer = 0.0
        elsif dist <= 1 && !follower.moving?
          follower.vibrant_state = :following
          follower.force_speed(player.move_speed)
          follower.turn_toward_player
          @idle_timer = 0.0
        elsif !follower.moving?
          follower.move_toward_player
        end
      end
    end

    def self.get_random_item
      total_weight = Settings::GATHER_ITEMS.values.sum
      random = rand(total_weight)
      Settings::GATHER_ITEMS.each do |item, weight|
        return item if random < weight
        random -= weight
      end
      return Settings::GATHER_ITEMS.keys.first
    end

    def self.check_item_gathering
      return unless Manager.toggled?
      return unless Settings.enable_item_gathering?
      
      state = Manager.save_data
      state.steps += 1
      
      if state.steps >= Settings::ITEM_STEP_THRESHOLD
        state.steps = 0
        if state.holding_item.nil? && rand(100) < Settings::ITEM_CHANCE
          state.holding_item = get_random_item
          follower = $game_temp.followers.get_follower_by_name("VibrantFollower_0")
          Emotes.show(follower, :Music) if follower
        end
      end
    end
  end
end

EventHandlers.add(:on_frame_update, :vibrant_ai_loop, proc {
  VibrantCompanions::AI.update
})

# Deja este bloque así en el Módulo 3:
EventHandlers.add(:on_player_step_taken, :vibrant_item_gathering, proc {
  VibrantCompanions::AI.check_item_gathering
})


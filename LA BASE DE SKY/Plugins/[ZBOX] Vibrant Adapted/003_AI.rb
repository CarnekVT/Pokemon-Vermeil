# encoding: utf-8
#===============================================================================
# [ZBOX] Vibrant Adapted — AI & Emotes
#===============================================================================

module VibrantAdapted
  #=============================================================================
  # Emotes
  #=============================================================================
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

  #=============================================================================
  # PhysicalEmotes
  #=============================================================================
  module PhysicalEmotes
    def self.play(event, type)
      return unless VibrantAdapted::Settings::ENABLE_PHYSICAL_EMOTES
      return unless event

      case type
      when :shiver
        pbMoveRoute(event, [
          PBMoveRoute::TURN_RIGHT, PBMoveRoute::WAIT, 2,
          PBMoveRoute::TURN_LEFT, PBMoveRoute::WAIT, 2,
          PBMoveRoute::TURN_RIGHT, PBMoveRoute::WAIT, 2,
          PBMoveRoute::TURN_LEFT, PBMoveRoute::WAIT, 2,
          PBMoveRoute::TURN_TOWARD_PLAYER
        ])
      when :jump_happy
        pbMoveRoute(event, [
          PBMoveRoute::JUMP, 0, 0, PBMoveRoute::WAIT, 10,
          PBMoveRoute::JUMP, 0, 0
        ])
      when :spin
        pbMoveRoute(event, [
          PBMoveRoute::TURN_RIGHT90, PBMoveRoute::WAIT, 4,
          PBMoveRoute::TURN_RIGHT90, PBMoveRoute::WAIT, 4,
          PBMoveRoute::TURN_RIGHT90, PBMoveRoute::WAIT, 4,
          PBMoveRoute::TURN_RIGHT90, PBMoveRoute::WAIT, 4,
          PBMoveRoute::TURN_TOWARD_PLAYER
        ])
      when :look_around
        pbMoveRoute(event, [
          PBMoveRoute::TURN_RIGHT90, PBMoveRoute::WAIT, 15,
          PBMoveRoute::TURN180, PBMoveRoute::WAIT, 15,
          PBMoveRoute::TURN_TOWARD_PLAYER
        ])
      when :step_back
        back_dir = 10 - $game_player.direction
        tx = event.x + (back_dir == 6 ? 1 : back_dir == 4 ? -1 : 0)
        ty = event.y + (back_dir == 2 ? 1 : back_dir == 8 ? -1 : 0)
        if $game_map.passable?(event.x, event.y, back_dir, event) &&
           !VibrantAdapted::Settings.water_tile?(tx, ty)
          pbMoveRoute(event, [
            PBMoveRoute::BACKWARD, PBMoveRoute::WAIT, 10,
            PBMoveRoute::FORWARD
          ])
        end
      when :love_rub
        fwd_dir = $game_player.direction
        tx = event.x + (fwd_dir == 6 ? 1 : fwd_dir == 4 ? -1 : 0)
        ty = event.y + (fwd_dir == 2 ? 1 : fwd_dir == 8 ? -1 : 0)
        if $game_map.passable?(event.x, event.y, fwd_dir, event) &&
           !VibrantAdapted::Settings.water_tile?(tx, ty)
          pbMoveRoute(event, [
            PBMoveRoute::FORWARD, PBMoveRoute::WAIT, 15,
            PBMoveRoute::BACKWARD
          ])
        end
      end
    end
  end

  #=============================================================================
  # AI — wandering (activatable desde opciones)
  #=============================================================================
  module AI
    def self.update
      @idle_timer  ||= 0.0
      @wander_timer ||= 0.0

      return if $game_temp.in_menu || $game_temp.message_window_showing
      follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
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
        elsif VibrantAdapted::Settings.enable_wandering?
          @idle_timer += dt
          if @idle_timer > VibrantAdapted::Settings::IDLE_START_TIME
            follower.vibrant_state = :wandering
            follower.move_speed = [player.move_speed - 1, 2].max
            @wander_timer = 0.0
          end
        end

      when :wandering
        if player_moving || dist > VibrantAdapted::Settings::WANDER_RADIUS + 1
          follower.vibrant_state = :returning
          Emotes.show(follower, :Exclamation)
          follower.move_speed = [player.move_speed + 1, 5].min
        else
          @wander_timer += dt
          if !follower.moving? && @wander_timer >= VibrantAdapted::Settings::WANDER_STEP_DELAY
            @wander_timer = 0.0
            if dist < VibrantAdapted::Settings::WANDER_RADIUS
              dirs = [2, 4, 6, 8].select { |d|
                tx = follower.x + (d == 6 ? 1 : d == 4 ? -1 : 0)
                ty = follower.y + (d == 2 ? 1 : d == 8 ? -1 : 0)
                $game_map.passable?(follower.x, follower.y, d, follower) &&
                !VibrantAdapted::Settings.water_tile?(tx, ty)
              }
              pbTurnTowardEvent(follower, $game_player) if dirs.empty?
              follower.move_random unless dirs.empty?
            else
              pbTurnTowardEvent(follower, $game_player)
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
          follower.move_speed = player.move_speed
          pbTurnTowardEvent(follower, $game_player)
          @idle_timer = 0.0
        elsif !follower.moving?
          dx = (player.x - follower.x).clamp(-1, 1)
          dy = (player.y - follower.y).clamp(-1, 1)
          dirs = []
          dirs << (dy > 0 ? 2 : 8) if dy != 0
          dirs << (dx > 0 ? 6 : 4) if dx != 0
          can_move = dirs.any? { |d|
            tx = follower.x + (d == 6 ? 1 : d == 4 ? -1 : 0)
            ty = follower.y + (d == 2 ? 1 : d == 8 ? -1 : 0)
            $game_map.passable?(follower.x, follower.y, d, follower) &&
            !VibrantAdapted::Settings.water_tile?(tx, ty)
          }
          can_move ? follower.move_toward_player : pbTurnTowardEvent(follower, $game_player)
        end
      end
    end
  end
end

EventHandlers.add(:on_frame_update, :va_ai_loop, proc {
  VibrantAdapted::AI.update
})

#===============================================================================
# Stored in $stats
#===============================================================================
class GameStats
  # Play
  attr_reader   :real_time_saved
  attr_accessor :save_filename_number   # -1 if haven't saved yet

  def initialize
    # Travel
    @distance_walked               = 0
    @distance_cycled               = 0
    @distance_surfed               = 0
    @distance_slid_on_ice          = 0
    @bump_count                    = 0
    @cycle_count                   = 0
    @surf_count                    = 0
    @dive_count                    = 0
    # Field actions
    @fly_count                     = 0
    @cut_count                     = 0
    @flash_count                   = 0
    @rock_smash_count              = 0
    @rock_smash_battles            = 0
    @headbutt_count                = 0
    @headbutt_battles              = 0
    @strength_push_count           = 0
    @waterfall_count               = 0
    @waterfalls_descended          = 0
    # Items
    @repel_count                   = 0
    @itemfinder_count              = 0
    @fishing_count                 = 0
    @fishing_battles               = 0
    @poke_radar_count              = 0
    @poke_radar_longest_chain      = 0
    @berry_plants_picked           = 0
    @max_yield_berry_plants        = 0
    @berries_planted               = 0
    # NPCs
    @poke_center_count             = 0   # Incremented in Poké Center nurse events
    @revived_fossil_count          = 0   # Incremented in fossil reviver events
    @lottery_prize_count           = 0   # Incremented in lottery NPC events
    # Pokémon
    @eggs_hatched                  = 0
    @evolution_count               = 0
    @evolutions_cancelled          = 0
    @trade_count                   = 0
    @pokemon_release_count         = 0
    @moves_taught_by_item          = 0
    @moves_taught_by_tutor         = 0
    @moves_taught_by_reminder      = 0
    @day_care_deposits             = 0
    @day_care_levels_gained        = 0
    @pokerus_infections            = 0
    @shadow_pokemon_purified       = 0
    # Battles
    @wild_battles_won              = 0
    @wild_battles_lost             = 0
    @wild_battles_fled             = 0
    @trainer_battles_won           = 0
    @trainer_battles_lost          = 0
    @total_exp_gained              = 0
    @battle_money_gained           = 0
    @battle_money_lost             = 0
    @blacked_out_count             = 0
    @mega_evolution_count          = 0
    @primal_reversion_count        = 0
    @failed_poke_ball_count        = 0
    # Currency
    @money_spent_at_marts          = 0
    @money_earned_at_marts         = 0
    @mart_items_bought             = 0
    @premier_balls_earned          = 0
    @drinks_bought                 = 0   # Incremented in vending machine events
    @drinks_won                    = 0   # Incremented in vending machine events
    @coins_won                     = 0
    @coins_lost                    = 0
    @battle_points_won             = 0
    @battle_points_spent           = 0
    @soot_collected                = 0
    # Special stats
    @gym_leader_attempts           = [0] * 50   # Incremented in Gym Leader events (50 is arbitrary but suitably large)
    @times_to_get_badges           = []   # Set with set_time_to_badge(number) in Gym Leader events
    @elite_four_attempts           = 0   # Incremented in door event leading to the first E4 member
    @hall_of_fame_entry_count      = 0   # Incremented in Hall of Fame event
    @time_to_enter_hall_of_fame    = 0   # Set with set_time_to_hall_of_fame in Hall of Fame event
    @safari_pokemon_caught         = 0
    @most_captures_per_safari_game = 0
    @bug_contest_count             = 0
    @bug_contest_wins              = 0
    # Play
    @play_time                     = 0
    @play_sessions                 = 0
    @time_last_saved               = 0
    @real_time_saved               = 0
    @save_filename_number          = -1
  end

  # For looking at a save file's play time.
  def real_play_time
    return @play_time
  end

  def play_time_per_session
    return play_time / @play_sessions
  end

  def set_time_last_saved
    @time_last_saved = play_time
    @real_time_saved = Time.now.to_i
  end

  def time_since_last_save
    return play_time - @time_last_saved
  end
end


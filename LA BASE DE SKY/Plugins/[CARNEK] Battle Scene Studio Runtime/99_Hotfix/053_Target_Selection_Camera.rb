# frozen_string_literal: true
# Pokémon Essentials 21.1: pbChooseTarget selects indices 0,2,4 (player)
# and 1,3,5 (opponents), and calls pbSelectBattler on each cursor change.
# Use ONE EBDX world vector; the selected Pokemon and its shadow remain
# projectively aligned because this does not touch any sprite's x/y/zoom.
module BSSTargetMenuCamera
  def pbChooseTarget(*args,&block)
    return super unless respond_to?(:vermeil_cinema_active?) && vermeil_cinema_active?
    @bss_target_select_depth=@bss_target_select_depth.to_i+1
    @bss_selected_target_index=nil
    @vermeil_cinema_last_shot=nil
    result=super
    if result.is_a?(Integer) && result>=0
      # The move should start from default MAIN, not the target preview.
      vermeil_cinema_return_main(9) if respond_to?(:vermeil_cinema_return_main)
    end
    result
  ensure
    if @bss_target_select_depth.to_i>0
      @bss_target_select_depth-=1
      @bss_selected_target_index=nil
      @vermeil_cinema_last_shot=nil
    end
  end

  def pbSelectBattler(*args,&block)
    result=super
    if @bss_target_select_depth.to_i>0 && args[0].is_a?(Integer) && args[0]>=0
      idx=args[0]
      selected=(@battle.battlers[idx] rescue nil)
      if selected && !(selected.fainted? rescue true)
        @bss_selected_target_index=idx
        @vermeil_cinema_last_shot=nil
        if respond_to?(:vermeil_cinema_focus_vector) && respond_to?(:vermeil_cinema_acquire_shot)
          vermeil_cinema_acquire_shot(vermeil_cinema_focus_vector(idx))
        end
      end
    end
    result
  end
end

if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSSTargetMenuCamera)
  Battle::Scene.prepend(BSSTargetMenuCamera)
end

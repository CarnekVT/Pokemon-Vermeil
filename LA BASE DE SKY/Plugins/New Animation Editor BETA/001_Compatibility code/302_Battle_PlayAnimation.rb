#===============================================================================
#
#===============================================================================
class Battle::Scene
  ANIMATION_DEFAULTS = [:TACKLE, :DEFENSECURL]   # With target, without target
  ANIMATION_DEFAULTS_FOR_TYPE_CATEGORY = {
    :NORMAL   => [:TACKLE,       :SONICBOOM,    :DEFENSECURL, :BODYSLAM,   nil,            :TAILWHIP],
    :FIGHTING => [:MACHPUNCH,    :AURASPHERE,   :BULKUP,      nil,         nil,            nil],
    :FLYING   => [:WINGATTACK,   :GUST,         :ROOST,       nil,         :AIRCUTTER,     :FEATHERDANCE],
    :POISON   => [:POISONSTING,  :SLUDGE,       :ACIDARMOR,   nil,         :ACID,          :POISONPOWDER],
    :GROUND   => [:SANDTOMB,     :MUDSLAP,      :MUDSPORT,    :EARTHQUAKE, :EARTHPOWER,    :SANDATTACK],
    :ROCK     => [:ROCKTHROW,    :POWERGEM,     :ROCKPOLISH,  :ROCKSLIDE,  nil,            :SANDSTORM],
    :BUG      => [:TWINEEDLE,    :BUGBUZZ,      :QUIVERDANCE, nil,         :STRUGGLEBUG,   :STRINGSHOT],
    :GHOST    => [:ASTONISH,     :SHADOWBALL,   :GRUDGE,      nil,         nil,            :CONFUSERAY],
    :STEEL    => [:IRONHEAD,     :MIRRORSHOT,   :IRONDEFENSE, nil,         nil,            :METALSOUND],
    :FIRE     => [:FIREPUNCH,    :EMBER,        :SUNNYDAY,    nil,         :INCINERATE,    :WILLOWISP],
    :WATER    => [:CRABHAMMER,   :WATERGUN,     :AQUARING,    nil,         :SURF,          :WATERSPORT],
    :GRASS    => [:VINEWHIP,     :RAZORLEAF,    :COTTONGUARD, nil,         nil,            :SPORE],
    :ELECTRIC => [:THUNDERPUNCH, :THUNDERSHOCK, :CHARGE,      nil,         :DISCHARGE,     :THUNDERWAVE],
    :PSYCHIC  => [:ZENHEADBUTT,  :CONFUSION,    :CALMMIND,    nil,         :SYNCHRONOISE,  :MIRACLEEYE],
    :ICE      => [:ICEPUNCH,     :ICEBEAM,      :MIST,        :AVALANCHE,  :POWDERSNOW,    :HAIL],
    :DRAGON   => [:DRAGONCLAW,   :DRAGONRAGE,   :DRAGONDANCE, nil,         :TWISTER,       nil],
    :DARK     => [:KNOCKOFF,     :DARKPULSE,    :HONECLAWS,   nil,         :SNARL,         :EMBARGO],
    :FAIRY    => [:TACKLE,       :FAIRYWIND,    :MOONLIGHT,   nil,         :DAZZLINGGLEAM, :SWEETKISS]
  }

  #-----------------------------------------------------------------------------
  # Loads a move animation.
  #-----------------------------------------------------------------------------

  # Returns an array of GameData::Animation if a new animation(s) is found.
  # Return [animation index, shouldn't be flipped] if an old animation is found.
  def find_move_animation(move_id, version, user_index)
    # Get animation
    anims = find_move_animation_for_move(move_id, version, user_index)
    return anims if anims
    # Get information to decide which default animation to try
    if move_id == :STRUGGLE && !GameData::Move.exists?(move_id)
      target_data = GameData::Target.get(@battle.struggle.target)
      move_type = @battle.struggle.type
      default_idx = @battle.struggle.category
      status = @battle.struggle.statusMove?
    else
      move_data = GameData::Move.get(move_id)
      target_data = GameData::Target.get(move_data.target)
      move_type = move_data.type
      default_idx = move_data.category
      status = move_data.status?
    end
    # Check for a default animation
    if move_type
      default_idx += 3 if target_data.num_targets > 1 ||
                          (target_data.num_targets > 0 && status)
      wanted_move = ANIMATION_DEFAULTS_FOR_TYPE_CATEGORY[move_type][default_idx]
      anims = find_move_animation_for_move(wanted_move, 0, user_index)
      return anims if anims
      if default_idx >= 3
        wanted_move = ANIMATION_DEFAULTS_FOR_TYPE_CATEGORY[move_type][default_idx - 3]
        anims = find_move_animation_for_move(wanted_move, 0, user_index)
        return anims if anims
        return nil if ANIMATION_DEFAULTS.include?(wanted_move)   # No need to check for these animations twice
      end
    end
    # Use Tackle or Defense Curl's animation
    if target_data.num_targets == 0 && target_data.id != :None
      return find_move_animation_for_move(ANIMATION_DEFAULTS[1], 0, user_index)
    end
    return find_move_animation_for_move(ANIMATION_DEFAULTS[0], 0, user_index)
  end

  # Find an animation(s) for the given move_id.
  def find_move_animation_for_move(move_id, version, user_index)
    # Find new animation
    anims = try_get_better_move_animation(move_id, version, user_index)
    return anims if anims
    if version > 0
      anims = try_get_better_move_animation(move_id, 0, user_index)
      return anims if anims
    end
    # Find old animation
    anim = pbFindMoveAnimDetails(move_id, user_index, version)
    return anim
  end

  # Finds a new animation for the given move_id and version. Prefers opposing
  # animations if the user is opposing. Can return multiple animations.
  def try_get_better_move_animation(move_id, version, user_index)
    ret = []
    backup_ret = []
    GameData::Animation.each do |anim|
      next if !anim.move_animation? || anim.ignore
      next if anim.move != move_id.to_s
      next if anim.version != version
      if !user_index
        ret.push(anim)
        next
      end
      if user_index.even?   # User is on player's side
        ret.push(anim) if !anim.opposing_animation?
      else                  # User is on opposing side
        (anim.opposing_animation?) ? ret.push(anim) : backup_ret.push(anim)
      end
    end
    return ret if !ret.empty?
    return backup_ret if !backup_ret.empty?
    return nil
  end

  # Returns the animation ID to use for a given move/user. Returns nil if that
  # move has no animations defined for it.
  def pbFindMoveAnimDetails(moveID, idxUser, hitNum = 0)
    real_move_id = GameData::Move.try_get(moveID)&.id || moveID
    anims = pbLoadBattleAnimations
    return nil if !anims
    anim_id = -1
    foe_anim_id = -1
    no_flip = false
    anims.length.times do |i|
      next if !anims[i]
      if anims[i].name[/^OppMove\:\s*(.*)$/]
        if GameData::Move.exists?($~[1])
          moveid = GameData::Move.get($~[1]).id
          foe_anim_id = i if moveid == real_move_id
        end
      elsif anims[i].name[/^Move\:\s*(.*)$/]
        if GameData::Move.exists?($~[1])
          moveid = GameData::Move.get($~[1]).id
          anim_id = i if moveid == real_move_id
        end
      end
    end
    if (idxUser & 1) == 0   # On player's side
      anim = anim_id
    else                # On opposing side
      anim = foe_anim_id
      no_flip = true if anim >= 0
      anim = anim_id if anim < 0
    end
    return [anim + hitNum, no_flip] if anim >= 0
    return nil
  end

  #-----------------------------------------------------------------------------
  # Loads a common animation.
  #-----------------------------------------------------------------------------

  def try_get_better_common_animation(anim_name, user_index)
    # Find a new format common animation to play
    ret = []
    backup_ret = []
    GameData::Animation.each do |anim|
      next if !anim.common_animation? || anim.ignore
      next if anim.move != anim_name
      if !user_index
        ret.push(anim)
        next
      end
      if user_index.even?   # User is on player's side
        ret.push(anim) if !anim.opposing_animation?
      else                  # User is on opposing side
        (anim.opposing_animation?) ? ret.push(anim) : backup_ret.push(anim)
      end
    end
    return ret if !ret.empty?
    return backup_ret if !backup_ret.empty?
    # Find an old format common animation to play
    target = target[0] if target.is_a?(Array)
    animations = pbLoadBattleAnimations
    return nil if !animations
    animations.each do |anim|
      next if !anim || anim.name != "Common:" + anim_name
      ret = anim
      break
    end
    return ret
  end

  #-----------------------------------------------------------------------------
  # Plays a move/common animation.
  #-----------------------------------------------------------------------------

  # Plays a move animation.
  def pbAnimation(move_id, user, targets, version = 0)
    anims = find_move_animation(move_id, version, user&.index)
    return if !anims || anims.empty?
    if anims[0].is_a?(GameData::Animation)   # New format animation
      pbSaveShadows do
        # NOTE: anims.sample is a random valid animation.
        play_better_animation(anims.sample, user, targets)
      end
    else                                     # Old format animation
      anim = anims[0]
      target = (targets.is_a?(Array)) ? targets[0] : targets
      animations = pbLoadBattleAnimations
      return if !animations
      pbSaveShadows do
        if anims[1]   # On opposing side and using OppMove animation
          pbAnimationCore(animations[anim], target, user, true)
        else           # On player's side, and/or using Move animation
          pbAnimationCore(animations[anim], user, target)
        end
      end
    end
  end

  # Plays a common animation.
  def pbCommonAnimation(anim_name, user = nil, target = nil)
    return if nil_or_empty?(anim_name)
    # Find an animation to play (new format or old format)
    anims = try_get_better_common_animation(anim_name, user&.index)
    return if !anims
    # Play a new format animation
    if anims.is_a?(Array)
      # NOTE: anims.sample is a random valid animation.
      play_better_animation(anims.sample, user, target)
      return
    end
    # Play an old format animation
    target = target[0] if target.is_a?(Array)
    pbAnimationCore(anims, user, target || user)
  end

  #-----------------------------------------------------------------------------

  def play_better_animation(anim_data, user, targets)
    return if !anim_data
    @briefMessage = false
    # Memorize old battler coordinates, to be reset after the animation
    old_battler_coords = []
    if user
      sprite = @sprites["pokemon_#{user.index}"]
      old_battler_coords[user.index] = [sprite.x, sprite.y]
    end
    if targets
      targets = [targets] if !targets.is_a?(Array)
      targets.each do |target|
        sprite = @sprites["pokemon_#{target.index}"]
        old_battler_coords[target.index] = [sprite.x, sprite.y]
      end
    end
    # Memorize data box visibilities
    old_data_box_visibilities = {}
    @battle.battlers.each_with_index do |b, i|
      next if !@sprites["dataBox_#{i}"]
      old_data_box_visibilities[i] = @sprites["dataBox_#{i}"].visible
      @sprites["dataBox_#{i}"].visible = false if anim_data.hides_data_boxes
    end
    # Create animation player
    anim_player = AnimationPlayer.new(anim_data, user, targets, self)
    anim_player.set_up
    # Play animation
    anim_player.start
    loop do
      pbUpdate
      anim_player.update
      break if anim_player.can_continue_battle?
    end
    anim_player.dispose
    # Restore old battler coordinates
    old_battler_coords.each_with_index do |values, i|
      next if !values
      sprite = @sprites["pokemon_#{i}"]
      sprite.x = values[0]
      sprite.y = values[1]
      if sprite.pattern
        sprite.pattern.dispose
        sprite.pattern = nil
      end
    end
    # Restore data box visibilities
    old_data_box_visibilities.each_pair do |index, val|
      @sprites["dataBox_#{index}"].visible = val
    end
  end
end

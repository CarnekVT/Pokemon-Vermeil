#===============================================================================
# [VERMEIL] Fast Status Animations
# 001_Animation_Dispatcher.rb
#
# NOTE: We do NOT override pbAnimation here because DBK rewrites it
# and the alias chain breaks. Instead, the actual pause is caused by
# the COMMON animations and STATUS infliction animations that fire
# AFTER the move animation. Those are handled by 002 and 003.
#
# The move animation itself (Spore, Growth, etc.) plays as defined
# in the NAE/old system. The blocking calls we eliminate are:
#   1. pbCommonAnimation("StatUp"/"StatDown") in pbRaiseStatStage
#   2. pbCommonAnimation(status_name) in pbInflictStatus
#   3. pbCommonAnimation("LeechSeed") in end-of-round
#
# This reduces status moves from ~3 blocking calls to 1.
#===============================================================================

class Battle::Scene
  SKIP_COMMON_ANIMATIONS = [
    "Sleep", "Sleeping", "Poison", "Toxic",
    "Burn", "Paralysis", "Freeze", "Frozen",
    "Confusion", "LeechSeed", "Leech Seed",
    "SnapTrap", "Snap Trap", "Curse",
  ].freeze

  FAST_COMMON_ANIMATIONS = [
    "StatUp", "StatDown", "HealthUp", "HealthDown",
  ].freeze

  TYPE_FLASH_COLORS = {
    :NORMAL   => Color.new(168, 168, 120),
    :FIGHTING => Color.new(192, 48, 40),
    :FLYING   => Color.new(168, 144, 240),
    :POISON   => Color.new(160, 64, 160),
    :GROUND   => Color.new(224, 192, 112),
    :ROCK     => Color.new(184, 160, 56),
    :BUG      => Color.new(168, 184, 32),
    :GHOST    => Color.new(112, 88, 152),
    :STEEL    => Color.new(184, 184, 208),
    :FIRE     => Color.new(248, 128, 48),
    :WATER    => Color.new(104, 144, 240),
    :GRASS    => Color.new(120, 200, 80),
    :ELECTRIC => Color.new(248, 208, 48),
    :PSYCHIC  => Color.new(248, 88, 136),
    :ICE      => Color.new(152, 216, 216),
    :DRAGON   => Color.new(112, 56, 248),
    :DARK     => Color.new(112, 88, 72),
    :FAIRY    => Color.new(238, 153, 172),
  }.freeze

  alias_method :_vermeil_fast_status_orig_pbCommonAnimation, :pbCommonAnimation
  def pbCommonAnimation(anim_name, user = nil, targets = nil)
    return if nil_or_empty?(anim_name)
    if SKIP_COMMON_ANIMATIONS.include?(anim_name)
      return
    end
    if FAST_COMMON_ANIMATIONS.include?(anim_name)
      pbQuickStatAnimation(user, anim_name)
      return
    end
    _vermeil_fast_status_orig_pbCommonAnimation(anim_name, user, targets)
  end

  def pbQuickStatAnimation(user, stat_name)
    return if user.nil?
    sprite_key = "pokemon_#{user.index}"
    sprite = @sprites[sprite_key]
    return if sprite.nil?
    is_up = stat_name.include?("Up")
    flash_color = is_up ? Color.new(0, 200, 0) : Color.new(200, 0, 0)
    orig_zoom_x = sprite.zoom_x
    orig_zoom_y = sprite.zoom_y
    orig_tone = sprite.tone.clone
    flash_frames = [
      { zoom: 1.0, tone: Tone.new(0, 0, 0) },
      { zoom: 1.1, tone: Tone.new(flash_color.red / 3, flash_color.green / 3, flash_color.blue / 3) },
      { zoom: 1.0, tone: Tone.new(0, 0, 0) },
    ]
    flash_frames.each do |frame|
      sprite.zoom_x = frame[:zoom]
      sprite.zoom_y = frame[:zoom]
      sprite.tone = frame[:tone]
      pbUpdate
    end
    sprite.zoom_x = orig_zoom_x
    sprite.zoom_y = orig_zoom_y
    sprite.tone = orig_tone
  end
end

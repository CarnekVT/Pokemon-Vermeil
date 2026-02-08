#===============================================================================
# Battleback Defaults (Base/Message) - Plugin override
#===============================================================================
# Provides fallback base/message battlebacks to avoid missing file errors.
# Set these to the prefix of your shared base/message files.
# Example: "indoor" -> indoor_base0.png, indoor_base1.png, indoor_message.png
#===============================================================================

class Battle::Scene
  DEFAULT_BATTLEBACK_BASE = "indoor1"
  DEFAULT_BATTLEBACK_MESSAGE = "indoor1"

  # Re-implement to inject defaults before sprites are created.
  def pbCreateBackdropSprites
    case @battle.time
    when 1 then time = "eve"
    when 2 then time = "night"
    end
    # Put everything together into backdrop, bases and message bar filenames
    backdropFilename = @battle.backdrop
    baseFilename = @battle.backdrop
    baseFilename = sprintf("%s_%s", baseFilename, @battle.backdropBase) if @battle.backdropBase
    messageFilename = @battle.backdrop
    if time
      trialName = sprintf("%s_%s", backdropFilename, time)
      if pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_bg", trialName))
        backdropFilename = trialName
      end
      trialName = sprintf("%s_%s", baseFilename, time)
      if pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_base0", trialName))
        baseFilename = trialName
      end
      trialName = sprintf("%s_%s", messageFilename, time)
      if pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_message", trialName))
        messageFilename = trialName
      end
    end
    if !pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_base0", baseFilename)) &&
       @battle.backdropBase
      baseFilename = @battle.backdropBase
      if time
        trialName = sprintf("%s_%s", baseFilename, time)
        if pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_base0", trialName))
          baseFilename = trialName
        end
      end
    end
    # Fallbacks for missing base/message
    if !pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_base0", baseFilename)) ||
       !pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_base1", baseFilename))
      defaultBase = DEFAULT_BATTLEBACK_BASE
      if defaultBase &&
         pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_base0", defaultBase)) &&
         pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_base1", defaultBase))
        baseFilename = defaultBase
      end
    end
    if !pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_message", messageFilename))
      defaultMessage = DEFAULT_BATTLEBACK_MESSAGE
      if defaultMessage &&
         pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_message", defaultMessage))
        messageFilename = defaultMessage
      end
    end
    # Finalise filenames
    battleBG   = "Graphics/Battlebacks/" + backdropFilename + "_bg"
    playerBase = "Graphics/Battlebacks/" + baseFilename + "_base0"
    enemyBase  = "Graphics/Battlebacks/" + baseFilename + "_base1"
    messageBG  = "Graphics/Battlebacks/" + messageFilename + "_message"
    # Apply graphics
    bg = pbAddSprite("battle_bg", 0, 0, battleBG, @viewport)
    bg.z = 0
    disable_bg_slide = Settings.const_defined?(:DISABLE_SLIDING_BACKGROUND) &&
                       Settings::DISABLE_SLIDING_BACKGROUND
    if !disable_bg_slide
      bg = pbAddSprite("battle_bg2", -Graphics.width, 0, battleBG, @viewport)
      bg.z      = 0
      bg.mirror = true
    end
    2.times do |side|
      baseX, baseY = Battle::Scene.pbBattlerPosition(side)
      base = pbAddSprite("base_#{side}", baseX, baseY,
                         (side == 0) ? playerBase : enemyBase, @viewport)
      base.z = 1
      if base.bitmap
        base.ox = base.bitmap.width / 2
        base.oy = (side == 0) ? base.bitmap.height : base.bitmap.height / 2
      end
    end
    cmdBarBG = pbAddSprite("cmdBar_bg", 0, Graphics.height - 96, messageBG, @viewport)
    cmdBarBG.z = 180
  end
end

# Expose defaults for other plugins (e.g., DBK)
class Battle
  DEFAULT_BATTLEBACK_BASE = Battle::Scene::DEFAULT_BATTLEBACK_BASE
  DEFAULT_BATTLEBACK_MESSAGE = Battle::Scene::DEFAULT_BATTLEBACK_MESSAGE
end

#===============================================================================
# Battleback defaults for DBK utilities (Mega/Primal animations)
#===============================================================================
if Battle.method_defined?(:pbGetBattlefieldFiles)
  class Battle
    unless method_defined?(:lb_default_pbGetBattlefieldFiles)
      alias_method :lb_default_pbGetBattlefieldFiles, :pbGetBattlefieldFiles
    end

    def pbGetBattlefieldFiles
      backdropFilename, baseFilename = lb_default_pbGetBattlefieldFiles
      baseTest = sprintf("Graphics/Battlebacks/%s_base1", baseFilename)
      if !pbResolveBitmap(baseTest) &&
         Battle::Scene::DEFAULT_BATTLEBACK_BASE &&
         pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_base1", Battle::Scene::DEFAULT_BATTLEBACK_BASE))
        baseFilename = Battle::Scene::DEFAULT_BATTLEBACK_BASE
      end
      return backdropFilename, baseFilename
    end
  end
end

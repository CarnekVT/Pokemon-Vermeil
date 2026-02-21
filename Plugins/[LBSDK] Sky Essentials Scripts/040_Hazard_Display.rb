# #===============================================================================
# # Hazard Display System
# # Shows spikes, toxic spikes, stealth rock, and sticky web in battle
# #===============================================================================

# #===============================================================================
# # Hazard Settings
# #===============================================================================
# module HazardSettings
#   # Hard quarantine switch: disables all Hazard Display logic and hooks.
#   HARD_QUARANTINE = true

#   # Whether to show hazard graphics in battle
#   ENABLE_HAZARD_DISPLAY = false
  
#   # Hazard image path
#   HAZARD_GRAPHICS_PATH = "Graphics/UI/Battle/hazards/"
  
#   # Hazard positions on the battlefield (adjust as needed)
#   PLAYER_SIDE_HAZARD_X = 128
#   PLAYER_SIDE_HAZARD_Y = 340
#   FOE_SIDE_HAZARD_X = 350
#   FOE_SIDE_HAZARD_Y = 160
  
#   # Hazard spacing (for multiple hazards on the same side)
#   HAZARD_SPACING = 32
  
#   # Hazard opacity (0-255)
#   HAZARD_OPACITY = 200
  
#   # Hazard zoom (0.0-1.0)
#   HAZARD_ZOOM = 0.8
  
#   # Hazard z-index (should be below battlers but above background)
#   HAZARD_Z_INDEX = 20

#   HAZARD_FILE_BY_TYPE = {
#     spikes: "spikes.png",
#     toxic_spikes: "toxic_spikes.png",
#     stealth_rock: "stealth_rock.png",
#     sticky_web: "sticky_web.png"
#   }

#   @bitmap_cache = {}

#   def self.bitmap_for(hazard_type)
#     filename = HAZARD_FILE_BY_TYPE[hazard_type]
#     return nil if !filename
#     cached = @bitmap_cache[hazard_type]
#     return cached if cached && !cached.disposed?
#     path = HAZARD_GRAPHICS_PATH + filename
#     resolved = pbResolveBitmap(path)
#     return nil if !resolved
#     bmp = Bitmap.new(resolved)
#     @bitmap_cache[hazard_type] = bmp
#     return bmp
#   end

#   def self.preload_bitmaps
#     HAZARD_FILE_BY_TYPE.each_key { |k| bitmap_for(k) }
#   end
# end

# #===============================================================================
# # Hazard Data Class
# #===============================================================================
# class HazardData
#   attr_accessor :sprite
#   attr_accessor :type
#   attr_accessor :x
#   attr_accessor :y
#   attr_accessor :opacity
#   attr_accessor :zoom
  
#   def initialize(type, x, y)
#     @type = type
#     @x = x
#     @y = y
#     @opacity = HazardSettings::HAZARD_OPACITY
#     @zoom = HazardSettings::HAZARD_ZOOM
#     @sprite = nil
#   end
  
#   def create_sprite(viewport)
#     return if !HazardSettings::ENABLE_HAZARD_DISPLAY
#     bmp = HazardSettings.bitmap_for(@type)
#     return if !bmp
#     @sprite = IconSprite.new(@x, @y, viewport)
#     @sprite.bitmap = bmp
#     if @sprite
#       @sprite.opacity = @opacity
#       @sprite.zoom_x = @zoom
#       @sprite.zoom_y = @zoom
#       @sprite.z = HazardSettings::HAZARD_Z_INDEX
#     end
#   end
  
#   def dispose
#     @sprite&.dispose
#     @sprite = nil
#   end
  
#   def visible?
#     @sprite && !@sprite.disposed? && @sprite.visible
#   end
  
#   def show
#     @sprite.visible = true if @sprite && !@sprite.disposed?
#   end
  
#   def hide
#     @sprite.visible = false if @sprite && !@sprite.disposed?
#   end
  
#   private
# end

# #===============================================================================
# # Battle Scene Extensions
# #===============================================================================
# class Battle::Scene
#   # Initialize hazard sprites
#   alias pbInitHazardSprites pbInitSprites
#   def pbInitSprites
#     pbInitHazardSprites
#     return if HazardSettings::HARD_QUARANTINE
#     HazardSettings.preload_bitmaps if HazardSettings::ENABLE_HAZARD_DISPLAY
#     initialize_hazard_sprites if HazardSettings::ENABLE_HAZARD_DISPLAY
#   end
  
#   # Dispose hazard sprites
#   alias pbDisposeHazardSprites pbDisposeSprites
#   def pbDisposeSprites
#     return pbDisposeHazardSprites if HazardSettings::HARD_QUARANTINE
#     # Dispose hazard sprites first
#     if HazardSettings::ENABLE_HAZARD_DISPLAY && @hazard_data && @hazard_data[:player] && @hazard_data[:foe]
#       @hazard_data[:player].each { |hazard| hazard.dispose }
#       @hazard_data[:foe].each { |hazard| hazard.dispose }
#       @hazard_data.clear
#     end
#     # Call original method
#     pbDisposeHazardSprites
#   end
  
#   # Dispose hazard sprites when battle ends
#   alias pbEndBattleWithHazards pbEndBattle
#   def pbEndBattle(result)
#     return pbEndBattleWithHazards(result) if HazardSettings::HARD_QUARANTINE
#     # Hide all hazards immediately when battle ends
#     if HazardSettings::ENABLE_HAZARD_DISPLAY && @hazard_data
#       # Hide player side hazards
#       if @hazard_data[:player]
#         @hazard_data[:player].each { |hazard| hazard.hide }
#       end
#       # Hide foe side hazards
#       if @hazard_data[:foe]
#         @hazard_data[:foe].each { |hazard| hazard.hide }
#       end
#     end
#     # Call original method
#     pbEndBattleWithHazards(result)
#   end
  
#   # Update hazard sprites
#   alias pbUpdateHazardFrame pbFrameUpdate
#   def pbFrameUpdate(cw = nil)
#     pbUpdateHazardFrame(cw)
#     return if HazardSettings::HARD_QUARANTINE
#     update_hazard_sprites if HazardSettings::ENABLE_HAZARD_DISPLAY
#   end
  
#   # Refresh hazard sprites
#   def pbUpdateHazardSprites
#     return if HazardSettings::HARD_QUARANTINE
#     return if !HazardSettings::ENABLE_HAZARD_DISPLAY
#     if pbHazardsSuspended?
#       @hazard_refresh_queued = true
#       return
#     end
#     update_hazard_sprites
#   end

#   # Generic animation API: pause/resume hazard visual refresh safely.
#   def pbHazardsSuspend(_tag = nil)
#     return if HazardSettings::HARD_QUARANTINE
#     @hazard_suspend_count ||= 0
#     @hazard_suspend_count += 1
#   end

#   def pbHazardsResume(_tag = nil, refresh = true)
#     return if HazardSettings::HARD_QUARANTINE
#     @hazard_suspend_count ||= 0
#     @hazard_suspend_count -= 1 if @hazard_suspend_count > 0
#     if !pbHazardsSuspended? && refresh && @hazard_refresh_queued
#       @hazard_refresh_queued = false
#       pbHazardsForceRefreshNow
#     elsif !pbHazardsSuspended? && refresh
#       pbHazardsForceRefreshNow
#     end
#   end

#   def pbHazardsSuspended?
#     return false if HazardSettings::HARD_QUARANTINE
#     return (@hazard_suspend_count || 0) > 0
#   end

#   # Hard refresh used by coded animations: ensures hazard sprites are created
#   # and fully visible in the same frame (no perceived gradual appearance).
#   def pbHazardsForceRefreshNow
#     return if HazardSettings::HARD_QUARANTINE
#     update_hazard_sprites
#     return if !@hazard_data
#     @hazard_data.each_value do |arr|
#       next if !arr
#       arr.each do |hazard|
#         next if !hazard || !hazard.respond_to?(:sprite)
#         s = hazard.sprite
#         next if !s || (s.respond_to?(:disposed?) && s.disposed?)
#         s.visible = true if s.respond_to?(:visible=)
#         if hazard.respond_to?(:opacity) && s.respond_to?(:opacity=)
#           s.opacity = hazard.opacity
#         end
#       end
#     end
#   end
  
#   private
  
#   def initialize_hazard_sprites
#     @hazard_data = {
#       player: [],
#       foe: []
#     }
#     @hazard_suspend_count = 0
#     @hazard_refresh_queued = false
#   end
  
#   # Public method to dispose hazard sprites
#   def pbDisposeHazardSprites
#     puts "Disposing hazard sprites..."
#     if @hazard_data && @hazard_data[:player] && @hazard_data[:foe]
#       @hazard_data[:player].each { |hazard| hazard.dispose }
#       @hazard_data[:foe].each { |hazard| hazard.dispose }
#       @hazard_data.clear
#     end
#   end
  
#   def update_hazard_sprites
#     return if HazardSettings::HARD_QUARANTINE
#     return if !HazardSettings::ENABLE_HAZARD_DISPLAY
#     if pbHazardsSuspended?
#       @hazard_refresh_queued = true
#       return
#     end
#     # Do not update hazards if the battle has ended
#     return if @battleEnd
#     # Initialize hazard data if it doesn't exist
#     initialize_hazard_sprites if !@hazard_data
#     # Update player's side hazards
#     update_side_hazards(:player, 0)
#     # Update foe's side hazards
#     update_side_hazards(:foe, 1)
#   end
  
#   def update_side_hazards(side, battle_side)
#     # Ensure hazard data for the side exists
#     @hazard_data ||= { player: [], foe: [] }
#     @hazard_data[side] ||= []
#     # Get current hazards on the side
#     current_hazards = get_side_hazards(battle_side) || []
    
#     # Create or update hazard sprites
#     current_hazards.each_with_index do |hazard_type, index|
#       hazard = @hazard_data[side][index]
#       if !hazard || hazard.type != hazard_type
#         # Dispose old hazard if it exists and type is different
#         hazard.dispose if hazard
#         # Create new hazard
#         x = get_hazard_x(side, index)
#         y = get_hazard_y(side)
#         hazard = HazardData.new(hazard_type, x, y)
#         hazard.create_sprite(@viewport)
#         @hazard_data[side][index] = hazard
#       end
#       # Show hazard
#       hazard.show if !hazard.visible?
#     end
    
#     # Hide or dispose extra hazards
#     if @hazard_data[side] && current_hazards
#       (@hazard_data[side].length - current_hazards.length).times do |i|
#         index = current_hazards.length + i
#         hazard = @hazard_data[side][index]
#         if hazard && hazard.visible?
#           hazard.hide
#           # You could add a fade-out animation here if desired
#         end
#       end
#     end
#   end
  
#   def get_side_hazards(side)
#     hazards = []
#     battle_side = @battle.sides[side]
#     if battle_side
#       # Add hazards based on their effects
#       if battle_side.effects[PBEffects::Spikes] > 0
#         hazards << :spikes
#       end
#       if battle_side.effects[PBEffects::ToxicSpikes] > 0
#         hazards << :toxic_spikes
#       end
#       if battle_side.effects[PBEffects::StealthRock]
#         hazards << :stealth_rock
#       end
#       if battle_side.effects[PBEffects::StickyWeb]
#         hazards << :sticky_web
#       end
#       # Terrain effects are handled by the battle system's background animations, not as small hazard sprites
#     end
#     return hazards
#   end
  
#   def get_hazard_x(side, index)
#     base_x = (side == :player) ? HazardSettings::PLAYER_SIDE_HAZARD_X : HazardSettings::FOE_SIDE_HAZARD_X
#     return base_x + (index * HazardSettings::HAZARD_SPACING)
#   end
  
#   def get_hazard_y(side)
#     return (side == :player) ? HazardSettings::PLAYER_SIDE_HAZARD_Y : HazardSettings::FOE_SIDE_HAZARD_Y
#   end
# end

# #===============================================================================
# # Battle Extensions
# #===============================================================================
# class Battle
#   # Refresh hazards when terrain starts (before message)
#   alias pbStartTerrainWithHazards pbStartTerrain
#   def pbStartTerrain(user, newTerrain, fixedDuration = true)
#     return pbStartTerrainWithHazards(user, newTerrain, fixedDuration) if HazardSettings::HARD_QUARANTINE
#     # Update hazards before terrain starts to ensure sprites are visible when message appears
#     @scene.update_hazard_sprites if @scene.respond_to?(:update_hazard_sprites)
#     # Call original method
#     pbStartTerrainWithHazards(user, newTerrain, fixedDuration)
#   end

#   # Refresh hazards when terrain continues (before message)
#   alias pbEOREndTerrainWithHazards pbEOREndTerrain
#   def pbEOREndTerrain
#     return pbEOREndTerrainWithHazards if HazardSettings::HARD_QUARANTINE
#     # Update hazards before terrain message to ensure sprites are visible
#     @scene.update_hazard_sprites if @scene.respond_to?(:update_hazard_sprites)
#     # Call original method
#     pbEOREndTerrainWithHazards
#   end

#   # Refresh hazards when battle starts (before terrain message)
#   alias pbStartBattleCoreWithHazards pbStartBattleCore
#   def pbStartBattleCore(battle_loop = true)
#     # Call original method
#     # The Generation 9 Pack Scripts version of this method calls pbTerrainStartMessage
#     # which we've already aliased to update hazards before the message
#     result = pbStartBattleCoreWithHazards(battle_loop)
#     result
#   end

#   # Refresh hazards when terrain start message is displayed (before message)
#   alias pbTerrainStartMessageWithHazards pbTerrainStartMessage
#   def pbTerrainStartMessage
#     return pbTerrainStartMessageWithHazards if HazardSettings::HARD_QUARANTINE
#     # Update hazards before terrain start message
#     @scene.update_hazard_sprites if @scene.respond_to?(:update_hazard_sprites)
#     # Call original method
#     result = pbTerrainStartMessageWithHazards
#     result
#   end

#   # Dispose hazards when battle ends
#   alias pbEndOfBattleWithHazards pbEndOfBattle
#   def pbEndOfBattle(*args)
#     return pbEndOfBattleWithHazards(*args) if HazardSettings::HARD_QUARANTINE
#     # Call original method
#     result = pbEndOfBattleWithHazards(*args)
#     # Dispose hazard sprites
#     @scene.pbDisposeHazardSprites if @scene.respond_to?(:pbDisposeHazardSprites)
#     return result
#   end

#   # Refresh hazards at end of round
#   alias pbEndOfRoundPhaseWithHazards pbEndOfRoundPhase
#   def pbEndOfRoundPhase
#     return pbEndOfRoundPhaseWithHazards if HazardSettings::HARD_QUARANTINE
#     result = pbEndOfRoundPhaseWithHazards
#     @scene.update_hazard_sprites if @scene.respond_to?(:update_hazard_sprites)
#     result
#   end
# end

# #===============================================================================
# # Battler Extensions
# #===============================================================================
# class Battle::Battler
#   # Refresh hazards after a move is used
#   alias pbUseMoveWithHazards pbUseMove
#   def pbUseMove(choice, specialUsage = false)
#     return pbUseMoveWithHazards(choice, specialUsage) if HazardSettings::HARD_QUARANTINE
#     result = pbUseMoveWithHazards(choice, specialUsage)
#     @battle.scene.pbUpdateHazardSprites if @battle.scene.respond_to?(:pbUpdateHazardSprites)
#     result
#   end
# end

# #===============================================================================
# # Add hazard images to project
# # Note: This will copy the hazard images from La Base de Sky to your project
# #===============================================================================
# if defined?(PluginManager)
#   module PluginManager
#     class << self
#       alias register_hazard_plugin register
#       def register(plugin)
#         if plugin[:name] == "Hazard Display System" && !File.exist?("Graphics/UI/Battle/hazards")
#           require 'fileutils'
#           source_dir = "../../La-Base-de-Sky/LA BASE DE SKY/Graphics/UI/Battle/hazards"
#           dest_dir = "Graphics/UI/Battle/hazards"
#           if File.exist?(source_dir)
#             FileUtils.mkdir_p(dest_dir)
#             FileUtils.cp_r(File.join(source_dir, "."), dest_dir)
#           end
#         end
#         register_hazard_plugin(plugin)
#       end
#     end
#   end
# end


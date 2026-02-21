#===============================================================================
# Hazard Display System
# Shows spikes, toxic spikes, stealth rock, and sticky web in battle
#===============================================================================

#===============================================================================
module HazardSettings
	# Hard quarantine switch: disables all Hazard Display logic and hooks.
	HARD_QUARANTINE = false

	# Whether to show hazard graphics in battle
	ENABLE_HAZARD_DISPLAY = true

	# Hazard image path
	HAZARD_GRAPHICS_PATH = "Graphics/UI/Battle/hazards/"

	# Hazard positions on the battlefield (adjust as needed)
	PLAYER_SIDE_HAZARD_X = 128
	PLAYER_SIDE_HAZARD_Y = 340
	FOE_SIDE_HAZARD_X = 350
	FOE_SIDE_HAZARD_Y = 160

	# Hazard spacing (for multiple hazards on the same side)
	HAZARD_SPACING = 32

	# Hazard opacity (0-255)
	HAZARD_OPACITY = 200

	# Hazard zoom (1.0 = 100%)
	HAZARD_ZOOM = 0.8

	# Hazard z-index (should be below battlers but above background)
	# Default base z; per-type z overrides follow. Use low values so battlers render above hazards.
	HAZARD_Z_INDEX = 10

	# Horizontal offset from center for left/right placement
	HAZARD_SIDE_OFFSET = 20

	# Global horizontal shift to move all hazards (positive = move right)
	HAZARD_CENTER_SHIFT = 12

	# Additional global fine tuning shift (positive = move right)
	HAZARD_GLOBAL_SHIFT = 16

	# Fixed positions per side and per hazard type. Each entry is [x,y].
	# Explicit independent X positions so each hazard can be moved without
	# affecting the others. Values chosen to match requested layout:
	#  - sticky: slightly right of previous center
	#  - stealth: same X as sticky (center)
	#  - spikes: a bit right of sticky
	#  - toxic_spikes: further right
	HAZARD_POSITIONS = {
		player: {
			# Layout per user's mock: spikes=left, stealth=center, sticky=center(green), toxic=right
			spikes: [120, 388],       # left
			stealth_rock: [140, 388], # center
			sticky_web: [140, 392],   # center (green)
			toxic_spikes: [176, 388]   # right (purple)
		},
		foe: {
			spikes: [328, 184],       # left (foe side)
			stealth_rock: [348, 184], # center
			sticky_web: [348, 184],   # center (green)
			toxic_spikes: [384, 184]   # right (purple)
		}
	}

	# NOTE: color tinting removed — hazards use their default image colors

	# Pixel offset to separate multiple stacked icons for the same hazard type
	HAZARD_STACK_OFFSET = 10

	# Per-type z-order so sticky stays behind and other hazards render above it
	# Use low values so battlers render above these sprites; sticky_web should be behind others.
	HAZARD_Z_BY_TYPE = {
		sticky_web: 5,
		spikes: 40,
		toxic_spikes: 50,
		stealth_rock: 40
	}

	HAZARD_FILE_BY_TYPE = {
		spikes: "spikes.png",
		toxic_spikes: "toxic_spikes.png",
		stealth_rock: "stealth_rock.png",
		sticky_web: "sticky_web.png"
	}

	@bitmap_cache = {}

	def self.bitmap_for(hazard_type)
		return nil if HARD_QUARANTINE || !ENABLE_HAZARD_DISPLAY
		filename = HAZARD_FILE_BY_TYPE[hazard_type]
		return nil unless filename
		cached = @bitmap_cache[hazard_type]
		return cached if cached && !cached.disposed?
		path = HAZARD_GRAPHICS_PATH + filename
		resolved = pbResolveBitmap(path)
		return nil unless resolved
		bmp = Bitmap.new(resolved)
		@bitmap_cache[hazard_type] = bmp
		return bmp
	end

	def self.preload_bitmaps
		return if HARD_QUARANTINE || !ENABLE_HAZARD_DISPLAY
		HAZARD_FILE_BY_TYPE.each_key { |k| bitmap_for(k) }
	end
end

#===============================================================================
class HazardData
	attr_accessor :sprite, :type, :x, :y, :opacity, :zoom

	def initialize(type, x, y)
		@type = type
		@x = x
		@y = y
		@opacity = HazardSettings::HAZARD_OPACITY
		@zoom = HazardSettings::HAZARD_ZOOM
		@sprite = nil
	end

	def create_sprite(viewport)
		return if HazardSettings::HARD_QUARANTINE || !HazardSettings::ENABLE_HAZARD_DISPLAY
		bmp = HazardSettings.bitmap_for(@type)
		return if !bmp
		@sprite = IconSprite.new(0, 0, viewport)
		@sprite.bitmap = bmp
		if @sprite
			@sprite.zoom_x = @zoom
			@sprite.zoom_y = @zoom
			# Anchor bottom-center so the icon appears 'on the ground' at (x,y)
			@sprite.ox = (@sprite.bitmap.width / 2)
			@sprite.oy = @sprite.bitmap.height
			@sprite.x = @x
			@sprite.y = @y
			@sprite.opacity = @opacity
			# Use per-type z if available so sticky_web stays behind other hazards
			@sprite.z = HazardSettings::HAZARD_Z_BY_TYPE[@type] || HazardSettings::HAZARD_Z_INDEX
				# No tint applied — use default asset colors
			@sprite.visible = false
		end
	end

	def dispose
		if @sprite && !(@sprite.respond_to?(:disposed?) && @sprite.disposed?)
			@sprite.dispose
		end
		@sprite = nil
	end

	def visible?
		return false unless @sprite
		return false if @sprite.respond_to?(:disposed?) && @sprite.disposed?
		return !!@sprite.visible
	end

	def show
		return unless @sprite && !(@sprite.respond_to?(:disposed?) && @sprite.disposed?)
		@sprite.visible = true
	end

	def hide
		return unless @sprite && !(@sprite.respond_to?(:disposed?) && @sprite.disposed?)
		@sprite.visible = false
	end
end

#===============================================================================
class Battle::Scene
	# Initialize hazard sprites when scene sprites are initialized
	alias_method :pbInitSprites_with_hazards, :pbInitSprites
	def pbInitSprites
		pbInitSprites_with_hazards
		return if HazardSettings::HARD_QUARANTINE
		HazardSettings.preload_bitmaps if HazardSettings::ENABLE_HAZARD_DISPLAY
		initialize_hazard_sprites if HazardSettings::ENABLE_HAZARD_DISPLAY
	end

	# Dispose hazard sprites safely when disposing scene sprites
	alias_method :pbDisposeSprites_with_hazards, :pbDisposeSprites
	def pbDisposeSprites
		return pbDisposeSprites_with_hazards if HazardSettings::HARD_QUARANTINE
		if HazardSettings::ENABLE_HAZARD_DISPLAY && @hazard_data
			@hazard_data[:player]&.each { |hazard| hazard.dispose }
			@hazard_data[:foe]&.each { |hazard| hazard.dispose }
			@hazard_data&.clear
		end
		pbDisposeSprites_with_hazards
	end

	# When battle ends, hide hazards immediately
	alias_method :pbEndBattle_with_hazards, :pbEndBattle
	def pbEndBattle(result)
		return pbEndBattle_with_hazards(result) if HazardSettings::HARD_QUARANTINE
		if HazardSettings::ENABLE_HAZARD_DISPLAY && @hazard_data
			@hazard_data[:player]&.each { |h| h.hide }
			@hazard_data[:foe]&.each { |h| h.hide }
		end
		pbEndBattle_with_hazards(result)
	end

	# Called every frame
	alias_method :pbFrameUpdate_with_hazards, :pbFrameUpdate
	def pbFrameUpdate(cw = nil)
		pbFrameUpdate_with_hazards(cw)
		return if HazardSettings::HARD_QUARANTINE
		update_hazard_sprites if HazardSettings::ENABLE_HAZARD_DISPLAY
	end

	# Public method to request hazard refresh
	def pbUpdateHazardSprites
		return if HazardSettings::HARD_QUARANTINE
		return unless HazardSettings::ENABLE_HAZARD_DISPLAY
		if pbHazardsSuspended?
			@hazard_refresh_queued = true
			return
		end
		update_hazard_sprites
	end

	# Generic animation API: pause/resume hazard visual refresh safely.
	def pbHazardsSuspend(_tag = nil)
		return if HazardSettings::HARD_QUARANTINE
		@hazard_suspend_count ||= 0
		@hazard_suspend_count += 1
	end

	def pbHazardsResume(_tag = nil, refresh = true)
		return if HazardSettings::HARD_QUARANTINE
		@hazard_suspend_count ||= 0
		@hazard_suspend_count -= 1 if @hazard_suspend_count > 0
		if !pbHazardsSuspended? && refresh && @hazard_refresh_queued
			@hazard_refresh_queued = false
			pbHazardsForceRefreshNow
		elsif !pbHazardsSuspended? && refresh
			pbHazardsForceRefreshNow
		end
	end

	def pbHazardsSuspended?
		return false if HazardSettings::HARD_QUARANTINE
		return (@hazard_suspend_count || 0) > 0
	end

	# Force immediate refresh and ensure sprites are visible with correct opacity
	def pbHazardsForceRefreshNow
		return if HazardSettings::HARD_QUARANTINE
		update_hazard_sprites
		return if !@hazard_data
		@hazard_data.each_value do |arr|
			next if !arr
			arr.each do |hazard|
				next if !hazard || !hazard.respond_to?(:sprite)
				s = hazard.sprite
				next if !s || (s.respond_to?(:disposed?) && s.disposed?)
				s.visible = true if s.respond_to?(:visible=)
				s.opacity = hazard.opacity if hazard.respond_to?(:opacity) && s.respond_to?(:opacity=)
			end
		end
	end

	private

	def initialize_hazard_sprites
		@hazard_data = { player: [], foe: [] }
		@hazard_suspend_count = 0
		@hazard_refresh_queued = false
	end

	def update_hazard_sprites
		return if HazardSettings::HARD_QUARANTINE
		return unless HazardSettings::ENABLE_HAZARD_DISPLAY
		if pbHazardsSuspended?
			@hazard_refresh_queued = true
			return
		end
		return if @battleEnd
		initialize_hazard_sprites if !@hazard_data
		update_side_hazards(:player, 0)
		update_side_hazards(:foe, 1)
	end

	def update_side_hazards(side, battle_side)
		@hazard_data ||= { player: [], foe: [] }
		old = @hazard_data[side] || []
		current_hazards = get_side_hazards(battle_side) || []

		# Build new hazard list for this side using fixed positions per type.
		# For repeated hazards of the same type, stack them vertically above the base.
		new_list = []
		type_counts = Hash.new(0)
		current_hazards.each do |hazard_type|
			idx = type_counts[hazard_type]
			type_counts[hazard_type] += 1
			x = get_hazard_x(side, idx, hazard_type)
			y = get_hazard_y(side, idx, hazard_type)
			h = HazardData.new(hazard_type, x, y)
			h.create_sprite(@viewport)
			h.show
			new_list << h
		end

		# Dispose old sprites and replace with new list
		old.each { |h| h.dispose } if old
		@hazard_data[side] = new_list
	end

	def get_side_hazards(side)
		hazards = []
		battle_side = @battle.sides[side]
		if battle_side
			spikes_count = battle_side.effects[PBEffects::Spikes]
			if spikes_count && spikes_count > 0
				spikes_count.times { hazards << :spikes }
			end
			toxic_count = battle_side.effects[PBEffects::ToxicSpikes]
			if toxic_count && toxic_count > 0
				toxic_count.times { hazards << :toxic_spikes }
			end
			hazards << :stealth_rock if battle_side.effects[PBEffects::StealthRock]
			hazards << :sticky_web if battle_side.effects[PBEffects::StickyWeb]
		end
		hazards
	end

	def get_hazard_x(side, index, hazard_type)
		pos = HazardSettings::HAZARD_POSITIONS[(side == :player) ? :player : :foe]
		base = pos[hazard_type] || [0, 0]
		x = base[0]
		# Slight horizontal offset per stacked item so icons don't fully overlap
		# Apply global fine-tune shift so user can nudge all hazards right
		x + (index * HazardSettings::HAZARD_STACK_OFFSET) + (HazardSettings.const_defined?(:HAZARD_GLOBAL_SHIFT) ? HazardSettings::HAZARD_GLOBAL_SHIFT : 0)
	end

	def get_hazard_y(side, index, hazard_type)
		pos = HazardSettings::HAZARD_POSITIONS[(side == :player) ? :player : :foe]
		base = pos[hazard_type] || [0, 0]
		y = base[1]
		# Slight vertical offset for stacks on the player side to improve visibility
		(side == :player) ? (y - (index * 2)) : (y + (index * 2))
	end
end

#===============================================================================
class Battle
	alias_method :pbStartTerrain_with_hazards, :pbStartTerrain
	def pbStartTerrain(user, newTerrain, fixedDuration = true)
		return pbStartTerrain_with_hazards(user, newTerrain, fixedDuration) if HazardSettings::HARD_QUARANTINE
		@scene.pbUpdateHazardSprites if @scene.respond_to?(:pbUpdateHazardSprites)
		pbStartTerrain_with_hazards(user, newTerrain, fixedDuration)
	end

	alias_method :pbEOREndTerrain_with_hazards, :pbEOREndTerrain
	def pbEOREndTerrain
		return pbEOREndTerrain_with_hazards if HazardSettings::HARD_QUARANTINE
		@scene.pbUpdateHazardSprites if @scene.respond_to?(:pbUpdateHazardSprites)
		pbEOREndTerrain_with_hazards
	end

	alias_method :pbStartBattleCore_with_hazards, :pbStartBattleCore
	def pbStartBattleCore(battle_loop = true)
		result = pbStartBattleCore_with_hazards(battle_loop)
		result
	end

	alias_method :pbTerrainStartMessage_with_hazards, :pbTerrainStartMessage
	def pbTerrainStartMessage
		return pbTerrainStartMessage_with_hazards if HazardSettings::HARD_QUARANTINE
		@scene.pbUpdateHazardSprites if @scene.respond_to?(:pbUpdateHazardSprites)
		pbTerrainStartMessage_with_hazards
	end

	alias_method :pbEndOfBattle_with_hazards, :pbEndOfBattle
	def pbEndOfBattle(*args)
		return pbEndOfBattle_with_hazards(*args) if HazardSettings::HARD_QUARANTINE
		result = pbEndOfBattle_with_hazards(*args)
		@scene.pbDisposeSprites if @scene.respond_to?(:pbDisposeSprites)
		result
	end

	alias_method :pbEndOfRoundPhase_with_hazards, :pbEndOfRoundPhase
	def pbEndOfRoundPhase
		return pbEndOfRoundPhase_with_hazards if HazardSettings::HARD_QUARANTINE
		result = pbEndOfRoundPhase_with_hazards
		@scene.pbUpdateHazardSprites if @scene.respond_to?(:pbUpdateHazardSprites)
		result
	end
end

#===============================================================================
class Battle::Battler
	alias_method :pbUseMove_with_hazards, :pbUseMove
	def pbUseMove(choice, specialUsage = false)
		return pbUseMove_with_hazards(choice, specialUsage) if HazardSettings::HARD_QUARANTINE
		result = pbUseMove_with_hazards(choice, specialUsage)
		@battle.scene.pbUpdateHazardSprites if @battle.scene.respond_to?(:pbUpdateHazardSprites)
		result
	end
end

#===============================================================================
# Copy hazard images from La Base de Sky when plugin registers (optional)
if defined?(PluginManager)
	module PluginManager
		class << self
			alias_method :register_without_hazard_assets, :register
			def register(plugin)
				if plugin[:name] == "Hazard Display System" && !File.exist?("Graphics/UI/Battle/hazards")
					require 'fileutils'
					source_dir = "../../La-Base-de-Sky/LA BASE DE SKY/Graphics/UI/Battle/hazards"
					dest_dir = "Graphics/UI/Battle/hazards"
					if File.exist?(source_dir)
						FileUtils.mkdir_p(dest_dir)
						FileUtils.cp_r(File.join(source_dir, "."), dest_dir)
					end
				end
				register_without_hazard_assets(plugin)
			end
		end
	end
end


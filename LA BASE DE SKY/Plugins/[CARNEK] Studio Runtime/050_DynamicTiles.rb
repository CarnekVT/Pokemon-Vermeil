#===============================================================================
# Dynamic Tile Runtime - animated map graphics independent from RPG Maker events.
#===============================================================================
module CarnekStudio
  module DynamicTiles
    module_function
    def data; @data ||= CarnekStudio.load_json("dynamic_tiles.json", {"definitions"=>[],"placements"=>[]}); end
    def reload; @data=nil; data; end
    def definition(id); (data["definitions"]||[]).find{|d|d["id"].to_s==id.to_s}; end
    def placements(map_id); (data["placements"]||[]).select{|p|p["mapId"].to_i==map_id.to_i}; end
    def blocked?(map_id,x,y)
      placements(map_id).any? do |p|
        d=definition(p["tile"]); next false unless d && d.dig("collision","blocksPlayer")
        w=(d["widthTiles"]||1).to_i; h=(d["heightTiles"]||1).to_i
        x>=p["x"].to_i && x<p["x"].to_i+w && y>=p["y"].to_i && y<p["y"].to_i+h
      end
    end
  end
  if defined?(Sprite)
  class DynamicTileSprite < Sprite
    def initialize(viewport, placement, definition)
      super(viewport); @p=placement; @d=definition; @tick=0; @frame=0; self.bitmap=AnimatedBitmap.new(@d["graphic"]).deanimate
      @frames=[(@d["frames"]||1).to_i,1].max; @fps=[(@d["fps"]||8).to_i,1].max
      @fw=bitmap.width/@frames; @fh=bitmap.height; self.src_rect=Rect.new(0,0,@fw,@fh); self.z=(@p["z"]||@d["z"]||20).to_i
    rescue
      dispose rescue nil
    end
    def update
      super; return if disposed? || !bitmap
      dx=($game_map.display_x.to_f/Game_Map::X_SUBPIXELS);dy=($game_map.display_y.to_f/Game_Map::Y_SUBPIXELS)
      self.x=(@p["x"].to_i*Game_Map::TILE_WIDTH-dx).round; self.y=(@p["y"].to_i*Game_Map::TILE_HEIGHT-dy).round
      @tick+=1; interval=[(Graphics.frame_rate.to_f/@fps).round,1].max
      if @tick>=interval;@tick=0;@frame=(@frame+1)%@frames;self.src_rect.x=@frame*@fw;end
    end
  end
  end
end
if defined?(Spriteset_Map) && defined?(CarnekStudio::DynamicTileSprite)
  class Spriteset_Map
    alias __carnek_dt_init initialize unless method_defined?(:__carnek_dt_init)
    def initialize(*args)
      __carnek_dt_init(*args); @carnek_dynamic_tiles=[]; carnek_build_dynamic_tiles
    end
    def carnek_build_dynamic_tiles
      return unless $game_map
      vp = @viewport1 || @viewport || @map_viewport
      CarnekStudio::DynamicTiles.placements($game_map.map_id).each do |p|
        d=CarnekStudio::DynamicTiles.definition(p["tile"]); next unless d
        s=CarnekStudio::DynamicTileSprite.new(vp,p,d); @carnek_dynamic_tiles << s unless s.disposed?
      end
    end
    alias __carnek_dt_update update unless method_defined?(:__carnek_dt_update)
    def update
      __carnek_dt_update; (@carnek_dynamic_tiles||[]).each{|s|s.update unless s.disposed?}
    end
    alias __carnek_dt_dispose dispose unless method_defined?(:__carnek_dt_dispose)
    def dispose
      (@carnek_dynamic_tiles||[]).each{|s|s.dispose rescue nil}; __carnek_dt_dispose
    end
  end
end
if defined?(Game_Player)
  class Game_Player
    alias __carnek_dt_passable passable? unless method_defined?(:__carnek_dt_passable)
    def passable?(x,y,d,*args)
      nx=x;ny=y; case d;when 2 then ny+=1;when 4 then nx-=1;when 6 then nx+=1;when 8 then ny-=1;end
      return false if $game_map && CarnekStudio::DynamicTiles.blocked?($game_map.map_id,nx,ny)
      __carnek_dt_passable(x,y,d,*args)
    end
  end
end

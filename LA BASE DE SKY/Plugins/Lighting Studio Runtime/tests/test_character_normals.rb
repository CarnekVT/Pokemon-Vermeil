# Run from LA BASE DE SKY: ruby "Plugins/Lighting Studio Runtime/tests/test_character_normals.rb"
# A tiny RGSS mock that checks cached normal illumination without booting mkxp.
class Color
  attr_accessor :red,:green,:blue,:alpha
  def initialize(r,g,b,a=255); @red,@green,@blue,@alpha=r,g,b,a; end
end
class Bitmap
  attr_reader :width,:height
  attr_accessor :raw_data
  def initialize(width,height=nil)
    if height.nil?
      @width=4;@height=4
      @raw_data=Array.new(16){[255,128,128,255]}.flatten.pack('C*')
    else
      @width=width;@height=height;@raw_data="\0"*(width*height*4)
    end
    @disposed=false
  end
  def disposed?; @disposed; end
  def dispose; @disposed=true; end
end
module Graphics
  def self.frame_count; @frames||=1; end
  def self.advance; @frames=frame_count+1; end
end
class Sprite
  attr_accessor :bitmap,:visible,:x,:y,:z,:ox,:oy,:zoom_x,:zoom_y,:angle,:mirror,:opacity,:blend_type
  def initialize(viewport=nil);@visible=true;@src_rect=Rect.new(0,0,4,4);end
  def src_rect;@src_rect;end
  def viewport;nil;end
  def disposed?;@disposed||false;end
  def dispose;@disposed=true;end
end
class Rect
  attr_accessor :x,:y,:width,:height
  def initialize(x,y,w,h);@x,@y,@width,@height=x,y,w,h;end
  def set(x,y,w,h);initialize(x,y,w,h);end
end
class Sprite_Character < Sprite
  attr_accessor :character
  def update;end
end
class Game_Map
  TILE_WIDTH=32;TILE_HEIGHT=32
  def map_id;79;end
end
module LightingStudio
  def self.load_map(map_id)
    {'enabled'=>true,'lights'=>[{'x'=>5.5,'y'=>5.5,'radiusPx'=>192,
      'color'=>'#FFD080','intensity'=>0.9}]}
  end
  def self.number(v,d,lo,hi); [[(v||d).to_f,lo].max,hi].min;end
  def self.hex_color(hex)
    [hex[1,2],hex[3,2],hex[5,2]].map{|c| c.to_i(16)}
  end
  def self.normal_for_character(c);'mock.png';end
end
$game_map=Game_Map.new
class CharacterMock
  attr_accessor :x,:y
  def initialize(x,y);@x,@y=x,y;end
  def map;$game_map;end
  def character_name;'trainer_POKEMONTRAINER_Red';end
end
$game_player=CharacterMock.new(5,5)
source=File.expand_path('../003_CharacterNormals.rb',__dir__)
load source
mod=LightingStudioNormals
raise "direction selection failed" unless (info=mod.nearby_light($game_player)) && info[2]>0
path='mock.png'
left=mod.frame_bitmap(path,[0,0,4,4],0,[255,200,150])
raise "no lit frame" if !left||left.raw_data.bytesize!=64
Graphics.advance
right=mod.frame_bitmap(path,[0,0,4,4],4,[255,200,150])
raise "direction response equal" unless left.raw_data.getbyte(0)>right.raw_data.getbyte(0)
raise "cache not reused" unless mod.frame_bitmap(path,[0,0,4,4],0,[255,200,150]).equal?(left)
mod.mode=:normals
raise "debug mode failed" unless mod.mode==:normals
mod.mode=:lit
sprite=Sprite_Character.new
sprite.character=$game_player
sprite.bitmap=Bitmap.new(4,4)
sprite.update
raise "player overlay not created" unless sprite.instance_variable_get(:@ls_normal_overlay)
sprite.dispose
mod.release
puts "Character normals cached lighting mock tests passed"

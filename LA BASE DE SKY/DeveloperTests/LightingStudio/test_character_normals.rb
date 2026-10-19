# Run from LA BASE DE SKY: ruby "DeveloperTests/LightingStudio/test_character_normals.rb"
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
module System
  def self.uptime; @time||=0.0; end
  def self.uptime=(n); @time=n; end
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
  X_SUBPIXELS=4;Y_SUBPIXELS=4
  def map_id;79;end
end
module LightingStudio
  def self.load_map(map_id)
    @mock_map || {'enabled'=>true,'lights'=>[{'x'=>5.5,'y'=>5.5,'radiusPx'=>192,
      'color'=>'#FFD080','intensity'=>0.8,'pulse'=>{
        'enabled'=>true,'speedHz'=>1.0,'intensity'=>0.5,
        'radius'=>0.3,'phase'=>0
      }}]}
  end
  def self.number(v,d,lo,hi); [[(v||d).to_f,lo].max,hi].min;end
  def self.hex_color(hex)
    [hex[1,2],hex[3,2],hex[5,2]].map{|c| c.to_i(16)}
  end
  def self.normal_for_character(c);'mock.png';end
  def self.pulse_values(pulse,now)
    return [1.0,1.0] unless pulse.is_a?(Hash) && pulse['enabled']
    wave=Math.sin(now*2.0*Math::PI*pulse['speedHz'].to_f)
    [[0.1,1.0+wave*pulse['radius'].to_f].max,
     [0.0,1.0+wave*pulse['intensity'].to_f].max]
  end
end
$game_map=Game_Map.new
class CharacterMock
  attr_accessor :x,:y,:real_x,:real_y
  def initialize(x,y);@x,@y=x,y;@real_x=x*128;@real_y=y*128;end
  def map;$game_map;end
  def character_name;'trainer_POKEMONTRAINER_Red';end
end
$game_player=CharacterMock.new(5,5)
source=File.expand_path('../../Plugins/Lighting Studio Runtime/003_CharacterNormals.rb',__dir__)
load source
mod=LightingStudioNormals
raise "direction selection failed" unless (info=mod.nearby_light($game_player)) && info[2]>0
# A bright pulse must affect normal lighting strength, using map pulse values.
System.uptime=0.0
normal_strength=mod.nearby_light($game_player)[2]
System.uptime=0.25
bright_strength=mod.nearby_light($game_player)[2]
raise "pulse intensity not reflected in normal lighting" unless bright_strength>normal_strength
System.uptime=0.75
dim_strength=mod.nearby_light($game_player)[2]
raise "pulse did not dim normal lighting" unless dim_strength<normal_strength
System.uptime=0.0

# The falloff reaches zero smoothly instead of abruptly disappearing at radius.
values=[0.8,0.85,0.92,1.0].map{|t| mod.smooth_edge(t)}
raise "falloff does not taper correctly" unless values[0]>values[1] && values[1]>values[2] && values[2]==0.0 && values[3]==0.0
raise "falloff not monotonic" unless values[0]>=values[1] && values[1]>=values[2] && values[2]>=values[3]

# REGRESSION: Narrow ellipse/rectangle zones were excluding the player
# even though the edge of the sprite was visibly illuminated in-game.
['ellipse','rectangle'].each do |kind|
  LightingStudio.instance_variable_set(:@mock_map,{
    'enabled'=>true,
    'lights'=>[{'x'=>5.5,'y'=>5.5,'type'=>kind,'widthPx'=>64,
      'heightPx'=>64,'intensity'=>0.9,'radiusPx'=>96,'color'=>'#FFD080'}]
  })
  mod.clear_lights
  near=CharacterMock.new(6.5,5.0) # center is 48px from lamp; area half-width=32px
  influence=mod.nearby_light(near)
  raise "#{kind} normal lighting disappeared at sprite boundary" unless
    influence && influence[2]>0.1
end
LightingStudio.instance_variable_set(:@mock_map,nil)
mod.clear_lights
# Live sprite update should keep the baked overlay while leaving the light.
Graphics.advance
sprite=Sprite_Character.new
sprite.character=$game_player
sprite.bitmap=Bitmap.new(4,4)
System.uptime=0.12
sprite.update
normal_overlay=sprite.instance_variable_get(:@ls_normal_overlay)
raise "normal lighting invisible near lamp" unless normal_overlay &&
  normal_overlay.visible && normal_overlay.opacity>0
$game_player.x=20
$game_player.real_x=20*128
System.uptime=0.2
Graphics.advance
sprite.update
raise "normal layer disappeared instead of fading" unless
  normal_overlay.visible && normal_overlay.opacity>0
$game_player.x=5
$game_player.real_x=5*128
sprite.dispose


# Retain the existing baked layer during fade-out, even after the light is gone.
fake=Sprite.new
a=mod.eased_opacity(fake,180,0.0)
b=mod.eased_opacity(fake,180,0.08)
c=mod.eased_opacity(fake,0,0.16)
raise "no smooth attack" unless b>a && a>0 && b<180
raise "normal layer popping on exit" unless c>0 && c<b
d=c
30.times{|i| d=mod.eased_opacity(fake,0,0.24+0.08*i)}
raise "normal overlay never fades out" unless d==0

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

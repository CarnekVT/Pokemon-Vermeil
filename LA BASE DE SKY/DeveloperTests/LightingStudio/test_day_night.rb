# encoding: UTF-8
# Run from LA BASE DE SKY: ruby "DeveloperTests/LightingStudio/test_day_night.rb"
require 'json'

module System
  @uptime=120.0
  def self.uptime;@uptime;end
  def self.uptime=(value);@uptime=value.to_f;end
end

module LightingStudio
  DATA_PATH='Data/LightingStudio/maps.json'
  def self.hex_color(value)
    [value[1,2],value[3,2],value[5,2]].map{|v|v.to_i(16)}
  end
  def self.load_map(id)
    JSON.parse(File.binread(DATA_PATH)).fetch('maps').fetch(id.to_s)
  end
end

$PokemonGlobal=Object.new
$game_map=Struct.new(:map_id).new(79)
class ClockTestSpriteset
  attr_reader :calls
  def initialize;@calls=0;end
  def ls_update_day_night(force=false)
    @calls+=1 if force
  end
end
spriteset=ClockTestSpriteset.new
$scene=Struct.new(:spriteset).new(spriteset)

def _INTL(value,*args)
  value.gsub(/\{(\d+)\}/){args[$1.to_i-1].to_s}
end
$bag_responses=[]
$bag_choices=[]
$bag_prompts=[]
def pbMessage(message,choices=nil,*_rest)
  $bag_prompts << message
  if choices
    $bag_choices=choices
    return $bag_responses.shift || -1
  end
  0
end

# Native Tone and vanilla tile tint mock. In-game these are provided by RGSS
# and PBDayNight; the Lighting Studio plugin must compose/suppress correctly.
class Tone
  attr_accessor :red,:green,:blue,:gray
  def initialize(r=0,g=0,b=0,a=0)
    set(r,g,b,a)
  end
  def set(r,g,b,a);@red,@green,@blue,@gray=r,g,b,a;end
end
class TileToneTest
  attr_reader :tone
  def initialize;@tone=Tone.new;end
end
def pbDayNightTint(object)
  object.tone.set(-70,-90,15,55)
end


class LightTestViewport
  attr_accessor :tone
  def disposed?;false;end
end
class Spriteset_Map
  def self.viewport; @viewport ||= LightTestViewport.new;end
end
class Scene_Map
  def updateSpritesets(refresh=false)
    Spriteset_Map.viewport.tone=Tone.new(0,0,0,0)
  end
end
$game_screen=Struct.new(:tone).new(Tone.new(-5,-3,2,3))

load 'Plugins/Lighting Studio Runtime/004_DayNight.rb'
time=LightingStudioDayNight
raise 'RGBG native Tone not selected' unless time.native_tone?
raise 'Neutral daytime tone must not wash tiles' unless time.tone_values(12)==[0,0,0,0]
night=time.tone_values(23)
raise 'Evening Tone should darken red and green gently' unless night[0]<0 && night[1]<0 &&
  night[2]>=0 && night[3]>0
composed=time.compose_tone(Tone.new(-8,5,2,8),night)
raise 'RGSS event tone lost' unless composed.red==night[0]-8 &&
  composed.green==night[1]+5 && composed.blue==night[2]+2 && composed.gray==night[3]+8
Scene_Map.new.updateSpritesets
final_tone=Spriteset_Map.viewport.tone
actual_clock_tone=time.tone_values
raise 'Final viewport tone not applied after spritesets' unless
  [final_tone.red,final_tone.green,final_tone.blue,final_tone.gray]==
  [actual_clock_tone[0]-5,actual_clock_tone[1]-3,
   actual_clock_tone[2]+2,actual_clock_tone[3]+3]
renderer=TileToneTest.new
pbDayNightTint(renderer)
raise 'Vanilla tone duplicated custom cycle' unless [renderer.tone.red,renderer.tone.green,renderer.tone.blue,renderer.tone.gray]==[0,0,0,0]
time.settings['enabled']=false
pbDayNightTint(renderer)
raise 'Vanilla tone failed to recover outside custom clock' unless renderer.tone.red==-70
time.settings['enabled']=true
raise 'Clock config was not saved' unless time.settings['enabled']==true &&
  time.settings['source']=='internal'
raise 'Map 79 ignores the clock' unless time.active_on_map?(LightingStudio.load_map(79))
raise 'Map 79 keyframes are absent' unless time.keyframes.length>=2

time.set_internal_time(0,0)
midnight=time.ambient(LightingStudio.load_map(79))
time.set_internal_time(12,0)
noon=time.ambient(LightingStudio.load_map(79))
raise 'Day-night tint does not change' if midnight==noon
raise 'Noon should have no darkness' unless noon[1].abs<0.001
raise 'Immediate lighting refresh not called' unless spriteset.calls==2
raise 'Hour is incorrect' unless (time.current_hour-12.0).abs<0.0001
raise 'Clock diagnostic not working' unless time.debug_status[:enabled]==true

load 'Plugins/Lighting Studio Runtime/005_SleepingBag.rb'
# Minimal RGSS mock to validate event-like white fade, sound and timing.
class Color
  def initialize(*rgba);@rgba=rgba;end
end
class Bitmap
  def initialize(w,h);@disposed=false;end
  def set_pixel(*args);end
  def disposed?;@disposed;end
  def dispose;@disposed=true;end
end
class Viewport
  attr_accessor :z
  def initialize(*bounds);@disposed=false;end
  def disposed?;@disposed;end
  def dispose;@disposed=true;end
end
class Sprite
  attr_accessor :bitmap,:zoom_x,:zoom_y,:opacity
  def initialize(*args);@disposed=false;end
  def disposed?;@disposed;end
  def dispose;@disposed=true;end
end
module Graphics
  @updates=0
  def self.width;640;end
  def self.height;480;end
  def self.update;@updates+=1;end
  def self.updates;@updates;end
end
module Input
  def self.update;end
end
$me_count=0
def pbMEPlay(name)
  raise 'Incorrect sleep ME' unless name=='Pokemon Healing'
  $me_count+=1
end

hours=[7,11,15,17,19,23]
hours.each_with_index do |hour,index|
  time.set_internal_time(8,0)
  $bag_responses=[index]
  before=spriteset.calls
  raise "Sleeping Bag did not change time for slot #{index}" unless time.use_sleeping_bag
  raise "Sleeping Bag hour #{index} incorrect" unless (time.current_hour-hour).abs<0.0001
  raise "Sleeping Bag must display all six slots" unless $bag_choices.length==6
  raise "Sleeping Bag choice order changed" unless $bag_choices==['7 a.m.','11 a.m.','3 p.m.','5 p.m.','7 p.m.','11 p.m.']
  raise "Sleeping Bag prompt differs from the reference" unless $bag_prompts[-2].include?('¿A qué hora quieres despertar?')
  raise "Sleeping Bag did not request ambient refresh" unless spriteset.calls>before
end
raise "Wrong six slots" unless LightingStudioDayNight::SLEEPING_BAG_SLOTS.map{|a|a[0]}==hours

# Directional lighting windows: overnight, daytime, gradual edges.
schedule={'enabled'=>true,'startHour'=>19,'endHour'=>7,'fadeMinutes'=>20}
raise "Lamp visible at noon" unless time.schedule_factor(schedule,12)==0.0
raise "Night lamp off at midnight" unless time.schedule_factor(schedule,0)>0.99
raise "Lamp must fade in at 19:10" unless (time.schedule_factor(schedule,19+10.0/60)-0.5).abs<0.00001
raise "Lamp must fade out at 06:50" unless (time.schedule_factor(schedule,6+50.0/60)-0.5).abs<0.00001
raise "Legacy light must stay on" unless time.schedule_factor(nil,12)==1.0
raise "Manual clock disabled should ignore schedule" unless time.schedule_factor({'enabled'=>false},12)==1.0
instant={'enabled'=>true,'startHour'=>19,'endHour'=>7,'fadeMinutes'=>0}
raise "Lamp should light at exactly 19:00" unless time.schedule_factor(instant,19)==1.0
raise "Lamp should remain lit at 06:59" unless time.schedule_factor(instant,6.99)==1.0
raise "Lamp should switch off at 07:00" unless time.schedule_factor(instant,7)==0.0

raise 'Sleeping Bag forced no map refresh' unless spriteset.calls>=14
raise 'Sleeping Bag ME did not play 6 times' unless $me_count==6
raise 'Sleep transition did not use 80 graphics frames per skip' unless Graphics.updates==6*80

puts 'Lighting Studio day/night, single-page sleeping bag hours and immediate refresh tests passed'

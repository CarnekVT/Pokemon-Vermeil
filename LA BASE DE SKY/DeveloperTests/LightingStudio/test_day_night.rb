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
$bag_choice=0
$bag_choices=[]
$bag_prompts=[]
def pbMessage(message,choices=nil,*_rest)
  $bag_prompts << message
  if choices
    $bag_choices=choices
    return $bag_choice
  end
  0
end

load 'Plugins/Lighting Studio Runtime/004_DayNight.rb'
time=LightingStudioDayNight
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
hours=[6,9,12,15,18,21]
hours.each_with_index do |hour,index|
  time.set_internal_time(8,0)
  $bag_choice=index
  raise 'Sleeping Bag did not advance time' unless time.use_sleeping_bag
  raise "Sleeping Bag hour #{index} incorrect" unless (time.current_hour-hour).abs<0.0001
  raise 'Sleeping Bag must expose exactly six times and Cancel' unless $bag_choices.length==7
  raise 'Sleeping Bag prompt is not natural' unless $bag_prompts[-2].include?('¿A qué hora quieres despertar?')
end
raise 'Sleeping Bag forced no map refresh' unless spriteset.calls>=14
puts 'Lighting Studio day/night, fixed sleeping hours and immediate refresh tests passed'

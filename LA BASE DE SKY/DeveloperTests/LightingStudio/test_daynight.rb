# Run from LA BASE DE SKY: ruby DeveloperTests/LightingStudio/test_daynight.rb
# Clock+item regression without Pokémon Essentials or mkxp.
module System
  def self.uptime; @now||=0.0; end
  def self.uptime=(x);@now=x;end
end
module LightingStudio
  def self.hex_color(str)
    [str[1,2],str[3,2],str[5,2]].map { |v| v.to_i(16) }
  end
end
module ItemHandlers
  module UseFromBag
    @entries={}
    def self.add(id,callback);@entries[id]=callback;end
    def self.handler(id);@entries[id];end
  end
  module UseInField
    @entries={}
    def self.add(id,callback);@entries[id]=callback;end
    def self.handler(id);@entries[id];end
  end
end
def _INTL(str,*args)
  str.gsub(/\{(\d+)\}/) { |m| args[$1.to_i-1].to_s }
end
$menu_choice=nil
def pbMessage(_text,commands=nil,*args)
  commands ? $menu_choice : 0
end
$PokemonGlobal=Object.new
base=File.expand_path('../../Plugins/Lighting Studio Runtime',__dir__)
load File.join(base,'004_DayNight.rb')
load File.join(base,'005_SleepingBag.rb')
m=LightingStudioDayNight
m.instance_variable_set(:@cached,{
  'enabled'=>true,'source'=>'internal','startHour'=>8,
  'minutesPerSecond'=>1,
  'keyframes'=>[
    {'hour'=>0,'color'=>'#000000','darkness'=>0.8},
    {'hour'=>12,'color'=>'#FFFFFF','darkness'=>0.0}
  ]
})
raise "item not registered" unless ItemHandlers::UseFromBag.handler(:SLEEPINGBAG)
m.set_internal_time(18,30)
raise "set internal clock failed" unless (m.current_hour-18.5).abs<0.001
System.uptime=5
raise "internal clock did not advance" unless m.current_hour>18.5
rgb,dark=m.interpolate(6)
raise "timeline RGB interpolation" unless rgb==[128,128,128] && (dark-0.4).abs<0.001
raise "midnight interpolation" unless m.interpolate(0)[1]==m.interpolate(24)[1]
$menu_choice=0 # 05:00 (first of seven fixed Sleeping Bag slots)
raise "sleeping bag use failed" unless m.use_sleeping_bag
raise "wake time was not applied" unless (m.current_hour-5.0).abs<0.001
$menu_choice=7 # Cancel
raise "cancel must leave time unchanged" if m.use_sleeping_bag
raise "cancel changed clock" unless (m.current_hour-6.0).abs<0.001
m.instance_variable_set(:@cached,{'enabled'=>true,'source'=>'real'})
raise "real clock should disable bag" if m.use_sleeping_bag
puts "Lighting Studio day/night clock and Sleeping Bag tests passed"

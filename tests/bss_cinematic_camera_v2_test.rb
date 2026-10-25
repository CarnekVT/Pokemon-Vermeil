# frozen_string_literal: true
# Stub-only camera contract checks. Does not claim in-game rendering parity.
module Graphics
  def self.width; 640; end
  def self.height; 480; end
end
module BSS064
  def self.log(message); end
end
module BSS070EBDXCore
  def self.get_vector(_, _=nil); [102,408,32,342,1,1]; end
  def self.camera_config; @camera_config ||= {}; end
  def self.set_config(cfg); @camera_config=cfg; end
end
class VectorStub
  attr_accessor :inc
  def initialize(v); @v=v.dup; @goal=v.dup; @inc=0.1; end
  def get; @v.clone; end
  def set(v); @goal=v.clone; end
  def update; @v=@v.each_with_index.map{|x,i| x+(@goal[i]-x)*@inc}; end
end
class SpriteStub
  attr_accessor :x,:y,:zoom_x,:zoom_y
  def initialize; @x=0;@y=0;@zoom_x=1;@zoom_y=1; end
  def disposed?; false; end
end
class BattleStub
  attr_accessor :battlers
  def initialize(n=2); @battlers=(1..n).map{|i| Object.new};end
end
module Battle
  class Scene
    attr_reader :vector, :sprites, :battle
    def initialize
      @vector=VectorStub.new(BSS070EBDXCore.get_vector(:MAIN))
      @battle=BattleStub.new
      @sprites={"pokemon_0"=>SpriteStub.new,"pokemon_1"=>SpriteStub.new,"shadow_0"=>SpriteStub.new,"shadow_1"=>SpriteStub.new}
      @bss070_ebdx_room=Object.new
      def @bss070_ebdx_room.shadows_enabled?; true; end
      @steps=[]
    end
    def bss070_ebdx_active?; true; end
    def bss070_ebdx_camera_enabled?;true; end
    def bss070_ebdx_camera_config;BSS070EBDXCore.camera_config; end
    def bss070_ebdx_native_sprite(i);@sprites["pokemon_#{i}"];end
    def bss070_ebdx_native_shadow_sprite(i);@sprites["shadow_#{i}"];end
    def bss070_ebdx_sprite_loaded?(sp);true;end
    def bss096_native_position(i);i==0 ? [160,360,50,1,1]:[480,190,50,1,1];end
    def bss096_native_shadow_position(i);i==0 ? [160,370,30,1,0.25]:[480,200,30,1,0.25];end
    def pbInitSprites;true;end
    def pbCommandMenu; 7.times { bss070_ebdx_tick }; :command_done; end
    def pbFightMenu; 7.times { bss070_ebdx_tick }; :fight_done; end
    def bss070_ebdx_tick(advance_camera=true,align=true)
      @steps << [advance_camera,align]
      bss070_ebdx_apply_world_alignment if align
      true
    end
    def bss070_ebdx_apply_world_alignment
      @sprites.each do |k,s|
        i=k.end_with?("_0") ? 0 : 1
        row=k.start_with?("shadow") ? bss096_native_shadow_position(i) : bss096_native_position(i)
        s.x=row[0];s.y=row[1];s.zoom_x=row[3];s.zoom_y=row[4]
      end
      true
    end
    def bss070_ebdx_camera_enter(*args);false;end
    def bss070_ebdx_camera_leave(*args);false;end
    def bss096_camera_to_main(*args);:old;end
    def bss_layered_next_ebdx_shot(*args);:old;end
    def bss083_settle_camera(*args);:old;end
    def bss_unified_camera_to(*args);:old;end
  end
end
require_relative '044_Cinematic_Camera_Director'
def assert(message,cond)
  raise message unless cond
end
assert('loaded',Battle::Scene.ancestors.include?(VermeilBSSCinemaScene))
s=Battle::Scene.new
s.pbInitSprites
assert('enabled',s.vermeil_cinema_active?)
assert('initial phase idle',s.vermeil_cinema_phase==:idle)
ref=BSS070EBDXCore.get_vector(:MAIN)
80.times{s.bss070_ebdx_tick}
v=s.vector.get
assert('idle zoom actually moves',v[4]>1.015)
assert('environment tick delegated with no competing old advance',s.instance_variable_get(:@steps).all?{|row|row[0]==false})
assert('battler anchored with same zoom',s.sprites['pokemon_0'].zoom_x>1.015)
assert('shadow follows same absolute framing',s.sprites['shadow_0'].zoom_x>1.015)
old=[s.sprites['pokemon_0'].x,s.sprites['pokemon_0'].y,s.sprites['pokemon_0'].zoom_x]
s.bss070_ebdx_apply_world_alignment
newp=[s.sprites['pokemon_0'].x,s.sprites['pokemon_0'].y,s.sprites['pokemon_0'].zoom_x]
assert('idempotent alignment',old==newp)
idle_zoom=s.vector.get[4]
s.pbCommandMenu
cmd=s.vector.get
assert('command zoom stronger',cmd[4]>idle_zoom)
assert('command returns idle',s.vermeil_cinema_phase==:idle)
s.pbFightMenu
fight=s.vector.get
assert('fight zoom stronger',fight[4]>cmd[4])
assert('fight returns idle',s.vermeil_cinema_phase==:idle)
freeze=s.vector.get
s.instance_variable_set(:@bss_shared_camera_depth,1)
def s.bss_shared_camera_leased?; @bss_shared_camera_depth.to_i>0; end
10.times{s.bss070_ebdx_tick}
assert('BAS lease freezes world camera',s.vector.get==freeze)
s.instance_variable_set(:@bss_shared_camera_depth,0)
s.bss070_ebdx_tick
assert('BAS release resumes',s.vector.get!=freeze)
assert('no more MAIN snap',s.bss096_camera_to_main==false)
assert('no old random shot',s.bss_layered_next_ebdx_shot.nil?)
BSS070EBDXCore.set_config({'preset'=>'static'})
assert('static respected',!s.vermeil_cinema_active?)
assert('static legacy dispatcher used',s.bss096_camera_to_main==:old)
BSS070EBDXCore.set_config({'preset'=>'gen5_plus','cinematicCamera'=>false})
assert('explicit disable respected',!s.vermeil_cinema_active?)
BSS070EBDXCore.set_config({})
puts 'CAMERA V2 TESTS PASS: 16 camera/ownership/compatibility assertions'
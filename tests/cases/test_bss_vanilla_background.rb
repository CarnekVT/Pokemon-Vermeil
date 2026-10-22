require 'minitest/autorun'

# Minimal runtime stubs: test renderer routing and update contracts without assets.
class Viewport
  Rect = Struct.new(:x,:y,:width,:height)
  attr_accessor :z, :color
  attr_reader :rect
  def initialize(x=0,y=0,w=640,h=480)
    @rect=Rect.new(x,y,w,h);@z=50;@disposed=false
  end
  def disposed?; @disposed; end
  def dispose; @disposed=true; end
end
class BSS070EBDXVector
  attr_accessor :inc
  attr_reader :updates
  def initialize(*);@updates=0;end
  def snap(*);end
  def set(*);end
  def update;@updates+=1;end
end
class BSS070EBDXRoom
  attr_reader :data, :updates, :refreshes, :viewport
  def initialize(viewport,scene,data)
    @viewport=viewport;@scene=scene;@data=data;@updates=0;@refreshes=0;@disposed=false
  end
  def refresh(data); @refreshes+=1;@data=data; end
  def update; @updates+=1; end
  def dispose; @disposed=true; end
  def disposed?; @disposed; end
end
class BSS070CustomRoom < BSS070EBDXRoom; end
class StubBattle
  attr_accessor :bss_environment_config
  def initialize(env={});@bss_environment_config=env;end
end
class FakeSprite
  attr_accessor :visible, :opacity
  def initialize;@visible=true;@opacity=255;end
end
class Battle
  class Scene
    attr_reader :sprites, :native_ticks
    def initialize(battle,renderer=BSS070EBDXRoom)
      @battle=battle;@renderer=renderer;@viewport=Viewport.new
      @sprites={"battle_bg"=>FakeSprite.new,"battle_bg2"=>FakeSprite.new,"base_0"=>FakeSprite.new,"base_1"=>FakeSprite.new}
      @native_ticks=0
    end
    def bss070_ebdx_room_class(_battle); @renderer; end
    def pbGraphicsUpdate(*); @native_ticks+=1; :native_done; end
  end
end
module BSS070EBDXCore
  class << self
    attr_accessor :mapped, :scene_data, :active
    def active_for_battle?(_battle);!!@active;end
    def map_backdrop;@mapped;end
    def get_vector(*);[100,400,30,340,1,1];end
    def environment_for(_stub);@scene_data;end
  end
end
module BSSLightingClockBridge
  class << self
    attr_accessor :phase
    def active?; !@phase.nil?; end
    def night?; @phase==:night;end
    def dawn?;@phase==:dawn;end
    def slot(_data=nil);@phase;end
  end
end
require_relative '../../LA BASE DE SKY/Plugins/[CARNEK] Battle Scene Studio Runtime/90_CustomRooms/038_Fondos_EBDX_Vanilla'

class BattleSceneVanillaBackgroundTest < Minitest::Test
  def setup
    BSS070EBDXCore.mapped='Field';BSS070EBDXCore.active=false
    BSS070EBDXCore.scene_data={'backdrop'=>'Field','sky'=>true,'outdoor'=>true}
    BSSLightingClockBridge.phase=:day
  end
  def test_standard_renderer_and_live_tick
    scene=Battle::Scene.new(StubBattle.new)
    assert BSSZBoxFondosEBDXVanilla.install(scene)
    room=scene.sprites['battlebg']
    assert_equal BSS070EBDXRoom,room.class.superclass
    assert_equal 1,room.updates
    assert_equal :native_done,scene.pbGraphicsUpdate
    assert_equal 2,room.updates
    assert_equal false,scene.sprites['battle_bg'].visible
    assert_equal false,scene.sprites['base_0'].visible
    assert BSSZBoxFondosEBDXVanilla.install(scene)
    room.dispose
    assert room.viewport.disposed?
  end
  def test_custom_renderer_keeps_custom_layers
    BSS070EBDXCore.scene_data={'backdrop'=>'Island','img001'=>{'bitmap'=>'foam'},'outdoor'=>true}
    scene=Battle::Scene.new(StubBattle.new,BSS070CustomRoom)
    assert BSSZBoxFondosEBDXVanilla.install(scene)
    assert_equal BSS070CustomRoom,scene.sprites['battlebg'].class.superclass
  end
  def test_lighting_time_switch_rebuilds_only_on_boundary
    scene=Battle::Scene.new(StubBattle.new)
    assert BSSZBoxFondosEBDXVanilla.install(scene)
    room=scene.sprites['battlebg']
    room.update
    assert_equal 0,room.refreshes
    BSSLightingClockBridge.phase=:night
    room.update
    assert_equal 1,room.refreshes
    room.update
    assert_equal 1,room.refreshes
  end
  def test_does_not_override_ebdx_engine_or_unspecified_vanilla
    BSS070EBDXCore.active=true
    scene=Battle::Scene.new(StubBattle.new)
    refute BSSZBoxFondosEBDXVanilla.install(scene)
    assert_nil scene.sprites['battlebg']
    BSS070EBDXCore.active=false;BSS070EBDXCore.mapped=nil
    refute BSSZBoxFondosEBDXVanilla.install(scene)
    scene2=Battle::Scene.new(StubBattle.new({'ebdxBackdrop'=>'Field'}))
    assert BSSZBoxFondosEBDXVanilla.install(scene2)
  end
end

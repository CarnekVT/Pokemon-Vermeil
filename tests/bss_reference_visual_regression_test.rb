# frozen_string_literal: true
# Run from the repository root:
#   ruby tests/bss_reference_visual_regression_test.rb
#
# These are syntax and core-contract tests. They do not simulate graphics,
# timing, physical input polling or BSS/BAS playback in mkxp-z.
require "ripper"
root=File.expand_path("..",__dir__)
plugin=File.join(root,"LA BASE DE SKY","Plugins")
bss=File.join(plugin,"[CARNEK] Battle Scene Studio Runtime")
input=File.join(plugin,"[VERMEIL] Input Studio","001_Core.rb")
paths={
  "Input Studio"=>input,
  "BSS Dialogue Engine"=>File.join(bss,"00_Base","005_Boss_Midbattle_Dialogues.rb"),
  "Native trainer floor"=>File.join(bss,"10_EBDX_Source","005_Faithful_EBDX_Room.rb"),
  "World actor projection"=>File.join(bss,"70_Runtime_Pipeline","031_World_Battlers_Intro.rb"),
  "Native sendout authority"=>File.join(bss,"80_Stability","034_Stability_Reset.rb"),
  "Presentation camera"=>File.join(bss,"99_Hotfix","044_Cinematic_Camera_Director.rb"),
  "NDS intro"=>File.join(bss,"99_Hotfix","050_NDS_Intro_Camera_Handoff.rb"),
  "Layered lighting"=>File.join(bss,"90_CustomRooms","039_Lighting_Layered_Backdrops.rb"),
  "Animated Pokemon"=>File.join(plugin,"[LBDS] Sprites Animados DBK","[006] Battler Sprites.rb"),
  "Trainer z order"=>File.join(bss,"99_Hotfix","051_Camera_Phase_and_Depth_Authority.rb"),
  "Scripted camera lock"=>File.join(bss,"99_Hotfix","049_Scripted_Speech_Camera_Hold.rb")
}
def assert(label,pass)
  raise "FAIL: #{label}" unless pass
end

paths.each do |label,path|
  assert("exists: #{label}",File.file?(path))
  assert("Ruby parses: #{label}",!!Ripper.sexp(File.read(path,encoding:"UTF-8")))
end
assert("obsolete visibility hotfix removed",
       !File.exist?(File.join(bss,"99_Hotfix","052_Battler_Visibility_and_Cinematic_HUD.rb")))
assert("obsolete review fixes removed",
       !File.exist?(File.join(bss,"99_Hotfix","998_BSS_Review_Fixes.rb")))
source=File.read(input)
legacy=source.split("LEGACY_STUDIO_ACTIONS = {",2)[1].split("}.freeze",2)[0]
assert("native directions not intercepted globally",
       !legacy.match?(/\b(?:UP|DOWN|LEFT|RIGHT)\s*=>/))
assert("map movement checks BSS runtime owner",source.include?("BSS064.instance_variable_get(:@running)"))
intro=File.read(paths["NDS intro"])
assert("intro timing in seconds, not 20 frames",intro.include?("HOLD_SECONDS") && intro.include?("REVEAL_SECONDS"))
assert("intro uses elapsed wall clock",intro.include?("Time.now.to_f-began"))
assert("native intro animations have qualified owner",intro.include?("Battle::Scene::Animation::DataBoxAppear.new") &&
       intro.include?("Battle::Scene::Animation::Intro2.new"))
assert("intro captures scenery separately",intro.include?("captured=[]") &&
       intro.include?("captured.each") && intro.include?("pbFrameUpdate"))
assert("animated trainer plays during reveal",intro.include?("trainer.play") &&
       intro.include?("pbAnimateTrainerIntros"))
assert("impact timing shortened",intro.include?("HOLD_SECONDS = 0.12") &&
       intro.include?("REVEAL_SECONDS = 0.82"))
camera=File.read(paths["Presentation camera"])
assert("real-time camera sweeps exist",camera.include?("SWEEP_SECONDS = 3.0") &&
       camera.include?("vermeil_cinema_sweep_tick"))
assert("slow camera moves in command and idle",camera.include?("phase==:idle || phase==:command"))
assert("bag and party return to MAIN",camera.include?("vermeil_cinema_queue_home") &&
       camera.include?("choice!=0") && camera.include?("vermeil_cinema_home_tick"))
assert("scripted dialogue owns camera vector",camera.include?("@vermeil_cinema_script_camera_hold") &&
       File.read(paths["Scripted camera lock"]).include?("script_camera_hold"))
assert("trainer kept above Pokemon and terrain",
       File.read(paths["Trainer z order"]).include?("trainer.z=[trainer.z.to_i,foe_z+2,52+i].max"))
assert("wild opponent trainer count is nil-safe",
       File.read(paths["Native trainer floor"]).include?("owners.respond_to?(:length)"))
assert("MAIN zoom-out is normalized baseline",
       File.read(paths["Native trainer floor"]).include?("342,0.86,0.86"))
assert("zero-sized native sendout zoom is not treated as neutral",
       File.read(paths["Native trainer floor"]).include?("bss070_ebdx_safe_metric_scale") &&
       File.read(paths["Native trainer floor"]).include?("x>0.02 && y>0.02"))
world=File.read(paths["World actor projection"])
assert("both player and enemy doubles gain lateral space",
       world.include?("[-21.0,27.0]") && world.include?("[-15.0,22.0]"))
assert("both player and enemy triples gain lateral space",
       world.include?("[-28.0,3.0,36.0]") && world.include?("[-21.0,3.0,26.0]"))
native=File.read(paths["Native sendout authority"])
assert("stable visibility check recognizes BAS leases",
       native.include?("bss106_stable_battler_frame?") &&
       native.include?("@bas_runtime_playback_depth.to_i>0"))
assert("scene update reconciles DBK logical visibility",
       native.include?("bss106_restore_active_battlers"))
assert("visual recovery detects zero zoom without touching BAS playback",
       native.include?("collapsed=sp.respond_to?(:zoom_x)") &&
       native.include?("sp.zoom_x=scale[0]") &&
       native.include?("@bas_runtime_playback_depth.to_i>0"))
dialogue=File.read(paths["BSS Dialogue Engine"])
lighting=File.read(paths["Layered lighting"])
assert("cinematic overlay has separate tween targets",dialogue.include?("dim_target,1.0") &&
       dialogue.include?("dim_target,0.0"))
assert("layered lighting advances fades every update",lighting.include?("duration=target>alpha ? 0.30 : 0.44"))
animated=File.read(paths["Animated Pokemon"])
assert("animated sprite drops old vanish state on replacement",animated.include?("!previous.equal?(pkmn)") &&
       animated.include?("pkmnSprite.vanishMode = 0"))

# Real BSS106 native sendout completion logic with stubbed battle actors.
module BSS064
  def self.log(*);end
end
class Battle
  class Scene
    class BattlerSprite
      attr_reader :pkmn
      attr_accessor :vanishMode,:opacity,:substitute,:selected,:zoom_x,:zoom_y
      def initialize(pokemon)
        @pkmn=pokemon
        @visible=false
        @spriteVisible=false
        @vanishMode=2
        @opacity=0
        @zoom_x=1.0
        @zoom_y=1.0
      end
      def visible=(flag)
        @spriteVisible=flag
        @visible=flag
      end
      def visible;@visible;end
      def disposed?;false;end
      def update
        @visible=@spriteVisible
      end
    end
  end
end
load paths["Native sendout authority"]
scene=Battle::Scene.new
def scene.bss070_ebdx_anchor_scale(_idx);[1.0,1.0];end
old_pokemon=Object.new
new_pokemon=Object.new
battler=Struct.new(:index,:pokemon,:faint) do
  def fainted?;!!faint;end
end.new(1,old_pokemon,false)
sprite=Battle::Scene::BattlerSprite.new(old_pokemon)
scene.instance_variable_set(:@battle,Struct.new(:battlers).new([nil,battler]))
scene.instance_variable_set(:@sprites,{"pokemon_1"=>sprite,"trainer_1"=>Object.new})
scene.bss106_finish_sendout([[1,old_pokemon]])
assert("first Pokemon is revealed",sprite.visible && sprite.opacity==255 && sprite.vanishMode==0)
sprite.update
assert("DBK logical visible state persists",sprite.visible)
battler.pokemon=new_pokemon
sprite=Battle::Scene::BattlerSprite.new(new_pokemon)
scene.instance_variable_set(:@sprites,{"pokemon_1"=>sprite,"trainer_1"=>Object.new})
scene.bss106_finish_sendout([[1,new_pokemon]])
assert("replacement in same slot is revealed",sprite.visible && sprite.vanishMode==0)
assert("native sendout token is tracked",scene.instance_variable_get(:@bss106_presented_pokemon)[1]==new_pokemon.object_id)
sprite.visible=false
sprite.opacity=0
sprite.vanishMode=1
scene.bss106_restore_presented_on_command
assert("command boundary recovers a hidden replacement",sprite.visible && sprite.opacity==255 && sprite.vanishMode==0)
# BAS is the exclusive animation owner. The recovery must never flash
# a target back into view before its authored BAS timeline ends.
scene.instance_variable_set(:@bas_runtime_playback_depth,1)
sprite.visible=false
scene.bss106_restore_active_battlers
assert("BAS playback owns temporary invisible frame",!sprite.visible)
scene.instance_variable_set(:@bas_runtime_playback_depth,0)
scene.bss106_restore_active_battlers
assert("post-BAS stable scene restores logical visibility",sprite.visible)
sprite.zoom_x=0.0
sprite.zoom_y=0.0
scene.bss106_restore_active_battlers
assert("zero zoom is recovered in stable scene frames",sprite.zoom_x==1.0 && sprite.zoom_y==1.0)
sprite.instance_variable_set(:@visible,false)
sprite.selected=2
scene.bss106_restore_active_battlers
assert("native target blink remains respected",!sprite.visible)
sprite.selected=0
sprite.update
battler.faint=true
sprite.visible=false
scene.bss106_finish_sendout([[1,new_pokemon]])
assert("fainted Pokemon not resurrected",!sprite.visible)
puts "BSS CORE REGRESSION TESTS PASS (not an in-game render test)"

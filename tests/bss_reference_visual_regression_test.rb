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
  "NDS intro"=>File.join(bss,"99_Hotfix","050_NDS_Intro_Camera_Handoff.rb")
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
camera=File.read(paths["Presentation camera"])
assert("one stable idle shot at a time",camera.include?("IDLE_HOLD_FRAMES"))
assert("idle camera has actual movement",camera.include?("IDLE_PAN_X") && camera.include?("phase == :idle"))

# Real BSS106 native sendout completion logic with stubbed battle actors.
module BSS064
  def self.log(*);end
end
class Battle
  class Scene
    class BattlerSprite
      attr_reader :pkmn
      attr_accessor :vanishMode,:opacity,:substitute
      def initialize(pokemon)
        @pkmn=pokemon
        @visible=false
        @spriteVisible=false
        @vanishMode=2
        @opacity=0
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
battler.faint=true
sprite.visible=false
scene.bss106_finish_sendout([[1,new_pokemon]])
assert("fainted Pokemon not resurrected",!sprite.visible)
puts "BSS CORE REGRESSION TESTS PASS (not an in-game render test)"

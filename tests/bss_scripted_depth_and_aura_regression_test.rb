# frozen_string_literal: true
# Static/source contract checks. Run from repository root:
# ruby tests/bss_scripted_depth_and_aura_regression_test.rb
# These do NOT replace a real visual test in Pokemon Essentials.
require "ripper"
require "json"

root=File.expand_path("..",__dir__)
runtime=File.join(root,"LA BASE DE SKY","Plugins","[CARNEK] Battle Scene Studio Runtime")
editor=File.join(root,"LA BASE DE SKY","Plugins","MakerStudio","003_Editor","Mods","Battle Scene Studio")
read=lambda { |path| File.read(path,encoding:"UTF-8") }
verify=lambda { |name,ok| raise("BSS regression failed: #{name}") unless ok }
files={
  "dialogues"=>File.join(runtime,"00_Base","005_Boss_Midbattle_Dialogues.rb"),
  "events"=>File.join(runtime,"99_Hotfix","048_Dialogue_Event_Bridge.rb"),
  "speaker"=>File.join(runtime,"99_Hotfix","049_Scripted_Speech_Camera_Hold.rb"),
  "intro"=>File.join(runtime,"99_Hotfix","050_NDS_Intro_Camera_Handoff.rb"),
  "aura"=>File.join(runtime,"00_Base","004_Bosses_Totems.rb")
}
src={}
files.each do |name,path|
  verify.call("#{name} exists",File.file?(path))
  source=read.call(path)
  verify.call("#{name} parses Ruby",!Ripper.sexp(source).nil?)
  src[name]=source
end
verify.call("cinematic trainer option is normalized",src["dialogues"].include?("trainerPortraitMode:"))
verify.call("trainer remains behind battlers",src["speaker"].include?("trainer.z=foes.map(&:to_i).min-1"))
verify.call("portrait depth reapplied before rendering",src["speaker"].include?("bss_scripted_apply_speaker_priority if @bss_dialogue_cinema_active"))
verify.call("only the native trainer is used",src["speaker"].include?("bss_scripted_trainer_actor") && src["speaker"].include?("portrait.visible=false"))
verify.call("042 trainer height is cached once",src["intro"].include?("@bss_nds_trainer_anchor[i+1]"))
verify.call("dialogue reuses cached trainer XY",src["speaker"].include?("@bss_nds_trainer_anchor"))
verify.call("dialogue does not reposition trainer per frame",!src["speaker"].include?("trainer.pbSetPosition"))
verify.call("trainer fades into the authored coordinates",src["intro"].include?("trainer_states.each do |trainer,was_visible,old_opacity|"))
verify.call("intro pans to opponent then zooms out",src["intro"].include?("lead_x=") && src["intro"].include?("zoom=1.82-0.82*ease") && src["intro"].include?("sx=close_x*(1.0-sweep)+cx*sweep"))
verify.call("real trainer state restored after cinematic",src["speaker"].include?("def bss_scripted_restore_trainer_actor"))
verify.call("victory music starts with scripted speech",src["events"].include?("@scene.pbTrainerBattleSuccess"))
verify.call("defeated trainer appears before cinematic message",src["events"].include?("@scene.pbShowOpponent(0)") &&
  src["events"].index("@scene.pbShowOpponent(0)") < src["events"].index('engine.process_event("BattleEndWin",1,nil)'))
verify.call("result trainer native entrance is shown only once",src["events"].include?("@bss_scripted_result_trainer_shown"))
verify.call("victory audio plays once",src["events"].include?("BSSScriptedVictoryAudioOnce"))
verify.call("scripted win presented before native result",src["events"].include?('engine.process_event("BattleEndWin",1,nil)'))
verify.call("late win event is not repeated",src["events"].include?('next if @bss_scripted_pre_end_win'))
verify.call("black curtain exists",src["intro"].include?("darkness.z=2"))
verify.call("intro graphic above curtain",src["intro"].include?("grass.z=4"))
verify.call("intro graphic starts transparent",src["intro"].include?("grass.opacity=0"))
verify.call("intro artwork eases in and out",src["intro"].include?("entrance=[[elapsed/0.27") && src["intro"].include?("departure=[["))
verify.call("diagonal intro fragments stay beneath biome artwork",src["intro"].include?("mosaic.z=3") && src["intro"].include?("grass.z=4"))
verify.call("diagonal fragments dispose bitmap cleanly",src["intro"].include?("mosaic_bitmap.dispose"))
verify.call("camera settles at 1x before real actor reveal",src["intro"].include?("zoom=1.82-0.82*ease") && src["intro"].include?("reveal=[[(p-0.77)/0.23"))
verify.call("trainer bitmap not manually played during intro",!src["intro"].include?("trainer.play if trainer"))
verify.call("trainer animation resets for native intro",src["intro"].include?("trainer.to_first_frame"))
verify.call("native 042 trainer coordinates applied to BSS prelude",src["intro"].include?("trainer.pbSetPosition"))
verify.call("wild receives the curtain",!src["intro"].include?("if @battle.trainerBattle?\n        viewport=Viewport.new"))
verify.call("aura layers use BAS camera restore slots",src["aura"].include?("BSS064AuraLayerCameraSync") && src["aura"].include?("apply_camera_to_sprite(part,state)"))

addon=JSON.parse(read.call(File.join(root,"LA BASE DE SKY","Data","BattleSceneStudio","scripted_battles.json")))
chano=addon.fetch("blueprints").find { |b| b["key"]=="joven_chano_guionizado" }
verify.call("scripted Chano still available",!chano.nil?)
verify.call("portrait mode playable",chano["dialogues"]["triggers"].any? { |t| t["trainerPortraitMode"]=="behind" })
verify.call("Studio has portrait option",read.call(File.join(editor,"index.js")).include?("installTrainerPortraitChoice"))
fix042=read.call(File.join(root,"LA BASE DE SKY","Plugins","Carnek Project Settings","patches","042_TrainerSpriteEditorShadowFix.rb"))
verify.call("042 applies both horizontal and vertical offset",fix042.include?("self.x += offset[0]") && fix042.include?("self.y += offset[1]"))
puts "BSS SCRIPTED DEPTH/AURA SOURCE CONTRACTS PASS (visual game test still required)"

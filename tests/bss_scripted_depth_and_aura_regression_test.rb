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
verify.call("trainer remains behind battlers",src["speaker"].include?("sp.z=foes.map(&:to_i).min-1"))
verify.call("portrait depth reapplied before rendering",src["speaker"].include?("bss_scripted_apply_speaker_priority if @bss_dialogue_cinema_active"))
verify.call("scripted win presented before native result",src["events"].include?('engine.process_event("BattleEndWin",1,nil)'))
verify.call("late win event is not repeated",src["events"].include?('next if @bss_scripted_pre_end_win'))
verify.call("black curtain exists",src["intro"].include?("darkness.z=2"))
verify.call("intro graphic above curtain",src["intro"].include?("grass.z=4"))
verify.call("wild receives the curtain",!src["intro"].include?("if @battle.trainerBattle?\n        viewport=Viewport.new"))
verify.call("aura layers use BAS camera restore slots",src["aura"].include?("BSS064AuraLayerCameraSync") && src["aura"].include?("apply_camera_to_sprite(part,state)"))

addon=JSON.parse(read.call(File.join(root,"LA BASE DE SKY","Data","BattleSceneStudio","scripted_battles.json")))
chano=addon.fetch("blueprints").find { |b| b["key"]=="joven_chano_guionizado" }
verify.call("scripted Chano still available",!chano.nil?)
verify.call("portrait mode playable",chano["dialogues"]["triggers"].any? { |t| t["trainerPortraitMode"]=="behind" })
verify.call("Studio has portrait option",read.call(File.join(editor,"index.js")).include?("installTrainerPortraitChoice"))
puts "BSS SCRIPTED DEPTH/AURA SOURCE CONTRACTS PASS (visual game test still required)"

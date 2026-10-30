# frozen_string_literal: true
require "minitest/autorun"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/001_Core"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture/009_Audio"

def pbSEPlay(name); $bifrost_audio_played=name; end

module Input
  JUMPUP = :jumpup
  JUMPDOWN = :jumpdown
  SPECIAL = :special
  ACTION = :action
  AUX1 = :aux1
  AUX2 = :aux2
  USE = :use
  BACK = :back
end

class BifrostCoreTest < Minitest::Test
  def setup
    BifrostCapture.reload!
  end

  def test_translation_placeholders_always_receive_mutable_strings
    root=File.expand_path(
      "../LA BASE DE SKY/Plugins/[VERMEIL] Bifrost Capture",__dir__)
    Dir.glob(File.join(root,"*.rb")).each do |path|
      source=File.read(path)
      unsafe=source.scan(/_INTL\("[^"]*\{\d+\}[^"]*"\s*,/)
      assert_empty unsafe, "FrozenError risk in #{File.basename(path)}: #{unsafe.inspect}"
    end
  end

  def test_all_editable_png_layers_and_vector_sources_are_in_project
    root=File.expand_path("../LA BASE DE SKY/Graphics/UI/Bifrost",__dir__)
    { "panel"=>[392,116],"slot"=>[46,42],
      "slot_selected"=>[46,42],"target"=>[228,48],
      "keycap"=>[74,22] }.each do |name,(width,height)|
      path=File.join(root,"#{name}.png")
      assert File.file?(path),"Missing game PNG: #{path}"
      png=File.binread(path,24)
      assert_equal "\x89PNG\r\n\x1a\n".b,png.byteslice(0,8)
      assert_equal [width,height],png.byteslice(16,8).unpack("NN")
      svg=File.join(root,"_source","#{name}.svg")
      assert File.file?(svg),"Missing editable SVG: #{svg}"
    end
  end

  def test_negative_hud_offsets_survive_ini_parsing
    require "tmpdir"
    Dir.mktmpdir("bifrost-offsets") do |dir|
      path=File.join(dir,"settings.ini")
      File.write(path,"[global]\nhud_offset_x=-72\nhud_offset_y=35\n")
      data=BifrostCapture.read_ini(path,["global"])
      assert_equal "-72",data["global"]["hud_offset_x"]
      assert_equal "35",data["global"]["hud_offset_y"]
    end
  end

  def test_new_capture_pacing_and_personalizable_hud_defaults
    cfg = BifrostCapture::DEFAULTS
    assert_equal "17",cfg["throw_cooldown_frames"]
    assert_equal "25",cfg["escape_reaction_chance"]
    assert_equal "8",cfg["escape_reaction_hp_percent"]
    assert_equal "bottom_right",cfg["hud_position"]
    assert_equal "100",cfg["hud_scale"]
    assert_equal "1",cfg["temperament_indicators"]
    assert_equal "3",cfg["aggressive_lunge_distance"]
    assert_equal "4",cfg["aggressive_chase_speed"]
    assert_equal "5",cfg["aggressive_lunge_speed"]
    assert_equal "0",cfg["hud_offset_x"]
    assert_equal "0",cfg["hud_offset_y"]
  end

  def test_three_temperaments_are_stable_and_selectable
    %w[neutral timid aggressive].each do |choice|
      event=Object.new
      cfg=BifrostCapture::DEFAULTS.merge("temperament"=>choice)
      assert_equal choice.to_sym,BifrostCapture.temperament_for(event,cfg)
      assert_equal choice.to_sym,BifrostCapture.temperament_for(event,
                          cfg.merge("temperament"=>"mixed"))
    end
  end

  def test_sound_events_can_be_replaced_or_muted
    $bifrost_audio_played=nil
    cfg=BifrostCapture::DEFAULTS.merge("audio_profile"=>"original",
          "sfx_throw"=>"custom_throw")
    require "tmpdir"
    Dir.mktmpdir("bifrost-custom") do |dir|
      Dir.chdir(dir) do
        Dir.mkdir("Audio")
        Dir.mkdir("Audio/SE")
        Dir.mkdir("Audio/SE/Bifrost")
        File.binwrite("Audio/SE/Bifrost/custom_throw.wav","RIFFtest")
        assert BifrostCapture::Audio.play(:throw,cfg)
        assert_equal "Bifrost/custom_throw.wav",$bifrost_audio_played
      end
    end
    assert_equal false,BifrostCapture::Audio.play(:throw,
                    cfg.merge("audio_profile"=>"muted"))
    refute BifrostCapture::Audio.play(:throw,
                    cfg.merge("sfx_throw"=>"../unsafe_file"))
  end

  def test_za_default_plays_real_cc0_wav_and_no_synthetic_generated
    root=File.expand_path("../LA BASE DE SKY",__dir__)
    Dir.chdir(root) do
      $bifrost_audio_played=nil
      assert BifrostCapture::Audio.play(:switch,BifrostCapture::DEFAULTS)
      assert_equal "Bifrost/real_switch.wav",$bifrost_audio_played
      wav = File.binread("Audio/SE/Bifrost/real_switch.wav")
      assert_equal "RIFF",wav.byteslice(0,4)
      assert_equal "WAVE",wav.byteslice(8,4)
      assert_operator wav.bytesize,:>,1024
      refute BifrostCapture::Audio.respond_to?(:create_original_cue)
    end
  end

  def test_critical_throw_has_own_real_audio
    root=File.expand_path("../LA BASE DE SKY",__dir__)
    Dir.chdir(root) do
      assert BifrostCapture::Audio.play(:critical,BifrostCapture::DEFAULTS)
      assert_equal "Bifrost/real_critical.wav",$bifrost_audio_played
    end
  end

  def test_reserved_actions_never_leak_into_capture_by_default
    cfg=BifrostCapture::DEFAULTS
    assert_equal "none",cfg["target_key"]
    assert_equal "none",cfg["mode_key"]
    assert_nil BifrostCapture.capture_action(cfg,"mode_key")
    assert_nil BifrostCapture.capture_action(
      cfg.merge("mode_key"=>"aux2","contextual_mode_toggle"=>"1"),"mode_key"),
      "legacy saves must not re-enable W passability debug key"
    assert_equal "za_like",cfg["audio_profile"]
    assert_equal :jumpup,BifrostCapture.capture_action(cfg,"hotkey")
    assert_equal :jumpdown,BifrostCapture.capture_action(cfg,"ball_key")
    %w[action special aux1 aux2 use back].each do |reserved|
      candidate=cfg.merge("target_key"=>reserved)
      assert_nil BifrostCapture.capture_action(candidate,"target_key"),
        "Capture must not hijack built-in map action #{reserved}"
    end
    assert_nil BifrostCapture.capture_action(cfg.merge("ball_key"=>"jumpup"),
                                               "ball_key")
  end

  def test_project_defaults_keep_exclusive_bifrost
    cfg = BifrostCapture::DEFAULTS
    assert_equal "bifrost",cfg["profile"]
    assert_equal "1",cfg["restricted_species"]
    assert_equal "classic",cfg["encounter_mode"]
    assert_equal "always",cfg["access_mode"]
  end

  def test_other_project_can_enable_full_ow
    cfg = BifrostCapture::DEFAULTS.merge(
      BifrostCapture::PROFILES["full_ow"])
    assert_equal "0",cfg["restricted_species"]
    assert_equal "overworld",cfg["encounter_mode"]
    assert BifrostCapture.overworld_encounters?(cfg)
  end

  def test_all_species_are_eligible_in_full_overworld
    cfg = BifrostCapture::DEFAULTS.merge("restricted_species"=>"0")
    assert BifrostCapture.allow_species?(:PIKACHU,cfg)
    assert BifrostCapture.allow_species?(:RAIKOU,cfg)
  end

  def test_bifrost_only_catalog_is_configurable
    cfg = BifrostCapture::DEFAULTS
    assert BifrostCapture.allow_species?(:RAIKOU,cfg)
    refute BifrostCapture.allow_species?(:PIKACHU,cfg)
  end

  def test_eight_tiles_always_outside_seven_tile_limit
    cfg = BifrostCapture::DEFAULTS
    assert BifrostCapture.geometry(10,10,10,6,cfg)[:in_range]
    assert BifrostCapture.geometry(10,10,13,6,cfg)[:in_range]
    refute BifrostCapture.geometry(10,10,10,2,cfg)[:in_range]
    assert_in_delta 1.0,BifrostCapture.hit_chance(4,cfg),0.00001
    assert_equal 0.0,BifrostCapture.hit_chance(8,cfg)
  end
end

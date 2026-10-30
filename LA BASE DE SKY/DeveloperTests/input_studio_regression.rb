# frozen_string_literal: true
# Run: ruby "LA BASE DE SKY/DeveloperTests/input_studio_regression.rb"
# Isolated logic checks; does not substitute for running Game.exe / mkxp.
require "tmpdir"
require "fileutils"
Dir.mktmpdir("vermeil-input-studio") do |dir|
  module System
    class << self
      attr_accessor :test_dir
      def data_directory; @test_dir; end
    end
  end
  System.test_dir = dir
  module Input
    UP = 8; DOWN = 2; LEFT = 4; RIGHT = 6
    USE = 11; BACK = 12; ACTION = 13; JUMPUP = 14
    JUMPDOWN = 15; SPECIAL = 16; AUX1 = 17; AUX2 = 18
    MOUSELEFT = 19
    @physical = {}
    @raw_keys = Array.new(512, false)
    class << self
      attr_accessor :physical, :raw_keys
      def press?(_key); false; end
      def trigger?(_key); false; end
      def repeat?(_key); false; end
      def release?(_key); false; end
      def dir4(*_args); 0; end
      def dir8(*_args); 0; end
      def update; end
      def pressex?(name); !!@physical[name.to_s]; end
      def triggerex?(name); !!@physical[name.to_s]; end
      def repeatex?(name); !!@physical[name.to_s]; end
      def releaseex?(_name); false; end
      def raw_key_states; @raw_keys; end
    end
  end
  class Scene_Map; end
  $scene = Scene_Map.new
  def assert!(value, label)
    raise "FAILED: #{label}" unless value
    puts "PASS: #{label}"
  end
  root = File.expand_path("../Plugins/[VERMEIL] Input Studio", __dir__)
  load File.join(root, "001_Core.rb")
  assert!(InputStudio::VERSION == "1.0.1", "version")
  Input.physical["UP"] = true
  assert!(Input.dir4(true) == 8 && Input.dir4(false) == 8 && Input.dir4 == 8,
          "dir4 supports Essentials last-frame argument (true/false/omitted)")
  assert!(Input.dir8 == 8, "dir8 keyboard movement")
  Input.physical["UP"] = false
  assert!(Input.dir4(false) == 0, "dir4 neutral")
  assert!(!InputStudio.assign("move_up","keyboard","W"), "conflict detected")
  assert!(InputStudio.conflicts("move_up","keyboard","W").include?("Auxiliar 2"),
          "conflicting existing action identified")
  assert!(InputStudio.assign("move_up","keyboard","W",0,true),
          "user-confirmed conflict replacement persists")
  assert!(InputStudio.bindings("move_up","keyboard") == ["W"], "primary action remapped")
  assert!(!InputStudio.bindings("aux2","keyboard").include?("W"), "conflict cleared")
  assert!(File.file?(InputStudio.profile_file), "player profile saved externally")
  InputStudio.load!
  assert!(InputStudio.bindings("move_up","keyboard") == ["W"], "profile survives reload")
  Input.physical["W"] = true
  assert!(Input.dir4(true) == 8, "movement reads remapped key")
  Input.physical["W"] = false
  assert!(InputStudio.reset("move_up"), "reset action")
  assert!(InputStudio.bindings("move_up","keyboard") == ["UP"], "reset falls back to original")
  assert!(InputStudio.reset("aux2"), "restore conflicting auxiliary action")
  assert!(!InputStudio.assign("move_up","keyboard","F1"), "system F1 protected")
  assert!(!InputStudio.active?("bifrost_ball_next"), "Bifrost action inactive in map")
  assert!(InputStudio.with_context("bifrost") { InputStudio.active?("bifrost_ball_next") },
          "Bifrost context activates relevant action")
  assert!(InputStudio.context == "map", "context does not leak")
  InputStudio.modal = true
  assert!(!InputStudio.press?("move_up"), "modal suppresses gameplay input")
  InputStudio.modal = false

  class Color
    def initialize(*); end
  end
  class Bitmap
    FontStub = Struct.new(:size,:color)
    attr_reader :font
    def initialize(*); @font = FontStub.new; end
    def clear; end
    def fill_rect(*); end
    def draw_text(*); end
    def disposed?; false; end
    def dispose; end
  end
  class Sprite
    attr_accessor :z, :bitmap
    def initialize; end
    def disposed?; false; end
    def dispose; end
  end
  module Graphics
    def self.width; 640; end
    def self.height; 480; end
    def self.update; end
  end
  load File.join(root, "002_Overlay.rb")
  overlay = InputStudio::Overlay.new
  overlay.instance_variable_set(:@category,"Movimiento")
  overlay.send(:capture_start,0)
  # SDL scancode for W is 26; W conflicts with AUX2 in map context.
  Input.raw_keys[26] = true
  overlay.send(:capture_tick)
  pending = overlay.instance_variable_get(:@pending)
  assert!(pending && pending[:key]=="W", "overlay detects actual physical keyboard capture")
  assert!(overlay.instance_variable_get(:@capture).nil?, "overlay exits capture to confirm conflict")
  Input.physical["RETURN"] = true
  overlay.send(:pending_tick)
  assert!(InputStudio.bindings("move_up","keyboard").first=="W",
          "overlay applies confirmed assignment")
  assert!(overlay.instance_variable_get(:@pending).nil?, "confirmation modal cleared")
  Input.physical["RETURN"] = false
  puts "Input Studio isolated regression checks passed"
end

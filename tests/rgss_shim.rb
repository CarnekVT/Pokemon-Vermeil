# Stand-ins for everything MKXP-Z injects into the Ruby VM before the game's own
# scripts run: the RGSS graphics/input/audio classes and the mkxp-specific
# modules. They exist so the engine scripts can be evaluated by a plain `ruby`
# process, with no window, no GL context and no game loop.
#
# Only the parts the scripts touch at load time (or that battle logic reaches
# during a headless fight) are real; everything else is a no-op.

require "json"

#===============================================================================
# Write guard
#===============================================================================
# The test process must never modify the repository: no errorlog.txt, no
# recompiled .dat files, no save files. Reads go through untouched.
module WriteGuard
  WRITE_MODE = /[wa+]/

  class Violation < StandardError; end

  class << self
    # Runs a block with the guard lifted, for the harness's own bookkeeping.
    def unguarded
      @off = true
      yield
    ensure
      @off = false
    end

    def off? = @off
  end
end

class File
  class << self
    alias_method :unguarded_open, :open

    def open(path, mode = "r", *args, &block)
      if !WriteGuard.off? && mode.is_a?(String) && mode.match?(WriteGuard::WRITE_MODE)
        raise WriteGuard::Violation, "el test intentó escribir en #{path}"
      end
      unguarded_open(path, mode, *args, &block)
    end

    def write(path, *)
      raise WriteGuard::Violation, "el test intentó escribir en #{path}"
    end

    def delete(*paths)
      raise WriteGuard::Violation, "el test intentó borrar #{paths.join(', ')}"
    end
  end
end

class Dir
  class << self
    def mkdir(path, *)
      raise WriteGuard::Violation, "el test intentó crear el directorio #{path}"
    end
  end
end

#===============================================================================
# Null object behaviour
#===============================================================================
# Reader methods answer nil, writers echo the value back. Enough for the drawing
# and animation calls that battle code makes on sprites and viewports.
module NullMethods
  def method_missing(name, *args, &block)
    name.to_s.end_with?("=") ? args.first : nil
  end

  def respond_to_missing?(*) = true
end

#===============================================================================
# Exceptions
#===============================================================================
# Raised by mkxp-z on file/graphics errors. Several scripts rescue them by name,
# and PokemonSystem#initialize references MKXPError directly.
class RGSSError < StandardError; end
class MKXPError < StandardError; end
class Reset < Exception; end
class Hangup < Exception; end

#===============================================================================
# Value classes
#===============================================================================
class Rect
  attr_accessor :x, :y, :width, :height

  def initialize(x = 0, y = 0, width = 0, height = 0)
    set(x, y, width, height)
  end

  def set(x, y, width, height)
    @x, @y, @width, @height = x, y, width, height
    self
  end

  def empty = set(0, 0, 0, 0)

  def ==(other)
    other.is_a?(Rect) && other.x == @x && other.y == @y &&
      other.width == @width && other.height == @height
  end
end

class Color
  attr_accessor :red, :green, :blue, :alpha

  def initialize(red = 0, green = 0, blue = 0, alpha = 255)
    set(red, green, blue, alpha)
  end

  def set(red, green, blue, alpha = 255)
    @red, @green, @blue, @alpha = red, green, blue, alpha
    self
  end
end

class Tone
  attr_accessor :red, :green, :blue, :gray

  def initialize(red = 0, green = 0, blue = 0, gray = 0)
    set(red, green, blue, gray)
  end

  def set(red, green, blue, gray = 0)
    @red, @green, @blue, @gray = red, green, blue, gray
    self
  end
end

class Font
  include NullMethods

  attr_accessor :name, :size, :bold, :italic, :color, :shadow, :outline, :out_color

  def initialize(name = "Arial", size = 24)
    @name, @size = name, size
    @color, @out_color = Color.new(255, 255, 255), Color.new(0, 0, 0)
    @bold = @italic = @shadow = @outline = false
  end

  class << self
    include NullMethods

    attr_accessor :default_name, :default_size, :default_bold, :default_italic,
                  :default_color, :default_shadow, :default_outline, :default_out_color

    def exist?(*) = true
  end

  self.default_name    = "Arial"
  self.default_size    = 24
  self.default_bold    = false
  self.default_italic  = false
  self.default_shadow  = false
  self.default_outline = true
end

class Table
  attr_reader :xsize, :ysize, :zsize

  def initialize(xsize = 0, ysize = 0, zsize = 0)
    resize(xsize, ysize, zsize)
  end

  def resize(xsize = 0, ysize = 0, zsize = 0)
    @xsize, @ysize, @zsize = xsize, ysize, zsize
    @cells = Hash.new(0)
    self
  end

  def [](*key) = @cells[key]

  def []=(*args)
    @cells[args[0..-2]] = args[-1]
  end
end

#===============================================================================
# Graphics objects
#===============================================================================
class Bitmap
  include NullMethods

  attr_accessor :font
  attr_reader :width, :height

  # Bitmap.new takes either a path or a width/height pair. Loading a real image
  # is pointless here, so a path yields a fixed-size blank surface.
  def initialize(width = 1, height = 1)
    width, height = 32, 32 if width.is_a?(String)
    @width, @height = width, height
    @font = Font.new
    @disposed = false
  end

  def self.max_size = 4096

  def rect = Rect.new(0, 0, @width, @height)

  # 003_Technical/002_MKXP_Compatibility.rb aliases this method, so it has to
  # exist as a real instance method rather than fall through to method_missing.
  def draw_text(*); end

  # ponytail: 8px per character is a rough guess; UI code is untested anyway, and
  # only battle/data logic asserts on real values.
  def text_size(text) = Rect.new(0, 0, text.to_s.length * 8, 24)

  def get_pixel(*) = Color.new
  def dispose = (@disposed = true)
  def disposed? = @disposed
end

class Sprite
  include NullMethods
  def initialize(*); end
  def disposed? = false
end

class Viewport
  include NullMethods
  def initialize(*); end
  def disposed? = false
end

class Window
  include NullMethods
  def initialize(*); end
  def disposed? = false
end

class Plane
  include NullMethods
  def initialize(*); end
  def disposed? = false
end

class Tilemap
  include NullMethods
  def initialize(*); end
  def disposed? = false
end

#===============================================================================
# Engine modules
#===============================================================================
# These have to be modules, not classes: the game's own scripts reopen them with
# `module Graphics`, which fails against a class with "is not a module".
module Graphics
  extend NullMethods

  def self.width = 512
  def self.height = 384
  def self.frame_rate = 60
  def self.frame_count = 0
  def self.fullscreen = false
  def self.update; end
  def self.wait(*); end
end

module Input
  extend NullMethods

  %w[DOWN LEFT RIGHT UP A B C X Y Z L R SHIFT CTRL ALT F5 F6 F7 F8 F9
     USE BACK ACTION JUMPUP JUMPDOWN SPECIAL AUX1 AUX2
     MOUSELEFT MOUSERIGHT MOUSEMIDDLE].each_with_index do |key, i|
    const_set(key, i + 1)
  end

  def self.update; end
  def self.press?(*) = false
  def self.trigger?(*) = false
  def self.repeat?(*) = false
  def self.release?(*) = false
  def self.dir4 = 0
  def self.dir8 = 0
  def self.mouse_x = 0
  def self.mouse_y = 0
end

module Audio
  extend NullMethods
end

module System
  VERSION = "2.4.2"

  # Unknown System calls answer "" rather than nil: most of them are queried for
  # strings (pbGetLanguage slices System.user_language, for one).
  def self.method_missing(name, *args)
    name.to_s.end_with?("=") ? args.first : ""
  end

  def self.respond_to_missing?(*) = true

  def self.game_title = "La Base de Sky (tests)"
  def self.platform = "Linux"
  def self.user_language = "es_ES"
  def self.uptime = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  def self.data_directory = Dir.pwd
  def self.is_linux? = true
  def self.is_windows? = false
  def self.is_macos? = false
  def self.reload_cache; end
end

module MKXP
  extend NullMethods
  def self.puts(*); end
end

module CFG
  extend NullMethods
  def self.[](*) = nil
end

module HTTPLite
  extend NullMethods

  # mkxp-z bundles a JSON parser here; Ruby's own is a drop-in for what the
  # scripts ask of it (reading mkxp.json, mostly).
  module JSON
    def self.parse(string) = ::JSON.parse(string)
    def self.generate(object) = ::JSON.generate(object)
  end
end

#===============================================================================
# RGSS data classes
#===============================================================================
# The plain data structures RPG Maker XP stores inside .rxdata files. Scripts
# instantiate and reopen them, so the field names and constructor defaults match
# RGSS exactly.
#
# ponytail: only the classes the engine and its plugins actually reference. The
# database ones (RPG::System, RPG::Tileset, RPG::Actor...) would be needed to
# Marshal-load Data/System.rxdata or a map; add them when a test loads maps.
module RPG
  class Sprite < ::Sprite; end

  class Weather
    include NullMethods
    MAX = 40
    def initialize(*); end
  end

  class AudioFile
    attr_accessor :name, :volume, :pitch

    def initialize(name = "", volume = 100, pitch = 100)
      @name, @volume, @pitch = name, volume, pitch
    end
  end

  # mkxp-z gives these class-level playback helpers; here they do nothing.
  class BGM < AudioFile
    class << self
      def stop; end
      def fade(*); end
    end
  end

  class BGS < BGM; end
  class ME  < BGM; end
  class SE  < BGM; end

  class EventCommand
    attr_accessor :code, :indent, :parameters

    def initialize(code = 0, indent = 0, parameters = [])
      @code, @indent, @parameters = code, indent, parameters
    end
  end

  class MoveCommand
    attr_accessor :code, :parameters

    def initialize(code = 0, parameters = [])
      @code, @parameters = code, parameters
    end
  end

  class MoveRoute
    attr_accessor :repeat, :skippable, :list

    def initialize
      @repeat, @skippable = true, false
      @list = [MoveCommand.new]
    end
  end

  class Event
    attr_accessor :id, :name, :x, :y, :pages

    def initialize(x, y)
      @id, @name = 0, ""
      @x, @y = x, y
      @pages = [Page.new]
    end

    class Page
      attr_accessor :condition, :graphic, :move_type, :move_speed, :move_frequency,
                    :move_route, :walk_anime, :step_anime, :direction_fix, :through,
                    :always_on_top, :trigger, :list

      def initialize
        @condition = Condition.new
        @graphic   = Graphic.new
        @move_type, @move_speed, @move_frequency = 0, 3, 3
        @move_route = MoveRoute.new
        @walk_anime, @step_anime = true, false
        @direction_fix = @through = @always_on_top = false
        @trigger = 0
        @list = [EventCommand.new]
      end

      class Condition
        attr_accessor :switch1_valid, :switch2_valid, :variable_valid, :self_switch_valid,
                      :switch1_id, :switch2_id, :variable_id, :variable_value, :self_switch_ch

        def initialize
          @switch1_valid = @switch2_valid = @variable_valid = @self_switch_valid = false
          @switch1_id = @switch2_id = @variable_id = 1
          @variable_value = 0
          @self_switch_ch = "A"
        end
      end

      class Graphic
        attr_accessor :tile_id, :character_name, :character_hue, :direction,
                      :pattern, :opacity, :blend_type

        def initialize
          @tile_id, @character_name, @character_hue = 0, "", 0
          @direction, @pattern = 2, 0
          @opacity, @blend_type = 255, 0
        end
      end
    end
  end

  class CommonEvent
    attr_accessor :id, :name, :trigger, :switch_id, :list

    def initialize
      @id, @name, @trigger, @switch_id = 0, "", 0, 1
      @list = [EventCommand.new]
    end
  end

  class Map
    attr_accessor :tileset_id, :width, :height, :autoplay_bgm, :bgm, :autoplay_bgs,
                  :bgs, :encounter_list, :encounter_step, :data, :events

    def initialize(width, height)
      @tileset_id = 1
      @width, @height = width, height
      @autoplay_bgm = @autoplay_bgs = false
      @bgm = AudioFile.new
      @bgs = AudioFile.new("", 80)
      @encounter_list = []
      @encounter_step = 30
      @data = Table.new(width, height, 3)
      @events = {}
    end
  end

  class MapInfo
    attr_accessor :name, :parent_id, :order, :expanded, :scroll_x, :scroll_y

    def initialize
      @name = ""
      @parent_id = @order = @scroll_x = @scroll_y = 0
      @expanded = false
    end
  end

  class Animation
    attr_accessor :id, :name, :animation_name, :animation_hue, :position,
                  :frame_max, :frames, :timings

    def initialize
      @id, @name, @animation_name, @animation_hue = 0, "", "", 0
      @position, @frame_max = 1, 1
      @frames = [Frame.new]
      @timings = []
    end

    class Frame
      attr_accessor :cell_max, :cell_data

      def initialize
        @cell_max = 0
        @cell_data = Table.new(0, 0)
      end
    end

    class Timing
      attr_accessor :frame, :se, :flash_scope, :flash_color, :flash_duration, :condition

      def initialize
        @frame = 0
        @se = AudioFile.new("", 80)
        @flash_scope = 0
        @flash_color = Color.new(255, 255, 255, 255)
        @flash_duration = 5
        @condition = 0
      end
    end
  end
end

def load_data(filename)
  File.unguarded_open(filename, "rb") { |file| Marshal.load(file) }
end

def save_data(*)
  raise WriteGuard::Violation, "el test intentó guardar datos con save_data"
end

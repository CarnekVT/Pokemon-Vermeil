# Boots Pokémon Essentials inside a plain `ruby` process: evaluates every engine
# script and plugin against the RGSS shim, loads the compiled PBS data, and
# builds the handful of globals that battle and Pokémon code expects.
#
# Booting happens once per process; `TestGame.new_state` then gives each test a
# fresh player, bag and RNG seed.

require "stringio"
require_relative "framework"
require_relative "rgss_shim"

module TestGame
  # The game folder is the one holding mkxp.json — the only unambiguous marker.
  # Its name is not assumed anywhere.
  GAME_DIR = Dir.glob(File.expand_path("../*/mkxp.json", __dir__)).first&.then { |f| File.dirname(f) } ||
             raise("No se encontró mkxp.json: ¿está tests/ junto a la carpeta del juego?")

  # Default trainer for the fake player. Any type from PBS/trainer_types.txt works.
  PLAYER_TRAINER_TYPE = :POKEMONTRAINER_Red

  class << self
    # @return [Array<Array(String, Exception)>] scripts that failed to evaluate
    attr_reader :load_errors

    # @return [String] everything the engine printed while booting
    attr_reader :boot_output

    def booted? = !@booted.nil?

    def boot
      return if @booted

      @load_errors = []
      Dir.chdir(GAME_DIR)
      # Same flags a developer runs the game with, minus $INTERNAL: PluginManager
      # only scans the Plugins/ folder when $DEBUG is on, and PBDebug only writes
      # its log when both are on.
      $DEBUG = true
      $INTERNAL = false
      $RGSS_SCRIPTS = []

      @boot_output = capture_output do
        load_engine_scripts
        define_project_version
        surface_exceptions
        neutralize_plugin_exit
        load_plugins
        MessageTypes.load_default_messages
        GameData.load_all
      end

      @booted = true
    end

    # Fresh game state for one test. Seeding keeps battles reproducible.
    def new_state(seed: 1234)
      boot
      srand(seed)
      $PokemonSystem      = PokemonSystem.new
      $game_temp          = Game_Temp.new
      $game_system        = Game_System.new
      $game_switches      = Game_Switches.new
      $game_variables     = Game_Variables.new
      $game_self_switches = Game_SelfSwitches.new
      $game_screen        = Game_Screen.new
      $player             = Player.new("Tester", PLAYER_TRAINER_TYPE)
      $stats              = GameStats.new
      $bag                = PokemonBag.new
      $PokemonGlobal      = PokemonGlobalMetadata.new
      $PokemonMap         = PokemonMapMetadata.new
      $PokemonStorage     = PokemonStorage.new
      $PokemonEncounters  = nil
      $game_map           = nil
      $scene              = nil
      nil
    end

    # Runs a block with engine chatter swallowed, returning what it printed.
    def capture_output
      previous = $stdout
      captured = StringIO.new
      $stdout = captured
      yield
      captured.string
    ensure
      $stdout = previous
    end

    private

    # Mirrors the load order of Data/Scripts/999_Main/999_Main.rb: files first in
    # alphabetical order, then subfolders, recursively. 999_Main itself is the
    # game loop and must not run.
    def load_engine_scripts
      walk("Data/Scripts") do |path|
        next if path.include?("999_Main")
        evaluate(path, File.unguarded_open(path, "r:UTF-8", &:read))
      end
    end

    # In the game, an exception raised mid-battle is written to errorlog.txt and
    # the battle carries on. In a test run that exception is the result, so it is
    # re-raised: the write guard would only report the logging attempt and hide
    # what actually went wrong.
    def surface_exceptions
      Object.send(:define_method, :pbPrintException) { |e| raise e }
    end

    # 999_Main.rb is skipped because it is the game loop, but it also declares the
    # project version that PluginManager quotes in its errors, so that one
    # constant is lifted out of the file rather than duplicated here.
    def define_project_version
      return if defined?(LBDSKY)
      source = File.unguarded_open("Data/Scripts/999_Main/999_Main.rb", "r:UTF-8", &:read)
      version = source[/^\s*VERSION\s*=\s*"([^"]+)"/, 1]
      Object.const_set(:LBDSKY, Module.new)
      LBDSKY.const_set(:VERSION, version) if version
    end

    # Plugins are evaluated from source rather than through
    # PluginManager.runPlugins, which reads the pre-compiled
    # Data/PluginScripts.rxdata: that file can lag behind the .rb files, and the
    # tests are meant to check what is actually in the repository.
    def load_plugins
      order, plugins = PluginManager.getPluginOrder
      order.each do |name|
        meta = plugins[name]
        next if disabled?(meta)
        PluginManager.register(meta.reject { |key, _| [:scripts, :dir].include?(key) })
        meta[:scripts].each do |script|
          path = File.join(meta[:dir], script)
          evaluate("[#{name}] #{script}", File.unguarded_open(path, "r:UTF-8", &:read))
        end
      end
    rescue Exception => e
      @load_errors << ["PluginManager.getPluginOrder", e]
    end

    def disabled?(meta)
      return false if !meta.key?(:disabled)
      ["true", "verdadero", "si", "x"].include?(meta[:disabled].to_s.downcase)
    end

    def evaluate(name, code)
      eval(code.gsub("\t", "  "), TOPLEVEL_BINDING, name)
    rescue Exception => e
      @load_errors << [name, e]
    end

    # PluginManager.error ends with Kernel.exit! true, which would abort the test
    # run with a success status. Raising instead turns it into a visible failure.
    def neutralize_plugin_exit
      return if !defined?(PluginManager)
      PluginManager.define_singleton_method(:error) do |msg|
        raise "Error del plugin: #{msg}"
      end
    end

    def walk(path, &block)
      files, folders = [], []
      Dir.foreach(path) do |entry|
        next if entry.start_with?(".")
        (File.directory?(File.join(path, entry)) ? folders : files) << entry
      end
      files.sort.each { |file| block.call(File.join(path, file)) }
      folders.sort.each { |folder| walk(File.join(path, folder), &block) }
    end
  end
end

# Base class for every test: boots the engine once, then hands each test a clean
# player, bag and RNG.
class EngineTest < TestCase
  def setup
    TestGame.new_state
  end
end

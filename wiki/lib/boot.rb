# frozen_string_literal: true

require "json"
require "fileutils"

# Arranca el motor de Essentials headless reutilizando el harness de los tests.
# Ese harness localiza la carpeta del juego por mkxp.json, evalúa scripts y
# plugins contra el shim de RGSS, compila los PBS si faltan los .dat y monta
# GameData. Aquí solo añadimos: forzar una recompilación fresca (para que la
# wiki refleje los .txt actuales) y levantar el WriteGuard para poder escribir
# la salida.
module Boot
  class << self
    attr_reader :game_dir

    def load_engine(recompile: true)
      require File.join(REPO_ROOT, "tests", "harness")

      TestGame.boot
      TestGame.new_state   # $player / $game_temp: los necesitan pbGetMapNameFromId y la carga de mapas
      @game_dir = TestGame::GAME_DIR

      report_load_errors

      if recompile
        recompile_pbs
      elsif pbs_stale?
        warn "AVISO: hay PBS/*.txt más nuevos que Data/species.dat y se pasó --no-recompile; " \
             "la wiki puede no reflejar los cambios recientes."
      end

      # El harness deja $DEBUG activo (PluginManager solo escanea Plugins/ así); con
      # $DEBUG Ruby imprime toda excepción aunque se rescate (ruido de FileUtils).
      $DEBUG = false
      self
    end

    # ponytail: el WriteGuard del shim aborta cualquier escritura para proteger
    # el repo durante los tests; la wiki sí tiene que escribir su salida, así que
    # se levanta solo alrededor de esa fase.
    def unguarded(&block)
      WriteGuard.unguarded(&block)
    end

    private

    def report_load_errors
      errors = TestGame.load_errors
      return if errors.empty?

      warn "AVISO: #{errors.size} script(s) del juego no cargaron; la wiki puede quedar incompleta:"
      errors.first(10).each { |name, e| warn "  #{name}: #{e.class}: #{e.message}" }
    end

    def pbs_stale?
      dat = File.join(@game_dir, "Data", "species.dat")
      return true unless File.exist?(dat)

      newest_pbs = Dir[File.join(@game_dir, "PBS", "*.txt")].map { |f| File.mtime(f) }.max
      newest_pbs && newest_pbs > File.mtime(dat)
    end

    def recompile_pbs
      puts "Compilando los PBS para reflejar los .txt actuales..."
      TestGame.capture_output do
        WriteGuard.unguarded do
          FileLineData.clear
          Compiler.compile_pbs_files
        end
        GameData.load_all
      end
    end
  end
end

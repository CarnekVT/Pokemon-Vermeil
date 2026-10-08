module LBDSKY
  VERSION = "1.2.1.1" # No modificar esto
end

Console.setup_console

class Scene_DebugIntro
  def main
    Graphics.transition(0)
    sscene = PokemonLoad_Scene.new
    sscreen = PokemonLoadScreen.new(sscene)
    sscreen.pbStartLoadScreen
    Graphics.freeze
  end
end

def pbCallTitle
  return Scene_DebugIntro.new if $DEBUG && !Settings::SHOW_TITLE_SCREEN_ON_DEBUG
  return Scene_Intro.new
end

def mainFunction
  if true #$DEBUG
    pbCriticalCode { mainFunctionDebug }
  else
    mainFunctionDebug
  end
  return 1
end

def mainFunctionDebug
  begin
    MessageTypes.load_default_messages if FileTest.exist?("Data/messages_core.dat")
    PluginManager.runPlugins
    Compiler.main
    Game.initialize
    # Graphics.resize_screen(Settings::SCREEN_WIDTH, Settings::SCREEN_HEIGHT)
    # Graphics.scale = 0.5
    # Graphics.update
    Game.set_up_system
    Graphics.update
    Graphics.freeze
    $scene = pbCallTitle
    $scene.main until $scene.nil?
    Graphics.transition
  rescue Reset
    # Al pulsar F12 (reinicio del juego), refrescar la caché del sistema
    # para que los archivos modificados durante la sesión se vuelvan a cargar.
    begin
      System.reload_cache if defined?(System) && System.respond_to?(:reload_cache)
    rescue Exception
    end
    # F12 dispara Graphics.__reset__, que hace dispose de todos los Disposables
    # (Sprite/Bitmap/Viewport/Window/Plane/Tilemap). Los globals que retienen uno
    # de esos objetos sobreviven al reinicio apuntando a un recurso ya liberado:
    # al reutilizarlo crashea con "disposed ...". Anularlos fuerza reconstrucción
    # limpia tras el re-eval de scripts.
    $blk = nil     # fundido a negro de Marin (058_Utilities/012: showBlk/hideBlk)
    $blkVp = nil
    raise
  rescue Hangup
    pbPrintException($!) if !$DEBUG
    pbEmergencySave
    raise
  end
end

loop do
  retval = mainFunction
  case retval
  when 0   # failed
    loop do
      Graphics.update
    end
  when 1   # ended successfully
    break
  end
end


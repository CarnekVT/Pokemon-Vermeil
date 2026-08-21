#===============================================================================
# Scene Director Runtime -> Scene Engine
#===============================================================================
if defined?(SceneEngine::Player)
  class SceneEngine::Player
    def studio_dispatch(command, vars = {})
      type = command["type"].to_s
      value = CarnekStudio.ruby_value(command.key?("value") ? command["value"] : command["args"])
      case type
      when "wait" then wait(value.to_i)
      when "show"
        h = value.is_a?(Hash) ? value : {"filename"=>value.to_s}
        show(h["filename"], (h["x"]||0).to_f, (h["y"]||0).to_f,
             fade:(h["fade"]||SceneEngine::Settings::FADE_DEFAULT).to_i,
             origin:(h["origin"]||:top_left).to_sym, zoom:(h["zoom"]||1).to_f, z:h["z"])
      when "hide"
        h = value.is_a?(Hash) ? value : {"filename"=>value}
        hide(h["filename"], fade:(h["fade"]||0).to_i)
      when "hide_all" then hide_all(fade:(value.is_a?(Hash) ? value["fade"].to_i : value.to_i))
      when "show_textbox" then show_textbox(value.to_i)
      when "hide_textbox" then hide_textbox(value.to_i)
      when "text"
        h = value.is_a?(Hash) ? value : {"text"=>value.to_s}
        text_inline(h["text"].to_s, speaker:h["speaker"], speed:(h["speed"]||:normal).to_sym, format_args:h["format_args"])
      when "show_centered_text"
        h = value.is_a?(Hash) ? value : {"text"=>value.to_s}
        show_centered_text(h["text"].to_s, speed:(h["speed"]||:normal).to_sym)
      when "hide_centered_text" then hide_centered_text
      when "bgm" then bgm(value.to_s)
      when "bgs" then bgs(value.to_s)
      when "se" then se(value.to_s)
      when "stop_bgm" then stop_bgm(value.to_f)
      when "stop_bgs" then stop_bgs
      when "fade_from_black" then fade_from_black(value.to_i)
      when "fade_to_black" then fade_to_black(value.to_i)
      when "to_white" then to_white(value.to_i)
      when "from_white" then from_white(value.to_i)
      when "stop_float" then stop_float(fade:(value||0).to_i)
      when "stop_aura" then stop_aura
      when "stop_scrolling" then stop_scrolling
      when "hide_floating" then hide_floating
      when "change_float_bitmap" then change_float_bitmap(value.to_s)
      when "fade_out_images"
        h=value.is_a?(Hash)?value:{"duration"=>value}; fade_out_images((h["duration"]||0).to_i,h["filenames"])
      when "fade_out_floating" then fade_out_floating(value.to_i)
      when "fade_out_scrolling" then fade_out_scrolling(value.to_i)
      when "fade_in_scrolling" then fade_in_scrolling(value.to_i)
      when "transfer_player"
        h=value; transfer_player(h["map_id"].to_i,h["x"].to_i,h["y"].to_i,(h["direction"]||2).to_i) if h.is_a?(Hash)
      when "change_player" then pbChangePlayer(value.to_i)
      when "float_sprite"
        h=value; float_sprite(h["filename"],h["fw"].to_i,h["fh"].to_i,h["frames"].to_i,h["x"].to_f,h["y"].to_f,end_y:h["end_y"].to_f,speed:(h["speed"]||1).to_f,fps:(h["fps"]||6).to_i,ghost_interval:(h["ghost_interval"]||1).to_i,bg:!!h["bg"],glow:!!h["glow"],fade:(h["fade"]||SceneEngine::Settings::FADE_DEFAULT).to_i) if h.is_a?(Hash)
      when "start_aura"
        h=value; start_aura(h["filename"],h["fw"].to_i,h["fh"].to_i,count:(h["count"]||8).to_i,range_x:(h["range_x"]||30).to_i,range_y:(h["range_y"]||60).to_i,duration:(h["duration"]||120).to_i) if h.is_a?(Hash)
      when "start_scrolling"
        h=value; start_scrolling(h["filename"],h["x"].to_f,h["y"].to_f,speed:(h["speed"]||1).to_f,z:h["z"],mirror:!!h["mirror"],horizontal:!!h["horizontal"]) if h.is_a?(Hash)
      when "show_floating"
        h=value; show_floating(h["filename"],h["x"].to_f,h["y"].to_f,amplitude:(h["amplitude"]||8).to_f,speed:(h["speed"]||0.05).to_f,z:h["z"],zoom:(h["zoom"]||1).to_f,opacity:(h["opacity"]||255).to_i,fade:(h["fade"]||0).to_i) if h.is_a?(Hash)
      when "switch"
        h=value; $game_switches[h["id"].to_i]=!!h["value"] if h.is_a?(Hash)
      when "variable"
        h=value; $game_variables[h["id"].to_i]=h["value"] if h.is_a?(Hash)
      when "call_scene" then studio_play_scene(value.to_s, vars)
      when "script"
        @studio_script_binding ||= binding
        eval(value.to_s, @studio_script_binding)
      end
    end
    def studio_play_scene(scene_id, vars = {})
      data = CarnekStudio.load_json("scenes.json", {"scenes"=>[]})
      scene = (data["scenes"] || []).find { |s| s["id"].to_s == scene_id.to_s }
      return false unless scene
      (scene["commands"] || []).each { |cmd| studio_dispatch(cmd, vars) }
      true
    end
  end
  module SceneEngine
    def self.play_studio_scene(scene_id, vars = {})
      player = SceneEngine::Player.new
      player.run { studio_play_scene(scene_id, vars) }
    end
  end
end

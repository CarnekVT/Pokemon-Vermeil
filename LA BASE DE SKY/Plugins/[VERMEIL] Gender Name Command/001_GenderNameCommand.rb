# encoding: UTF-8
#===============================================================================
# [VERMEIL] Gender Name Command v1.0.0 - Pokemon Essentials v21.1
# Reemplaza \AN por un nombre fijo según el género del protagonista.
#===============================================================================
module VermeilGenderName
  MALE_NAME   = "Dorian"
  FEMALE_NAME = "Gilia"

  # No se presupone un género antes de escoger al protagonista.
  def self.current_name
    return nil if !$player
    return FEMALE_NAME if $player.female?
    return MALE_NAME if $player.male?
    return nil
  end

  def self.expand(message)
    return message if !message.is_a?(String)
    name = current_name
    return message if !name || !message.match?(/\\AN/i)
    # Las barras duplicadas son literales, igual que en Essentials.
    # \\AN se muestra como \AN; \AN se sustituye por el nombre.
    message.gsub(/(\\+)AN(?![A-Za-z0-9_])/i) do |match|
      slashes = Regexp.last_match(1)
      slashes.length.odd? ? slashes[0...-1] + name : match
    end
  end
end

# Tanto "Mostrar texto" como pbMessage llegan a pbMessageDisplay.
# Conservamos la implementación original y solo preprocesamos \AN.
class Object
  alias_method :pbMessageDisplay_before_vermeil_gender_name, :pbMessageDisplay

  def pbMessageDisplay(msgwindow, message, letterbyletter = true, commandProc = nil, &block)
    replaced = VermeilGenderName.expand(message)
    pbMessageDisplay_before_vermeil_gender_name(msgwindow, replaced, letterbyletter, commandProc, &block)
  end
  private :pbMessageDisplay
end

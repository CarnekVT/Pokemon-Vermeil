# encoding: utf-8
module SceneEngine
  @players = {}

  def self.play(scene_name, &block)
    scene_name = scene_name.to_s
    player = Player.new(scene_name)
    @players[scene_name] = player
    player.run(&block)
    @players.delete(scene_name)
  end

  def self.load_dialog(scene_name)
    path = "#{Settings::SCENES_DIR}/#{scene_name}/dialogue.txt"
    return {} unless File.exist?(path)

    data = {}
    current_label = nil
    current_speaker = nil
    current_speed = :normal
    current_text = []
    raw = File.read(path, encoding: "UTF-8")

    raw.each_line do |line|
      s = line.strip
      if s =~ /^\[(\w+)\]/
        if current_label
          data[current_label] = {
            speaker: current_speaker,
            speed:   current_speed,
            text:    current_text.join("\n")
          }
        end
        current_label = $1.to_sym
        current_speaker = nil
        current_speed = :normal
        current_text = []
      elsif s =~ /^speaker=(.+)/i
        current_speaker = $1.strip
      elsif s =~ /^speed=(.+)/i
        current_speed = $1.strip.to_sym
      elsif current_label && !s.empty?
        current_text << s
      end
    end

    if current_label
      data[current_label] = {
        speaker: current_speaker,
        speed:   current_speed,
        text:    current_text.join("\n")
      }
    end
    data
  end
end

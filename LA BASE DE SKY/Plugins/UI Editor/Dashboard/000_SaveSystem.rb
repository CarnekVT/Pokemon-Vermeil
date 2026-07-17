module UI_Editor
  module SaveSystem
    module_function
    FILE_PATH = "Data/ui_editor_config.rxdata"

    def guardar
      File.open(FILE_PATH, "wb") do |f|
        Marshal.dump($Settings_UI_Editor, f)
      end
    end

    def cargar
      garbage_collect_screenshots()
      if File.exist?(FILE_PATH) && File.size(FILE_PATH) > 0
        begin
          File.open(FILE_PATH, "rb") do |f|
            $Settings_UI_Editor = Marshal.load(f)
          end
        rescue => e
          puts "UI Editor: Error cargando config (#{e.message}), creando por defecto."
          create_default()
        end
      else
        create_default()
      end
    end

    def create_default
      $Settings_UI_Editor = Settings_UI_Editor.new
      guardar()
    end

    def self.garbage_collect_screenshots
      DeleteUnusedScreenshots.delete_unused
    end
  end

  def self.settings
    if $Settings_UI_Editor.nil?
      $Settings_UI_Editor = Settings_UI_Editor.new
    end
    return $Settings_UI_Editor
  end
end

module Game
  class << self
    unless method_defined?(:ui_editor_initialize)
      alias_method :ui_editor_initialize, :initialize
    end
  end

  def self.initialize
    ui_editor_initialize
    begin
      UI_Editor::SaveSystem.cargar
    rescue => e
      UI_Editor::SaveSystem.create_default
    end
  end
end



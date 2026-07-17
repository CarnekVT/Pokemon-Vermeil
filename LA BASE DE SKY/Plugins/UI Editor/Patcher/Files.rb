
module UI_Editor
  module Patcher
    class FilesHandler
      ROOT_DIR      = "Plugins/Addons-UIs"
      BACKUP_DIR    = ROOT_DIR + "/UI_Editor_Backups"

      def initialize(root = ROOT_DIR, backup = BACKUP_DIR)
        @root_dir   = root
        @backup_dir = backup
        create_folders
      end

      def create_folders
        Dir.mkdir(@root_dir) unless File.exist?(@root_dir)
        Dir.mkdir(@backup_dir) unless File.exist?(@backup_dir)

        create_meta_txt
      end

      def get_addon_path(class_name)
        safe_name = class_name.to_s.gsub("::", "_")
        File.join(@root_dir, "Addon_#{safe_name}.rb")
      end


      def save_debug_json(report_hash)
        debug_content = JSON.pretty_generate(report_hash)
        debug_path = File.join(@backup_dir, "last_patch_debug.json")
        write_file(debug_path, debug_content)
      end



      def create_backup(file_path)
        return unless File.exist?(file_path)
        timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
        filename  = File.basename(file_path, ".rb")
        dest = File.join(@backup_dir, "#{filename}_#{timestamp}.txt")
        
        File.open(file_path, 'rb') { |s| File.open(dest, 'wb') { |d| d.write(s.read) } }
      end

      def write_file(path, content)
        File.write(path, content)
      end

      private

      def create_meta_txt
        file_path = File.join(@root_dir, "meta.txt")
        return if File.exist?(file_path)
        File.open(file_path, "w") do |f|
          f.puts "Name         = UI Editor Addons"
          f.puts "Version      = 1.0.0"
          f.puts "Essentials   = 21.1"
          f.puts "Last         = true"
          f.puts "Credits      = UI Editor"
        end
      end
    end
  end
end
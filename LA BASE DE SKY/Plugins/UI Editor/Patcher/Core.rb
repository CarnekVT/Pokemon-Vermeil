require 'json'
module UI_Editor
  module Patcher
    class Core
      include MiolUtils
      def initialize
        @files = FilesHandler.new
        @condition = ConditionClasses.new
      end

      def request_compilation(all_data, original_stats, parent_scene)
        echo_color("--- INICIANDO PROCESO ---", "magenta")

        compiler = PatchCompiler.new(all_data, original_stats, parent_scene, @condition)
        report_hash = compiler.generate_report_hash

        return nil if report_hash["Changes"].empty?

        if show_preview(report_hash)

          execute_disk_patch(report_hash) 

          @files.save_debug_json(report_hash)
          return report_hash
        else
          return pbMessage("Operacion cancelada")
        end
      end

      private

      def execute_disk_patch(report)

        changes_by_class = report["Changes"].group_by { |c| c["owner_class"] }

        changes_by_class.each do |target_class, incoming_changes|
          addon_path = @files.get_addon_path(target_class)
          target_method = incoming_changes.first["target_method"]

          history_dna = { consts: {}, deltas: {} }
          if File.exist?(addon_path)
            @files.create_backup(addon_path)
            lines = File.readlines(addon_path)
            history_dna = Parser.parse(lines)
          end

          final_dna = Merger.merge(history_dna, incoming_changes)

          new_content = Generator.generate(target_class, target_method, final_dna)


          @files.write_file(addon_path, new_content)
          echo_color("✔ Addon actualizado: #{target_class}", "verde")
        end
      end



      def show_preview(report)
        echo_color("--------- PREVIEW ---------","amarillo")

        report["Changes"].each do |change|
          klass  = change["owner_class"]
          path   = change["path"]
          cond   = change["condition"]
          deltas = change["deltas"]

          
          header = "[ #{klass} ] -> #{path}"
          header += " (Condición: #{cond})" if cond
          echo_color(header, "verde")

          
          deltas.each do |prop, data|
            op = data["delta"] >= 0 ? "+=" : "-="
            val = data["delta"].abs
            if change["type"] == "const" ||  change["type"] == "hash_const"
              echoln "     = #{data['absolute']}"
            else
              echoln "    #{prop} #{op} #{val} (Final: #{data['absolute']})"
            end
          end
        end
        
        echo_color("---------------------------------------","amarillo")
        pbMessage("Cambios visibles en consola la debug")
        return pbConfirmMessage("¿Te parecen correctos Estos cambios? Al confirmar se aplicaran los cambios")
      end
    end
    
  end
  

end

module UI_Editor
  module Patcher
    class Generator
      START_TAG = "# === UI START ==="
      END_TAG   = "# === UI END ==="

      def self.generate(klass, method, dna)
        
        const_block = build_const_block(dna[:consts])
        hook_block  = build_hook_block(klass, method)
        delta_block = build_delta_block(dna[:deltas])

        
        return <<~RUBY
          #{START_TAG}
          # ADDON GENERADO AUTOMÁTICAMENTE POR  UI EDITOR V1
          # NO EDITAR ESTE BLOQUE MANUALMENTE
          
          class #{klass}
          #{const_block}
          #{hook_block}
            def apply_UI_deltas
              return if @ui_editor_applied
              return if defined?(@sprites).nil?
              @ui_editor_applied = true
              #{START_TAG}
          #{delta_block}
              #{END_TAG}
            end
          end
        RUBY
      end

      private

      # --- BLOQUE DE CONSTANTES ---
      def self.build_const_block(consts)
        return "" if consts.empty?
        lines = consts.map { |name, val| "  #{name} = #{val}" }
        return "\n  # --- Constantes de Interfaz ---\n" + lines.join("\n") + "\n"
      end

      # --- BLOQUE DE HOOK (Alias Method) ---
      def self.build_hook_block(klass, method)
        alias_name = "ui_editor_#{method.gsub(':', '_')}"
        
        return <<~RUBY
            # Inyección por Capas (Alias)
              if !method_defined?(:#{alias_name})
                alias_method :#{alias_name}, :#{method}
              end

              def #{method}(*args, &block)
                result = send(:#{alias_name}, *args, &block)
                apply_UI_deltas
                return result
              end
        RUBY
      end

      def self.build_delta_block(deltas)
        return "    # Sin cambios registrados." if deltas.empty?


        grouped = deltas.values.group_by { |d| d[:condition] }
        
        final_lines = []

        grouped.each do |condition, objects|
          indent = condition ? "      " : "    "
          lines = []


          objects.each do |obj|
            path = obj[:path_real]
            obj[:props].each do |prop, val|
              op = val >= 0 ? "+=" : "-="
              
              cmd = (path == "self") ? "#{prop} #{op} #{val.abs}" : "#{path}.#{prop} #{op} #{val.abs}"
              lines << "#{indent}(#{cmd} rescue nil)"
            end
          end


          if condition
            final_lines << "    if #{condition}\n#{lines.join("\n")}\n    end"
          else
            final_lines << lines.join("\n")
          end
        end

        return final_lines.join("\n")
      end
    end
  end
end
module UI_Editor
  module Patcher
    class Parser
      
      START_TAG = "# === UI START ==="
      END_TAG   = "# === UI END ==="

      def self.parse(lines)
        dna = { consts: {}, deltas: {} }
        in_ui_editor_block = false
        current_condition = nil

        lines.each do |line|
          line = line.strip
          

          if line.include?(START_TAG)
            in_ui_editor_block = true
            next
          elsif line.include?(END_TAG)
            in_ui_editor_block = false
            current_condition = nil
            next
          end

          
          if line =~ /^([A-Z][A-Z0-9_]*(?:\[.+?\])*)\s*=\s*(-?[\d.]+)/
            dna[:consts][$1.strip] = $2.to_f
            next
          end

          next unless in_ui_editor_block

          if line.start_with?("if ")

            type, val = ConditionHandlers.detect(line)

            current_condition = ConditionHandlers.generate(type, val)
            next
          

          elsif line == "end"
            current_condition = nil
            next
          end


          if line =~ /\(\s*(.+?)\s*([+-]=)\s*([\d.-]+)\s*rescue/
            full_path = $1.strip 
            operator  = $2       
            value     = $3.to_f
            

            if full_path.include?(".")
              path_parts = full_path.split(".")
              prop = path_parts.pop
              path = path_parts.join(".")
            else

              path = "self"
              prop = full_path
            end

            unique_key = current_condition ? "#{path}_IF_#{current_condition}" : path

            dna[:deltas][unique_key] ||= { 
              path_real: path, 
              condition: current_condition, 
              props: {} 
            }
            
            
            dna[:deltas][unique_key][:props][prop] = (operator == "-=" ? -value : value)
          end
        end

        return dna
      end
    end
  end
end

module UI_Editor
  module Patcher
    class Merger

      def self.merge(history, incoming)

        merge_constants(history[:consts], incoming)

        merge_deltas(history[:deltas], incoming)


        cleanup_dna(history)

        return history
      end

      private


      def self.merge_constants(history_consts, incoming)
        incoming.each do |change|
          next unless ["const", "hash_const"].include?(change["type"])
          

          path = change["path"]

          new_val = change["deltas"].values.first["absolute"]
          
          history_consts[path] = new_val
        end
      end


      def self.merge_deltas(history_deltas, incoming)
        incoming.each do |change|
          next if ["const", "hash_const"].include?(change["type"])

          path = change["path"]
          cond = change["condition"]
          

          norm_cond = ConditionHandlers.normalize(cond) if cond
          unique_key = norm_cond ? "#{path}_IF_#{norm_cond}" : path


          history_deltas[unique_key] ||= { 
            path_real: path, 
            condition: norm_cond, 
            props: {} 
          }

          change["deltas"].each do |prop, data|
            old_val = history_deltas[unique_key][:props][prop] || 0.0
            new_delta = data["delta"].to_f
            

            history_deltas[unique_key][:props][prop] = (old_val + new_delta).round(2)
          end
        end
      end


      def self.cleanup_dna(history)

        history[:deltas].each do |key, data|
          data[:props].delete_if { |prop, val| val.abs < 0.001 }
        end

        history[:deltas].delete_if { |key, data| data[:props].empty? }
      end
    end
  end
end



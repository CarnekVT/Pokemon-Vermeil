module UI_Editor
  module Patcher
    class PatchCompiler
      include MiolUtils

      def initialize(all_data, original_stats, parent_scene, condition)
        @all_data = all_data
        @orig     = original_stats
        @parent_scene = parent_scene
        @context_for_condition =  condition
      end

      
      def generate_report_hash
        report = {
          "Scene_Class" => @parent_scene.class.name,
          "Changes"     => []
        }

        @all_data.each do |category, entries|
          entries.each do |main_key, entry|
            
            main_change = process_object(entry[:main], nil, main_key, entry)
            report["Changes"] << main_change if main_change

            
            entry[:internals].each do |ivar, obj|
              
              internal_change = process_object(obj, ivar, main_key, entry, entry[:main])
              report["Changes"] << internal_change if internal_change
            end
          end
        end

        return report
      end

      private

      
      def process_object(obj, internal_var, main_key, entry, parent_obj = nil)
        return nil if !obj || obj.disposed?
        orig_stats = @orig[obj.object_id]
        return nil if !orig_stats

        
        ctx = resolve_context(obj, internal_var, main_key)
        
        
        deltas = calculate_deltas(obj, orig_stats, parent_obj, ctx[:rules])
        return nil if deltas.empty?

        
        path = resolve_path(obj, internal_var, main_key, ctx)
        return nil if path.nil?

        return {
          "path"          => path,
          "type"          => obj.is_a?(VirtualPointProxy) ? obj.type.to_s : "sprite",
          "owner_class"   => ctx[:owner],
          "target_method" => ctx[:method],
          "condition"     => ctx[:condition],
          "deltas"        => deltas
        }
      end

      
      def calculate_deltas(obj, orig, parent_obj, rules)
        obj_deltas = {}
        props = obj.is_a?(VirtualPointProxy) ? [:x, :y] : [:x, :y, :z, :zoom, :opacity, :angle]

        props.each do |prop|
          curr_val = get_val(obj, prop)
          diff = (curr_val - (orig[prop] || 0)).round(2)
          next if diff.abs < 0.001

          if parent_obj
            p_orig = @orig[parent_obj.object_id]
            p_diff = (get_val(parent_obj, prop) - (p_orig[prop] || 0)).round(2)
            next if (diff - p_diff).abs < 0.01
          end

          
          prop_name = (rules[:property_map] && rules[:property_map][prop]) || prop.to_s

          obj_deltas[prop_name] = { "delta" => diff, "absolute" => curr_val }
        end
        obj_deltas
      end


      def resolve_context(obj, internal_var, main_key)
        is_proxy = obj.is_a?(VirtualPointProxy)
        owner_name =  is_proxy ? obj.owner_class : obj.class.name
        
        
        rules = @context_for_condition.exception_for(owner_name)
        
        
        actual_owner = rules[:is_component] ? owner_name : @parent_scene.class.name

        
        condition = nil
        if rules[:auto_condition]
          idx = main_key.to_s.match(/_(\d+)/)
        
          condition = ConditionHandlers.generate(rules[:auto_condition], idx[1]) if idx
        end

        {
          owner: actual_owner,
          rules: rules,
          condition: condition,
          method: detect_target_method(actual_owner)
        }
      end

      def resolve_path(obj, internal_var, main_key, ctx)
        return obj.get_patch_path if obj.is_a?(VirtualPointProxy)
        
        if ctx[:rules][:path_logic] == :component_internal
          return internal_var.nil? ? "self" : "@#{internal_var}"
        end
        
        UI_Editor_Helper.find_object_path(obj, @parent_scene)
      end

      def detect_target_method(class_name)
        return "initialize" if class_name.include?("Battle::Scene")
        klass = Object.const_get(class_name) rescue (return "pbStartScene")
        return "pbStartScene" if klass.instance_methods(false).include?(:pbStartScene)
        return "initialize"
      end
    end
  end
end
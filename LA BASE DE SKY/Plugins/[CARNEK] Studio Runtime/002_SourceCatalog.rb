#===============================================================================
# Carnek Studio - Source Catalog
# Runtime reflection is read-only: it describes the effective Input module and
# writes a catalog for Maker Studio. It never changes Input itself.
#===============================================================================
module CarnekStudio
  module SourceCatalog
    module_function

    def json_safe_value(value)
      case value
      when NilClass, TrueClass, FalseClass, Numeric, String
        value
      when Symbol
        value.to_s
      else
        value.inspect
      end
    rescue
      nil
    end

    def input_catalog
      constants = []
      if defined?(Input)
        Input.constants(false).map(&:to_s).sort.each do |name|
          begin
            value = Input.const_get(name)
            constants << {
              "name"       => name,
              "expr"       => "Input::#{name}",
              "value"      => json_safe_value(value),
              "value_type" => value.class.to_s
            }
          rescue
          end
        end
      end
      {
        "schema"       => "carnek-studio.source-catalog.input",
        "version"      => 1,
        "generated_at" => Time.now.to_s,
        "source"       => "runtime-reflection",
        "constants"    => constants,
        "capabilities" => {
          "trigger"   => defined?(Input) && Input.respond_to?(:trigger?),
          "press"     => defined?(Input) && Input.respond_to?(:press?),
          "repeat"    => defined?(Input) && Input.respond_to?(:repeat?),
          "release"   => defined?(Input) && Input.respond_to?(:release?),
          "triggerex" => defined?(Input) && Input.respond_to?(:triggerex?),
          "pressex"   => defined?(Input) && Input.respond_to?(:pressex?),
          "repeatex"  => defined?(Input) && Input.respond_to?(:repeatex?)
        }
      }
    end

    def refresh_input!
      CarnekStudio.ensure_data_dir
      target = CarnekStudio.path("input_source_catalog.json")
      data = input_catalog
      # Always refresh at game boot so an Essentials/plugin update is reflected.
      File.binwrite(target, JSON.pretty_generate(data))
      data
    rescue => e
      PBDebug.log("[CarnekStudio] Input source catalog: #{e.message}") if defined?(PBDebug)
      nil
    end
  end
end

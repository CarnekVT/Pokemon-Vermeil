#=================================================================================================
# CLASES CON CONDICIONES EXCEPCIONALES.
#================================================================================================
=begin
  Habra clases las cuales los cambios que el editor tiene que escribir son bastante especificos
  Para aquellas clases las cuales no se pueden parchear de manera tradicional hay que especificarles 
  # ! excepciones
  Ejemplo la clase Databox crea el objeto databox en un combate, es una clase anidada en Battle::Scene
  y para poder interceptar un databox y manipular tu posicion de manera permanente sin manipular el codigo
  propio de la clase generamos lo que para el editor son # * "Excepciones"

  en vez de escribir 
  @sprite["databox0"].x += 120

  hara
  if @battler && @battler.index == 0
    @spriteX += 120
  end

  Por qué de esta manera tan extraña? Pues en explicaciones anteriores se explica que el editor percibe si la clase a parchear usa
  pbStarScene (muy usado en Pokemon Essentials) o initialize.

  y en aquellos objetos los cuales el sprite no se crea en el initialize se les aplica ciertas condiciones especiales.



  para añadir un condicional para un objeto debemos seguir los siguientes pasos

  Poner el nombre de la clase en el hash @classes_exceptions con una estructura

  {
  "Nombre_de_la_clase" => {
  
    Define si la clase es dueña de sus propios sprites. 
    Si es true, el Addon se inyectará en esta clase y no en la Escena Madre.

    :is_component    => true, 

    si la clase no tiene definida una "propiedad" en su initialize
    pero si  se especificaban sus propiedades de manera especifica. se puede adaptar a ello

    :property_map    => { :propiedad => "propiedad"},

    sirve para especificar si se usara self u @variable
    
    :path_logic      => :component_internal, 

    Especifica qué lógica de 'ConditionHandlers'  debe usarse para que el parche solo afecte al objeto correcto.

    :auto_condition  => :condition  
    }
  }
=end





module UI_Editor
  module Patcher
    class ConditionClasses
      def initialize
        @classes_exceptions = {
          "Battle::Scene::PokemonDataBox" => {
            :is_component    => true,
            :property_map    => { :x => "@spriteX", :y => "@spriteY" },
            :path_logic      => :component_internal,
            :auto_condition  => :databox             
          }
          
        }
      end

      def exception_for(owner_class)
        match = @classes_exceptions.keys.find { |k| owner_class.include?(k) }
        return @classes_exceptions[match] || defaults
      end

      def defaults
        {
          :is_component   => false,
          :property_map   => {},
          :path_logic     => :standard,
          :auto_condition => nil
        }
      end
    end
    
  end
  
end


#=============================================================================================================
# CONTROLADOR DE CONDICIONALES
# Busca funcionar de manera similar a los MenuHandlers para buscar conseguir mas modularidad a la hora
# de definir un condition para un obj


module ConditionHandlers
  @@handlers = {}

  module_function

  def add(id, hash)
    @@handlers[id.to_sym] = hash
  end
  
  def generate(id, value)
    handler = @@handlers[id.to_sym]
    return value.to_s if !handler || !handler["gen"]
    return handler["gen"].call(value)
  end


  def detect(line)
    line = line.strip.gsub(/^if\s+/, "").gsub(/\s+$/, "")
    
    @@handlers.each do |id, hash|
      next unless hash["regex"]
      if line =~ hash["regex"]

        return [id, $1] 
      end
    end
    

    return [:custom, line]
  end

  def normalize(str)
    return "" if str.nil?
    str.strip.gsub(/\s+/, " ").gsub("= =", "==")
  end
end

ConditionHandlers.add(:databox, {
  "gen"   => ->(v) { "@battler && @battler.index == #{v}" },
  "regex" => /@battler\.index\s*==\s*(\d+)/
})

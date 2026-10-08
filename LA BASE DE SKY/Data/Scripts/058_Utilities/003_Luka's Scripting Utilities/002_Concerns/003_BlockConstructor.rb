#===============================================================================
#  Luka's Scripting Utilities
#
#  * Various object extensions
#===============================================================================
module LUTS
  module Concerns
    # Block constructor module to allow passing of blocks when instanciating
    # new objects. Alternative to the `.tap` method.
    module BlockConstructor
      # Guard contra re-eval por F12: sin él, el re-alias captura la versión ya
      # parcheada de initialize (este módulo no tiene original externo que el
      # motor re-establezca) -> recursión infinita "stack level too deep".
      unless private_method_defined?(:with_block_constructor_initialize)
        alias with_block_constructor_initialize initialize
      end
      def initialize(*args, &block)
        with_block_constructor_initialize(*args)

        block.call(self) if block_given?
      end
    end
  end
end

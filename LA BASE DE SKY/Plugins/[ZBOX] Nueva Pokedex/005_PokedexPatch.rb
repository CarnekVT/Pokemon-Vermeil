# encoding: UTF-8
# Compatibilidad con la Pokédex regional en JSON de Vermeil.
# No se reemplazan registros @seen / @owned ni las APIs estándar globales.
class Player
  class Pokedex
    alias_method :vermeil_original_seen_count, :seen_count unless method_defined?(:vermeil_original_seen_count)
    alias_method :vermeil_original_owned_count, :owned_count unless method_defined?(:vermeil_original_owned_count)

    def seen_count(dex = -1)
      if dex && dex >= 0 && defined?(NuevaPokedex) && NuevaPokedex.enabled_dexes.include?(dex)
        return NuevaPokedex.regional_species(dex).count { |slot| NuevaPokedex.slot_seen?(slot) }
      end
      vermeil_original_seen_count(dex)
    end

    def owned_count(dex = -1)
      if dex && dex >= 0 && defined?(NuevaPokedex) && NuevaPokedex.enabled_dexes.include?(dex)
        return NuevaPokedex.regional_species(dex).count { |slot| NuevaPokedex.slot_owned?(slot) }
      end
      vermeil_original_owned_count(dex)
    end
  end
end

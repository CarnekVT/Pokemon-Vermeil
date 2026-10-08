#===============================================================================
# [ZBOX] Nueva Pokédex - Parche de Robustez para Player::Pokedex y Regional Dex
# Resuelve permanentemente la excepción:
#   NoMethodError at 006_Player_Pokedex.rb:383 - undefined method 'each' for nil:NilClass
#===============================================================================

# 1. Blindar pbAllRegionalSpecies para que NUNCA devuelva nil si una dex no está en PBS
if defined?(pbAllRegionalSpecies)
  unless defined?(_LBDS_CUST_newpokedex_orig_pbAllRegionalSpecies)
    alias _LBDS_CUST_newpokedex_orig_pbAllRegionalSpecies pbAllRegionalSpecies
  end

  def pbAllRegionalSpecies(dex = 0)
    begin
      res = _LBDS_CUST_newpokedex_orig_pbAllRegionalSpecies(dex)
      return res if res.is_a?(Array) && !res.empty?
    rescue StandardError
    end

    if defined?(NewPokedex) && NewPokedex.respond_to?(:species_in_dex)
      custom_list = NewPokedex.species_in_dex(dex) rescue nil
      return custom_list if custom_list.is_a?(Array) && !custom_list.empty?
    end

    return []
  end
end

# 2. Blindar directamente Player::Pokedex en caso de llamadas a dexes no compiladas en regional_dexes.dat
class Player
  class Pokedex
    unless method_defined?(:_LBDS_CUST_newpokedex_orig_seen_count)
      alias_method :_LBDS_CUST_newpokedex_orig_seen_count, :seen_count
    end

    def seen_count(dex = -1)
      if dex && dex >= 0
        species_list = nil
        if defined?(NewPokedex) && NewPokedex.respond_to?(:species_in_dex)
          species_list = NewPokedex.species_in_dex(dex) rescue nil
        end
        if (!species_list || species_list.empty?) && defined?(pbAllRegionalSpecies)
          species_list = pbAllRegionalSpecies(dex) rescue nil
        end
        return 0 if !species_list.is_a?(Array) || species_list.empty?
        return species_list.count { |s| seen?(s) }
      end
      return @seen ? @seen.values.count { |s| s } : 0
    rescue StandardError
      return 0
    end

    unless method_defined?(:_LBDS_CUST_newpokedex_orig_owned_count)
      alias_method :_LBDS_CUST_newpokedex_orig_owned_count, :owned_count
    end

    def owned_count(dex = -1)
      if dex && dex >= 0
        species_list = nil
        if defined?(NewPokedex) && NewPokedex.respond_to?(:species_in_dex)
          species_list = NewPokedex.species_in_dex(dex) rescue nil
        end
        if (!species_list || species_list.empty?) && defined?(pbAllRegionalSpecies)
          species_list = pbAllRegionalSpecies(dex) rescue nil
        end
        return 0 if !species_list.is_a?(Array) || species_list.empty?
        return species_list.count { |s| owned?(s) }
      end
      return @owned ? @owned.values.count { |s| s } : 0
    rescue StandardError
      return 0
    end
  end
end

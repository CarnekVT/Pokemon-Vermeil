#===============================================================================
# [CARNEK] Shiny Variants Runtime - Extensión de la Clase Pokemon
#===============================================================================
class Pokemon
  attr_accessor :shiny_variant

  alias __shinyvar_super_shiny? super_shiny?
  def super_shiny?
    return true if @shiny_variant == :supershiny
    return false if @shiny_variant && @shiny_variant != :supershiny && @shiny_variant != :none
    return __shinyvar_super_shiny?
  end

  def shiny_variant
    return @shiny_variant if @shiny_variant && @shiny_variant != :none
    return :supershiny if super_shiny?
    return :shiny if shiny?
    return :none
  end

  def shiny_variant=(val)
    if val.nil? || val == :none || val == false
      @shiny_variant = nil
      @shiny = false
      @super_shiny = false
    elsif val == :supershiny || val == "supershiny"
      @shiny_variant = :supershiny
      @super_shiny = true
      @shiny = true
    elsif val == :shiny || val == "shiny"
      @shiny_variant = :shiny
      @super_shiny = false
      @shiny = true
    else
      @shiny_variant = val.to_sym
      @shiny = true
      @super_shiny = false
    end
  end

  alias __shinyvar_shiny_assign shiny=
  def shiny=(value)
    __shinyvar_shiny_assign(value)
    @shiny_variant = nil if !value
  end

  alias __shinyvar_super_shiny_assign super_shiny=
  def super_shiny=(value)
    __shinyvar_super_shiny_assign(value)
    if value
      @shiny_variant = :supershiny
    elsif @shiny_variant == :supershiny
      @shiny_variant = nil
    end
  end

  def has_custom_shiny_variant?
    v = shiny_variant
    return v != :none && v != :shiny && v != :supershiny
  end

  # Hook de inicialización para soporte de generación automática de variantes
  alias __shinyvar_initialize initialize
  def initialize(*args)
    __shinyvar_initialize(*args)
    return if !ShinyVariantsSettings::ENABLED
    return if @shiny_variant # Ya asignado manualmente

    # Chequeo de variantes adicionales si es shiny o mediante rates propios
    ShinyVariantRegistry.all.each do |v_data|
      v_id = v_data["id"].to_sym
      next if v_id == :shiny || v_id == :supershiny
      rate = (v_data["rate"] || ShinyVariantsSettings::DEFAULT_VARIANT_CHANCE).to_i
      if rate > 0 && rand(rate) == 0
        self.shiny_variant = v_id
        break
      end
    end
  end
end

# Extensión para que los combatientes en batalla expongan su variante correctamente
if defined?(Battle::Battler)
  class Battle::Battler
    def shiny_variant
      poke = displayPokemon
      return poke.shiny_variant if poke && poke.respond_to?(:shiny_variant)
      return :none
    end
  end
end

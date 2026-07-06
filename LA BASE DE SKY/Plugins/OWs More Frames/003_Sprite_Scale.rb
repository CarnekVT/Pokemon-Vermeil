# encoding: utf-8
#===============================================================================
# OWs More Frames — Sprite Scale
# Permite escalar los sprites de personajes en overworld (jugador, followers,
# eventos) multiplicando su tamaño. Útil para sprites x1 que se ven pequeños.
#===============================================================================
module OWsMoreFrames
  module SpriteScale
    # Factor de escala de sprites OW (personajes). 1.0 = original, 2.0 = doble
    SCALE = 1.0

  end
end

class Sprite_Character
  alias _ows_scale_orig_initialize initialize unless method_defined?(:_ows_scale_orig_initialize)
  def initialize(*args)
    _ows_scale_orig_initialize(*args)
    apply_ows_scale
  end

  alias _ows_scale_orig_set_charset_graphic set_charset_graphic unless method_defined?(:_ows_scale_orig_set_charset_graphic)
  def set_charset_graphic
    _ows_scale_orig_set_charset_graphic
    apply_ows_scale
  end

  private

  def apply_ows_scale
    s = OWsMoreFrames::SpriteScale::SCALE
    self.zoom_x = TilemapRenderer::ZOOM_X * s
    self.zoom_y = TilemapRenderer::ZOOM_Y * s
  end
end

class Sprite_Character
  alias _ows_scale_orig_update update unless method_defined?(:_ows_scale_orig_update)
  def update(*args)
    _ows_scale_orig_update(*args)
  end
end


# =============================================================================
# Vibrant Companions — Espaciado simétrico izquierda/derecha
# Hace que get_horizontal_bounds use la fila "abajo" (dirección 2) para
# izquierda(4) y derecha(6), forzando bounds simétricos independientemente
# de la dirección real del sprite.
# =============================================================================
if defined?(VibrantCompanions) && defined?(VibrantCompanions::SmartSpacing)
  module VibrantCompanions
    module SmartSpacing
      class << self
        alias _ows_symm_orig_get_horizontal_bounds get_horizontal_bounds unless method_defined?(:_ows_symm_orig_get_horizontal_bounds)
        def get_horizontal_bounds(character_name, direction)
          dir = ([4, 6].include?(direction)) ? 2 : direction
          raw = _ows_symm_orig_get_horizontal_bounds(character_name, dir)
          if raw && [4, 6].include?(direction)
            raw = raw.dup
            ext = [raw[:right] - raw[:ox], raw[:ox] - raw[:left]].max
            raw[:left]  = raw[:ox] - ext
            raw[:right] = raw[:ox] + ext
          end
          raw
        end
      end
    end
  end
end

# =============================================================================
# Escalado en pantalla de carga (TrainerWalkingCharSprite)
# =============================================================================
module OWsMoreFrames
  module SpriteScale
    # Parche singleton para TrainerWalkingCharSprite
    def self.patch_trainer_sprite!
      return if @trainer_patched
      @trainer_patched = true
      TrainerWalkingCharSprite.class_eval do
        alias _ows_scale_orig_charset_set charset= unless method_defined?(:_ows_scale_orig_charset_set)
        def charset=(value)
          _ows_scale_orig_charset_set(value)
          apply_ows_trainer_scale
        end

        alias _ows_scale_orig_altcharset_set altcharset= unless method_defined?(:_ows_scale_orig_altcharset_set)
        def altcharset=(value)
          _ows_scale_orig_altcharset_set(value)
          apply_ows_trainer_scale
        end
      end
    end
  end
end

class TrainerWalkingCharSprite
  def apply_ows_trainer_scale
    s = OWsMoreFrames::SpriteScale::SCALE
    self.zoom_x = s
    self.zoom_y = s
  end
end

OWsMoreFrames::SpriteScale.patch_trainer_sprite!

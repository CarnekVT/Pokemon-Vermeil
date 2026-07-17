# Plugins/Carnek Project Settings/Settings/PC_Icon_Offset.rb

# ponytail: Centrar icono 42x42 en el slot 64x56 (5x5 grid).
# Offset: X = (64-42)/2 = 11, Y = (56-42)/2 = 7

class PokemonBoxSprite
  alias _ZBOX_PC_orig_initialize initialize
  
  def initialize(storage, box_number, viewport = nil)
    _ZBOX_PC_orig_initialize(storage, box_number, viewport)
    
    PokemonBox::BOX_SIZE.times do |i|
      sprite = @pokemonsprites[i]
      next if sprite.nil? || sprite.disposed?
      sprite.x += 11
      sprite.y += 7
    end
  end
end

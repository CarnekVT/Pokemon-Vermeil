################################################################################
#                       Animated Pokemon Selection Interface                   #
################################################################################
class AnimatedPokemonDisplay

  # Pokémon, x correction, y correction
  SPRITE_CORRECTIONS = [
    [:BULBASAUR, 6, -8],
    [:CHARMANDER, 6, -3],
    [:SQUIRTLE, 10, -6],
    [:CHIKORITA, 12, -16],
    [:CYNDAQUIL, 9, -6],
    [:TOTODILE, 0, -26],
    [:TREECKO, 8, -10],
    [:TORCHIC, 5, -9],
    [:MUDKIP, 7, 0],
    [:TURTWIG, 0, -4],
    [:CHIMCHAR, 9, -12],
    [:PIPLUP, 0, -6],
    [:SNIVY, 7, -7],
    [:TEPIG, 12, -8],
    [:OSHAWOTT, -7, -17],
    [:CHESPIN, 7, -3],
    [:FENNEKIN, 0, 0],
    [:FROAKIE, 0, -58],
    [:ROWLET, 8, -2],
    [:LITTEN, 0, 0],
    [:POPPLIO, 0, -12],
    [:GROOKEY, 7, -27],
    [:SCORBUNNY, 5, -20],
    [:SOBBLE, 3, -51],
    [:SPRIGATITO, 4, -3],
    [:FUECOCO, 2, -9],
    [:QUAXLY, 3, -13],
    [:SCATTERBUG, 0, -3],
    [:BLIPBUG, 0, 0],
    [:TEDDIURSA, 0, 0],
    [:WOOLOO, 4, -43],
    [:LECHONK, 0, -20],
    [:STARLY, 10, -0],
    [:ROLYCOLY, 10, -45],
  ]

  BASE_Y_CORRECTION = -10
  
  def initialize(pokemon, bg = false, ox = 0, oy = 0, zoom_x = 1, zoom_y = 1)
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @pokemon = pokemon
    @bg = bg
    @state = :normal
    @fade_speed = 15 #*2
    @ox = ox
    @oy = oy
    @zoom_x = zoom_x
    @zoom_y = zoom_y
    # display_animated_pokemon
    @opacity = 0
  end

  def display_animated_pokemon
    if defined?(RandomizedChallenge) && RandomizedChallenge.enabled? && !@pokemon.is_a?(Pokemon)
      RandomizedChallenge.pause_random_species
      @pokemon = Pokemon.new(@pokemon, 1)
      RandomizedChallenge.resume_random_species
    end
    pokemon_obj = @pokemon.is_a?(Pokemon) ? @pokemon : Pokemon.new(@pokemon, 1)
    if @bg
      @sprites["bg"] = Sprite.new(@viewport)
      # Make the bg depend on the Pokémon's first type
      type = defined?(MonotypeChallenge) && MonotypeChallenge.enabled? ? MonotypeChallenge.type : pokemon_obj.types[0]
      @sprites["bg"].bitmap = Bitmap.new("Graphics/Pictures/fondo_poke_#{type.to_s.downcase}")
      @sprites["bg"].opacity = 0
    end

    # Check if the Pokémon has a sprite correction
    correction = SPRITE_CORRECTIONS.find { |c| c[0] == pokemon_obj.species }
    x_corr = correction ? correction[1] : 0
    y_corr = correction ? correction[2] : 0


    @sprites["poke_sprite"] = PokemonSprite.new(@viewport)
    @sprites["poke_sprite"].setPokemonBitmap(pokemon_obj)
    @sprites["poke_sprite"].setOffset(PictureOrigin::CENTER)
    @sprites["poke_sprite"].z = 99999
    @sprites["poke_sprite"].x = @ox + x_corr
    @sprites["poke_sprite"].y = @oy + y_corr + BASE_Y_CORRECTION
    @sprites["poke_sprite"].zoom_x = @zoom_x
    @sprites["poke_sprite"].zoom_y = @zoom_y
    @sprites["poke_sprite"].opacity = 0

    @state = :fadein
  end

  def update
    return if disposed?
    case @state
    when :fadein
      finished = true
      @sprites.each_value do |s|
        next unless s.respond_to?(:opacity)
        s.opacity += @fade_speed
        finished = false if s.opacity < 255
      end
      @state = :normal if finished
    when :fadeout
      finished = true
      @sprites.each_value do |s|
        next if s.disposed?
        next unless s.respond_to?(:opacity)
        s.opacity -= @fade_speed
        finished = false if s.opacity > 0
      end
      if finished
        @state = :disposed
        dispose
      end
    else
        @sprites.each_value do |s|
        next if s.disposed?
        s.update if s.respond_to?(:update)
        end
    end
  end

  def start_fade_out
    @state = :fadeout
  end

  def disposed?
    @state == :disposed
  end

  def dispose
    @sprites.each_value(&:dispose)
    @viewport.dispose
  end
end

module Graphics
  class << self
    alias _update_poke_animado update
    def update
      _update_poke_animado
      $poke_animado.update if defined?($poke_animado) && $poke_animado
    end
  end
end


# FUNCTIONS TO USE IT
def pbDisplayAnimatedPokemon(pokemon, bg = false, ox = 0, oy = 0, zoom_x = 1, zoom_y = 1)
  $poke_animado = AnimatedPokemonDisplay.new(pokemon, bg, ox, oy, zoom_x, zoom_y)
  $poke_animado.display_animated_pokemon
end

def pbEndAnimatedPokemon
  $poke_animado.start_fade_out if $poke_animado
end

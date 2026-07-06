################################################################################
#                       Interfaz de eleción de Starters                        #
################################################################################
class MostrarPokemonAnimado

  # Pokémon, corrección x, corrección y
  CORRECCIONES_SPRITES = [
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
  UI_Z = 999999
  FADE_SPEED = 15

  def initialize(pokemon, bg = false, ox = 0, oy = 0, zoom_x = 1, zoom_y = 1)
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = UI_Z
    @sprites = {}
    @pokemon = pokemon
    @bg = bg
    @estado = :normal
    @fade_speed = FADE_SPEED #*2
    @ox = ox
    @oy = oy
    @zoom_x = zoom_x
    @zoom_y = zoom_y
    @opacity = 0
  end

  def mostrar_poke_animado
    if defined?(RandomizedChallenge) && RandomizedChallenge.enabled? && !@pokemon.is_a?(Pokemon)
      RandomizedChallenge.pause_random_species
      @pokemon = Pokemon.new(@pokemon, 1)
      RandomizedChallenge.resume_random_species
    end
    pokemon_obj = @pokemon.is_a?(Pokemon) ? @pokemon : Pokemon.new(@pokemon, 1)
    if @bg
      # Hacemos que el bg dependa del primer tipo del Pokémon
      type = defined?(MonotypeChallenge) && MonotypeChallenge.enabled? ? MonotypeChallenge.type : pokemon_obj.types[0]
      bg_path = pbResolveBitmap("Graphics/Pictures/fondo_poke_#{type.to_s.downcase}")
      if bg_path
        @sprites["bg"] = Sprite.new(@viewport)
        @sprites["bg"].bitmap = Bitmap.new(bg_path)
        @sprites["bg"].z = UI_Z - 1
        @sprites["bg"].visible = true
        @sprites["bg"].opacity = 0
      end
    end

    # Verificar si el Pokémon tiene una corrección de sprite
    correccion = CORRECCIONES_SPRITES.find { |c| c[0] == pokemon_obj.species }
    x_corr = correccion ? correccion[1] : 0
    y_corr = correccion ? correccion[2] : 0

    base_x = @ox + x_corr
    base_y = @oy + y_corr + BASE_Y_CORRECTION

    @sprites["poke_sprite"] = PokemonSprite.new(@viewport)
    @sprites["poke_sprite"].x = base_x
    @sprites["poke_sprite"].y = base_y
    @sprites["poke_sprite"].setPokemonBitmap(pokemon_obj)
    if !@sprites["poke_sprite"].bitmap
      @sprites["poke_sprite"].setSpeciesBitmap(
        pokemon_obj.species,
        pokemon_obj.gender,
        pokemon_obj.form,
        pokemon_obj.shiny?,
        pokemon_obj.shadowPokemon?,
        false,
        pokemon_obj.egg?
      )
    end
    @sprites["poke_sprite"].zoom_x = @zoom_x
    @sprites["poke_sprite"].zoom_y = @zoom_y
    if @sprites["poke_sprite"].bitmap
      @sprites["poke_sprite"].pbSetDisplay if @sprites["poke_sprite"].respond_to?(:pbSetDisplay)
    else
      @sprites["poke_sprite"].setOffset(PictureOrigin::BOTTOM)
      @sprites["poke_sprite"].x = base_x
      @sprites["poke_sprite"].y = base_y
    end
    @sprites["poke_sprite"].z = UI_Z
    @sprites["poke_sprite"].visible = true
    @sprites["poke_sprite"].opacity = @opacity
    @sprites["poke_sprite"].update

    @estado = :fadein
  end

  def update
    return if disposed?
    
    case @estado
    when :fadein
      terminado = true
      @sprites.each_value do |s|
        next if s.disposed?

        s.update if s.respond_to?(:update)
        next unless s.respond_to?(:opacity)

        s.opacity += @fade_speed
        terminado = false if s.opacity < 255
      end
      @estado = :normal if terminado
    when :fadeout
      terminado = true
      @sprites.each_value do |s|
        next if s.disposed?
        next unless s.respond_to?(:opacity)

        s.opacity -= @fade_speed
        terminado = false if s.opacity.positive?
      end
      if terminado
        @estado = :disposed
        dispose
        $poke_animado = nil if $poke_animado.equal?(self)
      end
    else
      @sprites.each_value do |s|
        next if s.disposed?

        s.update if s.respond_to?(:update)
      end
    end
  end

  def start_fade_out
    @estado = :fadeout
  end

  def disposed?
    @estado == :disposed
  end

  def dispose
    @estado = :disposed
    @sprites.each_value { |sprite| sprite.dispose if sprite && !sprite.disposed? }
    @viewport.dispose if @viewport && !@viewport.disposed?
  end
end

EventHandlers.add(:on_frame_update, :poke_animado_overlay,
                  proc { $poke_animado&.update if defined?($poke_animado) && !$poke_animado.disposed? })


# FUNCIONES PARA USARLO
def pbMostrarPkmnAnimado(pokemon, bg = false, ox = 0, oy = 0, zoom_x = 1, zoom_y = 1)
  if defined?($poke_animado) && $poke_animado && !$poke_animado.disposed?
    $poke_animado.dispose
    $poke_animado = nil
  end
  $poke_animado = MostrarPokemonAnimado.new(pokemon, bg, ox, oy, zoom_x, zoom_y)
  $poke_animado.mostrar_poke_animado
end

def pbTermninarPkmnAnimado
  $poke_animado&.start_fade_out
end
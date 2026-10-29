#===============================================================================
# Visual 2.5D HD - Atmosfera
#-------------------------------------------------------------------------------
# Capas a pantalla completa, por encima del mapa y por debajo de las imagenes y
# los mensajes:
#
#   - Neblina de distancia arriba, justo donde esta el punto de fuga.
#   - Neblina de primer plano abajo. Las dos juntas dejan enfocada solo la banda
#     central, que es como los mods 2.5D consiguen el aspecto de maqueta sin
#     tener que desenfocar de verdad.
#   - Vineteado suave en los bordes.
#   - Etiqueta de modo (2D / 2.5D) abajo a la izquierda.
#
# Todas se generan por codigo y son puramente decorativas.
#===============================================================================
module Visual25D
  class Atmosphere
    LABEL_W = 160
    LABEL_H = 28

    def initialize
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = Config::OVERLAY_Z
      @haze = Sprite.new(@viewport)
      @haze.bitmap = Visual25D.haze_bitmap(:top)
      @haze.z = 0
      @near_haze = Sprite.new(@viewport)
      @near_haze.bitmap = Visual25D.haze_bitmap(:bottom)
      @near_haze.z = 0
      # No crear sprites ni bitmaps de oscurecimiento de bordes cuando
      # el filtro esta desactivado. Evita ademas trabajo de renderizado.
      @vignette = {}
      if Config::VIGNETTE
        size = Visual25D.vignette_size
        [:top, :bottom, :left, :right].each do |edge|
          sprite = Sprite.new(@viewport)
          sprite.bitmap = Visual25D.vignette_bitmap(edge)
          sprite.z = 1
          case edge
          when :bottom then sprite.y = Graphics.height - size
          when :right  then sprite.x = Graphics.width - size
          end
          @vignette[edge] = sprite
        end
      end
      @mode_label = Sprite.new(@viewport)
      @mode_label.z = 10
      @mode_label.bitmap = Bitmap.new(LABEL_W, LABEL_H)
      pbSetSystemFont(@mode_label.bitmap)
      @mode_label.y = Graphics.height - LABEL_H - Config::MODE_LABEL_PAD_Y
      @mode_label.x = -LABEL_W
      @mode_label.visible = false
      @mode_label_key = nil
      @mode_anim = :hidden
      @mode_anim_t0 = 0.0
      @mode_in_from_x = -LABEL_W
      @mode_out_from_x = -LABEL_W
      @mode_was_blending = false
      @blur_top = Sprite.new(@viewport)
      @blur_top.z = -1
      @blur_top.visible = false
      @blur_bot = Sprite.new(@viewport)
      @blur_bot.z = -1
      @blur_bot.visible = false
      @blur_frame = nil
      @atmo_enabled = nil
      update
    end

    def update
      outdoor = !Config::HAZE_OUTDOOR_ONLY || $game_map&.metadata&.outdoor_map
      enabled = Visual25D.enabled?
      # ponytail: niebla/viñeta siguen el blend del fundido on/off.
      b = Visual25D.blend
      haze_op = (Visual25D.haze_opacity * b).round
      near_op = (Visual25D.near_haze_opacity * b).round
      vig_op = (Visual25D.vignette_opacity * b).round
      # Mas tilt → un poco mas neblina (opacity only; Bitmap cacheado).
      link = Config::HAZE_TILT_LINK.to_f
      if link > 0 && enabled && Config::MAX_TILT_DEGREES > 0
        tilt_f = (Visual25D.tilt.to_f / Config::MAX_TILT_DEGREES) * b
        mul = 1.0 + (link * tilt_f)
        haze_op = (haze_op * mul).round
        near_op = (near_op * mul).round
      end
      # Luz barata (Model3D light/ambient): sesgo top vs near haze.
      vig_left = vig_op
      vig_right = vig_op
      vig_tb = vig_op
      if Config::LIGHT_BIAS && enabled && Config::LIGHT_STRENGTH.to_f > 0
        amb = Config::LIGHT_AMBIENT.to_f
        amb = 0.0 if amb < 0.0
        amb = 1.0 if amb > 1.0
        str = Config::LIGHT_STRENGTH.to_f
        ly = Config::LIGHT_DIR_Y.to_f
        lx = Config::LIGHT_DIR_X.to_f
        # ly < 0 = luz desde arriba → un poco mas near-haze (suelo/camara).
        top_w = 1.0 + (str * (ly > 0 ? ly : 0.0))
        near_w = 1.0 + (str * (ly < 0 ? -ly : 0.0))
        haze_op = (haze_op * amb * top_w).round
        near_op = (near_op * amb * near_w).round
        # DIR_X: borde contrario a la luz un poco mas oscuro (vineta L/R).
        vig_left = (vig_op * amb * (1.0 + (str * (lx > 0 ? lx : 0.0)))).round
        vig_right = (vig_op * amb * (1.0 + (str * (lx < 0 ? -lx : 0.0)))).round
        vig_tb = (vig_op * amb).round
      end
      vig_left = 255 if vig_left > 255
      vig_right = 255 if vig_right > 255
      vig_tb = 255 if vig_tb > 255
      haze_op = 255 if haze_op > 255
      near_op = 255 if near_op > 255
      # Tone dia/noche: getTone cachea por minuto de juego.
      # ponytail: ivars escalares, sin Array por frame.
      if Settings::TIME_SHADING && outdoor && defined?(PBDayNight)
        t = PBDayNight.getTone
        tr = t.red
        tg = t.green
        tb = t.blue
        tgray = t.gray
      else
        tr = tg = tb = tgray = nil
      end
      # Label fuera del early-out de haze (sigue animando en idle).
      atmo_same = @atmo_enabled == enabled && @atmo_outdoor == outdoor &&
                  @atmo_haze_op == haze_op && @atmo_near_op == near_op &&
                  @atmo_vig_tb == vig_tb && @atmo_vig_l == vig_left &&
                  @atmo_vig_r == vig_right && @atmo_tr == tr && @atmo_tg == tg &&
                  @atmo_tb == tb && @atmo_tgray == tgray
      unless atmo_same
        @atmo_enabled = enabled
        @atmo_outdoor = outdoor
        @atmo_haze_op = haze_op
        @atmo_near_op = near_op
        @atmo_vig_tb = vig_tb
        @atmo_vig_l = vig_left
        @atmo_vig_r = vig_right
        @atmo_tr = tr
        @atmo_tg = tg
        @atmo_tb = tb
        @atmo_tgray = tgray
        update_haze(@haze, Config::HAZE && outdoor, haze_op)
        update_haze(@near_haze, Config::NEAR_HAZE && outdoor, near_op)
        vignette_visible = Config::VIGNETTE && enabled && vig_op > 0
        @vignette.each do |edge, sprite|
          sprite.visible = vignette_visible
          next if !vignette_visible
          case edge
          when :left  then sprite.opacity = vig_left
          when :right then sprite.opacity = vig_right
          else             sprite.opacity = vig_tb
          end
        end
      end
      update_mode_label
      update_band_blur
    end

    def mode_label_rest_x
      return Config::MODE_LABEL_PAD_X
    end

    def mode_label_hidden_x
      return -LABEL_W
    end

    def mode_label_slide_dur
      dur = Config::MODE_LABEL_SLIDE_SECONDS.to_f
      return 0.01 if dur <= 0
      return dur
    end

    def paint_mode_label_text
      key = Visual25D.mode_label_25d? ? :d25 : :d2
      return if key == @mode_label_key
      @mode_label_key = key
      text = (key == :d25) ? _INTL("Modo 2.5D") : _INTL("Modo 2D")
      bmp = @mode_label.bitmap
      bmp.clear
      pbSetSystemFont(bmp)
      base = Color.new(248, 248, 248)
      shadow = Color.new(64, 64, 64)
      pbDrawShadowText(bmp, 0, 0, LABEL_W, LABEL_H, text, base, shadow, 0)
    end

    def start_mode_label_in!
      paint_mode_label_text
      @mode_label.x = mode_label_hidden_x if @mode_anim == :hidden
      @mode_in_from_x = @mode_label.x
      @mode_anim = :in
      @mode_anim_t0 = System.uptime
      @mode_label.visible = true
    end

    def start_mode_label_out!
      return if @mode_anim == :out || @mode_anim == :hidden
      @mode_out_from_x = @mode_label.x
      @mode_anim = :out
      @mode_anim_t0 = System.uptime
      @mode_label.visible = true
    end

    def update_mode_label
      return if !@mode_label || @mode_label.disposed?
      unless Config::MODE_LABEL
        @mode_label.visible = false
        @mode_anim = :hidden
        return
      end
      blending = Visual25D.blending?
      if blending && !@mode_was_blending
        start_mode_label_in!
      elsif !blending && @mode_was_blending
        start_mode_label_out!
      end
      @mode_was_blending = blending
      # Mid-fundido: actualizar texto si invierten el toggle.
      paint_mode_label_text if blending && (@mode_anim == :in || @mode_anim == :hold)
      rest = mode_label_rest_x
      hidden = mode_label_hidden_x
      dur = mode_label_slide_dur
      case @mode_anim
      when :in
        t = ((System.uptime - @mode_anim_t0) / dur).clamp(0.0, 1.0)
        s = t * t * (3.0 - (2.0 * t))
        from = @mode_in_from_x
        @mode_label.x = (from + ((rest - from) * s)).round
        @mode_label.visible = true
        if t >= 1.0
          @mode_anim = :hold
          @mode_label.x = rest
        end
      when :hold
        @mode_label.x = rest
        @mode_label.visible = true
      when :out
        t = ((System.uptime - @mode_anim_t0) / dur).clamp(0.0, 1.0)
        s = t * t * (3.0 - (2.0 * t))
        from = @mode_out_from_x
        @mode_label.x = (from + ((hidden - from) * s)).round
        @mode_label.visible = true
        if t >= 1.0
          @mode_anim = :hidden
          @mode_label.x = hidden
          @mode_label.visible = false
        end
      else
        @mode_label.visible = false
        @mode_label.x = hidden
      end
    end

    def update_haze(sprite, wanted, opacity)
      visible = wanted && Visual25D.enabled? && opacity > 0
      sprite.visible = visible
      return if !visible
      sprite.opacity = opacity
      pbDayNightTint(sprite)
    end

    def dispose
      @haze.dispose
      @near_haze.dispose
      @vignette.each_value { |sprite| sprite.dispose }
      @vignette.clear
      dispose_band_blur
      @mode_label&.dispose
      @mode_label = nil
      @viewport.dispose
    end

    # Franjas de arriba y de abajo, muestreando la pantalla ya dibujada y
    # bajándola de resolución. Va debajo de la niebla. No es un shader.
    def update_band_blur
      show = Visual25D.respond_to?(:band_blur?) && Visual25D.band_blur? &&
             Visual25D.enabled? && Visual25D.tilt.to_i > 0
      if !show
        @blur_top.visible = false if @blur_top && !@blur_top.disposed?
        @blur_bot.visible = false if @blur_bot && !@blur_bot.disposed?
        return
      end
      dx = $game_map&.display_x
      dy = $game_map&.display_y
      frame = Graphics.frame_count
      need = @blur_top.bitmap.nil? || @blur_bot.bitmap.nil?
      moved = @blur_dx != dx || @blur_dy != dy
      stale = @blur_frame.nil? || (frame - @blur_frame) >= 3
      if need || (moved && stale && !$game_temp&.message_window_showing)
        @blur_dx = dx
        @blur_dy = dy
        @blur_frame = frame
        refresh_band_blur
      end
      op = (Config::BAND_BLUR_OPACITY * Visual25D.blend).round
      op = 0 if op < 0
      op = 255 if op > 255
      [@blur_top, @blur_bot].each do |spr|
        next if !spr || spr.disposed? || !spr.bitmap
        spr.opacity = op
        spr.visible = op > 0
      end
    end

    def refresh_band_blur
      return if !Graphics.respond_to?(:snap_to_bitmap)
      @blur_top.visible = false
      @blur_bot.visible = false
      snap = Graphics.snap_to_bitmap
      return if !snap
      w = Graphics.width
      h = Graphics.height
      top_h = (h * 0.22).round
      bot_h = (h * 0.16).round
      top_h = 8 if top_h < 8
      bot_h = 8 if bot_h < 8
      blit_band(@blur_top, snap, 0, 0, w, top_h)
      blit_band(@blur_bot, snap, 0, h - bot_h, w, bot_h)
      @blur_top.x = 0
      @blur_top.y = 0
      @blur_bot.x = 0
      @blur_bot.y = h - bot_h
    ensure
      snap&.dispose
    end

    def blit_band(sprite, snap, sx, sy, sw, sh)
      return if !sprite || sprite.disposed?
      factor = 4
      small_w = sw / factor
      small_h = sh / factor
      small_w = 1 if small_w < 1
      small_h = 1 if small_h < 1
      small = Bitmap.new(small_w, small_h)
      small.stretch_blt(small.rect, snap, Rect.new(sx, sy, sw, sh))
      small.blur if small.respond_to?(:blur)
      dest = sprite.bitmap
      if !dest || dest.disposed? || dest.width != sw || dest.height != sh
        dest.dispose if dest && !dest.disposed?
        dest = Bitmap.new(sw, sh)
        sprite.bitmap = dest
      end
      dest.stretch_blt(dest.rect, small, small.rect)
      small.dispose
    end

    def dispose_band_blur
      [@blur_top, @blur_bot].each do |spr|
        next if !spr || spr.disposed?
        spr.bitmap&.dispose
        spr.dispose
      end
      @blur_top = nil
      @blur_bot = nil
    end
  end
end

#===============================================================================
# La capa vive en Scene_Map y no en Spriteset_Map, porque Essentials crea un
# Spriteset_Map por cada mapa conectado y la neblina se acumularia.
#===============================================================================
# Q era Turbo (AUX1). Solo ALT queda para turbo; Q = fundido 2.5D en OW.
if defined?(TurboConfig) && TurboConfig.const_defined?(:TOGGLE_KEYS)
  TurboConfig.send(:remove_const, :TOGGLE_KEYS)
  TurboConfig.const_set(:TOGGLE_KEYS, [Input::ALT])
end

module Visual25D
  class << self
    # Misma puerta que el movimiento libre en Scene_Map / Game_Player,
    # salvo un mensaje de personaje: ahi el interprete sigue corriendo y
    # cada frame entra por miniupdate, pero la Q debe poder cambiar el modo.
    def player_can_toggle_hotkey?
      return false if blending?
      return false if !$game_player
      return false if $game_temp&.in_menu || $game_temp&.in_battle
      if $game_temp&.message_window_showing
        return true
      end
      return false if $game_temp&.in_mini_update
      return false if pbMapInterpreterRunning?
      return false if $PokemonGlobal&.forced_movement?
      return true
    end

    def try_hotkey_toggle!
      # Exclusivo del juego en modo debug. AUX1 es un input logico
      # de Essentials, no una letra fisica ni una tecla configurable.
      return if !$DEBUG
      return if !defined?(Input::AUX1)
      return if !Input.trigger?(Input::AUX1)
      return if !player_can_toggle_hotkey?
      cambiar_modo_suave
    end
  end
end

# Durante el fundido 2.5D no se acepta input de movimiento: el scroll con la
# rejilla a medias dejaba franjas negras.
class Game_Player
  alias hd25_update_command_new update_command_new unless method_defined?(:hd25_update_command_new)
  def update_command_new
    return if Visual25D.blending?
    hd25_update_command_new
  end
end

class Scene_Map
  alias hd25_createSpritesets createSpritesets unless method_defined?(:hd25_createSpritesets)
  def createSpritesets
    # Un reinicio con F12 puede dejar el encuadre corrido y las medidas de la
    # camara a medias: al volver al mapa se parte de cero.
    Visual25D.reset_render_state
    Visual25D.ensure_perf_auto!
    hd25_createSpritesets
    @hd25_atmosphere = Visual25D::Atmosphere.new if !@hd25_atmosphere
  end

  alias hd25_disposeSpritesets disposeSpritesets unless method_defined?(:hd25_disposeSpritesets)
  def disposeSpritesets
    hd25_disposeSpritesets
    @hd25_atmosphere&.dispose
    @hd25_atmosphere = nil
  end

  alias hd25_updateSpritesets updateSpritesets unless method_defined?(:hd25_updateSpritesets)
  def updateSpritesets(refresh = false)
    # Hotkey ANTES del tilemap: prepare + sync grid + dibujo el mismo frame
    # (en update_input iba despues → 1 frame sin capas MS/paredes).
    Visual25D.try_hotkey_toggle!
    Visual25D.refresh_active
    hd25_updateSpritesets(refresh)
    @hd25_atmosphere&.update
  end
end
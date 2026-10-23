#===============================================================================
# Visual 2.5D HD - Paredes frontales
#-------------------------------------------------------------------------------
# Terrain tag :Cliff (19) en la cara que mira a la camara.
#
#   Lift en espacio SIN proyectar (Tile Depth). Misma arista unprojected
#   → mismo project_y → bottom(x,y) == top(x,y+1) sin bailar al scroll.
#
#   Rampa: smooth_rows + smooth_columns (menos escalones N-S).
#   Geometria por columna (aristas compartidas). Sin angle/media de vertices
#   (rompian esquinas).
#
#   pri>=1 = columna billboard; pies pri1 = top pri0 de y+1.
#===============================================================================
GameData::TerrainTag.register({ :id => :Cliff, :id_number => 19 })

module Visual25D
  #=============================================================================
  # Que casillas de un mapa son pared, y cuanto se levanta cada una.
  #=============================================================================
  class WallField
    attr_reader :flat

    def initialize(map)
      @width  = map.width
      @height = map.height
      @flat   = true
      return if !Config::WALLS
      return if !scan(map)
      measure
      @flat = false
    end

    # Cuanto sube el borde superior de esa casilla, en tiles de pared. Es un
    # numero con decimales: el suavizado deja valores intermedios.
    def lift(x, y)
      return 0.0 if @flat || x < 0 || y < 0 || x >= @width || y >= @height
      value = @lift[(y * @width) + x]
      return 0.0 if value < Config::LIFT_EPSILON
      return value
    end

    def lifted?(x, y)
      return false if @flat || x.nil? || y.nil? || x < 0 || y < 0 || x >= @width || y >= @height
      # ponytail: flags al medir; evita 2× lift() por tile/frame
      return @cell_lifted[(y * @width) + x] if @cell_lifted
      return lift(x, y) > 0.0 || lift(x, y + 1) > 0.0
    end

    # Casilla con desnivel propio o lateral (seal / bounds especiales).
    def wall_geom?(x, y)
      return false if @flat || x.nil? || y.nil? || x < 0 || y < 0 || x >= @width || y >= @height
      return false if !@wall_geom
      return @wall_geom[(y * @width) + x]
    end

    def lateral_step?(x, y)
      return false if @flat || x.nil? || y.nil? || x < 0 || y < 0 || x >= @width || y >= @height
      return false if !@lateral_step
      return @lateral_step[(y * @width) + x]
    end

    # Cuanto sube el borde de arriba y cuanto el de abajo de la casilla.
    #
    # El de abajo es el levantamiento de la casilla siguiente, que es el MISMO
    # numero que usa esa para su borde de arriba. Por eso ninguna casilla puede
    # taparle el borde a la de al lado ni separarse de ella: comparten el limite.
    # Un bordillo se estira porque su borde de arriba sube mas que el de abajo, y
    # la casilla que tiene encima se encoge un poco para acompanarlo.
    def span(x, y)
      return [lift(x, y), lift(x, y + 1)]
    end

    # Levantamiento del suelo bajo los pies de algo que esta en esa posicion. Los
    # pies se apoyan en el borde de abajo de la casilla, que va bajando conforme
    # el personaje avanza hacia la siguiente: por eso se interpola con fy y no da
    # un salto al cambiar de casilla.
    def ground_lift(x, y, fy)
      near = lift(x, y + 1)
      far  = lift(x, y + 2)
      return near + ((far - near) * fy)
    end

    def wall_at?(x, y)
      return false if @flat || x < 0 || y < 0 || x >= @width || y >= @height
      return @wall && @wall[(y * @width) + x]
    end

    # Para diagnostico: true si esta casilla Cliff y la de debajo no comparten run.
    def run_break?(x, y)
      return false if @flat || x < 0 || y < 0 || x >= @width || y + 1 >= @height
      return false if !@wall
      index = (y * @width) + x
      below = index + @width
      return false if !@wall[index] || !@wall[below]
      return !same_run?(index, below)
    end

    #---------------------------------------------------------------------------

    private

    def scan(map)
      tag = Config::WALL_TERRAIN_TAG
      return false if !tileset_uses_tag?(map, tag)
      @wall = Array.new(@width * @height, false)
      found = false
      @height.times do |y|
        @width.times do |x|
          # countBridge a true: el resultado se cachea y no puede depender de si
          # el jugador esta sobre un puente en este momento.
          next if map.terrain_tag(x, y, true).id != tag
          @wall[(y * @width) + x] = true
          found = true
        end
      end
      return found
    end

    # Recorrer 40.000 casillas llamando a terrain_tag no es gratis, y la inmensa
    # mayoria de los mapas no tiene ninguna pared marcada. Si el tileset del mapa
    # no usa el tag se descarta sin mirar el mapa.
    def tileset_uses_tag?(map, tag)
      return true if defined?(MakerStudio) && MakerStudio::ENABLED &&
                     MakerStudio.get_extended_data_for(map.map_id)
      tags = map.terrain_tags
      return false if !tags
      number = GameData::TerrainTag.try_get(tag).id_number
      tags.xsize.times { |tile_id| return true if tags[tile_id] == number }
      return false
    end

    def measure
      build_runs
      @lift = build_stacks.map { |value| value.to_f }
      # E-O y N-S: la rampa deja de verse como escalones de un tile por fila.
      Config::WALL_SMOOTHING.times do
        smooth_rows
        smooth_columns if Config::WALL_SMOOTH_VERTICAL
      end
      spread_upward
      # Una pasada extra tras el spread funde el escalon de la meseta.
      if Config::WALL_SMOOTH_VERTICAL
        smooth_rows
        smooth_columns
      end
      clear_lateral_bleed
      suppress_lift_noise
      build_wall_geom_flags
    end

    # Flags por casilla: scroll vertical llama project_tile miles de veces;
    # lateral_lift_step? hacia 4 vecinos era el pico de CPU cerca de Cliff.
    def build_wall_geom_flags
      eps = Config::LIFT_EPSILON
      n = @width * @height
      @cell_lifted = Array.new(n, false)
      @lateral_step = Array.new(n, false)
      @wall_geom = Array.new(n, false)
      @height.times do |y|
        row = y * @width
        @width.times do |x|
          i = row + x
          a = @lift[i]
          b = (y + 1 < @height) ? @lift[i + @width] : 0.0
          a = 0.0 if a < eps
          b = 0.0 if b < eps
          lifted = (a > 0.0 || b > 0.0)
          @cell_lifted[i] = lifted
          # Vecino fuera de mapa = 0 (igual que lift(-1,y)): sella bordes.
          la = (x > 0) ? @lift[i - 1] : 0.0
          lb = if x > 0
                 (y + 1 < @height) ? @lift[i - 1 + @width] : 0.0
               else
                 0.0
               end
          ra = (x + 1 < @width) ? @lift[i + 1] : 0.0
          rb = if x + 1 < @width
                 (y + 1 < @height) ? @lift[i + 1 + @width] : 0.0
               else
                 0.0
               end
          la = 0.0 if la < eps
          lb = 0.0 if lb < eps
          ra = 0.0 if ra < eps
          rb = 0.0 if rb < eps
          lateral = (la - a).abs > eps || (lb - b).abs > eps ||
                    (ra - a).abs > eps || (rb - b).abs > eps
          @lateral_step[i] = lateral
          @wall_geom[i] = lifted || lateral
        end
      end
    end

    # Lift lejos del Cliff parte la hierba: columnas con distinta altura → rajas
    # negras. Solo se conserva lift fuera de pared si hay Cliff JUSTO debajo
    # (1 fila de absorcion). Nada de meseta a 6+ filas.
    def clear_lateral_bleed
      @height.times do |y|
        row = y * @width
        @width.times do |x|
          index = row + x
          next if @wall[index]
          next if @lift[index] <= 0.0
          keep = (y + 1 < @height && @wall[index + @width])
          @lift[index] = 0.0 unless keep
        end
      end
    end

    # El suavizado + spread dejan lift minusculo a muchos tiles de distancia.
    # Eso deforma agua/suelo con redondeos de 1 px → puntos negros por todo el mapa.
    def suppress_lift_noise
      eps = Config::LIFT_EPSILON
      @lift.map! { |value| (value < eps) ? 0.0 : value }
    end

    # Hasta donde llega el tramo horizontal de pared al que pertenece cada
    # casilla. Es lo que distingue un bordillo de otro cuando estan pegados.
    def build_runs
      @run_start = Array.new(@width * @height, -1)
      @run_end   = Array.new(@width * @height, -1)
      @height.times do |y|
        x = 0
        while x < @width
          if !@wall[(y * @width) + x]
            x += 1
            next
          end
          last = x
          last += 1 while last + 1 < @width && @wall[(y * @width) + last + 1]
          (x..last).each do |i|
            @run_start[(y * @width) + i] = x
            @run_end[(y * @width) + i] = last
          end
          x = last + 1
        end
      end
    end

    # Altura de cada casilla dentro de su bordillo, contando desde abajo. Se
    # recorre de abajo arriba para que cada una solo tenga que mirar a la de
    # debajo.
    def build_stacks
      stacks = Array.new(@width * @height, 0)
      limit = Config::MAX_WALL_HEIGHT
      (@height - 1).downto(0) do |y|
        @width.times do |x|
          index = (y * @width) + x
          next if !@wall[index]
          below = index + @width
          stacks[index] = if y + 1 < @height && @wall[below] &&
                             stacks[below] < limit && same_run?(index, below)
                            stacks[below] + 1
                          else
                            1
                          end
        end
      end
      return stacks
    end

    # Misma pared si los tramos horizontales se solapan. La igualdad exacta
    # partia stacks en L / jogs de 1 tile aunque la cara fuera continua.
    def same_run?(index, below)
      a0 = @run_start[index]
      a1 = @run_end[index]
      b0 = @run_start[below]
      b1 = @run_end[below]
      return false if a0 < 0 || b0 < 0
      return a0 <= b1 && b0 <= a1
    end

    # Difumina el levantamiento a lo largo de cada fila. El centro de una pared
    # larga se queda en su valor y solo se mueven los extremos, que es donde hace
    # falta que baje poco a poco hasta el suelo de al lado.
    def smooth_rows
      @height.times do |y|
        row = y * @width
        previous = 0.0
        @width.times do |x|
          index = row + x
          current = @lift[index]
          following = (x + 1 < @width) ? @lift[index + 1] : 0.0
          @lift[index] = (previous + (current * 2.0) + following) / 4.0
          previous = current
        end
      end
    end

    # Igual que smooth_rows pero en vertical: rampa N-S hacia el Cliff continua.
    def smooth_columns
      @width.times do |x|
        previous = 0.0
        @height.times do |y|
          index = (y * @width) + x
          current = @lift[index]
          following = (y + 1 < @height) ? @lift[index + @width] : 0.0
          @lift[index] = (previous + (current * 2.0) + following) / 4.0
          previous = current
        end
      end
    end

    # Reparte el levantamiento hacia arriba, desvaneciendolo fila a fila.
    #
    # Sin esto, la casilla que hay justo encima de un bordillo tendria que
    # absorber ella sola todo el desnivel y saldria muy aplastada. Repartido, el
    # terreno sube hacia el bordillo de forma progresiva y cada fila se encoge
    # apenas un par de pixeles. Solo va hacia arriba: el suelo de debajo del
    # bordillo se queda donde esta.
    def spread_upward
      decay = Config::WALL_RISE
      return if decay <= 0.0
      (@height - 2).downto(0) do |y|
        row = y * @width
        below = row + @width
        @width.times do |x|
          value = @lift[below + x] * decay
          @lift[row + x] = value if value > @lift[row + x]
        end
      end
    end
  end

  #=============================================================================
  #
  #=============================================================================
  class << self
    def wall_field(map)
      return nil if !map || !Config::WALLS
      @wall_fields ||= {}
      field = @wall_fields[map.map_id]
      return field if field
      return @wall_fields[map.map_id] = WallField.new(map)
    end

    def clear_wall_field(map_id = nil)
      clear_lift_cache if respond_to?(:clear_lift_cache)
      return if !@wall_fields
      if map_id
        @wall_fields.delete(map_id)
      else
        @wall_fields.clear
      end
    end

    # Misma cuenta que cell_feet_dy / lift_amount_dy: amount de pies × step.
    def character_lift(character, ground)
      field = wall_field(character.map)
      return 0 if !field || field.flat
      tile_x = character.real_x.to_f / Game_Map::REAL_RES_X
      tile_y = character.real_y.to_f / Game_Map::REAL_RES_Y
      x = tile_x.floor
      y = tile_y.floor
      fy = tile_y - y
      amount = field.ground_lift(x, y, fy)
      return 0 if amount <= 0.0
      ensure_projection
      edge = ground - TilemapRenderer::DISPLAY_TILE_HEIGHT
      # ponytail: cache 1 slot — evita 2× raw_project_y si screen_y repite celda.
      fy_b = (fy * 256).to_i
      map_id = character.map.map_id
      stamp = projection_stamp
      if @char_lift_map == map_id && @char_lift_x == x && @char_lift_y == y &&
         @char_lift_fy == fy_b && @char_lift_edge == edge &&
         @char_lift_amt == amount && @char_lift_stamp == stamp
        return @char_lift_result
      end
      result = lift_amount_dy(amount, edge)
      @char_lift_map = map_id
      @char_lift_x = x
      @char_lift_y = y
      @char_lift_fy = fy_b
      @char_lift_edge = edge
      @char_lift_amt = amount
      @char_lift_stamp = stamp
      @char_lift_result = result
      return result
    end

    # Ancla de casilla (hierba, polvo, exclamacion): lift de pies × step.
    def cell_lift(map, x, y, ground)
      field = wall_field(map)
      return 0 if !field || field.flat
      amount = field.lift(x, y + 1)
      return 0 if amount <= 0.0
      ensure_projection
      edge = ground - TilemapRenderer::DISPLAY_TILE_HEIGHT
      stamp = projection_stamp
      map_id = map.map_id
      if @cell_lift_map == map_id && @cell_lift_x == x && @cell_lift_y == y &&
         @cell_lift_edge == edge && @cell_lift_amt == amount &&
         @cell_lift_stamp == stamp
        return @cell_lift_result
      end
      result = lift_amount_dy(amount, edge)
      @cell_lift_map = map_id
      @cell_lift_x = x
      @cell_lift_y = y
      @cell_lift_edge = edge
      @cell_lift_amt = amount
      @cell_lift_stamp = stamp
      @cell_lift_result = result
      return result
    end

    def clear_lift_cache
      @char_lift_stamp = nil
      @char_lift_result = nil
      @cell_lift_stamp = nil
      @cell_lift_result = nil
    end
  end
end

#===============================================================================
# Los datos del mapa cambian al cargarlo: las paredes de ese mapa dejan de valer.
#===============================================================================
class Game_Map
  alias hd25_setup setup unless method_defined?(:hd25_setup)
  def setup(map_id)
    hd25_setup(map_id)
    Visual25D.clear_wall_field(map_id)
  end
end
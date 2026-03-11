#===============================================================================
# Damage Number Indicator
# Créditos: Zik
#===============================================================================
class PokemonSystem
  attr_writer :damage_numbers

  def damage_numbers
    @damage_numbers = 1 if @damage_numbers.nil?
    return @damage_numbers
  end
end

MenuHandlers.add(:options_menu, :damage_numbers, {
  "name"        => _INTL("Indicador Daño"),
  "order"       => 90,
  "type"        => EnumOption,
  "parameters"  => [_INTL("Sí"), _INTL("No")],
  "description" => _INTL("Muestra números flotantes al recibir daño o curación en combate."),
  "get_proc"    => proc { next $PokemonSystem.damage_numbers },
  "set_proc"    => proc { |value, _scene| $PokemonSystem.damage_numbers = value }
})

module DamageNumberSettings
  ACTIVE = true
  SHOW_HEAL = true
  
  # Debug
  DEBUG_LOGS = false 

  # Visual General
  FONT_SIZE = 32
  FONT_BOLD = true
  
  #-----------------------------------------------------------------------------
  # Configuración de Colores por Categoría (R, G, B)
  #-----------------------------------------------------------------------------
  COLORS = {
    :physical => { # Daño normal
      :base   => Color.new(255, 255, 255), 
      :border => Color.new(180, 0, 0)
    },
    :critical => { # Golpe Crítico
      :base   => Color.new(255, 240, 0),
      :border => Color.new(220, 40, 0)
    },
    :heal => {     # Curación
      :base   => Color.new(80, 255, 80),
      :border => Color.new(0, 100, 0)
    },
    :poison => {   # Veneno
      :base   => Color.new(200, 100, 255),
      :border => Color.new(80, 0, 120)
    },
    :burn => {     # Quemadura
      :base   => Color.new(255, 140, 60),
      :border => Color.new(140, 40, 0)
    },
    :passive => {  # Clima, Trampas, Retroceso
      :base   => Color.new(220, 220, 220),
      :border => Color.new(60, 60, 60)
    }
  }
  
  # Animación
  DURATION = 50
  FLOAT_DIST = 60
end

#===============================================================================
# Sprite del Indicador
#===============================================================================
class DamageNumberSprite < Sprite
  def initialize(viewport, x, y, amount, category)
    super(viewport)
    @amount = amount
    @category = category
    @timer = 0
    @max_time = DamageNumberSettings::DURATION
    @initial_y = y
    @initial_x = x
    
    self.z = 99999 
    self.x = x
    self.y = y
    
    create_bitmap
    setup_initial_animation
  end

  def create_bitmap
    text = @amount.to_s
    
    # Prefijos/Sufijos según categoría
    case @category
    when :heal     then text = "+" + text
    when :critical then text = "¡" + text + "!"
    end

    # Colores de la configuración
    colors = DamageNumberSettings::COLORS[@category] || DamageNumberSettings::COLORS[:physical]
    base_color = colors[:base]
    border_color = colors[:border]

    temp = Bitmap.new(1, 1)
    pbSetSystemFont(temp)
    temp.font.size = DamageNumberSettings::FONT_SIZE
    temp.font.bold = DamageNumberSettings::FONT_BOLD
    
    # Si es crítico, hacemos la fuente un poco más grande
    if @category == :critical
      temp.font.size += 4 
    end

    rect = temp.text_size(text)
    w = rect.width + 8
    h = rect.height + 8
    temp.dispose

    # Crear bitmap final
    self.bitmap = Bitmap.new(w, h)
    pbSetSystemFont(self.bitmap)
    self.bitmap.font.size = DamageNumberSettings::FONT_SIZE
    self.bitmap.font.bold = DamageNumberSettings::FONT_BOLD
    
    if @category == :critical
      self.bitmap.font.size += 4
    end

    # Borde
    self.bitmap.font.color = border_color
    [-2, 0, 2].each do |ox|
      [-2, 0, 2].each do |oy|
        next if ox == 0 && oy == 0
        self.bitmap.draw_text(ox + 4, oy + 4, w, h, text, 1)
      end
    end

    # Texto
    self.bitmap.font.color = base_color
    self.bitmap.draw_text(4, 4, w, h, text, 1)

    self.ox = w / 2
    self.oy = h / 2
  end

  def setup_initial_animation
    case @category
    when :critical
      self.zoom_x = 2.0
      self.zoom_y = 2.0
    else
      self.zoom_x = 0.5
      self.zoom_y = 0.5
    end
  end

  def update
    return if disposed?
    super
    @timer += 1
    t = @timer.to_f / @max_time
    
    case @category
    when :critical
      # Animación de Impacto Crítico
      if @timer <= 10
        zt = @timer / 10.0
        self.zoom_x = self.zoom_y = 2.0 - (1.0 * zt) 
      end

      if @timer < 20
        shake_x = rand(-4..4)
        shake_y = rand(-4..4)
        self.x = @initial_x + shake_x
        self.y = @initial_y + shake_y
      else
        float_t = (@timer - 20).to_f / (@max_time - 20)
        offset = Math.sin(float_t * Math::PI / 2) * (DamageNumberSettings::FLOAT_DIST / 2)
        self.y = @initial_y - offset
        self.x = @initial_x
      end

    when :poison, :burn
      # Animación de Estado
      offset = Math.sin(t * Math::PI / 2) * DamageNumberSettings::FLOAT_DIST
      self.y = @initial_y - offset
      shake = Math.sin(@timer * 0.5) * 3
      self.x = @initial_x + shake
      if @timer <= 10
        zt = @timer / 10.0
        self.zoom_x = self.zoom_y = 0.5 + (0.5 * zt)
      end

    else # :physical, :heal, :passive
      offset = Math.sin(t * Math::PI / 2) * DamageNumberSettings::FLOAT_DIST
      self.y = @initial_y - offset
      if @timer <= 10
        zt = @timer / 10.0
        self.zoom_x = self.zoom_y = 0.5 + (0.5 * zt) + (0.2 * Math.sin(zt * Math::PI))
      elsif self.zoom_x > 1.0
        self.zoom_x -= 0.05
        self.zoom_y -= 0.05
      end
    end
    
    # Fade out general al final
    self.opacity = 255 * (1.0 - t) if t > 0.7
    
    dispose if @timer >= @max_time
  end
end

#===============================================================================
# Inyección en Battle::Scene
#===============================================================================
class Battle::Scene
  alias dni_initialize initialize
  def initialize
    dni_initialize
    @damage_nums = []
  end

  alias dni_pbUpdate pbUpdate
  def pbUpdate(cw = nil)
    dni_pbUpdate(cw)
    if @damage_nums
      @damage_nums.each { |s| s.update }
      @damage_nums.delete_if { |s| s.disposed? }
    end
  end

  alias dni_pbDisposeSprites pbDisposeSprites
  def pbDisposeSprites
    dni_pbDisposeSprites
    if @damage_nums
      @damage_nums.each { |s| s.dispose if !s.disposed? }
      @damage_nums.clear
    end
  end

  # ----------------------------------------------------------------------------
  # Daño Indirecto (Veneno, Quemadura, Clima, Recoil) y Curación
  # ----------------------------------------------------------------------------
  alias dni_pbHPChanged pbHPChanged
  def pbHPChanged(battler, oldHP, showAnim = false)
    if DamageNumberSettings::ACTIVE && $PokemonSystem.damage_numbers == 0 && battler
      diff = oldHP - battler.hp
      if diff != 0
        # Determinar Categoría
        category = :passive       
        if diff < 0 
          category = :heal
        else
          if battler.status == :POISON
            category = :poison
          elsif battler.status == :BURN
            category = :burn
          end
        end
        
        if category != :heal || DamageNumberSettings::SHOW_HEAL
          dni_create_sprite(battler, diff.abs, category)
        end
      end
    end
    dni_pbHPChanged(battler, oldHP, showAnim)
  end

  # ----------------------------------------------------------------------------
  # Daño Directo
  # ----------------------------------------------------------------------------
  alias dni_pbHitAndHPLossAnimation pbHitAndHPLossAnimation
  def pbHitAndHPLossAnimation(targets)
    if DamageNumberSettings::ACTIVE && $PokemonSystem.damage_numbers == 0
      targets.each do |data|
        battler = data[0]
        old_hp = data[1]
        
        if battler
          diff = old_hp - battler.hp
          if diff > 0
            amount = diff
            if battler.damageState && battler.damageState.calcDamage > amount
               amount = battler.damageState.calcDamage
            end

            # Determinar si es crítico
            category = :physical
            if battler.damageState && battler.damageState.critical
              category = :critical
            end
            
            dni_create_sprite(battler, amount, category)
          end
        end
      end
    end
    dni_pbHitAndHPLossAnimation(targets)
  end

  # ----------------------------------------------------------------------------
  # Creación del Sprite
  # ----------------------------------------------------------------------------
  def dni_create_sprite(battler, amount, category)
    return if !@sprites["pokemon_#{battler.index}"] || @sprites["pokemon_#{battler.index}"].disposed?
    pos = Battle::Scene.pbBattlerPosition(battler.index, battler.battle.pbSideSize(battler.index))
    base_x = pos[0]
    base_y = pos[1]

    if battler.index.even?
      final_y = base_y - 50
    else
      final_y = base_y - 80 
    end

    rand_x = rand(-20..20)
    final_x = base_x + rand_x

    if DamageNumberSettings::DEBUG_LOGS
      Console.echoln "[DNI] Cat: #{category} | Amt: #{amount}"
    end

    s = DamageNumberSprite.new(@viewport, final_x, final_y, amount, category)
    @damage_nums.push(s)
  end
end
#===============================================================================
# Sprite Positioner overhaul.
#===============================================================================
class SpritePositioner
  def pbOpen
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    battlebg   = "Graphics/Battlebacks/indoor1_bg"
    playerbase = "Graphics/Battlebacks/indoor1_base0"
    enemybase  = "Graphics/Battlebacks/indoor1_base1"
    @sprites["battle_bg"] = AnimatedPlane.new(@viewport)
    @sprites["battle_bg"].setBitmap(battlebg)
    @sprites["battle_bg"].z = 0
    baseX, baseY = Battle::Scene.pbBattlerPosition(0)
    @sprites["base_0"] = IconSprite.new(baseX, baseY, @viewport)
    @sprites["base_0"].setBitmap(playerbase)
    @sprites["base_0"].x -= @sprites["base_0"].bitmap.width / 2 if @sprites["base_0"].bitmap
    @sprites["base_0"].y -= @sprites["base_0"].bitmap.height if @sprites["base_0"].bitmap
    @sprites["base_0"].z = 1
    baseX, baseY = Battle::Scene.pbBattlerPosition(1)
    @sprites["base_1"] = IconSprite.new(baseX, baseY, @viewport)
    @sprites["base_1"].setBitmap(enemybase)
    @sprites["base_1"].x -= @sprites["base_1"].bitmap.width / 2 if @sprites["base_1"].bitmap
    @sprites["base_1"].y -= @sprites["base_1"].bitmap.height / 2 if @sprites["base_1"].bitmap
    @sprites["base_1"].z = 1
    @sprites["messageBox"] = IconSprite.new(0, Graphics.height - 96, @viewport)
    @sprites["messageBox"].setBitmap("Graphics/UI/Debug/battle_message")
    @sprites["messageBox"].z = 2
    @sprites["shadow_0"] = PokemonSprite.new(@viewport)
    @sprites["shadow_0"].setOffset(PictureOrigin::CENTER)
    @sprites["shadow_0"].z = 5
    @sprites["shadow_1"] = PokemonSprite.new(@viewport)
    @sprites["shadow_1"].setOffset(PictureOrigin::CENTER)
    @sprites["shadow_1"].z = 3
    @sprites["pokemon_0"] = PokemonSprite.new(@viewport)
    @sprites["pokemon_0"].setOffset(PictureOrigin::BOTTOM)
    @sprites["pokemon_0"].z = 6
    @sprites["pokemon_1"] = PokemonSprite.new(@viewport)
    @sprites["pokemon_1"].setOffset(PictureOrigin::BOTTOM)
    @sprites["pokemon_1"].z = 4
    @sprites["pokeicon"] = PokemonSpeciesIconSprite.new(nil, @viewport)
    @sprites["pokeicon"].setOffset(PictureOrigin::TOP_LEFT)
    @sprites["pokeicon"].x = 4
    @sprites["pokeicon"].y = 4
    @sprites["pokeicon"].z = 6
    @sprites["info"] = Window_UnformattedTextPokemon.new("")
    @sprites["info"].viewport = @viewport
    @sprites["info"].visible  = false
    @sprites["extra_info"] = Window_UnformattedTextPokemon.new("")
    @sprites["extra_info"].y = Graphics.height - 96
    @sprites["extra_info"].viewport = @viewport
    @sprites["extra_info"].visible  = false
    pbGetSpriteList
    @starting        = true
    @metricsChanged  = false
    @oldSpeciesIndex = 0
    @species         = nil
    @form            = 0
    @female          = false
    @shiny           = 0
    refresh
  end
  
  def pbGetSpriteList
    allspecies = []
    GameData::Species.each do |sp|
      name = (sp.form == 0) ? sp.name : _INTL("{1} (forma {2})", sp.real_name, sp.form)
      if name && !name.empty?
        allspecies.push([sp.id, sp.species, sp.form, name, false])
        next if !sp.has_gendered_sprites?
        allspecies.push([sp.id, sp.species, sp.form, name += " (F)", true])
      end
    end
    allspecies.sort! { |a, b| a[3] <=> b[3] }
    @allspecies = allspecies
    if @allspecies.empty?
      pbMessage("No se han encontrado especies.\nCerrando el editor...")
      pbClose
      return
    end
  end
  
  def pbChangeSpecies(species, form, female = false, shiny = 0)
    @species = species
    @form = form
    @female = female
    @shiny = shiny
    species_data = GameData::Species.get_species_form(@species, @form)
    return if !species_data
    @sprites["pokeicon"].pbSetParams(@species, ((@female) ? 1 : 0), @form, @shiny)
    @sprites["pokemon_0"].setSpeciesBitmap(@species, ((@female) ? 1 : 0), @form, (@shiny > 0), false, true)
    @sprites["pokemon_1"].setSpeciesBitmap(@species, ((@female) ? 1 : 0), @form, (@shiny > 0))
    @sprites["shadow_0"].setSpeciesShadowBitmap(@species, @form, @female, (@shiny > 0), false, false, true)
    @sprites["shadow_1"].setSpeciesShadowBitmap(@species, @form, @female, (@shiny > 0))
  end
  
  def pbUpdateShinyInfo
    case @shiny
    when 1
      @sprites["extra_info"].visible = true
      @sprites["extra_info"].setTextToFit("Shiny")
    when 2
      @sprites["extra_info"].visible = true
      @sprites["extra_info"].setTextToFit("Super Shiny")
    else
      @sprites["extra_info"].visible = false
      @sprites["extra_info"].setTextToFit("")
    end
  end

  def refresh
    if !@species
      @sprites["pokemon_0"].visible = false
      @sprites["pokemon_1"].visible = false
      @sprites["shadow_0"].visible = false
      @sprites["shadow_1"].visible = false
      @sprites["pokeicon"].visible  = false
      return
    end
    metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form, @female)
    case @shiny
    when 2 then hue = metrics_data.sprite_super_hue
    when 3 then hue = metrics_data.super_shiny_hue
    else        hue = 0
    end
    2.times do |i|
      scale = (i == 0) ? metrics_data.back_sprite_scale : metrics_data.front_sprite_scale
      speed = (i == 0) ? metrics_data.back_sprite_speed : metrics_data.front_sprite_speed
      @sprites["pokemon_#{i}"].iconBitmap.scale = scale
      @sprites["pokemon_#{i}"].iconBitmap.speed = speed
      @sprites["pokemon_#{i}"].iconBitmap.refresh
      @sprites["pokemon_#{i}"].iconBitmap.hue_change(hue)
      @sprites["pokemon_#{i}"].update
      pos = Battle::Scene.pbBattlerPosition(i, 1)
      @sprites["pokemon_#{i}"].setOffset(PictureOrigin::BOTTOM)
      @sprites["pokemon_#{i}"].x = pos[0]
      @sprites["pokemon_#{i}"].y = pos[1]
      metrics_data.apply_metrics_to_sprite(@sprites["pokemon_#{i}"], i)
      @sprites["pokemon_#{i}"].visible = true
      if @sprites["shadow_#{i}"].bitmap
        @sprites["shadow_#{i}"].iconBitmap.scale = scale
        @sprites["shadow_#{i}"].iconBitmap.speed = speed
        @sprites["shadow_#{i}"].iconBitmap.refresh
        @sprites["shadow_#{i}"].update
        @sprites["shadow_#{i}"].setOffset(PictureOrigin::CENTER)
        @sprites["shadow_#{i}"].x = pos[0]
        @sprites["shadow_#{i}"].y = pos[1] - (@sprites["shadow_#{i}"].height / 4).round
        metrics_data.apply_metrics_to_sprite(@sprites["shadow_#{i}"], i, true)
      end
      @sprites["shadow_#{i}"].visible = metrics_data.shows_shadow?
    end
  end
  
  def pbAutoPosition
    metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form, @female)
    old_back_y         = metrics_data.back_sprite[1]
    old_front_y        = metrics_data.front_sprite[1]
    old_front_altitude = metrics_data.front_sprite_altitude
    bitmap1 = @sprites["pokemon_0"].bitmap
    bitmap2 = @sprites["pokemon_1"].bitmap
    new_back_y  = (bitmap1.height - (findBottom(bitmap1) + 1)) / 2
    new_front_y = (bitmap2.height - (findBottom(bitmap2) + 1)) / 2
    new_front_y += 4
    if new_back_y != old_back_y || new_front_y != old_front_y || old_front_altitude != 0
      metrics_data.back_sprite[1]        = new_back_y
      metrics_data.front_sprite[1]       = new_front_y
      metrics_data.front_sprite_altitude = 0
      @metricsChanged = true
      refresh
    end
  end
  
  def pbAnimationSpeed
    if !@sprites["pokemon_0"].static? && !@sprites["pokemon_1"].static?
      pbMessage("Esta especie no está usando ningún sprite animado. No se puede cambiar la velocidad de animación.")
      return false
    end
    returnToList = false
    metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form, @female)
    oldval = metrics_data.animation_speed
    cmdvals = [0, 1, 2, 3, 4]
    commands = [
      _INTL("Quieto"),
      _INTL("Rápido"),
      _INTL("Normal"),
      _INTL("Lento"),
      _INTL("Muy lento")
    ]
    cw = Window_CommandPokemon.new(commands)
    cw.index    = (oldval.is_a?(Array)) ? oldval[0] : 0
    cw.viewport = @viewport
    ret = false
    oldindex = cw.index
    speed = cmdvals[oldindex]
    foe = commands[metrics_data.front_sprite_speed]
    ally = commands[metrics_data.back_sprite_speed]
    @sprites["extra_info"].setTextToFit("Animación Aliado = #{ally}\nAnimación Enemigo = #{foe}")
    @sprites["extra_info"].visible = true
    loop do
      Graphics.update
      Input.update
      cw.update
      self.update
      if cw.index != oldindex
        oldindex = cw.index
        speed = cmdvals[cw.index]
        metrics_data.animation_speed = [speed]
        refresh
      end
      if Input.trigger?(Input::ACTION)
        pbPlayDecisionSE
        @metricsChanged = true if metrics_data.animation_speed != oldval
        ret = true
        break
      elsif Input.trigger?(Input::BACK)
        metrics_data.animation_speed = oldval
        pbPlayCancelSE
        break
      elsif Input.trigger?(Input::USE)
        pbPlayDecisionSE
        cw.visible = false
        ch = Window_CommandPokemon.new([_INTL("Ambos"), _INTL("Aliado"), _INTL("Enemigo")])
        ch.x        = Graphics.width - ch.width
        ch.y        = Graphics.height - ch.height
        ch.viewport = @viewport
        oldsel = ch.index
        @sprites["extra_info"].setTextToFit("Animación Aliado = #{commands[cw.index]}\nAnimación Enemigo = #{commands[cw.index]}")
        loop do
          Graphics.update
          Input.update
          ch.update
          self.update
          if ch.index != oldsel
            oldsel = ch.index
            case ch.index
            when 0
              metrics_data.animation_speed = [speed]
            when 1
              metrics_data.animation_speed[0] = speed
              metrics_data.animation_speed[1] = oldval[1] || oldval[0] || 1
            when 2
              metrics_data.animation_speed[0] = oldval[0] || 1
              metrics_data.animation_speed[1] = speed
            end
            foe = commands[metrics_data.front_sprite_speed]
            ally = commands[metrics_data.back_sprite_speed]
            @sprites["extra_info"].setTextToFit("Animación Aliado = #{ally}\nAnimación Enemigo = #{foe}")
            refresh
          end
          if Input.trigger?(Input::BACK)
            pbPlayCancelSE
            metrics_data.animation_speed = oldval
            ch.dispose
            break
          elsif Input.trigger?(Input::USE)
            pbPlayDecisionSE
            @metricsChanged = true if metrics_data.animation_speed != oldval
            oldval = metrics_data.animation_speed
            ch.dispose
            returnToList = ch.index == 0
            break
          end
        end
        break if returnToList
        cw.visible = true
        foe = commands[metrics_data.front_sprite_speed]
        ally = commands[metrics_data.back_sprite_speed]
        @sprites["extra_info"].setTextToFit("Animación Aliado = #{ally}\nAnimación Enemigo = #{foe}")
        metrics_data.animation_speed = [speed]
        refresh
      end
    end
    cw.dispose
    pbUpdateShinyInfo
    return ret
  end
  
  def pbSuperShinyHue
    @shiny = 3
    pbChangeSpecies(@species, @form, @female, @shiny)
    refresh
    metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form, @female)
    hue = metrics_data.super_shiny_hue
    oldhue = hue
    @sprites["info"].visible = true
    ret = false
    loop do
      Graphics.update
      Input.update
      self.update
      @sprites["info"].setTextToFit("Matiz de Super Shiny = #{hue}")
      if (Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN))
        hue += (Input.repeat?(Input::DOWN)) ? 1 : -1
        hue = 255 if hue >= 255
        hue = -255 if hue <= - 255
        metrics_data.super_shiny_hue = hue
        refresh
      elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
        hue += (Input.repeat?(Input::RIGHT)) ? 10 : -10
        hue = 255 if hue >= 255
        hue = -255 if hue <= - 255
        metrics_data.super_shiny_hue = hue
        refresh
      end
      if Input.repeat?(Input::ACTION)
        @metricsChanged = true if hue != oldhue
        ret = true
        pbPlayDecisionSE
        break
      elsif Input.repeat?(Input::BACK)
        pbPlayCancelSE
        metrics_data.super_shiny_hue = oldhue
        refresh
        break
      elsif Input.repeat?(Input::USE)
        @metricsChanged = true if hue != oldhue
        pbPlayDecisionSE
        break
      end
    end
    @shiny = (ret) ? 0 : 2
    pbChangeSpecies(@species, @form, @female, @shiny)
    @sprites["info"].visible = false
    @sprites["pokeicon"].refresh
    pbUpdateShinyInfo
    refresh
    return ret
  end
  
  def pbShadowSize
    sprite = @sprites["shadow_1"]
    metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form, @female)
    size = metrics_data.shadow_size
    oldsize = size
    showSprite = size != 0
    @sprites["info"].visible = true
    ret = false
    loop do
      sprite.visible = ((System.uptime * 8).to_i % 4) < 3 if showSprite
      Graphics.update
      Input.update
      self.update
      @sprites["info"].setTextToFit("Tamaño Sombra = #{size}")
      if (Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN))
        size += (Input.repeat?(Input::DOWN)) ? -1 : 1
        size = -9 if size < -9
        size = 9 if size > 9
        metrics_data.shadow_size = size
        showSprite = size != 0
        pbChangeSpecies(@species, @form, @female, @shiny)
        refresh
      end
      if Input.repeat?(Input::ACTION)
        @metricsChanged = true if size != oldsize
        ret = true
        pbPlayDecisionSE
        break
      elsif Input.repeat?(Input::BACK)
        metrics_data.shadow_size = oldsize
        pbPlayCancelSE
        refresh
        break
      elsif Input.repeat?(Input::USE)
        @metricsChanged = true if size != oldsize
        pbPlayDecisionSE
        break
      end
    end
    @sprites["info"].visible = false
    pbUpdateShinyInfo
    return ret
  end
  
  def pbSetParameter(param)
    return if !@species
    @sprites["extra_info"].visible = false
    case param
    when 3 then return pbAnimationSpeed
    when 4 then return pbSuperShinyHue
    when 6 then return pbShadowSize
    when 5
      pbAutoPosition
      return false
    end
    metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form, @female)
    2.times do |i|
      @sprites["pokemon_#{i}"].iconBitmap.deanimate
      @sprites["shadow_#{i}"].iconBitmap.deanimate
    end
    case param
    when 0
      sprite = @sprites["pokemon_0"]
      xpos = metrics_data.back_sprite[0]
      ypos = metrics_data.back_sprite[1]
      scale = metrics_data.back_sprite_scale
    when 1
      sprite = @sprites["pokemon_1"]
      xpos = metrics_data.front_sprite[0]
      ypos = metrics_data.front_sprite[1]
      scale = metrics_data.front_sprite_scale
    when 2
      sprite = @sprites["shadow_1"]
      xpos = metrics_data.shadow_sprite[0]   # Shadow X (both)
      scale = metrics_data.shadow_sprite[1]  # Ally's shadow Y
      ypos = metrics_data.shadow_sprite[2]   # Enemy's shadow Y
    end
    oldxpos = xpos
    oldypos = ypos
    oldscale = scale
    @sprites["info"].visible = true
    ret = false

    # --- Setup de cajas delimitadoras y ratón ---
    box_sprites = [Sprite.new(@viewport), Sprite.new(@viewport)]
    box_sprites.each { |b| b.z = 99999; b.visible = false }
    dragging = false
    drag_target = -1
    mouse_start_x = 0
    mouse_start_y = 0
    metric_start_x = 0
    metric_start_y = 0
    drag_mult_x = 1
    drag_mult_y = 1
    # --------------------------------------------------

    loop do
      # Definir qué sprites están activos según el parámetro
      active_sprites = []
      case param
      when 0 then active_sprites = [@sprites["pokemon_0"]]
      when 1 then active_sprites = [@sprites["pokemon_1"]]
      when 2 then active_sprites = [@sprites["shadow_0"], @sprites["shadow_1"]]
      end

      active_sprites.each do |spr|
        spr.visible = ((System.uptime * 8).to_i % 4) < 3 if spr
      end

      Graphics.update
      Input.update
      self.update
      
      case param
      when 0 then @sprites["info"].setTextToFit("Posición Aliado = #{xpos},#{ypos},#{scale}")
      when 1 then @sprites["info"].setTextToFit("Posición Enemigo = #{xpos},#{ypos},#{scale}")
      when 2 then @sprites["info"].setTextToFit("Posición Sombra = #{xpos},#{scale},#{ypos}")
      end

      # --- Lógica de arrastre múltiple con ratón ---
      active_sprites.each_with_index do |spr, i|
        if spr && spr.bitmap && spr.visible
          zx = spr.zoom_x.abs
          zy = spr.zoom_y.abs
          bw = (spr.bitmap.width * zx).to_i
          bh = (spr.bitmap.height * zy).to_i
          left = spr.x - (spr.ox * zx)
          top = spr.y - (spr.oy * zy)

          if !box_sprites[i].bitmap || box_sprites[i].bitmap.width != bw || box_sprites[i].bitmap.height != bh
            box_sprites[i].bitmap&.dispose
            box_sprites[i].bitmap = Bitmap.new(bw, bh)
            rojo = Color.new(255, 0, 0)
            box_sprites[i].bitmap.fill_rect(0, 0, bw, 2, rojo)
            box_sprites[i].bitmap.fill_rect(0, bh - 2, bw, 2, rojo)
            box_sprites[i].bitmap.fill_rect(0, 0, 2, bh, rojo)
            box_sprites[i].bitmap.fill_rect(bw - 2, 0, 2, bh, rojo)
          end
          box_sprites[i].x = left
          box_sprites[i].y = top
          box_sprites[i].visible = true
        else
          box_sprites[i].visible = false
        end
      end

      mx = Input.mouse_x
      my = Input.mouse_y

      if mx && my
        if Input.trigger?(Input::MOUSELEFT)
          active_sprites.each_with_index do |spr, i|
            next if !spr || !spr.bitmap || !box_sprites[i].visible
            left = box_sprites[i].x
            right = left + box_sprites[i].bitmap.width
            top = box_sprites[i].y
            bottom = top + box_sprites[i].bitmap.height
            
            if mx >= left && mx <= right && my >= top && my <= bottom
              dragging = true
              drag_target = i
              mouse_start_x = mx
              mouse_start_y = my
              metric_start_x = xpos
              # Si es la sombra aliada (i==0 en param 2), su Y es la variable 'scale'
              metric_start_y = (param == 2 && i == 0) ? scale : ypos
              
              old_sx = spr.x
              old_sy = spr.y
              
              case param
              when 0
                metrics_data.back_sprite[0] = xpos + 1
                metrics_data.back_sprite[1] = ypos + 1
              when 1
                metrics_data.front_sprite[0] = xpos + 1
                metrics_data.front_sprite[1] = ypos + 1
              when 2
                metrics_data.shadow_sprite[0] = xpos + 1
                if i == 0
                  metrics_data.shadow_sprite[1] = scale + 1
                else
                  metrics_data.shadow_sprite[2] = ypos + 1
                end
              end
              refresh
              2.times { |j| @sprites["pokemon_#{j}"].iconBitmap.deanimate; @sprites["shadow_#{j}"].iconBitmap.deanimate }
              
              diff_x = spr.x - old_sx
              diff_y = spr.y - old_sy
              drag_mult_x = diff_x != 0 ? diff_x : 1
              drag_mult_y = diff_y != 0 ? diff_y : 1
              
              case param
              when 0
                metrics_data.back_sprite[0] = xpos
                metrics_data.back_sprite[1] = ypos
              when 1
                metrics_data.front_sprite[0] = xpos
                metrics_data.front_sprite[1] = ypos
              when 2
                metrics_data.shadow_sprite[0] = xpos
                metrics_data.shadow_sprite[1] = scale
                metrics_data.shadow_sprite[2] = ypos
              end
              refresh
              2.times { |j| @sprites["pokemon_#{j}"].iconBitmap.deanimate; @sprites["shadow_#{j}"].iconBitmap.deanimate }
              break # Solo agarrar un sprite a la vez
            end
          end
        elsif Input.press?(Input::MOUSELEFT)
          if dragging
            dx = mx - mouse_start_x
            dy = my - mouse_start_y
            
            new_xpos = metric_start_x + (dx.to_f / drag_mult_x).round
            new_ypos = metric_start_y + (dy.to_f / drag_mult_y).round

            changed = false
            if xpos != new_xpos
              xpos = new_xpos
              changed = true
            end
            
            if param == 2 && drag_target == 0
              if scale != new_ypos
                scale = new_ypos
                changed = true
              end
            else
              if ypos != new_ypos
                ypos = new_ypos
                changed = true
              end
            end

            if changed
              case param
              when 0
                metrics_data.back_sprite[0] = xpos
                metrics_data.back_sprite[1] = ypos
              when 1
                metrics_data.front_sprite[0] = xpos
                metrics_data.front_sprite[1] = ypos
              when 2
                metrics_data.shadow_sprite[0] = xpos
                metrics_data.shadow_sprite[1] = scale
                metrics_data.shadow_sprite[2] = ypos
              end
              refresh
              2.times { |j| @sprites["pokemon_#{j}"].iconBitmap.deanimate; @sprites["shadow_#{j}"].iconBitmap.deanimate }
            end
          end
        else
          dragging = false
          drag_target = -1
        end
      end
      # ------------------------------------------

      if (Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN))
        ypos += (Input.repeat?(Input::DOWN)) ? 1 : -1
        case param
        when 0 then metrics_data.back_sprite[1]   = ypos
        when 1 then metrics_data.front_sprite[1]  = ypos
        when 2 then metrics_data.shadow_sprite[2] = ypos
        end
        refresh
        2.times do |i|
          @sprites["pokemon_#{i}"].iconBitmap.deanimate
          @sprites["shadow_#{i}"].iconBitmap.deanimate
        end
      end
      if Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
        xpos += (Input.repeat?(Input::RIGHT)) ? 1 : -1
        case param
        when 0 then metrics_data.back_sprite[0]   = xpos
        when 1 then metrics_data.front_sprite[0]  = xpos
        when 2 then metrics_data.shadow_sprite[0] = xpos
        end
        refresh
        2.times do |i|
          @sprites["pokemon_#{i}"].iconBitmap.deanimate
          @sprites["shadow_#{i}"].iconBitmap.deanimate
        end
      end
      if (Input.repeat?(Input::JUMPUP) || Input.repeat?(Input::JUMPDOWN))
        scale += (Input.repeat?(Input::JUMPDOWN)) ? 1 : -1
        scale = 1 if param < 2 && scale < 1
        scale = 10 if param < 2 && scale > 10
        case param
        when 0 then metrics_data.back_sprite[2]   = scale
        when 1 then metrics_data.front_sprite[2]  = scale
        when 2 then metrics_data.shadow_sprite[1] = scale
        end
        pbChangeSpecies(@species, @form, @female, @shiny) if param < 2
        refresh
        2.times do |i|
          @sprites["pokemon_#{i}"].iconBitmap.deanimate
          @sprites["shadow_#{i}"].iconBitmap.deanimate
        end
      end
      if Input.repeat?(Input::ACTION)
        @metricsChanged = true if xpos != oldxpos || ypos != oldypos || scale != oldscale
        ret = true
        pbPlayDecisionSE
        break
      elsif Input.repeat?(Input::BACK)
        case param
        when 0
          metrics_data.back_sprite = [oldxpos, oldypos]
          if oldscale != Settings::BACK_BATTLER_SPRITE_SCALE
            metrics_data.back_sprite.push(oldscale)
          end
        when 1
          metrics_data.front_sprite = [oldxpos, oldypos]
          if oldscale != Settings::FRONT_BATTLER_SPRITE_SCALE
            metrics_data.front_sprite.push(oldscale)
          end
        when 2
          metrics_data.shadow_sprite = [oldxpos, oldscale, oldypos]
        end
        pbPlayCancelSE
        refresh
        break
      elsif Input.repeat?(Input::USE)
        @metricsChanged = true if xpos != oldxpos || ypos != oldypos || scale != oldscale
        pbPlayDecisionSE
        break
      end
    end

    box_sprites.each do |b|
      b.bitmap&.dispose
      b.dispose
    end

    @sprites["info"].visible = false
    sprite.visible = true
    2.times do |i|
      @sprites["pokemon_#{i}"].iconBitmap.reanimate
      @sprites["shadow_#{i}"].iconBitmap.reanimate
    end
    pbUpdateShinyInfo
    return ret
  end
  
  def pbMenu
    refresh
    cw = Window_CommandPokemon.new(
      [_INTL("Definir Posición Aliado"),
       _INTL("Definir Posición Enemigo"),
       _INTL("Definir Posición Sombra"),
       _INTL("Definir Velocidad de Anim."),
       _INTL("Definir Matiz Super Shiny"),
       _INTL("Auto-Posicionar Sprites")]
    )
    cw.x        = Graphics.width - cw.width
    cw.y        = Graphics.height - cw.height
    cw.viewport = @viewport
    ret = -1
    loop do
      Graphics.update
      Input.update
      cw.update
      self.update
      if Input.trigger?(Input::USE)
        pbPlayDecisionSE
        ret = cw.index
        break
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        break
      elsif Input.trigger?(Input::SPECIAL)
        pbPlayDecisionSE
        @shiny += 1
        @shiny = 0 if @shiny > 2
        pbUpdateShinyInfo
        pbChangeSpecies(@species, @form, @female, @shiny)
        refresh
      end
    end
    cw.dispose
    return ret
  end

  def pbSearchSpeciesInCommandList(cw, commands, prompt = nil)
    prompt ||= _INTL("Busca una especie en específico.")
    find_species = pbMessageFreeText("\\ts[]" + prompt, "", false, 100, Graphics.width)
    return if nil_or_empty?(find_species)
    return if find_species.downcase == commands[cw.index].downcase
    found_index = pbFindListIndexBySearch(commands, find_species, cw.index)
    if found_index.nil?
      pbMessage(_INTL("No se han encontrado especies."))
      return
    end
    pbPlayDecisionSE
    cw.index = found_index
    pbChangeSpecies(@allspecies[found_index][1], @allspecies[found_index][2], @allspecies[found_index][4], @shiny)
    refresh
  end

  def pbChooseSpecies
    if @starting
      pbFadeInAndShow(@sprites) { update }
      @starting = false
    end
    cw = Window_CommandPokemonEx.newEmpty(0, 0, 260, 176, @viewport)
    cw.rowHeight = 24
    pbSetSmallFont(cw.contents)
    cw.x = Graphics.width - cw.width
    cw.y = Graphics.height - cw.height
    commands = []
    @allspecies.each { |sp| commands.push(sp[3]) }
    cw.commands = commands
    cw.index    = @oldSpeciesIndex
    ret = false
    oldindex = -1
    @sprites["pokeicon"].visible = true
    loop do
      Graphics.update
      Input.update
      cw.update
      if cw.index != oldindex
        oldindex = cw.index
        pbChangeSpecies(@allspecies[cw.index][1], @allspecies[cw.index][2], @allspecies[cw.index][4], @shiny)
        refresh
      end
      self.update
      if Input.trigger?(Input::BACK)
        @sprites["pokeicon"].visible = false
        @sprites["extra_info"].visible = false
        pbChangeSpecies(nil, nil)
        refresh
        break
      elsif Input.trigger?(Input::USE)
        @sprites["pokeicon"].visible = false
        pbChangeSpecies(@allspecies[cw.index][1], @allspecies[cw.index][2], @allspecies[cw.index][4], @shiny)
        ret = true
        break
      elsif Input.trigger?(Input::SPECIAL)
        pbPlayDecisionSE
        @shiny += 1
        @shiny = 0 if @shiny > 2
        pbUpdateShinyInfo
        pbChangeSpecies(@allspecies[cw.index][1], @allspecies[cw.index][2], @allspecies[cw.index][4], @shiny)
        refresh
      elsif Input.trigger?(Input::ACTION)
        pbSearchSpeciesInCommandList(cw, commands)
      end
    end
    @oldSpeciesIndex = cw.index
    cw.dispose
    return ret
  end
end

class SpritePositionerScreen
  def pbStart
    @scene.pbOpen
    loop do
      species = @scene.pbChooseSpecies
      break if !species
      loop do
        command = @scene.pbMenu
        break if command < 0
        loop do
          par = @scene.pbSetParameter(command)
          break if !par
          case command            # Action Command Cycle
          when 0 then command = 1 # Ally Position   => Enemy Position
          when 1 then command = 2 # Enemy Position  => Shadow Position
          when 2 then command = 6 # Shadow Position => Shadow Size
          when 6 then command = 4 # Shadow Size     => Super Shiny Hue
          when 4 then command = 3 # Super Shiny Hue => Animation Speed
          when 3 then command = 0 # Animation Speed => Ally Position
          end
        end
      end
    end
    @scene.pbClose
  end
end

#===============================================================================
# Dynamax Sprite Positioner overhaul.
#===============================================================================
class DynamaxSpritePositioner < SpritePositioner
  def pbGetSpriteList
    allspecies = []
    GameData::Species.each do |sp|
	  next if !sp.dynamax_able?
	  next if @filter < 0 && !sp.gmax_move
      next if @filter > 0 && sp.generation != @filter
      name = (sp.form == 0) ? sp.name : _INTL("{1} (forma {2})", sp.real_name, sp.form)
      if name && !name.empty?
        allspecies.push([sp.id, sp.species, sp.form, name, false])
        next if !sp.has_gendered_sprites?
        allspecies.push([sp.id, sp.species, sp.form, name += " (F)", true])
      end
    end
    allspecies.sort! { |a, b| a[3] <=> b[3] }
    @allspecies = allspecies
    if @allspecies.empty?
      pbMessage("No se han encontrado especies.\nCerrando el editor...")
      pbClose
      return
    end
  end
  
  def pbChangeSpecies(species, form, female = false, shiny = 0)
    @species = species
    @form = form
    @female = female
    @shiny = shiny
    species_data = GameData::Species.get_species_form(@species, @form)
    return if !species_data
    @sprites["pokeicon"].pbSetParams(@species, (@female) ? 1 : 0, @form, @shiny)
    @sprites["pokemon_0"].clear_dynamax_pattern
    @sprites["pokemon_0"].setSpeciesBitmap(@species, (@female) ? 1 : 0, @form, (@shiny > 0), false, true)
    @sprites["pokemon_0"].set_dynamax_pattern(species_data.id, true)
    @sprites["pokemon_1"].clear_dynamax_pattern
    @sprites["pokemon_1"].setSpeciesBitmap(@species, (@female) ? 1 : 0, @form, (@shiny > 0))
    @sprites["pokemon_1"].set_dynamax_pattern(species_data.id, true)
    @sprites["shadow_0"].setSpeciesShadowBitmap(@species, @form, @female, (@shiny > 0), false, true, true)
    @sprites["shadow_1"].setSpeciesShadowBitmap(@species, @form, @female, (@shiny > 0), false, true)
  end
    
  def refresh
    if !@species
      @sprites["pokemon_0"].visible = false
      @sprites["pokemon_1"].visible = false
      @sprites["shadow_0"].visible = false
      @sprites["shadow_1"].visible = false
      @sprites["pokeicon"].visible  = false
      @sprites["pokemon_0"].clear_dynamax_pattern
      @sprites["pokemon_1"].clear_dynamax_pattern
      return
    end
    metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form, @female)
    case @shiny
    when 2 then hue = metrics_data.sprite_super_hue
    when 3 then hue = metrics_data.super_shiny_hue
    else        hue = 0
    end
    2.times do |i|
      scale = (i == 0) ? metrics_data.back_sprite_scale : metrics_data.front_sprite_scale
      speed = (i == 0) ? metrics_data.back_sprite_speed : metrics_data.front_sprite_speed
      @sprites["pokemon_#{i}"].iconBitmap.scale = scale
      @sprites["pokemon_#{i}"].iconBitmap.speed = speed
      @sprites["pokemon_#{i}"].iconBitmap.refresh
      @sprites["pokemon_#{i}"].iconBitmap.hue_change(hue)
      @sprites["pokemon_#{i}"].update
      pos = Battle::Scene.pbBattlerPosition(i, 1)
      @sprites["pokemon_#{i}"].setOffset(PictureOrigin::BOTTOM)
      @sprites["pokemon_#{i}"].x = pos[0]
      @sprites["pokemon_#{i}"].y = pos[1]
      metrics_data.apply_dynamax_metrics_to_sprite(@sprites["pokemon_#{i}"], i)
      @sprites["pokemon_#{i}"].set_dynamax_pattern(metrics_data.real_id, true)
      @sprites["pokemon_#{i}"].visible = true
      if @sprites["shadow_#{i}"].bitmap
        @sprites["shadow_#{i}"].iconBitmap.scale = scale
        @sprites["shadow_#{i}"].iconBitmap.speed = speed
        @sprites["shadow_#{i}"].iconBitmap.refresh
        @sprites["shadow_#{i}"].update
        @sprites["shadow_#{i}"].setOffset(PictureOrigin::CENTER)
        @sprites["shadow_#{i}"].x = pos[0]
        @sprites["shadow_#{i}"].y = pos[1] - ((@sprites["shadow_#{i}"].height * 1.5) / 4).round
        metrics_data.apply_dynamax_metrics_to_sprite(@sprites["shadow_#{i}"], i, true)
      end
      @sprites["shadow_#{i}"].visible = metrics_data.shows_shadow?
    end
  end

  def pbAutoPosition
    metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form, @female)
    old_back_y         = metrics_data.dmax_back_sprite[1]
    old_front_y        = metrics_data.dmax_front_sprite[1]
    bitmap1 = @sprites["pokemon_0"].bitmap
    bitmap2 = @sprites["pokemon_1"].bitmap
    new_back_y = (bitmap1.height - (findBottom(bitmap1) + 1)) / 2
    new_back_y += 54 if @spriteStyle == 1
    new_front_y = (bitmap2.height - (findBottom(bitmap2) + 1)) / 2
    new_front_y += (new_front_y * 1.5) - new_front_y
    new_front_y += 6
    if new_back_y != old_back_y || new_front_y != old_front_y
      metrics_data.dmax_back_sprite[1]  = new_back_y
      metrics_data.dmax_front_sprite[1] = new_front_y
      @metricsChanged = true
      refresh
    end
  end
  
  def pbSetParameter(param)
    return if !@species
    @sprites["extra_info"].visible = false
    if param == 2
      pbAutoPosition
      return false
    end
    metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form, @female)
    2.times do |i|
      @sprites["pokemon_#{i}"].iconBitmap.deanimate
      @sprites["shadow_#{i}"].iconBitmap.deanimate
    end
    case param
    when 0
      sprite = @sprites["pokemon_0"]
      xpos = metrics_data.dmax_back_sprite[0]
      ypos = metrics_data.dmax_back_sprite[1]
    when 1
      sprite = @sprites["pokemon_1"]
      xpos = metrics_data.dmax_front_sprite[0]
      ypos = metrics_data.dmax_front_sprite[1]
    end
    oldxpos = xpos
    oldypos = ypos
    @sprites["info"].visible = true
    ret = false

    # --- Setup de caja delimitadora y ratón ---
    box_sprite = Sprite.new(@viewport)
    box_sprite.z = 99999
    box_sprite.visible = false
    dragging = false
    mouse_start_x = 0
    mouse_start_y = 0
    metric_start_x = 0
    metric_start_y = 0
    drag_mult_x = 1
    drag_mult_y = 1
    # ------------------------------------------------

    loop do
      sprite.visible = ((System.uptime * 8).to_i % 4) < 3
      Graphics.update
      Input.update
      self.update
      case param
      when 0 then @sprites["info"].setTextToFit("Posición Aliado = #{xpos},#{ypos}")
      when 1 then @sprites["info"].setTextToFit("Posición Enemigo = #{xpos},#{ypos}")
      end

      # --- Lógica de arrastre con ratón ---
      if sprite.bitmap
        zx = sprite.zoom_x.abs
        zy = sprite.zoom_y.abs
        bw = (sprite.bitmap.width * zx).to_i
        bh = (sprite.bitmap.height * zy).to_i
        left = sprite.x - (sprite.ox * zx)
        right = left + bw
        top = sprite.y - (sprite.oy * zy)
        bottom = top + bh

        if !box_sprite.bitmap || box_sprite.bitmap.width != bw || box_sprite.bitmap.height != bh
          box_sprite.bitmap&.dispose
          box_sprite.bitmap = Bitmap.new(bw, bh)
          rojo = Color.new(255, 0, 0)
          box_sprite.bitmap.fill_rect(0, 0, bw, 2, rojo)
          box_sprite.bitmap.fill_rect(0, bh - 2, bw, 2, rojo)
          box_sprite.bitmap.fill_rect(0, 0, 2, bh, rojo)
          box_sprite.bitmap.fill_rect(bw - 2, 0, 2, bh, rojo)
        end
        box_sprite.x = left
        box_sprite.y = top
        box_sprite.visible = true

        mx = Input.mouse_x
        my = Input.mouse_y

        if mx && my
          if Input.trigger?(Input::MOUSELEFT)
            if mx >= left && mx <= right && my >= top && my <= bottom
              dragging = true
              mouse_start_x = mx
              mouse_start_y = my
              metric_start_x = xpos
              metric_start_y = ypos
              
              old_sx = sprite.x
              old_sy = sprite.y
              
              case param
              when 0
                metrics_data.dmax_back_sprite[0] = xpos + 1
                metrics_data.dmax_back_sprite[1] = ypos + 1
              when 1
                metrics_data.dmax_front_sprite[0] = xpos + 1
                metrics_data.dmax_front_sprite[1] = ypos + 1
              end
              refresh
              2.times do |i|
                @sprites["pokemon_#{i}"].iconBitmap.deanimate
                @sprites["shadow_#{i}"].iconBitmap.deanimate
              end
              
              diff_x = sprite.x - old_sx
              diff_y = sprite.y - old_sy
              drag_mult_x = diff_x != 0 ? diff_x : 1
              drag_mult_y = diff_y != 0 ? diff_y : 1
              
              case param
              when 0
                metrics_data.dmax_back_sprite[0] = xpos
                metrics_data.dmax_back_sprite[1] = ypos
              when 1
                metrics_data.dmax_front_sprite[0] = xpos
                metrics_data.dmax_front_sprite[1] = ypos
              end
              refresh
              2.times do |i|
                @sprites["pokemon_#{i}"].iconBitmap.deanimate
                @sprites["shadow_#{i}"].iconBitmap.deanimate
              end
            end
          elsif Input.press?(Input::MOUSELEFT)
            if dragging
              dx = mx - mouse_start_x
              dy = my - mouse_start_y
              
              new_xpos = metric_start_x + (dx.to_f / drag_mult_x).round
              new_ypos = metric_start_y + (dy.to_f / drag_mult_y).round

              if xpos != new_xpos || ypos != new_ypos
                xpos = new_xpos
                ypos = new_ypos
                case param
                when 0
                  metrics_data.dmax_back_sprite[0] = xpos
                  metrics_data.dmax_back_sprite[1] = ypos
                when 1
                  metrics_data.dmax_front_sprite[0] = xpos
                  metrics_data.dmax_front_sprite[1] = ypos
                end
                refresh
                2.times do |i|
                  @sprites["pokemon_#{i}"].iconBitmap.deanimate
                  @sprites["shadow_#{i}"].iconBitmap.deanimate
                end
              end
            end
          else
            dragging = false
          end
        end
      else
        box_sprite.visible = false
      end
      # ------------------------------------------

      if (Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN))
        ypos += (Input.repeat?(Input::DOWN)) ? 1 : -1
        case param
        when 0 then metrics_data.dmax_back_sprite[1]  = ypos
        when 1 then metrics_data.dmax_front_sprite[1] = ypos
        end
        refresh
        2.times do |i|
          @sprites["pokemon_#{i}"].iconBitmap.deanimate
          @sprites["shadow_#{i}"].iconBitmap.deanimate
        end
      end
      if Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
        xpos += (Input.repeat?(Input::RIGHT)) ? 1 : -1
        case param
        when 0 then metrics_data.dmax_back_sprite[0]  = xpos
        when 1 then metrics_data.dmax_front_sprite[0] = xpos
        end
        refresh
        2.times do |i|
          @sprites["pokemon_#{i}"].iconBitmap.deanimate
          @sprites["shadow_#{i}"].iconBitmap.deanimate
        end
      end
      if Input.repeat?(Input::ACTION)
        @metricsChanged = true if xpos != oldxpos || ypos != oldypos
        ret = true
        pbPlayDecisionSE
        break
      elsif Input.repeat?(Input::BACK)
        case param
        when 0
          metrics_data.dmax_back_sprite[0] = oldxpos
          metrics_data.dmax_back_sprite[1] = oldypos
        when 1
          metrics_data.dmax_front_sprite[0] = oldxpos
          metrics_data.dmax_front_sprite[1] = oldypos
        end
        pbPlayCancelSE
        refresh
        break
      elsif Input.repeat?(Input::USE)
        @metricsChanged = true if xpos != oldxpos || ypos != oldypos
        pbPlayDecisionSE
        break
      end
    end

    box_sprite.bitmap&.dispose
    box_sprite.dispose

    @sprites["info"].visible = false
    sprite.visible = true
    2.times do |i|
      @sprites["pokemon_#{i}"].iconBitmap.reanimate
      @sprites["shadow_#{i}"].iconBitmap.deanimate
    end
    pbUpdateShinyInfo
    return ret
  end
  
  def pbMenu
    refresh
    cw = Window_CommandPokemon.new(
      [_INTL("Definir Posición Aliado"),
       _INTL("Definir Posición Enemigo"),
       _INTL("Auto-Posicionar Sprites")]
    )
    cw.x        = Graphics.width - cw.width
    cw.y        = Graphics.height - cw.height
    cw.viewport = @viewport
    ret = -1
    loop do
      Graphics.update
      Input.update
      cw.update
      self.update
      if Input.trigger?(Input::USE)
        pbPlayDecisionSE
        ret = cw.index
        break
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        break
      elsif Input.trigger?(Input::SPECIAL)
        pbPlayDecisionSE
        @shiny += 1
        @shiny = 0 if @shiny > 2
        pbUpdateShinyInfo
        pbChangeSpecies(@species, @form, @female, @shiny)
        refresh
      end
    end
    cw.dispose
    return ret
  end
  
  def pbChooseSpecies
    if @starting
      pbFadeInAndShow(@sprites) { update }
      @starting = false
    end
    cw = Window_CommandPokemonEx.newEmpty(0, 0, 260, 176, @viewport)
    cw.rowHeight = 24
    pbSetSmallFont(cw.contents)
    cw.x = Graphics.width - cw.width
    cw.y = Graphics.height - cw.height
    commands = []
    @allspecies.each { |sp| commands.push(sp[3]) }
    cw.commands = commands
    cw.index    = @oldSpeciesIndex
    ret = false
    oldindex = -1
    @sprites["pokeicon"].visible = true
    loop do
      Graphics.update
      Input.update
      cw.update
      if cw.index != oldindex
        oldindex = cw.index
        pbChangeSpecies(@allspecies[cw.index][1], @allspecies[cw.index][2], @allspecies[cw.index][4], @shiny)
        refresh
      end
      self.update
      if Input.trigger?(Input::BACK)
        @sprites["pokeicon"].visible = false
        @sprites["extra_info"].visible = false
        pbChangeSpecies(nil, nil)
        refresh
        break
      elsif Input.trigger?(Input::USE)
        @sprites["pokeicon"].visible = false
        pbChangeSpecies(@allspecies[cw.index][1], @allspecies[cw.index][2], @allspecies[cw.index][4], @shiny)
        ret = true
        break
      elsif Input.trigger?(Input::SPECIAL)
        pbPlayDecisionSE
        @shiny += 1
        @shiny = 0 if @shiny > 2
        pbUpdateShinyInfo
        pbChangeSpecies(@allspecies[cw.index][1], @allspecies[cw.index][2], @allspecies[cw.index][4], @shiny)
        refresh
      elsif Input.trigger?(Input::ACTION) || Input.triggerex?(:F)
        pbSearchSpeciesInCommandList(cw, commands, _INTL("Buscar una especie en específico."))
      end
    end
    @oldSpeciesIndex = cw.index
    cw.dispose
    return ret
  end
end

class DynamaxSpritePositionerScreen < SpritePositionerScreen
  def pbStart
    @scene.pbOpen
    loop do
      species = @scene.pbChooseSpecies
      break if !species
      loop do
        command = @scene.pbMenu
        break if command < 0
        loop do
          par = @scene.pbSetParameter(command)
          break if !par
          case command
          when 0 then command = 1
          when 1 then command = 0
          end
        end
      end
    end
    @scene.pbClose
  end
end
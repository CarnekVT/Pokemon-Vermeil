#===============================================================================
#
#===============================================================================
class SpritePositioner
  def refresh
    if !@species
      @sprites["pokemon_0"].visible = false
      @sprites["pokemon_1"].visible = false
      @sprites["shadow_1"].visible = false
      return
    end
    metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form)
    2.times do |i|
      @sprites["pokemon_#{i}"].setOffset(PictureOrigin::BOTTOM)
      pos = Battle::Scene.pbBattlerPosition(i, 1)
      @sprites["pokemon_#{i}"].x = pos[0]
      @sprites["pokemon_#{i}"].y = pos[1]
      metrics_data.apply_metrics_to_sprite(@sprites["pokemon_#{i}"], i)
      @sprites["pokemon_#{i}"].visible = true
      next if i != 1
      @sprites["shadow_1"].x = pos[0]
      @sprites["shadow_1"].y = pos[1]
      if @sprites["shadow_1"].bitmap
        @sprites["shadow_1"].x -= @sprites["shadow_1"].bitmap.width / 2
        @sprites["shadow_1"].y -= @sprites["shadow_1"].bitmap.height / 2
      end
      metrics_data.apply_metrics_to_sprite(@sprites["shadow_1"], i, true)
      @sprites["shadow_1"].visible = true
    end
  end

  def pbSetParameter(param)
    return if !@species
    return pbShadowSize if param == 3
    if param == 5
      pbAutoPosition
      return false
    end
    metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form)
    case param
    when 0
      sprite = @sprites["pokemon_0"]
      xpos = metrics_data.back_sprite[0]
      ypos = metrics_data.back_sprite[1]
    when 1
      sprite = @sprites["pokemon_1"]
      xpos = metrics_data.front_sprite[0]
      ypos = metrics_data.front_sprite[1]
    when 2
      sprite = @sprites["pokemon_1"]
      ypos = metrics_data.front_sprite_altitude
    when 4
      sprite = @sprites["shadow_1"]
      xpos = metrics_data.shadow_x
      ypos = 0
    end
    oldxpos = xpos
    oldypos = ypos
    @sprites["info"].visible = true
    ret = false
    loop do
      sprite.visible = ((System.uptime * 8).to_i % 4) < 3   # Flash the selected sprite
      Graphics.update
      Input.update
      self.update
      case param
      when 0 then @sprites["info"].setTextToFit("Ally Position = #{xpos},#{ypos}")
      when 1 then @sprites["info"].setTextToFit("Enemy Position = #{xpos},#{ypos}")
      when 2 then @sprites["info"].setTextToFit("Enemy Altitude = #{ypos}")
      when 4 then @sprites["info"].setTextToFit("Shadow Position = #{xpos}")
      end
      if (Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)) && param != 4
        if param == 2
          ypos += (Input.repeat?(Input::DOWN)) ? -1 : 1
        else
          ypos += (Input.repeat?(Input::DOWN)) ? 1 : -1
        end
        case param
        when 0 then metrics_data.back_sprite[1]        = ypos
        when 1 then metrics_data.front_sprite[1]       = ypos
        when 2 then metrics_data.front_sprite_altitude = ypos
        end
        refresh
      end
      if Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
        xpos += (Input.repeat?(Input::RIGHT)) ? 1 : -1
        case param
        when 0 then metrics_data.back_sprite[0]  = xpos
        when 1 then metrics_data.front_sprite[0] = xpos
        when 4 then metrics_data.shadow_x        = xpos
        end
        refresh
      end
      if Input.repeat?(Input::ACTION) && param != 4   # Cycle to next option
        @metricsChanged = true if xpos != oldxpos || ypos != oldypos
        ret = true
        pbPlayDecisionSE
        break
      elsif Input.repeat?(Input::BACK)
        case param
        when 0
          metrics_data.back_sprite[0] = oldxpos
          metrics_data.back_sprite[1] = oldypos
        when 1
          metrics_data.front_sprite[0] = oldxpos
          metrics_data.front_sprite[1] = oldypos
        when 2
          metrics_data.front_sprite_altitude = oldypos
        when 4
          metrics_data.shadow_x = oldxpos
        end
        pbPlayCancelSE
        refresh
        break
      elsif Input.repeat?(Input::USE)
        @metricsChanged = true if xpos != oldxpos || (param != 4 && ypos != oldypos)
        pbPlayDecisionSE
        break
      end
    end
    @sprites["info"].visible = false
    sprite.visible = true
    return ret
  end

  def pbMenu
    refresh
    cw = Window_CommandPokemon.new(
      [_INTL("Set Ally Position"),
       _INTL("Set Enemy Position"),
       _INTL("Set Enemy Altitude"),
       _INTL("Set Shadow Size"),
       _INTL("Set Shadow Position"),
       _INTL("Auto-Position Sprites")]
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
      end
    end
    cw.dispose
    return ret
  end
end

#===============================================================================
#
#===============================================================================
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
          command = (command + 1) % 4
        end
      end
    end
    @scene.pbClose
  end
end

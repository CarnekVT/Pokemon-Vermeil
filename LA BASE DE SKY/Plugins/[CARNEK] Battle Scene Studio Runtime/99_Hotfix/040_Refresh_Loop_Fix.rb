# encoding: utf-8

# `stack level too deep` (SystemStackError) al crear cualquier sala EBDX no
# custom. BSSUnifiedAuthority (037) redefine `refresh` en el cuerpo de la clase
# y alías `_bss_unified_refresh` a la cima de la cadena de prepends
# (BSS098RuntimeRasterAuthority). Como los prepends despachan antes que la
# definición de la clase, el eco `super` de BSS078 vuelve a entrar en la misma
# cadena: BSS098 -> BSS090 -> BSS086 -> BSS078 -> clase -> BSS098 -> ... (loop).
# Este overlay restaura el `refresh` fiel de 10_EBDX_Source/005_Faithful_EBDX_Room
# como hoja de la cadena. El alias roto queda muerto y BSS070CustomRoom no se toca.
# Debe cargar DESPUÉS de 90_CustomRooms/037_Unified_Final_Authority.

if defined?(BSS070EBDXRoom) && BSS070EBDXRoom.method_defined?(:_bss_unified_refresh)
  class BSS070EBDXRoom
    def refresh(*args)
      unless args[0].is_a?(Hash)
        @sprites[args[0]] = args[1] if args[0].is_a?(String) && args.length > 1
        return
      end
      @fpIndex = 0
      bss076_dispose_owned_sprites!
      sx, sy = @scene.vector.spoof(@defaultvector)
      @sprites["void"] = BSS070EBDXSprite.new(@viewport)
      @sprites["void"].z = -10
      @overscan_pad = [(@viewport.width * 0.5).to_i, 192].max
      @sprites["void"].bitmap = Bitmap.new(@viewport.width + @overscan_pad * 2, @viewport.height + @overscan_pad * 2)
      @sprites["void"].x = -@overscan_pad
      @sprites["void"].y = -@overscan_pad
      @sprites["bg"] = BSS070EBDXSprite.new(@viewport)
      @sprites["bg"].z = 0
      @baseBmp = nil
      for key in ["backdrop", "base", "water", "spinningLights", "outdoor", "sky", "trees", "tallGrass", "spinLights",
                 "lightsA", "lightsB", "lightsC", "vacuum", "bubbles"]
        next if !@data.has_key?(key)
        case key
        when "backdrop"
          path = pbResolveBitmap(@data["backdrop"]) ? @data["backdrop"] : "Graphics/BattleSceneStudio/EBDX/Battlebacks/battlebg/" + @data["backdrop"]
          tbmp = pbBitmap(path)
          @sprites["bg"].bitmap = Bitmap.new(tbmp.width, tbmp.height)
          @sprites["bg"].bitmap.blt(0, 0, tbmp, tbmp.rect)
          tbmp.dispose
        when "base"
          str = pbResolveBitmap(@data["base"]) ? @data["base"] : "Graphics/BattleSceneStudio/EBDX/Battlebacks/base/" + @data["base"]
          @baseBmp = pbBitmap(str) if str
        when "sky"
          self.drawSky
        when "trees"
          self.drawTrees
        when "tallGrass"
          self.drawGrass
        when "spinLights"
          self.drawSpinLights
        when "lightsA"
          self.drawLightsA
        when "lightsB"
          self.drawLightsB
        when "lightsC"
          self.drawLightsC
        when "water"
          self.drawWater
        when "vacuum"
          self.vacuumWaves(@data[key])
        when "bubbles"
          self.bubbleStream(@data[key])
        end
      end
      for key in @data.keys
        if key.include?("img")
          self.drawImg(key)
        end
      end
      if @sprites["bg"].bitmap
        @sprites["bg"].center!
        @sprites["bg"].ox = sx / 1.5 - 16
        @sprites["bg"].oy = sy / 1.5 + 16
        if @data["wideWorld"] == true || @sprites["bg"].bitmap.width > 384 || @sprites["bg"].bitmap.height > 308
          logical_w = 384.0
          logical_h = 308.0
          extra_x = [(@sprites["bg"].bitmap.width.to_f  - logical_w) / 2.0, 0.0].max
          extra_y = [(@sprites["bg"].bitmap.height.to_f - logical_h) / 2.0, 0.0].max
          @sprites["bg"].ox += extra_x
          @sprites["bg"].oy += extra_y
          @bss_wide_world_origin = [extra_x, extra_y]
        else
          @bss_wide_world_origin = [0.0, 0.0]
        end
        if @baseBmp
          logical_h = 308.0
          sy = @scene.vector.spoof(@defaultvector)[1]
          oy = sy / 1.5 + 16
          oy += @bss_wide_world_origin[1] if @bss_wide_world_origin
          dist_from_bottom_of_screen = (logical_h / 2.0)
          screen_bottom_y = oy + dist_from_bottom_of_screen
          base_y = screen_bottom_y - @baseBmp.height
          @sprites["bg"].bitmap.blt(0, base_y.to_i, @baseBmp, @baseBmp.rect)
        end
        c1 = @sprites["bg"].bitmap.get_pixel(0, 0)
        c2 = @sprites["bg"].bitmap.get_pixel(0, @sprites["bg"].bitmap.height - 1)
        vw = @sprites["void"].bitmap.width
        vh = @sprites["void"].bitmap.height
        split = [@overscan_pad.to_i + @viewport.height / 2, vh].min
        @sprites["void"].bitmap.fill_rect(0, 0, vw, split, c1)
        @sprites["void"].bitmap.fill_rect(0, split, vw, vh - split, c2)
      end
      self.adjustMetrics
      self.daylightTint
    end
  end
end
#===============================================================================
# VIBRANT COMPANIONS - SHADOW COMPATIBILITY
#===============================================================================

if defined?(Sprite_OWShadow)
  class Sprite_OWShadow
    attr_reader :event unless method_defined?(:event)
    
    def apply_shadow_fusion(base_bmp, src_rect = nil)
      $all_ow_shadows.reject! { |s| s.disposed? || (s.sprite && s.sprite.disposed?) }
      
      is_vibrant = @event.respond_to?(:name) && @event.name && @event.name.to_s.start_with?("VibrantFollower")
      
      current_state = get_vibrant_fusion_state(is_vibrant)
      if @last_fusion_state == current_state && @render_bitmap
        return @render_bitmap
      end
      @last_fusion_state = current_state

      my_rect = src_rect || base_bmp.rect
      if !@render_bitmap || @render_bitmap.width != my_rect.width || @render_bitmap.height != my_rect.height
        @render_bitmap.dispose if @render_bitmap
        @render_bitmap = Bitmap.new(my_rect.width, my_rect.height)
      end
      @render_bitmap.clear
      @render_bitmap.blt(0, 0, base_bmp, my_rect)

      my_x, my_y = @sprite.x, @sprite.y
      my_ox, my_oy = @sprite.ox, @sprite.oy
      my_zx, my_zy = @sprite.zoom_x, @sprite.zoom_y

      exact_p_x1 = my_x - (my_ox * my_zx)
      exact_p_x2 = exact_p_x1 + (my_rect.width * my_zx)
      exact_p_y1 = my_y - (my_oy * my_zy)
      exact_p_y2 = exact_p_y1 + (my_rect.height * my_zy)

      $all_ow_shadows.each do |other|
        next if other == self || other.disposed?
        
        o_sprite = other.sprite
        next if !o_sprite || o_sprite.disposed? || !o_sprite.visible || o_sprite.opacity == 0
        next if other.__id__ > self.__id__ 
        
        if is_vibrant
          o_is_vibrant = other.event.respond_to?(:name) && other.event.name && other.event.name.to_s.start_with?("VibrantFollower")
          next if o_is_vibrant
        end
        
        o_x, o_y = o_sprite.x, o_sprite.y
        next if (my_x - o_x).abs > 48 || (my_y - o_y).abs > 48
        
        o_bmp = o_sprite.bitmap
        next if !o_bmp || o_bmp.disposed?
        
        o_rect = o_sprite.src_rect
        o_ox, o_oy = o_sprite.ox, o_sprite.oy
        o_zx, o_zy = o_sprite.zoom_x, o_sprite.zoom_y
        
        exact_o_x1 = o_x - (o_ox * o_zx)
        exact_o_x2 = exact_o_x1 + (o_rect.width * o_zx)
        exact_o_y1 = o_y - (o_oy * o_zy)
        exact_o_y2 = exact_o_y1 + (o_rect.height * o_zy)
        
        ix = [exact_p_x1, exact_o_x1].max
        iy = [exact_p_y1, exact_o_y1].max
        iw = [exact_p_x2, exact_o_x2].min - ix
        ih = [exact_p_y2, exact_o_y2].min - iy
        
        next if iw <= 0 || ih <= 0
        
        start_px = ((ix - exact_p_x1) / my_zx).floor
        end_px   = ((ix + iw - exact_p_x1) / my_zx).ceil
        start_py = ((iy - exact_p_y1) / my_zy).floor
        end_py   = ((iy + ih - exact_p_y1) / my_zy).ceil
        
        loop_start_x = [start_px - 1, 0].max
        loop_end_x   = [end_px + 1, my_rect.width].min
        loop_start_y = [start_py - 1, 0].max
        loop_end_y   = [end_py + 1, my_rect.height].min
        
        (loop_start_x...loop_end_x).each do |px|
          (loop_start_y...loop_end_y).each do |py|
            next if @render_bitmap.get_pixel(px, py).alpha == 0
            
            screen_px = exact_p_x1 + (px * my_zx)
            screen_py = exact_p_y1 + (py * my_zy)
            
            local_o_x = ((screen_px - o_x) / o_zx) + o_ox
            local_o_y = ((screen_py - o_y) / o_zy) + o_oy
            
            local_o_x = o_rect.width - 1.0 - local_o_x if o_sprite.mirror
            
            if local_o_x >= -0.5 && local_o_x <= o_rect.width - 0.5 && local_o_y >= -0.5 && local_o_y <= o_rect.height - 0.5
              ox_clamp = local_o_x.round.clamp(0, o_rect.width - 1)
              oy_clamp = local_o_y.round.clamp(0, o_rect.height - 1)
              
              if o_bmp.get_pixel(o_rect.x + ox_clamp, o_rect.y + oy_clamp).alpha > 20 
                @render_bitmap.clear_rect(px, py, 1, 1)
              end
            end
          end
        end
      end

      return @render_bitmap
    end
    
    def get_vibrant_fusion_state(is_vibrant)
      state = [@sprite.x.round, @sprite.y.round, @rsprite.src_rect.x, @rsprite.src_rect.y]
      $all_ow_shadows.each do |other|
        next if other == self || other.disposed? || !other.sprite || other.sprite.disposed? || !other.sprite.visible
        
        if is_vibrant
          o_is_vibrant = other.event.respond_to?(:name) && other.event.name && other.event.name.to_s.start_with?("VibrantFollower")
          next if o_is_vibrant
        end
        
        next if (self.sprite.x - other.sprite.x).abs > 48
        next if (self.sprite.y - other.sprite.y).abs > 48
        state << other.sprite.x.round << other.sprite.y.round << other.sprite.src_rect.x
      end
      return state.hash
    end
  end
end
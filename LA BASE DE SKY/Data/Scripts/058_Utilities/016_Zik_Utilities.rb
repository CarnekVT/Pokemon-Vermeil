#===============================================================================
# Conversor HSL a RGB
#===============================================================================
class Float
  def hue_to_rgb(p, q)
    t = self
    t += 1.0 if t < 0.0
    t -= 1.0 if t > 1.0
    return p + (q - p) * 6.0 * t if t < 1.0 / 6.0
    return q if t < 1.0 / 2.0
    return p + (q - p) * (2.0 / 3.0 - t) * 6.0 if t < 2.0 / 3.0
    return p
  end
end

#===============================================================================
# Extensión de Bitmap para cambio de Hue por HSL
#===============================================================================
class Bitmap
  def apply_super_shiny_hue(hue)
    return if disposed? || hue == 0
    hue_shift = (hue % 360) / 360.0
    
    w = self.width
    h = self.height
    
    (0...h).each do |y|
      (0...w).each do |x|
        pixel = self.get_pixel(x, y)
        alpha = pixel.alpha
        next if alpha == 0
        
        r = pixel.red / 255.0
        g = pixel.green / 255.0
        b = pixel.blue / 255.0
        
        max = r
        max = g if g > max
        max = b if b > max
        
        min = r
        min = g if g < min
        min = b if b < min
        
        l = (max + min) / 2.0
        
        if max == min
          self.set_pixel(x, y, Color.new(l * 255, l * 255, l * 255, alpha))
          next
        end
        
        d = max - min
        s = l > 0.5 ? d / (2.0 - max - min) : d / (max + min)
        
        h_val = 0.0
        if max == r
          h_val = (g - b) / d + (g < b ? 6.0 : 0.0)
        elsif max == g
          h_val = (b - r) / d + 2.0
        elsif max == b
          h_val = (r - g) / d + 4.0
        end
        h_val /= 6.0
        
        # Aplicar el desplazamiento HUE
        h_val += hue_shift
        h_val -= 1.0 if h_val >= 1.0
        
        # Convertir HSL de vuelta a RGB
        q = l < 0.5 ? l * (1.0 + s) : l + s - l * s
        p = 2.0 * l - q
        
        new_r = (h_val + 1.0 / 3.0).hue_to_rgb(p, q) * 255
        new_g = h_val.hue_to_rgb(p, q) * 255
        new_b = (h_val - 1.0 / 3.0).hue_to_rgb(p, q) * 255
        
        self.set_pixel(x, y, Color.new(new_r, new_g, new_b, alpha))
      end
    end
  end
end
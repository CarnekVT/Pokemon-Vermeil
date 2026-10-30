# frozen_string_literal: true
# Bifrost Capture - map-space aim, real Sprite_Character bounds, projectile/HUD.
module BifrostCapture
  # Compact 3-slot ball wheel; aiming feedback is separate from capture result.
  class ThrowHUD
    def initialize
      @vp = Viewport.new(0,0,Graphics.width,Graphics.height)
      @vp.z = 999992
      @aim = Sprite.new(@vp)
      @aim.bitmap = Bitmap.new(64,64)
      @aim.ox = @aim.oy = 32
      @panel = Sprite.new(@vp)
      @panel.bitmap = Bitmap.new(316,104)
      @panel.x = [Graphics.width-323,4].max
      @panel.y = [Graphics.height-111,4].max
      @last_status = nil
      @icons = {}
      @ball_list = []
      @selected = 0
    end

    def equip(list,selected)
      @ball_list = list || []
      @selected = selected.to_i
    end

    def icon(item)
      return nil if !item
      return @icons[item] if @icons.key?(item)
      filename = pbResolveBitmap("Graphics/Items/#{item}")
      @icons[item] = filename ? Bitmap.new(filename) : nil
    end

    def reticle(x,y,status)
      @aim.x = x.to_i
      @aim.y = y.to_i
      @aim.visible = true
      return if status == @last_status
      @last_status = status
      bmp = @aim.bitmap
      bmp.clear
      color = case status
              when :ready then Color.new(136,249,188)
              when :blocked then Color.new(249,146,142)
              else Color.new(224,231,241)
              end
      72.times do |i|
        theta = i*2*Math::PI/72
        px=(32+Math.cos(theta)*19).round
        py=(32+Math.sin(theta)*19).round
        bmp.fill_rect(px,py,2,2,color)
      end
      # Four small breaks make the cursor readable over grass and foliage.
      bmp.fill_rect(31,2,2,10,color)
      bmp.fill_rect(31,52,2,10,color)
      bmp.fill_rect(2,31,10,2,color)
      bmp.fill_rect(52,31,10,2,color)
      bmp.fill_rect(30,30,4,4,color)
    end

    def draw(mode,item,count,focus,notice)
      bmp = @panel.bitmap
      bmp.clear
      bmp.fill_rect(0,0,316,104,Color.new(13,19,31,223))
      bmp.fill_rect(0,0,3,104,Color.new(174,195,227))
      bmp.font.size = 12
      bmp.font.color = Color.new(169,187,212)
      bmp.draw_text(12,4,280,16,mode == :ball ? "POKÉ BALL EQUIPADA" : "POKÉMON PREPARADO")
      if mode == :ball
        # Three-slot strip; middle slot is the item being thrown.
        [-1,0,1].each_with_index do |offset,i|
          next if @ball_list.empty?
          idx = (@selected+offset) % @ball_list.length
          selected_ball = @ball_list[idx][0]
          left = 14+i*54
          bmp.fill_rect(left,24,49,43,
            Color.new(44,64,85, i==1 ? 228 : 138))
          bmp.fill_rect(left,64,49,2,i==1 ?
            Color.new(146,231,194) : Color.new(83,107,130))
          source = icon(selected_ball)
          if source && source.width > 0 && source.height > 0
            bmp.stretch_blt(Rect.new(left+10,28,29,29), source,
                            Rect.new(0,0,source.width,source.height))
          else
            bmp.fill_rect(left+18,37,13,13,Color.new(211,223,244))
          end
          bmp.font.color = i==1 ? Color.new(243,247,255) :
                          Color.new(178,195,214)
          bmp.draw_text(left,52,49,13,"x#{$bag.quantity(selected_ball)}",1)
        end
      else
        bmp.fill_rect(15,28,153,42,Color.new(43,61,79,204))
        bmp.font.size = 17
        bmp.font.color = Color.new(235,243,253)
        bmp.draw_text(23,36,143,25,item ? item.name : "-")
      end
      bmp.fill_rect(182,24,123,43,Color.new(28,37,53,216))
      spec = focus && BifrostCapture.event_spec(focus)
      bmp.font.size = 12
      bmp.font.color = spec ? Color.new(175,243,200) :
                        Color.new(235,174,161)
      bmp.draw_text(189,25,109,19,spec ? spec[0].to_s : "SIN OBJETIVO")
      bmp.font.color = Color.new(227,234,244)
      bmp.draw_text(189,46,109,18,spec ? "Nv. #{spec[1]}" : "Busca un OW")
      bmp.font.size = 12
      bmp.font.color = Color.new(248,214,157)
      bmp.draw_text(13,71,293,17,notice.to_s)
      bmp.font.size = 10
      bmp.font.color = Color.new(176,193,216)
      bmp.draw_text(13,90,294,13,"W apuntar/soltar · Q cambiar · C lanzar · D modo")
    end

    def dispose
      @icons.each_value do |bitmap|
        bitmap.dispose if bitmap && !bitmap.disposed?
      end
      [@aim,@panel].each do |sprite|
        bitmap = sprite.bitmap
        sprite.dispose unless sprite.disposed?
        bitmap.dispose if bitmap && !bitmap.disposed?
      end
      @vp.dispose unless @vp.disposed?
    end
  end

  # Actual onscreen area from Sprite_Character (including camera zoom).
  def self.target_rect(event)
    if $scene.is_a?(Scene_Map) && $scene.respond_to?(:spriteset)
      spriteset = $scene.spriteset($game_map.map_id)
      sprites = spriteset && spriteset.instance_variable_get(:@character_sprites)
      sprite = sprites && sprites.find { |sp| sp && sp.character.equal?(event) }
      if sprite && !sprite.disposed? && sprite.visible
        w = [sprite.src_rect.width*sprite.zoom_x.abs,8].max
        h = [sprite.src_rect.height*sprite.zoom_y.abs,8].max
        return [sprite.x-sprite.ox*sprite.zoom_x,
                sprite.y-sprite.oy*sprite.zoom_y,w,h]
      end
    end
    size = event.respond_to?(:sprite_size) ? event.sprite_size : [32,32]
    w = [size[0].to_f,20].max
    h = [size[1].to_f,20].max
    [event.screen_x-w/2,event.screen_y-h,w,h]
  end

  def self.screen_position(event)
    x,y,w,h = target_rect(event)
    [x+w/2,y+h*0.55]
  end

  def self.rect_distance(px,py,rect)
    x,y,w,h = rect
    dx = [x-px,0,px-x-w].max
    dy = [y-py,0,py-y-h].max
    dx*dx+dy*dy
  end

  def self.visible_targets
    return [] unless $game_map
    $game_map.events.values.select do |event|
      next false unless eligible_event?(event)
      x,y,w,h = target_rect(event)
      x < Graphics.width && y < Graphics.height && x+w > 0 && y+h > 0
    end
  end

  def self.focus_at(point,cfg)
    return nil unless point
    radius = cfg["aim_target_radius"].to_i.clamp(4,120)
    nearest = visible_targets.map { |event|
      [event,rect_distance(point[0],point[1],target_rect(event))]
    }.min_by { |row| row[1] }
    nearest && nearest[1] <= radius*radius ? nearest[0] : nil
  end

  def self.closest_target
    all = visible_targets
    ready = all.select do |event|
      spec = event_spec(event)
      local = options($game_map.map_id,spec[0],event.id)
      geo = geometry($game_player.x,$game_player.y,event.x,event.y,local)
      geo[:in_range] && (local["line_of_sight"] != "1" ||
        line_clear?($game_player.x,$game_player.y,event.x,event.y))
    end
    (ready.empty? ? all : ready).min_by do |event|
      [($game_player.x-event.x).abs+($game_player.y-event.y).abs,event.id]
    end
  end

  def self.update_frame
    $scene.updateMaps
    $scene.updateSpritesets
  end

  def self.ball_bitmap(item)
    filename = pbResolveBitmap("Graphics/Items/#{item}")
    filename ||= pbResolveBitmap("Graphics/Items/POKEBALL")
    return Bitmap.new(filename) if filename
    bmp = Bitmap.new(18,18)
    bmp.fill_rect(2,2,14,7,Color.new(220,80,84))
    bmp.fill_rect(2,9,14,7,Color.new(244,241,225))
    bmp.fill_rect(2,8,14,2,Color.new(33,35,42))
    bmp.fill_rect(7,7,4,4,Color.new(247,247,247))
    bmp
  end

  # Engine input is processed by the normal Scene_Map update loop;
  # no extra Graphics.update or Input.update and no blocked player movement.
  def self.update_input
    LiveAim.update if defined?(LiveAim)
  end

  def self.aim
    return false unless defined?(LiveAim)
    LiveAim.start
  end
end

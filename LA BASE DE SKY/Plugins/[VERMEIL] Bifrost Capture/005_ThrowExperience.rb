# frozen_string_literal: true
# Bifrost Capture - map-space aim, real Sprite_Character bounds, projectile/HUD.
module BifrostCapture
  # Compact 3-slot ball wheel; aiming feedback is separate from capture result.
  # Map-space HUD. One restrained strip; no opaque window over the trainer.
  class ThrowHUD
    TEMPERAMENT_COLORS = {
      :neutral=>Color.new(158,224,191),
      :timid=>Color.new(126,191,248),
      :aggressive=>Color.new(247,154,122)
    }.freeze

    def initialize
      @vp = Viewport.new(0,0,Graphics.width,Graphics.height)
      @vp.z = 999992
      @aim = Sprite.new(@vp)
      @aim.bitmap = Bitmap.new(64,64)
      @aim.ox = @aim.oy = 32
      @panel = Sprite.new(@vp)
      @panel.bitmap = Bitmap.new(278,90)
      @panel.x = [Graphics.width-286,4].max
      @panel.y = [Graphics.height-98,4].max
      @last_status = nil
      @pulse = 0
      @icons = {}
      @ball_list = []
      @selected = 0
      @selection_key = nil
      @selection_frame = 0
    end

    def equip(list,selected)
      @ball_list = list || []
      @selected = selected.to_i
    end

    def icon(item)
      return nil unless item
      return @icons[item] if @icons.key?(item)
      filename = pbResolveBitmap("Graphics/Items/#{item}")
      @icons[item] = filename ? Bitmap.new(filename) : nil
    end

    def team_icon(pokemon)
      return nil unless pokemon && pokemon.respond_to?(:species)
      species = pokemon.species
      form = pokemon.respond_to?(:form) ? pokemon.form.to_i : 0
      key = [:pokemon_icon,species,form]
      return @icons[key] if @icons.key?(key)
      paths = []
      paths << "Graphics/Pokemon/Icons/#{species}_#{form}" if form > 0
      paths << "Graphics/Pokemon/Icons/#{species}"
      filename = paths.map { |p| pbResolveBitmap(p) }.compact.first
      @icons[key] = filename ? Bitmap.new(filename) : nil
    rescue StandardError
      @icons[key] = nil
    end

    def reticle(x,y,status,mood=:neutral)
      @aim.x = x.to_i
      @aim.y = y.to_i
      @pulse = (@pulse + 1) % 48
      zoom = status == :ready ? 1.0+Math.sin(@pulse*Math::PI/24)*0.035 : 1.0
      @aim.zoom_x = @aim.zoom_y = zoom
      stamp = [status,mood]
      return if stamp == @last_status
      @last_status = stamp
      bmp = @aim.bitmap
      bmp.clear
      color = status == :blocked ? Color.new(255,134,135) :
              status == :ready ? (TEMPERAMENT_COLORS[mood] ||
                                    TEMPERAMENT_COLORS[:neutral]) :
              Color.new(218,230,240)
      # Four separated arcs plus crossbars: readable against long grass.
      80.times do |i|
        next if (i / 10).odd? && i % 10 >= 5
        theta = i*2*Math::PI/80
        px = (32+Math.cos(theta)*19).round
        py = (32+Math.sin(theta)*19).round
        bmp.fill_rect(px,py,2,2,color)
      end
      bmp.fill_rect(31,5,2,8,color)
      bmp.fill_rect(31,51,2,8,color)
      bmp.fill_rect(5,31,8,2,color)
      bmp.fill_rect(51,31,8,2,color)
      bmp.fill_rect(30,30,4,4,color)
    end

    def draw(mode,item,count,focus,notice,party=nil,party_index=0)
      bmp = @panel.bitmap
      bmp.clear
      bmp.fill_rect(0,0,278,90,Color.new(13,21,32,205))
      bmp.fill_rect(0,0,3,90,Color.new(139,199,221))
      bmp.font.size = 11
      bmp.font.bold = false
      bmp.font.color = Color.new(190,205,222)
      selection_key = mode == :ball ? [:ball,item] : [:battle,item && item.object_id]
      if @selection_key != selection_key
        @selection_key = selection_key
        @selection_frame = 0
      end
      @selection_frame = [@selection_frame+1,9].min
      bmp.draw_text(11,2,175,17,mode == :ball ? "BALL EQUIPADA" : "EQUIPO POKÉMON")
      if mode == :ball
        [-1,0,1].each_with_index do |offset,i|
          next if @ball_list.empty?
          idx = (@selected+offset) % @ball_list.length
          selected_ball = @ball_list[idx][0]
          left = 10+i*47
          bmp.fill_rect(left,19,44,41,
            Color.new(43,66,78,i==1 ? 218 : 112))
          bmp.fill_rect(left,58,44,2,i==1 ?
            Color.new(146,234,189) : Color.new(77,102,118))
          source = icon(selected_ball)
          if source && source.width > 0 && source.height > 0
            bmp.stretch_blt(Rect.new(left+10,23,24,26),source,
              Rect.new(0,0,source.width,source.height))
          else
            bmp.fill_rect(left+17,30,11,11,Color.new(218,232,240))
          end
          bmp.font.color = Color.new(238,244,249)
          bmp.draw_text(left+2,47,40,13,"x#{$bag.quantity(selected_ball)}",1)
        end
      else
        # Z-A-style compact team selection: Pokémon icon and readable name.
        # Slide the selected icon in over 9 map frames without blocking input.
        bmp.fill_rect(11,20,138,43,Color.new(40,62,83,205))
        bmp.fill_rect(11,59,138,2,Color.new(134,217,196))
        if item
          icon = team_icon(item)
          offset = ((9-@selection_frame)*1.4).round
          if icon && icon.width > 0 && icon.height > 0
            frame_width = icon.width > icon.height ? icon.width/2 : icon.width
            bmp.stretch_blt(Rect.new(13-offset,23,35,35),icon,
              Rect.new(0,0,frame_width,icon.height))
          else
            bmp.fill_rect(19,29,23,23,Color.new(119,180,220))
          end
          bmp.font.color = Color.new(245,249,255)
          bmp.font.size = 13
          bmp.font.bold = true
          bmp.draw_text(53,25,92,19,item.name.to_s)
          bmp.font.bold = false
          bmp.font.size = 11
          bmp.font.color = Color.new(174,220,237)
          level = item.respond_to?(:level) ? item.level : "-"
          position = party ? "#{party_index.to_i+1}/#{party.length}" : ""
          bmp.draw_text(54,44,90,16,"Nv.#{level}  #{position}")
          if item.respond_to?(:hp) && item.respond_to?(:totalhp) &&
             item.totalhp.to_i > 0
            hp_fraction = (item.hp.to_f/item.totalhp).clamp(0.0,1.0)
            bmp.fill_rect(54,58,88,2,Color.new(35,47,60))
            bmp.fill_rect(54,58,(88*hp_fraction).round,2,
              Color.new(142,230,187))
          end
        end
      end
      spec = focus && BifrostCapture.event_spec(focus)
      if spec
        mood = BifrostCapture.temperament_for(focus)
        hue = TEMPERAMENT_COLORS[mood] || TEMPERAMENT_COLORS[:neutral]
        state = focus.instance_variable_get(:@bifrost_mood_state)
        state_label = state == :chase ? "¡PERSIGUE!" :
                      state == :flee ? "¡HUYE!" :
                      BifrostCapture.temperament_label(mood)
        bmp.fill_rect(157,18,114,43,Color.new(26,38,50,215))
        bmp.fill_rect(157,18,3,43,hue)
        bmp.font.color = hue
        bmp.font.size = 12
        bmp.draw_text(165,20,104,19,state_label)
        bmp.font.color = Color.new(235,241,250)
        bmp.draw_text(165,38,104,18,"#{spec[0]}  Nv.#{spec[1]}")
      else
        bmp.fill_rect(157,18,114,43,Color.new(26,38,50,190))
        bmp.font.color = Color.new(191,200,214)
        bmp.font.size = 12
        bmp.draw_text(166,29,99,20,"Sin objetivo")
      end
      bmp.font.size = 12
      bmp.font.color = Color.new(240,219,173)
      bmp.draw_text(11,64,256,15,notice.to_s)
      bmp.font.size = 9
      bmp.font.color = Color.new(172,194,211)
      cfg = BifrostCapture.options
      aim = BifrostCapture.binding_name(cfg,"hotkey")
      ball = BifrostCapture.binding_name(cfg,"ball_key")
      target_key = cfg["keyboard_target_key"].to_s.upcase
      mode_key = cfg["keyboard_mode_key"].to_s.upcase
      help = if target_key != "NONE" && mode_key != "NONE"
               "#{target_key} obj. · #{mode_key} modo · #{ball}/Mayús+#{ball} sel."
             else
               "#{aim} apuntar · #{ball} cambiar/mantener modo"
             end
      bmp.draw_text(11,78,256,12,help)
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

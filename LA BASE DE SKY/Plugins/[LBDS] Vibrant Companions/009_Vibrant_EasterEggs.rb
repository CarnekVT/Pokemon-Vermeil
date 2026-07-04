#===============================================================================
# VIBRANT COMPANIONS - MODULE 9: EASTER EGGS
# Interacciones secretas y eventos aleatorios raros
#===============================================================================

class FollowerSprites
  attr_reader :sprites unless method_defined?(:sprites)
end

module VibrantCompanions
  module EasterEggs
    #---------------------------------------------------------------------------
    # Evaluador Principal de Easter Eggs (Interacción)
    #---------------------------------------------------------------------------
    def self.try_trigger(pkmn, follower)
      return false unless Settings::ENABLE_EASTER_EGGS
      
      if rand(10000) == 0
        play_backflip(pkmn, follower)
        return true
      end
      
      return false
    end

    #---------------------------------------------------------------------------
    # Easter Egg 1: Backflip
    #---------------------------------------------------------------------------
    def self.play_backflip(pkmn, follower)
      actor_bitmap = RPG::Cache.character(follower.character_name, follower.character_hue)
      pbSEPlay("backflip", 0) rescue nil
      
      Emotes.show(follower, :Exclamation)
      pbWait(0.5)
      pbMessage(_INTL("¡{1} volteó a atras!", pkmn.name))
      
      sprite = nil
      if $scene.is_a?(Scene_Map) && $scene.spritesetGlobal && $scene.spritesetGlobal.respond_to?(:follower_sprites)
        follower_sprites_obj = $scene.spritesetGlobal.follower_sprites
        if follower_sprites_obj.respond_to?(:sprites)
          sprite = follower_sprites_obj.sprites.find { |s| s.character == follower }
        end
      end
      return unless sprite && sprite.bitmap
      
      orig_name = follower.character_name
      orig_x, orig_y = sprite.x, sprite.y
      orig_ox, orig_oy = sprite.ox, sprite.oy
      orig_z, orig_dir = sprite.z, follower.direction

      shadow_bmp = nil
      shadow_data = {}
      if sprite.respond_to?(:ow_shadow) && sprite.ow_shadow
        real_shadow = sprite.ow_shadow.instance_variable_get(:@sprite)
        if real_shadow && real_shadow.bitmap && !real_shadow.bitmap.disposed?
          shadow_bmp = real_shadow.bitmap.clone 
          shadow_data = { ox: real_shadow.ox, oy: real_shadow.oy, x: real_shadow.x, y: real_shadow.y }
        end
      end

      Graphics.freeze 
      follower.character_name = ""
      if sprite.respond_to?(:ow_shadow) && sprite.ow_shadow
        sprite.ow_shadow.instance_variable_set(:@shadow_fade, 0.0)
      end
      
      2.times { Graphics.update; pbUpdateSceneMap }
      
      view = Viewport.new(0, 0, Graphics.width, Graphics.height)
      view.z = 99999
      background = Sprite.new(view)
      background.bitmap = Graphics.snap_to_bitmap
      
      bg_center_x, bg_center_y = orig_x, orig_y - (orig_oy / 2)
      background.ox, background.oy = bg_center_x, bg_center_y
      background.x, background.y = bg_center_x, bg_center_y
      
      char_sprite = Sprite.new(view)
      char_sprite.bitmap = actor_bitmap
      char_sprite.src_rect = sprite.src_rect.clone
      char_sprite.z = 1000
      
      fw, fh = char_sprite.src_rect.width, char_sprite.src_rect.height
      center_ox, center_oy = fw / 2, fh / 2
      base_char_x, base_char_y = orig_x + (center_ox - orig_ox), orig_y + (center_oy - orig_oy)

      shadow_sprite = Sprite.new(view)
      if shadow_bmp
        shadow_sprite.bitmap = shadow_bmp
        shadow_sprite.ox, shadow_sprite.oy = shadow_data[:ox], shadow_data[:oy]
        shadow_sprite.z = 500
        base_shadow_x, base_shadow_y = shadow_data[:x], shadow_data[:y]
      end

      Graphics.transition(0) 

      pbSEPlay("backflip") rescue nil
      total_frames, jump_height, max_cam_zoom = 400.0, 70.0, 1.5
      target_angle = (rand(2) == 0) ? -360.0 : 360.0
      
      (1..total_frames).each do |frame|
        progress = frame / total_frames
        parabola = 4.0 * progress * (1.0 - progress)
        current_zoom = 1.0 + (max_cam_zoom - 1.0) * parabola
        background.zoom_x = background.zoom_y = current_zoom
        current_jump_y = jump_height * parabola
        char_sprite.ox, char_sprite.oy = center_ox, center_oy
        char_sprite.x = background.x + (base_char_x - background.ox) * current_zoom
        char_sprite.y = background.y + (base_char_y - current_jump_y - background.oy) * current_zoom
        char_sprite.angle, char_sprite.zoom_x, char_sprite.zoom_y = target_angle * progress, current_zoom, current_zoom
        if shadow_sprite.bitmap
          s_scale = [1.0 - (current_jump_y * 0.01), 0.4].max
          shadow_sprite.x = background.x + (base_shadow_x - background.ox) * current_zoom
          shadow_sprite.y = background.y + (base_shadow_y - background.oy) * current_zoom
          shadow_sprite.zoom_x = shadow_sprite.zoom_y = s_scale * current_zoom
        end
        c_dir = (progress > 0.25 && progress < 0.75) ? (10 - orig_dir) : orig_dir
        char_sprite.src_rect.y = (c_dir == 2 ? 0 : c_dir == 4 ? 1 : c_dir == 6 ? 2 : 3) * fh
        Graphics.update; Input.update
      end
      
      shadow_sprite.dispose; shadow_bmp.dispose if shadow_bmp
      char_sprite.dispose; background.bitmap.dispose; background.dispose; view.dispose
      follower.character_name = orig_name
      if sprite.respond_to?(:ow_shadow) && sprite.ow_shadow
        sprite.ow_shadow.instance_variable_set(:@shadow_fade, 1.0)
      end
    end

		#---------------------------------------------------------------------------
    # Easter Egg 2: Conga
    #---------------------------------------------------------------------------
    @@conga_triggered_on_map = false

    def self.reset_conga_map_flag
      @@conga_triggered_on_map = false
    end

    def self.check_conga
      return if !Settings::ENABLE_EASTER_EGGS
      return if !Settings.enable_caterpillar?
      
      state = Manager.save_data
      return if state.conga_timer > 0
      return if @@conga_triggered_on_map 
      
      return unless $game_map && $game_map.metadata && $game_map.metadata.outdoor_map
      
      # --- Verificación de línea recta ---
      all_x = [$game_player.x]
      all_y = [$game_player.y]
      
      count = 0
      $game_temp.followers.each_follower do |event, follower|
        if follower.name && follower.name.start_with?("VibrantFollower_")
          all_x << event.x
          all_y << event.y
          count += 1
        end
      end
      
      return if count < Settings.max_followers # Asegura que el tren esté completo
      
      # Verifica si todos están en la misma columna (X) o en la misma fila (Y)
      is_straight_x = all_x.uniq.length == 1
      is_straight_y = all_y.uniq.length == 1
      
      return unless is_straight_x || is_straight_y
      
      if rand(100000) == 0
        state.conga_timer = 10.0
        @@conga_triggered_on_map = true 
        $game_system.bgm_pause
        pbSEPlay("conga") rescue nil
      end
    end

		def self.cancel_conga
      state = Manager.save_data
      if state.conga_timer > 0
        state.conga_timer = 0.0
        $game_system.bgm_unpause
        pbSEStop rescue nil
      end
    end
  end
end

# Hook independiente para la Conga (Al final para asegurar carga)
EventHandlers.add(:on_player_step_taken, :vibrant_conga_check, proc {
  VibrantCompanions::EasterEggs.check_conga
})

# Resetear la bandera de la conga al cambiar de mapa y detenerla si estaba activa
EventHandlers.add(:on_enter_map, :vibrant_conga_map_reset, proc { |_old_map_id|
  VibrantCompanions::EasterEggs.reset_conga_map_flag
  VibrantCompanions::EasterEggs.cancel_conga
})

# Aborta la conga instantáneamente si abres el menú o hablas con alguien
EventHandlers.add(:on_frame_update, :vibrant_conga_cancel_monitor, proc {
  state = VibrantCompanions::Manager.save_data
  next if state.conga_timer <= 0
  
  # Si salimos del mapa, abrimos el menú, o sale una caja de texto -> Cancelar
  if !$scene.is_a?(Scene_Map) || $game_temp.message_window_showing || $game_temp.in_menu
    VibrantCompanions::EasterEggs.cancel_conga
  end
})
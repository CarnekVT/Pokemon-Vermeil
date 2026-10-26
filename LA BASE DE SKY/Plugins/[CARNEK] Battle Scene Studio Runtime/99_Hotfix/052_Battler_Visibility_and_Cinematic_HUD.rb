# frozen_string_literal: true
# BSS: one-shot restoration of active battler visibility after native sendout,
# cinematic databox isolation, and trainer home position during speech.
# Never drive bas attack-frame sprites, and never force opacity every frame.
module BSSSceneVisibilityAndHud
  def bss_visibility_active?
    respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
  rescue StandardError
    false
  end

  def bss_recover_active_battlers_after_sendout(indices=nil)
    return unless bss_visibility_active? && @sprites.is_a?(Hash) && @battle
    return if @bss070_ebdx_bas_frame || @bas_runtime_playback_depth.to_i>0
    return if @bss_camera_attack_phase_depth.to_i>0
    room=@bss070_ebdx_room
    @battle.battlers.each do |bat|
      next unless bat && !(bat.fainted? rescue true)
      i=bat.index
      next if indices && !indices.include?(i)
      sprite=@sprites["pokemon_#{i}"]
      next unless sprite && !(sprite.disposed? rescue true)
      # DynamicPokemonSprite may expose only animatedBitmap (not bitmap).
      # Requiring a non-nil bitmap here skipped freshly switched-in Pokémon,
      # leaving them invisible until the first BAS move assigned a frame.
      # Only called at completed sendout and before the first command menu;
      # faint, substitute and move animations are never affected here.
      sprite.visible=true if sprite.respond_to?(:visible=)
      sprite.opacity=255 if sprite.respond_to?(:opacity=) && sprite.opacity.to_i==0
      shadow=@sprites["shadow_#{i}"]
      enabled=(!room || !room.respond_to?(:shadows_enabled?) || room.shadows_enabled?)
      if enabled && shadow && !(shadow.disposed? rescue true)
        shadow.visible=true if shadow.respond_to?(:visible=)
        shadow.opacity=255 if shadow.respond_to?(:opacity=) && shadow.opacity.to_i==0
      end
    end
    bss070_ebdx_apply_world_alignment if respond_to?(:bss070_ebdx_apply_world_alignment)
  rescue StandardError => e
    BSS064.log("BSS sendout visibility: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def pbSendOutBattlers(*args,&block)
    result=super
    rows=args[0].is_a?(Array) ? args[0] : []
    indices=rows.filter_map do |row|
      value=row.is_a?(Array) ? row[0] : row
      value.respond_to?(:index) ? value.index : (value.is_a?(Integer) ? value : nil)
    end
    indices=nil if indices.empty?
    bss_recover_active_battlers_after_sendout(indices)
    # The DynamicPokemonSprite can load one frame after the sendout method.
    # Perform a single second recovery on the next scene update.
    @bss_pending_visibility_restore=indices || :all
    # Dynamic spritesheets can resolve after the sendout scene has returned.
    # Retry briefly instead of attempting a single premature visible=true.
    @bss_pending_visibility_frames=12
    result
  end

  def pbChangePokemon(*args,&block)
    # Sprite swap is NOT a sendout. Leave it invisible until the native
    # Poké Ball animation completes; pbSendOutBattlers performs recovery.
    super
  end

  def pbCommandMenu(*args,&block)
    if bss_visibility_active? && !@bss_first_command_visibility_recovered
      @bss_first_command_visibility_recovered=true
      bss_recover_active_battlers_after_sendout
    end
    super
  end

  def bss_cinematic_hud_sprite?(key)
    !!(key.to_s =~ /\A(?:dataBox_|bss_boss_hud|boss.*(?:hud|bar|box)|totem.*(?:hud|bar|box)|raid.*(?:hud|bar|box))/i)
  end

  def bss_cinematic_hud_hide!
    return unless @bss_dialogue_cinema_active && @sprites.is_a?(Hash)
    @bss_cinematic_hud_saved ||= {}
    @bss_cinematic_hud_requested ||= {}
    @sprites.each do |key,sp|
      next unless bss_cinematic_hud_sprite?(key)
      next unless sp && !(sp.disposed? rescue true) && sp.respond_to?(:visible)
      @bss_cinematic_hud_saved[key]=sp.visible unless @bss_cinematic_hud_saved.key?(key)
      if sp.respond_to?(:request_visibility)
        # BossHUD already has a dedicated short easing animation. Do not set
        # facade.visible=false or repeatedly restart its tween every frame.
        unless @bss_cinematic_hud_requested[key]
          sp.request_visibility(false,0.17)
          @bss_cinematic_hud_requested[key]=true
        end
      elsif sp.respond_to?(:visible=)
        sp.visible=false
      end
    end
  end

  def bss_cinematic_hud_release!
    saved=@bss_cinematic_hud_saved
    @bss_cinematic_hud_saved=nil
    @bss_cinematic_hud_fade ||= {}
    @bss_cinematic_hud_requested=nil
    return unless saved && @sprites.is_a?(Hash)
    saved.each do |key,was_visible|
      sp=@sprites[key]
      next unless sp && !(sp.disposed? rescue true)
      show=was_visible
      if key.to_s =~ /\AdataBox_(\d+)\z/
        idx=$1.to_i
        battler=(@battle.battlers[idx] rescue nil)
        boss_idx=(@bss_boss_hud_index rescue nil)
        show=!!(battler && !(battler.fainted? rescue true) && boss_idx!=idx)
      elsif key.to_s=="bss_boss_hud"
        battler=(@battle.battlers[@bss_boss_hud_index] rescue nil)
        show=!!(battler && !(battler.fainted? rescue true))
      end
      sp.visible=show if sp.respond_to?(:visible=)
      if sp.respond_to?(:request_visibility)
        sp.request_visibility(show,0.14)
      elsif show && key.to_s.start_with?("dataBox_") && sp.respond_to?(:opacity=)
        # DBK may leave its native databox at opacity=0 after speech. Fade
        # back in once rather than making the HUD appear instantly.
        final=255
        sp.opacity=0
        @bss_cinematic_hud_fade[key]=[0,final,7]
      end
    end
  end

  def bss_cinematic_tone_refresh!
    room=@bss070_ebdx_room
    if room && !(room.disposed? rescue true) && room.respond_to?(:bss_layered_apply_tone!)
      room.bss_layered_apply_tone!(true)
    end
  end

  def pbStartSpeech(*args,&block)
    bss = bss_visibility_active? && @bss_dialogue_cinema_active
    if bss && !@bss_cinematic_trainer_home
      @bss_cinematic_trainer_home={}
      @sprites.each do |name,sp|
        next unless name.to_s =~ /\Atrainer_\d+\z/ && sp && !(sp.disposed? rescue true)
        @bss_cinematic_trainer_home[name]=[sp.x,sp.y] if sp.respond_to?(:x) && sp.respond_to?(:y)
      end
    end
    # Snapshot the HUD BEFORE DBK toggles its databoxes. Otherwise the
    # snapshot captures the hidden state and restores invisible HUD forever.
    if bss && @sprites.is_a?(Hash)
      @bss_cinematic_hud_saved ||= {}
      @sprites.each do |key,sp|
        next unless bss_cinematic_hud_sprite?(key)
        next unless sp && !(sp.disposed? rescue true) && sp.respond_to?(:visible)
        @bss_cinematic_hud_saved[key]=sp.visible unless @bss_cinematic_hud_saved.key?(key)
      end
    end
    result=super
    if bss
      bss_cinematic_hud_hide!
      bss_cinematic_tone_refresh!
    end
    result
  end

  def pbToggleDataboxes(*args,&block)
    result=super
    bss_cinematic_hud_hide! if @bss_dialogue_cinema_active
    result
  end

  def pbForceEndSpeech(*args,&block)
    result=super
    if @bss_dialogue_cinema_active
      # Only restore coordinates saved before this speech. Trainer visibility
      # remains owned by DBK/Essentials (e.g., it can legitimately disappear).
      (@bss_cinematic_trainer_home || {}).each do |name,xy|
        sp=@sprites[name] rescue nil
        next unless sp && !(sp.disposed? rescue true)
        sp.x=xy[0] if sp.respond_to?(:x=)
        sp.y=xy[1] if sp.respond_to?(:y=)
      end
      @bss_cinematic_trainer_home=nil
      @bss_dialogue_cinema_active=false
      bss_cinematic_hud_release!
      bss_cinematic_tone_refresh!
    end
    result
  end

  def pbUpdate(*args,&block)
    result=super
    if bss_visibility_active?
      want=@bss_dialogue_cinema_active ? 1.0 : 0.0
      have=@bss_dialogue_dim_alpha.to_f
      if (want-have).abs>0.002
        step=1.0/13.0
        @bss_dialogue_dim_alpha= want>have ? [have+step,want].min : [have-step,want].max
        bss_cinematic_tone_refresh!
      end
    end
    if @bss_pending_visibility_restore && !@bss070_ebdx_bas_frame &&
       @bss_camera_attack_phase_depth.to_i==0 && !@bss_nds_intro_active
      indices=@bss_pending_visibility_restore==:all ? nil : @bss_pending_visibility_restore
      bss_recover_active_battlers_after_sendout(indices)
      @bss_pending_visibility_frames=@bss_pending_visibility_frames.to_i-1
      if @bss_pending_visibility_frames<=0
        @bss_pending_visibility_restore=nil
        @bss_pending_visibility_frames=0
      end
    end
    bss_cinematic_hud_hide! if @bss_dialogue_cinema_active
    if !@bss_dialogue_cinema_active && @bss_cinematic_hud_fade && @sprites
      @bss_cinematic_hud_fade.keys.each do |key|
        sp=@sprites[key]
        row=@bss_cinematic_hud_fade[key]
        if !sp || (sp.disposed? rescue true) || !row
          @bss_cinematic_hud_fade.delete(key)
          next
        end
        row[0]+=1
        t=[[row[0].to_f/[row[2],1].max,1.0].min,0.0].max
        sp.opacity=(row[1]*t*t*(3.0-2.0*t)).round if sp.respond_to?(:opacity=)
        @bss_cinematic_hud_fade.delete(key) if row[0]>=row[2]
      end
    end
    result
  end
end

if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSSSceneVisibilityAndHud)
  Battle::Scene.prepend(BSSSceneVisibilityAndHud)
end

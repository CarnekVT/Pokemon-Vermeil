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

  def bss_recover_active_battlers_after_sendout
    return unless bss_visibility_active? && @sprites.is_a?(Hash) && @battle
    return if @bss070_ebdx_bas_frame || @bas_runtime_playback_depth.to_i>0
    return if @bss_camera_attack_phase_depth.to_i>0
    room=@bss070_ebdx_room
    @battle.battlers.each do |bat|
      next unless bat && !(bat.fainted? rescue true)
      i=bat.index
      sprite=@sprites["pokemon_#{i}"]
      next unless sprite && !(sprite.disposed? rescue true)
      loaded=(!sprite.respond_to?(:bitmap) || !!sprite.bitmap)
      loaded ||= !!(sprite.iconBitmap rescue nil)
      next unless loaded
      # Only called at completed sendout and before the first command menu;
      # faint, substitute and move animations are never affected here.
      sprite.visible=true if sprite.respond_to?(:visible=)
      sprite.opacity=255 if sprite.respond_to?(:opacity=) && sprite.opacity.to_i==0
      shadow=@sprites["shadow_#{i}"]
      enabled=(!room || !room.respond_to?(:shadows_enabled?) || room.shadows_enabled?)
      if enabled && shadow && !(shadow.disposed? rescue true) && (shadow.bitmap rescue nil)
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
    bss_recover_active_battlers_after_sendout
    result
  end

  def pbCommandMenu(*args,&block)
    if bss_visibility_active? && !@bss_first_command_visibility_recovered
      @bss_first_command_visibility_recovered=true
      bss_recover_active_battlers_after_sendout
    end
    super
  end

  def bss_cinematic_hud_sprite?(key)
    !!(key.to_s =~ /\A(?:dataBox_|boss.*(?:hud|bar|box)|totem.*(?:hud|bar|box)|raid.*(?:hud|bar|box))/i)
  end

  def bss_cinematic_hud_hide!
    return unless @bss_dialogue_cinema_active && @sprites.is_a?(Hash)
    @bss_cinematic_hud_saved ||= {}
    @sprites.each do |key,sp|
      next unless bss_cinematic_hud_sprite?(key)
      next unless sp && !(sp.disposed? rescue true) && sp.respond_to?(:visible)
      @bss_cinematic_hud_saved[key]=sp.visible unless @bss_cinematic_hud_saved.key?(key)
      sp.visible=false if sp.respond_to?(:visible=)
    end
  end

  def bss_cinematic_hud_release!
    saved=@bss_cinematic_hud_saved
    @bss_cinematic_hud_saved=nil
    return unless saved && @sprites.is_a?(Hash)
    saved.each do |key,was_visible|
      sp=@sprites[key]
      sp.visible=was_visible if sp && !(sp.disposed? rescue true) && sp.respond_to?(:visible=)
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
    bss_cinematic_hud_hide! if @bss_dialogue_cinema_active
    result
  end
end

if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSSSceneVisibilityAndHud)
  Battle::Scene.prepend(BSSSceneVisibilityAndHud)
end

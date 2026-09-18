#===============================================================================
# Battle Scene Studio v0.8.2
# Final fixes for EBDX overscan/sendout projection, SOS isolation, custom scene
# JSON normalization, Enhanced UI Z authority and Intro Studio context mapping.
#===============================================================================
module BSS080
  VERSION = "0.8.2"
  module_function

  def normalize_scene_value(value, depth=0)
    case value
    when Hash
      out={}
      value.each do |k,v|
        key = depth == 0 ? k.to_s : (k.is_a?(String) ? k.to_sym : k)
        out[key]=normalize_scene_value(v, depth+1)
      end
      out
    when Array
      value.map { |v| normalize_scene_value(v, depth+1) }
    else
      value
    end
  end

  def intro_config
    raw=(defined?(BSS070EBDXCore) ? BSS070EBDXCore.global_config["ebdxIntro"] : nil) rescue nil
    raw={} if !raw.is_a?(Hash)
    d={
      "biomeSource"=>"auto",
      "encounterMappings"=>{"Land"=>"Grass","Cave"=>"Cave","Water"=>"Water","Fishing"=>"Water"},
      "mapOverrides"=>{}
    }
    raw.each { |k,v| d[k.to_s]=v }
    d["encounterMappings"]={} if !d["encounterMappings"].is_a?(Hash)
    d["mapOverrides"]={} if !d["mapOverrides"].is_a?(Hash)
    d
  rescue
    {"biomeSource"=>"auto","encounterMappings"=>{"Land"=>"Grass","Cave"=>"Cave","Water"=>"Water","Fishing"=>"Water"},"mapOverrides"=>{}}
  end

  def normalize_intro_kind(v)
    s=v.to_s.strip.downcase
    return "Water" if s.include?("water") || s.include?("surf") || s.include?("fish")
    return "Cave" if s.include?("cave")
    "Grass"
  end

  def encounter_type_tokens
    raw=nil
    begin
      raw=$game_temp.encounter_type if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:encounter_type)
    rescue
    end
    vals=[raw]
    begin
      if raw && defined?(GameData::EncounterType)
        data=GameData::EncounterType.get(raw) rescue nil
        vals << data.id if data && data.respond_to?(:id)
        vals << data.type if data && data.respond_to?(:type)
        vals << data.name if data && data.respond_to?(:name)
      end
    rescue
    end
    vals.compact.map { |x| x.to_s }
  end

  def encounter_intro_kind
    cfg=intro_config
    map=cfg["encounterMappings"] || {}
    tokens=encounter_type_tokens
    joined=tokens.join(" ").downcase
    bucket = if joined.include?("fish")
      "Fishing"
    elsif joined.include?("cave")
      "Cave"
    elsif joined.include?("water") || joined.include?("surf") || joined.include?("dive")
      "Water"
    else
      "Land"
    end
    normalize_intro_kind(map[bucket] || map[bucket.to_sym] || bucket)
  rescue
    "Grass"
  end

  def map_intro_kind
    cfg=intro_config
    id=if defined?($game_map) && $game_map && $game_map.respond_to?(:map_id) then $game_map.map_id.to_i else 0 end
    row=(cfg["mapOverrides"] || {})[id.to_s] || (cfg["mapOverrides"] || {})[id]
    return nil if row.nil? || row.to_s.strip.empty?
    normalize_intro_kind(row)
  rescue
    nil
  end
end

# scenes.json uses String keys; source-faithful EBDX expects String top-level
# scene blocks but Symbol parameter keys inside img/tree/etc hashes.
module BSS080SceneJSONNormalization
  def custom_environment(name)
    data=super
    data.is_a?(Hash) ? BSS080.normalize_scene_value(data,0) : data
  end
end
begin
  BSS070EBDXCore.singleton_class.prepend(BSS080SceneJSONNormalization) if defined?(BSS070EBDXCore) && !BSS070EBDXCore.singleton_class.ancestors.include?(BSS080SceneJSONNormalization)
rescue => e
  BSS064.log("BSS080 scene JSON install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

# New metric anchors created after pbChangePokemon/SOS inherit the same overscan
# translation already applied to the room and its authored elements.
module BSS080OverscanAnchorAuthority
  def adjustMetrics
    ret=super
    # refresh() rebuilds the room before BSS078 applies overscan.  Only translate
    # newly rebuilt metric anchors here when the *current* room bitmap is already
    # overscanned; otherwise BSS078RoomOverscan will translate them once later.
    bg=@sprites["bg"] rescue nil
    already_overscanned=bg && bg.instance_variable_get(:@bss078_overscanned)
    px=@bss078_pad_x.to_f; py=@bss078_pad_y.to_f
    if already_overscanned && (px != 0.0 || py != 0.0)
      @sprites.each do |key,sp|
        next if !sp || !(key.start_with?("battler") || key.start_with?("shadow") || key.start_with?("trainer_"))
        begin
          sp.ex=sp.ex.to_f+px if sp.respond_to?(:ex) && sp.respond_to?(:ex=) && !sp.ex.nil?
          sp.ey=sp.ey.to_f+py if sp.respond_to?(:ey) && sp.respond_to?(:ey=) && !sp.ey.nil?
        rescue
        end
      end
    end
    ret
  end

  def drawImg(key)
    ret=super
    begin
      data=@data[key]
      if data.is_a?(Hash) && (data[:colorize] || data["colorize"]).to_s.downcase=="slight"
        sp=@sprites[key]
        setColor(@sprites["bg"],sp,"slight") if sp
        sp.memorize_bitmap if sp && sp.respond_to?(:memorize_bitmap)
      end
    rescue
    end
    ret
  end
end
begin
  BSS070EBDXRoom.prepend(BSS080OverscanAnchorAuthority) if defined?(BSS070EBDXRoom) && !BSS070EBDXRoom.ancestors.include?(BSS080OverscanAnchorAuthority)
rescue => e
  BSS064.log("BSS080 overscan install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

module BSS080SceneAuthority
  def bss070_ebdx_snap_animation_baseline(vector_key=:MAIN)
    # Respect the source-faithful SENDOUT/ENEMY/SOS vector requested by the
    # caller.  v0.8.1 forced every ball sequence to MAIN and made battlers travel
    # toward the wrong coordinate system.
    super(vector_key)
  end

  # Immediately reproject after DBK/Animated Pokemon has loaded/rebuilt its
  # bitmap. Ball animations created on the next line therefore read EBDX coords.
  def pbChangePokemon(*args,&block)
    result=super
    if respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
      begin
        raw=args[0]
        idx = if raw.respond_to?(:index)
                raw.index
              elsif raw.is_a?(Numeric)
                raw.to_i
              else
                nil
              end
        if !idx.nil?
          bss070_ebdx_invalidate_anchors if respond_to?(:bss070_ebdx_invalidate_anchors)
          bss070_ebdx_recalibrate_if_needed if respond_to?(:bss070_ebdx_recalibrate_if_needed)
          room=@bss070_ebdx_room rescue nil
          if room && !(room.disposed? rescue true)
            room.update rescue nil
            sp=bss070_ebdx_native_sprite(idx) rescue nil
            anchor=room.battler(idx) rescue nil
            if sp && anchor
              sp.x=anchor.x if sp.respond_to?(:x=)
              sp.y=anchor.y if sp.respond_to?(:y=)
            end
            sh=bss070_ebdx_native_shadow_sprite(idx) rescue nil
            sa=room.shadow(idx) rescue nil
            if sh && sa
              sh.x=sa.x if sh.respond_to?(:x=)
              sh.y=sa.y if sh.respond_to?(:y=)
            end
          end
        end
      rescue => e
        BSS064.log("BSS081 pbChangePokemon projection warning: #{e.class}: #{e.message}") if defined?(BSS064)
      end
    end
    result
  end


  def bss080_enforce_enhanced_ui_z
    return if !@sprites.is_a?(Hash)
    @sprites.each do |key,sp|
      next if !sp || (sp.disposed? rescue false) || !sp.respond_to?(:z=)
      k=key.to_s
      begin
        if k =~ /(info_icon|ball_icon|item_icon|pokemon_icon|enhancedUI|prompt)/i
          sp.z=[(sp.z rescue 0).to_i,96020].max
        elsif k =~ /outline/i
          # Selection outline belongs behind Enhanced UI icons, never over them.
          sp.z=[(sp.z rescue 0).to_i,95980].max
          sp.z=95980 if sp.z.to_i>96019
        end
      rescue
      end
    end
  end

  def pbUpdate(*args,&block)
    ret=super
    bss080_enforce_enhanced_ui_z
    ret
  end

  # Enhanced Legacy Data can enumerate party2 during end-of-battle cleanup and
  # assumes no nil species. Expose a compact read view only for that final call.
  def pbEndBattle(*args,&block)
    battle=@battle rescue nil
    original=nil
    if battle && battle.instance_variable_defined?(:@party2)
      p2=battle.instance_variable_get(:@party2) rescue nil
      if p2.is_a?(Array) && p2.any?(&:nil?)
        original=p2
        battle.instance_variable_set(:@party2,p2.compact)
      end
    end
    super
  ensure
    battle.instance_variable_set(:@party2,original) if battle && original
  end

  def bss_pbSOSJoin(*args,&block)
    ret=super
    ret
  ensure
    battle=@battle rescue nil
    if battle && !(defined?(BSS078) && BSS078.true_boss?(battle))
      begin; bss073_repair_sos_databoxes(args[0],true) if respond_to?(:bss073_repair_sos_databoxes); rescue; end
      begin
        (@sprites || {}).each do |key,box|
          next if !key.to_s.start_with?("dataBox_") || !box
          box.bss654_clear_layout_override if box.respond_to?(:bss654_clear_layout_override)
        end
      rescue
      end
    end
  end

  # Intro source can be automatic, the real Essentials encounter type, a Map-ID
  # override or the selected EBDX scene. Encounter data comes from $game_temp and
  # GameData::EncounterType, not from surfing heuristics alone.
  def bss078_wild_intro_kind
    cfg=BSS080.intro_config
    source=cfg["biomeSource"].to_s.downcase
    mapped=BSS080.map_intro_kind
    case source
    when "map"
      return mapped || BSS080.encounter_intro_kind
    when "encounter"
      return BSS080.encounter_intro_kind
    when "ebdx"
      env=BSS070EBDXCore.environment_for(self) rescue {}
      bg=env.is_a?(Hash) ? (env["backdrop"] || env[:backdrop]).to_s : ""
      return BSS080.normalize_intro_kind(bg)
    else
      return mapped if mapped
      tokens=BSS080.encounter_type_tokens
      return BSS080.encounter_intro_kind if !tokens.empty?
      env=BSS070EBDXCore.environment_for(self) rescue {}
      bg=env.is_a?(Hash) ? (env["backdrop"] || env[:backdrop]).to_s : ""
      return BSS080.normalize_intro_kind(bg)
    end
  rescue
    super
  end

  # WildIntroNDS compatibility. The original implementation owns its reveal;
  # BSS only supplies the live EBDX world underneath it.
  def pbBattleIntroAnimation
    wild=@battle && @battle.respond_to?(:wildBattle?) && @battle.wildBattle?
    return super if !wild
    ebdx=respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    cfg=bss079_intro_config
    return super if !ebdx && cfg["useInVanilla"] != true
    bss070_ebdx_ensure_core if ebdx && respond_to?(:bss070_ebdx_ensure_core)

    if defined?(VermeilWildIntroNDS) && defined?(Battle::Scene::Animation::WildIntroReveal)
      size=(@battle.sideSizes[1] rescue 1).to_i
      size=1 if size<1
      size.times do |i|
        idx=(2*i)+1
        sp=@sprites["pokemon_#{idx}"] rescue nil
        sp.visible=false if sp && sp.respond_to?(:visible=)
      end
      reveal=Battle::Scene::Animation::WildIntroReveal.new(@sprites,@viewport,size,@battle.battlers,@battle)
      @animations.push(reveal)
      wait=(VermeilWildIntroNDS.reveal_wait_frames rescue 20).to_i
      wait=20 if wait<20
      wait.times { pbUpdate }
      bss079_finish_wild_intro
      return
    end

    bss079_play_custom_wild_intro(ebdx)
    bss079_finish_wild_intro
  rescue => e
    BSS064.log("BSS081 intro warning: #{e.class}: #{e.message}") if defined?(BSS064)
    super
  end

end
begin
  Battle::Scene.prepend(BSS080SceneAuthority) if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS080SceneAuthority)
rescue => e
  BSS064.log("BSS080 scene authority install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

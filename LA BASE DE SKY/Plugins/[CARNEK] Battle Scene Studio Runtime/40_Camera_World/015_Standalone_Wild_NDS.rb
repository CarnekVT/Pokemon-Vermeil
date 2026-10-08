#===============================================================================
# Battle Scene Studio v0.8.3
# Standalone Wild NDS intro.
#
# This transition is deliberately NOT an EBDX room animation. It snapshots the
# already composed battle world, runs on an isolated viewport, and disposes that
# viewport before returning control to the live scene. It never replaces
# battle_bg/base sprites and never writes the EBDX camera vector.
#===============================================================================
module BSS083StandaloneWildNDS
  HOLD = 8
  MOVE = 12
  REVEAL = 4
  FADE = 8
  module_function

  def enabled?(scene)
    battle = scene.instance_variable_get(:@battle) rescue nil
    return false if !battle || !(battle.wildBattle? rescue false)
    if defined?(VermeilWildIntroNDS)
      return false unless (VermeilWildIntroNDS.enabled? rescue true)
      return true
    end
    # Intro Studio/BSS fallback: the standalone transition is also the safe EBDX
    # wild intro when the separate Vermeil script is not installed.
    scene.respond_to?(:bss070_ebdx_active?) && scene.bss070_ebdx_active?
  rescue
    false
  end
end

module BSS083StandaloneWildNDSScene
  def bss083_nds_intro_config
    if defined?(VermeilWildIntroNDS) && VermeilWildIntroNDS.respond_to?(:intro_config_for)
      cfg = VermeilWildIntroNDS.intro_config_for(@battle) rescue nil
      return cfg if cfg.is_a?(Hash)
    end
    cfg = respond_to?(:bss079_intro_config) ? (bss079_intro_config rescue {}) : {}
    cfg = {} if !cfg.is_a?(Hash)
    {
      :visual => (respond_to?(:bss078_wild_intro_asset) ? (bss078_wild_intro_asset rescue nil) : nil),
      :se => nil,
      :drift => [(cfg["driftX"] || -6).to_f, (cfg["driftY"] || 2).to_f]
    }
  rescue
    { :visual => nil, :se => nil, :drift => [-6, 2] }
  end

  def bss083_nds_foe_rows
    rows = []
    size = (@battle.sideSizes[1] rescue 1).to_i
    size = 1 if size < 1
    size.times do |i|
      idx = i * 2 + 1
      sp = @sprites["pokemon_#{idx}"] rescue nil
      sh = @sprites["shadow_#{idx}"] rescue nil
      next if !sp || (sp.disposed? rescue true)
      # WildIntroNDS should never inherit a silhouette tone left by a previous
      # intro layer. Start and finish from the real battler's neutral coloration.
      begin; sp.tone = Tone.new(0, 0, 0, 0) if sp.respond_to?(:tone=); rescue; end
      rows << [idx, sp, sh]
    end
    rows
  end

  def bss083_nds_world_snapshot(foes)
    return nil if !defined?(Graphics) || !Graphics.respond_to?(:snap_to_bitmap)
    hidden = []
    (@sprites || {}).each do |key, sp|
      next if !sp || (sp.disposed? rescue false) || !sp.respond_to?(:visible)
      k = key.to_s
      # The EBDX room itself is the world and remains visible. Native battle_bg/
      # bases are hidden by BSS already. Snapshot only scenery, never battlers/UI.
      keep = (k == "battlebg")
      next if keep
      if k =~ /^(pokemon_|shadow_|dataBox_|trainer_|party|cmdBar|command|fight|target|message|enhanced|info_icon|ball_icon|leftarrow|rightarrow|boss|ability|itemWindow)/i ||
         k =~ /_outline\d+$/i
        begin
          hidden << [sp, sp.visible]
          sp.visible = false if sp.respond_to?(:visible=)
        rescue
        end
      end
    end
    Graphics.snap_to_bitmap
  ensure
    hidden.each do |sp, vis|
      begin; sp.visible = vis if sp && !(sp.disposed? rescue true) && sp.respond_to?(:visible=); rescue; end
    end if hidden
  end

  def bss083_nds_copy_sprite(src, viewport, z)
    return nil if !src || (src.disposed? rescue true)
    out = Sprite.new(viewport)
    out.bitmap = src.bitmap if src.respond_to?(:bitmap)
    if out.bitmap && src.respond_to?(:src_rect) && src.src_rect
      out.src_rect.set(src.src_rect.x, src.src_rect.y, src.src_rect.width, src.src_rect.height) rescue nil
    end
    out.x = src.x; out.y = src.y
    out.ox = src.ox; out.oy = src.oy
    out.zoom_x = src.zoom_x; out.zoom_y = src.zoom_y
    out.mirror = src.mirror if out.respond_to?(:mirror=) && src.respond_to?(:mirror)
    out.angle = src.angle if out.respond_to?(:angle=) && src.respond_to?(:angle)
    out.opacity = 0
    out.tone = Tone.new(0, 0, 0, 0) if out.respond_to?(:tone=)
    out.color = Color.new(0, 0, 0, 0) if out.respond_to?(:color=)
    out.z = z
    out
  rescue
    nil
  end

  def bss083_nds_play_se(se)
    return if !se
    if se.is_a?(Array)
      pbSEPlay(se[0], (se[1] || 100), (se[2] || 100)) rescue nil
    else
      pbSEPlay(se) rescue nil
    end
  end

  def bss083_nds_play_cry(idx)
    b = @battle.battlers[idx] rescue nil
    return if !b
    if b.respond_to?(:pokemon) && b.pokemon
      b.pokemon.play_cry rescue nil
    elsif b.respond_to?(:pbPlayCry)
      b.pbPlayCry rescue nil
    end
  end

  def bss083_run_standalone_wild_nds
    foes = bss083_nds_foe_rows
    return false if foes.empty?
    snap = bss083_nds_world_snapshot(foes)
    return false if !snap

    @bss083_standalone_intro = true
    begin; bss083_hide_enhanced_aux if respond_to?(:bss083_hide_enhanced_aux); rescue; end

    vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
    vp.z = 999_000 if vp.respond_to?(:z=)
    temp = []
    begin
      center_x = Graphics.width / 2.0
      center_y = Graphics.height / 2.0
      first = foes[0][1]
      focus_x = (first.x rescue Graphics.width * 0.75).to_f
      focus_y = (first.y rescue Graphics.height * 0.42).to_f
      zoom_start = 2.0

      bg = Sprite.new(vp)
      bg.bitmap = snap
      bg.ox = snap.width / 2
      bg.oy = snap.height / 2
      bg.x = center_x + (center_x - focus_x) * zoom_start
      bg.y = center_y + (center_y - focus_y) * zoom_start
      bg.zoom_x = zoom_start
      bg.zoom_y = zoom_start
      bg.z = 0
      temp << bg

      foe_temp = []
      foes.each_with_index do |row, i|
        idx, src, sh = row
        cp = bss083_nds_copy_sprite(src, vp, 100 + i)
        next if !cp
        ex = src.x.to_f; ey = src.y.to_f
        cp.x = center_x + (ex - focus_x) * zoom_start
        cp.y = center_y + (ey - focus_y) * zoom_start
        cp.zoom_x = src.zoom_x.to_f * zoom_start
        cp.zoom_y = src.zoom_y.to_f * zoom_start
        foe_temp << [idx, src, cp, ex, ey, src.zoom_x.to_f, src.zoom_y.to_f]
        temp << cp
      end

      cfg = bss083_nds_intro_config
      intro = nil
      visual = cfg[:visual] || cfg["visual"]
      if visual && (pbResolveBitmap(visual) rescue false)
        intro = Sprite.new(vp)
        intro.bitmap = pbBitmap(visual)
        scale = [Graphics.width.to_f / [intro.bitmap.width, 1].max, Graphics.height.to_f / [intro.bitmap.height, 1].max].max
        intro.zoom_x = scale; intro.zoom_y = scale
        intro.x = 0; intro.y = 0; intro.z = 800
        intro.opacity = 255
        temp << intro
      end
      bss083_nds_play_se(cfg[:se] || cfg["se"])
      drift = cfg[:drift] || cfg["drift"] || [-6, 2]
      dx = drift[0].to_f; dy = drift[1].to_f

      black = Sprite.new(vp)
      black.bitmap = Bitmap.new(1, 1)
      black.bitmap.fill_rect(0, 0, 1, 1, Color.new(0, 0, 0))
      black.zoom_x = Graphics.width; black.zoom_y = Graphics.height
      black.opacity = 255; black.z = 1000
      temp << black

      white = Sprite.new(vp)
      white.bitmap = Bitmap.new(1, 1)
      white.bitmap.fill_rect(0, 0, 1, 1, Color.new(255, 255, 255))
      white.zoom_x = Graphics.width; white.zoom_y = Graphics.height
      white.opacity = 0; white.z = 950
      temp << white

      total = BSS083StandaloneWildNDS::HOLD + BSS083StandaloneWildNDS::MOVE
      zoom_frames = [(BSS083StandaloneWildNDS::MOVE / BSS083StandaloneWildNDS::REVEAL.to_f).round, 1].max
      cried = false
      total.times do |f|
        # Black opening fades independently from the zoom/reveal.
        if f < BSS083StandaloneWildNDS::FADE
          black.opacity = (255 * (1.0 - (f + 1).to_f / BSS083StandaloneWildNDS::FADE)).round
        else
          black.opacity = 0
        end

        if intro
          intro.x += dx
          intro.y += (f >= BSS083StandaloneWildNDS::HOLD ? dy : 0)
          if f >= BSS083StandaloneWildNDS::HOLD
            p = (f - BSS083StandaloneWildNDS::HOLD + 1).to_f / BSS083StandaloneWildNDS::MOVE
            intro.opacity = (255 * (1.0 - [p / 0.65, 1.0].min)).round
          end
        end

        if f >= BSS083StandaloneWildNDS::HOLD
          local = f - BSS083StandaloneWildNDS::HOLD + 1
          zt = [local.to_f / zoom_frames, 1.0].min
          ease = 1.0 - (1.0 - zt) * (1.0 - zt)
          bg.x = (center_x + (center_x - focus_x) * zoom_start) + (center_x - (center_x + (center_x - focus_x) * zoom_start)) * ease
          bg.y = (center_y + (center_y - focus_y) * zoom_start) + (center_y - (center_y + (center_y - focus_y) * zoom_start)) * ease
          bg.zoom_x = zoom_start + (1.0 - zoom_start) * ease
          bg.zoom_y = bg.zoom_x
          foe_temp.each do |idx, src, cp, ex, ey, ezx, ezy|
            sx = center_x + (ex - focus_x) * zoom_start
            sy = center_y + (ey - focus_y) * zoom_start
            cp.x = sx + (ex - sx) * ease
            cp.y = sy + (ey - sy) * ease
            cp.zoom_x = ezx * (zoom_start + (1.0 - zoom_start) * ease)
            cp.zoom_y = ezy * (zoom_start + (1.0 - zoom_start) * ease)
            rp = [local.to_f / BSS083StandaloneWildNDS::REVEAL, 1.0].min
            cp.opacity = (255 * rp).round
          end
          if !cried
            bss083_nds_play_cry(foe_temp[0][0]) if foe_temp[0]
            cried = true
          end
          # White pop follows the original NDS-style reveal timing.
          if local <= 2
            white.opacity = (160 * local / 2.0).round
          elsif local <= 8
            white.opacity = (160 * (1.0 - (local - 2).to_f / 6.0)).round
          else
            white.opacity = 0
          end
        end

        Graphics.update
        Input.update if defined?(Input) && Input.respond_to?(:update)
      end

      # Normalize the real foes before the isolated viewport is removed. The
      # viewer never sees an intermediate black/silhouette frame.
      foes.each do |idx, src, sh|
        begin
          src.visible = true if src.respond_to?(:visible=)
          src.opacity = 255 if src.respond_to?(:opacity=)
          src.tone = Tone.new(0, 0, 0, 0) if src.respond_to?(:tone=)
        rescue
        end
      end
      true
    ensure
      temp.reverse_each do |sp|
        begin
          # Only the 1x1 black/white bitmaps and the snap are owned by this intro.
          if sp && sp.bitmap && sp.bitmap.width == 1 && sp.bitmap.height == 1
            sp.bitmap.dispose unless sp.bitmap.disposed? rescue nil
          end
          sp.dispose if sp && !(sp.disposed? rescue true)
        rescue
        end
      end
      begin; snap.dispose if snap && !(snap.disposed? rescue true); rescue; end
      begin; vp.dispose if vp && !(vp.disposed? rescue true); rescue; end
      @bss083_standalone_intro = false
    end
  rescue => e
    @bss083_standalone_intro = false
    BSS064.log("BSS083 standalone Wild NDS warning: #{e.class}: #{e.message}") if defined?(BSS064)
    false
  end

  def pbBattleIntroAnimation
    return super unless BSS083StandaloneWildNDS.enabled?(self)
    # Do not call the old BSS/EBDX WildIntroReveal chain. The standalone intro is
    # a full replacement for wild encounters and has no dependency on EBDX.
    if bss083_run_standalone_wild_nds
      bss079_finish_wild_intro if respond_to?(:bss079_finish_wild_intro)
      return
    end
    super
  end
end

begin
  Battle::Scene.prepend(BSS083StandaloneWildNDSScene) if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS083StandaloneWildNDSScene)
rescue => e
  BSS064.log("BSS083 standalone Wild NDS install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

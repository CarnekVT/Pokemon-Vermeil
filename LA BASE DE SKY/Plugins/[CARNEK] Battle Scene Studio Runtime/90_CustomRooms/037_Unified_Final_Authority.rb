#===============================================================================
# Battle Scene Studio v1.1.0 - Unified Final Authority
#
# Solves:
# 1. BAS-style approach & zoom camera transitions (Command/Fight menus).
# 2. Complete enforcement of Settings (DISABLE_SLIDING_*, SHOW_BATTLE_BASES).
# 3. Fixes SOS caller/battlers sinking down upon SOS call.
# 4. Universal custom/EBDX background & base asset resolution.
#===============================================================================

module BSSUnified
  module_function

  def resolve_bitmap(name, folders = [])
    return nil if name.nil? || name.to_s.strip.empty?
    str = name.to_s.strip

    # Direct resolve
    return str if pbResolveBitmap(str)

    # Search folders
    folders.each do |folder|
      f = folder.chomp("/")
      ["", ".png", ".jpg", ".bmp"].each do |ext|
        p1 = "#{f}/#{str}#{ext}"
        return p1 if pbResolveBitmap(p1)
      end
    end
    nil
  end

  def resolve_background_bitmap(name)
    resolve_bitmap(name, [
      "Graphics/BattleSceneStudio/EBDX/Battlebacks/battlebg",
      "Graphics/Battlebacks",
      "Graphics/BattleSceneStudio/EBDX/SceneAssets",
      "Graphics/Pictures",
      "Graphics"
    ]) || resolve_bitmap("#{name}_bg", ["Graphics/Battlebacks"])
  end

  def resolve_base_bitmap(name)
    resolve_bitmap(name, [
      "Graphics/BattleSceneStudio/EBDX/Battlebacks/base",
      "Graphics/Battlebacks",
      "Graphics"
    ]) || resolve_bitmap("#{name}_base0", ["Graphics/Battlebacks"])
  end

  def sliding_bg_disabled?
    return Settings.disable_sliding_background? if Settings.respond_to?(:disable_sliding_background?)
    defined?(Settings::DISABLE_SLIDING_BACKGROUND) && Settings::DISABLE_SLIDING_BACKGROUND
  end

  def sliding_sprites_disabled?
    return Settings.disable_sliding_sprites? if Settings.respond_to?(:disable_sliding_sprites?)
    defined?(Settings::DISABLE_SLIDING_SPRITES) && Settings::DISABLE_SLIDING_SPRITES
  end

  def sliding_bases_disabled?
    return Settings.disable_sliding_bases? if Settings.respond_to?(:disable_sliding_bases?)
    defined?(Settings::DISABLE_SLIDING_BASES) && Settings::DISABLE_SLIDING_BASES
  end

  def show_battle_bases?
    return Settings.show_battle_bases? if Settings.respond_to?(:show_battle_bases?)
    return Settings::SHOW_BATTLE_BASES if defined?(Settings::SHOW_BATTLE_BASES)
    true
  end

  def camera_approach_enabled?
    return Settings.camera_approach_enabled? if Settings.respond_to?(:camera_approach_enabled?)
    return Settings::ENABLE_CAMERA_APPROACH if defined?(Settings::ENABLE_CAMERA_APPROACH)
    true
  end

  def dynamic_camera_enabled?
    return Settings.dynamic_camera_enabled? if Settings.respond_to?(:dynamic_camera_enabled?)
    return Settings::DYNAMIC_CAMERA_ON if defined?(Settings::DYNAMIC_CAMERA_ON)
    true
  end

  def zoom_level(key = :default)
    return Settings.zoom_level(key) if Settings.respond_to?(:zoom_level)
    case key
    when :strong then 1.35
    when :sos    then 1.15
    else              1.25
    end
  end
end

#-------------------------------------------------------------------------------
# 1. SETTINGS AUTHORITY: Enforce Sliding & Base visibility in Intro animations
#-------------------------------------------------------------------------------
if defined?(Battle::Scene::Animation::Intro)
  class Battle::Scene::Animation::Intro < Battle::Scene::Animation
    def createProcesses
      appearTime = 20
      # Background slide control
      if @sprites["battle_bg2"] && !BSSUnified.sliding_bg_disabled?
        makeSlideSprite("battle_bg", 0.5, appearTime)
        makeSlideSprite("battle_bg2", 0.5, appearTime)
      end
      # Bases slide & display control
      if BSSUnified.show_battle_bases? && !BSSUnified.sliding_bases_disabled?
        makeSlideSprite("base_0", 1, appearTime, PictureOrigin::BOTTOM)
        makeSlideSprite("base_1", -1, appearTime, PictureOrigin::CENTER)
      end
      # Sprites slide control
      if !BSSUnified.sliding_sprites_disabled?
        @battle.player.each_with_index do |_p, i|
          makeSlideSprite("player_#{i + 1}", 1, appearTime, PictureOrigin::BOTTOM)
        end
        if @battle.trainerBattle?
          @battle.opponent.each_with_index do |_p, i|
            makeSlideSprite("trainer_#{i + 1}", -1, appearTime, PictureOrigin::BOTTOM)
          end
        else
          @battle.pbParty(1).each_with_index do |_pkmn, i|
            idxBattler = (2 * i) + 1
            makeSlideSprite("pokemon_#{idxBattler}", -1, appearTime, PictureOrigin::BOTTOM)
          end
        end
        @battle.battlers.length.times do |i|
          makeSlideSprite("shadow_#{i}", (i.even?) ? 1 : -1, appearTime, PictureOrigin::CENTER)
        end
      end
      # Black screen fades
      black_bg = pbResolveBitmap("Graphics/Battle animations/Screens/black") ? "Graphics/Battle animations/Screens/black" : "Graphics/Battle animations/black_screen"
      blackScreen = addNewSprite(0, 0, black_bg)
      blackScreen.setZ(0, 99999)
      blackScreen.moveOpacity(0, 8, 0)
      if @sprites["cmdBar_bg"]
        black_bar = pbResolveBitmap("Graphics/Battle animations/Screens/black_bar") ? "Graphics/Battle animations/Screens/black_bar" : "Graphics/Battle animations/black_bar"
        blackBar = addNewSprite(@sprites["cmdBar_bg"].x, @sprites["cmdBar_bg"].y, black_bar)
        blackBar.setZ(0, 99998)
        blackBar.moveOpacity(appearTime * 3 / 4, appearTime / 4, 0)
      end
    end
  end
end

# Hide bases and extra sliding background if configured
module BSSUnifiedBackdropControl
  def pbCreateBackdropSprites(*args)
    super(*args)
    BSSZBoxFondosEBDXVanilla.install(self) if defined?(BSSZBoxFondosEBDXVanilla)
    if BSSUnified.sliding_bg_disabled? && @sprites["battle_bg2"]
      @sprites["battle_bg2"].visible = false
      @sprites["battle_bg2"].dispose rescue nil
      @sprites.delete("battle_bg2")
    end
    if !BSSUnified.show_battle_bases?
      ["base_0", "base_1"].each do |k|
        if @sprites[k]
          @sprites[k].visible = false
          @sprites[k].dispose rescue nil
          @sprites.delete(k)
        end
      end
    end
  end
end

#-------------------------------------------------------------------------------
# 2. CAMERA AUTHORITY: BAS-style Approximations, Zooms & Idle Motion
#-------------------------------------------------------------------------------
module BSSUnifiedCameraAuthority
  def bss_unified_camera_to(mode, idxBattler = nil)
    return unless @vector

    case mode.to_s.downcase.to_sym
    when :command
      @bss083_camera_state = :command
      @bss070_ebdx_camera_mode = :command
      zoom = BSSUnified.zoom_level(:default)
      shot = (BSS083.camera_shot(:player, @battle) rescue nil) || (BSS070EBDXCore.get_vector(:MAIN, @battle) rescue [102, 408, 32, 342, 1, 1])
      target = shot.clone
      target[4] = zoom.to_f if target.size >= 5
      target[5] = zoom.to_f if target.size >= 6
      @vector.inc = 0.032
      @vector.set(target)
    when :fight
      @bss083_camera_state = :fight
      @bss070_ebdx_camera_mode = :fight
      zoom = BSSUnified.zoom_level(:strong)
      shot = (BSS083.camera_shot(:player, @battle) rescue nil) || (BSS070EBDXCore.get_vector(:MAIN, @battle) rescue [102, 408, 32, 342, 1, 1])
      target = shot.clone
      target[4] = zoom.to_f if target.size >= 5
      target[5] = zoom.to_f if target.size >= 6
      @vector.inc = 0.036
      @vector.set(target)
    when :main, :idle, :overview
      @bss083_camera_state = :idle
      @bss070_ebdx_camera_mode = :idle
      main = (BSS083.camera_shot(:main, @battle) rescue nil) || (BSS070EBDXCore.get_vector(:MAIN, @battle) rescue [102, 408, 32, 342, 1, 1])
      target = main.clone
      target[4] = 1.0 if target.size >= 5
      target[5] = 1.0 if target.size >= 6
      @vector.inc = 0.026
      @vector.set(target)
    end
  end

  def pbCommandMenu(idxBattler, firstAction, *args, &block)
    @bss_active_battler_idx = idxBattler
    @bss_in_command_menu = true
    if BSSUnified.dynamic_camera_enabled? && BSSUnified.camera_approach_enabled? && @vector
      bss_unified_camera_to(:command, idxBattler)
    end
    ret = super(idxBattler, firstAction, *args, &block)
    ret
  ensure
    @bss_in_command_menu = false
    if BSSUnified.dynamic_camera_enabled? && BSSUnified.camera_approach_enabled? && @vector
      if ret != 0 && !@bss_entering_fight
        bss_unified_camera_to(:main)
      end
    end
  end

  def pbFightMenu(idxBattler, *args, &block)
    @bss_active_battler_idx = idxBattler
    @bss_entering_fight = true
    if BSSUnified.dynamic_camera_enabled? && BSSUnified.camera_approach_enabled? && @vector
      bss_unified_camera_to(:fight, idxBattler)
    end
    ret = super(idxBattler, *args, &block)
    ret
  ensure
    @bss_entering_fight = false
    if BSSUnified.dynamic_camera_enabled? && BSSUnified.camera_approach_enabled? && @vector
      if ret == true
        bss_unified_camera_to(:main)
      else
        bss_unified_camera_to(:command, idxBattler)
      end
    end
  end

  def bss070_ebdx_camera_enter(mode, idxBattler = nil)
    return if !BSSUnified.dynamic_camera_enabled?
    return super(mode) if defined?(super) && !@vector
    idx = idxBattler || @bss_active_battler_idx
    bss_unified_camera_to(mode, idx)
    nil
  end

  def bss070_ebdx_camera_leave
    return if !BSSUnified.dynamic_camera_enabled?
    return if @bss_in_command_menu || @bss_entering_fight
    bss_unified_camera_to(:main)
    nil
  end

  # Ambient camera tick with smooth drift.
  # Camera behavior is spliced out (v1.2.1.1: EBDX mode = vanilla flow + EBDX
  # backgrounds only), so the vector never moves; the room keeps animating and
  # battlers keep their static MAIN anchors.
  def bss070_ebdx_tick(advance_camera = true, align = true)
    return super(advance_camera, align) if defined?(super) && !@vector

    if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
      @bss070_ebdx_room.update
    end

    bss070_ebdx_apply_world_alignment if align && respond_to?(:bss070_ebdx_apply_world_alignment)
  end
end

#-------------------------------------------------------------------------------
# 3. SOS POSITIONING: The original 002_Native_SOS animation + the single settle
# in 99_Hotfix/041_EBDX_Performance (ensure más externo) + apply_world_alignment
# are the ONLY authorities for caller/ally Y after an SOS join.
# The previous "sinking fix" here forced the caller AND its new ally onto the
# caller's pre-SOS Y, which smuggled both battlers into the same baseline. That
# caused the caller+ally stacked-Y symptom. The settle in 041 already
# recalibrates anchors with the new side_size before apply_world_alignment runs.
#-------------------------------------------------------------------------------
if defined?(Battle::Scene::Animation::BSSSOSJoin)
  class Battle::Scene::Animation::BSSSOSJoin < Battle::Scene::Animation
    alias _bss_orig_createProcesses createProcesses unless method_defined?(:_bss_orig_createProcesses)
    def createProcesses
      duration = 10
      scene = @battle.scene rescue nil
      ebdx_room = (scene && scene.respond_to?(:bss070_ebdx_active?) && scene.bss070_ebdx_active?) ? (scene.instance_variable_get(:@bss070_ebdx_room) rescue nil) : nil
      if ebdx_room && ebdx_room.respond_to?(:recalibrate_metrics!)
        ebdx_room.recalibrate_metrics! rescue nil
        ebdx_room.update rescue nil
      end

      @battle.battlers.each do |b|
        next if !b || b.opposes?(@idx_sos)
        bat = @sprites["pokemon_#{b.index}"]
        sha = @sprites["shadow_#{b.index}"]
        boxsp = @sprites["dataBox_#{b.index}"]
        next if !bat

        side_size = bat.respond_to?(:sideSize) && bat.sideSize ? bat.sideSize : @battle.pbSideSize(b.index)
        nx, ny, nz = bss_sos_battler_position(b, side_size, bat)
        sx, sy, sz = sha ? bss_sos_shadow_position(b, side_size, sha) : [nx, ny, 3]

        if ebdx_room
          anchor = ebdx_room.battler(b.index) rescue nil
          if anchor
            nx = anchor.x
            ny = anchor.y if b.index == @idx_sos
          end
          s_anchor = ebdx_room.shadow(b.index) rescue nil
          if s_anchor
            sx = s_anchor.x
            sy = s_anchor.y if b.index == @idx_sos
          end
        end

        if b.index == @idx_sos
          # Newly summoned ally: its own computed slot. (Do NOT clamp it onto the
          # caller's Y baseline; the 041 settle aligns every battler afterwards.)
          obj = addSprite(bat, PictureOrigin::BOTTOM)
          obj.setXY(0, nx, ny) if obj.respond_to?(:setXY)
          obj.setZ(0, nz) if obj.respond_to?(:setZ)
          obj.setTone(0, Tone.new(-196, -196, -196, -196))
          obj.setOpacity(0, 0)
          obj.setVisible(0, true)
          obj.moveOpacity(1, 6, 255)
          obj.moveTone(2, 8, Tone.new(0, 0, 0, 0), [bat, :pbPlayIntroAnimation])

          if sha
            sh = addSprite(sha, PictureOrigin::CENTER)
            sh.setXY(0, sx, sy)
            sh.setZ(0, sz) if sh.respond_to?(:setZ)
            sh.setOpacity(0, 0)
            sh.setVisible(0, true)
            sh.moveOpacity(2, 6, 255)
          end

          if boxsp
            mode = (BSS064.databox_animation_mode rescue "slide")
            if mode == "fade"
              bx = addSprite(boxsp)
              bx.setOpacity(0, 0)
              bx.setVisible(1, true)
              bx.moveOpacity(2, 8, 255)
            elsif mode == "pop"
              bx = addSprite(boxsp)
              bx.setOpacity(4, 255)
              bx.setVisible(4, true)
            else
              bx = addSprite(boxsp)
              dir = b.index.even? ? 1 : -1
              bx.setOpacity(0, 255) if bx.respond_to?(:setOpacity)
              bx.setDelta(0, dir * Graphics.width / 2, 0)
              bx.setVisible(1, true)
              bx.moveDelta(1, 10, -dir * Graphics.width / 2, 0)
            end
          end
        else
          # EXISTING BATTLER (Caller): slide horizontally without vertical movement to final combat position
          caller_y = bat.y
          obj = addSprite(bat, PictureOrigin::BOTTOM)
          obj.setZ(0, nz) if obj.respond_to?(:setZ)
          obj.moveXY(0, duration, nx, caller_y)

          if sha
            sh = addSprite(sha, PictureOrigin::CENTER)
            sh.setZ(0, sz) if sh.respond_to?(:setZ)
            sh.moveXY(0, duration, sx, sha.y)
          end

          if boxsp
            from = boxsp.instance_variable_get(:@bss656_reflow_from_xy) rescue nil
            to = boxsp.instance_variable_get(:@bss656_reflow_to_xy) rescue nil
            if from.is_a?(Array) && to.is_a?(Array)
              bx = addSprite(boxsp)
              bx.setXY(0, from[0], from[1])
              bx.moveXY(0, duration, to[0], to[1])
              boxsp.instance_variable_set(:@bss656_reflow_from_xy, nil) rescue nil
              boxsp.instance_variable_set(:@bss656_reflow_to_xy, nil) rescue nil
            end
          end
        end
      end
    end
  end
end

#-------------------------------------------------------------------------------
# 4. CUSTOM & EBDX BACKGROUNDS: Universal Loader with Correct Anchors
#-------------------------------------------------------------------------------
if defined?(BSS070CustomRoom)
  class BSS070CustomRoom < BSS070EBDXRoom
    def refresh(*args)
      bss076_dispose_owned_sprites! rescue nil
      sx, sy = @scene.vector.spoof(@defaultvector)

      # Void (Padding)
      @sprites["void"] = BSS070EBDXSprite.new(@viewport)
      @sprites["void"].z = -10
      @overscan_pad = [(@viewport.width * 0.5).to_i, 192].max
      @sprites["void"].bitmap = Bitmap.new(@viewport.width + @overscan_pad * 2, @viewport.height + @overscan_pad * 2)
      @sprites["void"].x = -@overscan_pad
      @sprites["void"].y = -@overscan_pad
      @sprites["void"].bitmap.fill_rect(0, 0, @sprites["void"].bitmap.width, @sprites["void"].bitmap.height, Color.new(0, 0, 0))

      # Backdrop
      if @data.has_key?("backdrop")
        path = BSSUnified.resolve_background_bitmap(@data["backdrop"])
        if path
          @sprites["bg"] = BSS070EBDXSprite.new(@viewport)
          @sprites["bg"].bitmap = pbBitmap(path)
          @sprites["bg"].z = 0
          @sprites["bg"].center!
          @sprites["bg"].ox = sx / 1.5 - 16
          @sprites["bg"].oy = sy / 1.5 + 16

          if @data["wideWorld"] == true || @sprites["bg"].bitmap.width > 384 || @sprites["bg"].bitmap.height > 308
            extra_x = [(@sprites["bg"].bitmap.width.to_f - 384.0) / 2.0, 0.0].max
            extra_y = [(@sprites["bg"].bitmap.height.to_f - 308.0) / 2.0, 0.0].max
            @sprites["bg"].ox += extra_x
            @sprites["bg"].oy += extra_y
            @bss_wide_world_origin = [extra_x, extra_y]
          else
            @bss_wide_world_origin = [0.0, 0.0]
          end
        end
      end

      # Fallback empty bg if no backdrop found
      if !@sprites["bg"] || !@sprites["bg"].bitmap
        @sprites["bg"] = BSS070EBDXSprite.new(@viewport)
        @sprites["bg"].bitmap = Bitmap.new(384, 308)
        @sprites["bg"].z = 0
        @sprites["bg"].center!
        @bss_wide_world_origin = [0.0, 0.0]
      end

      # ponytail: en una escena custom (libraryId "project") la "base" NO es la
      # plataforma deslizante de EBDX estándar: es el SUELO autoría del fondo
      # (p.ej. base/Water.png de Island). Dibujarla aunque SHOW_BATTLE_BASES=false;
      # ese flag solo gobierna los rooms EBDX estándar (ver 99_Hotfix/040).
      if @data.has_key?("base")
        str = BSSUnified.resolve_base_bitmap(@data["base"])
        if str
          @sprites["base"] = BSS070EBDXSprite.new(@viewport)
          @sprites["base"].bitmap = pbBitmap(str)
          @sprites["base"].z = 1
          base_h = @sprites["base"].bitmap.height
          extra_y = [(@sprites["bg"].bitmap.height.to_f - 308.0) / 2.0, 0.0].max
          dist_to_bottom = extra_y + 308 - @sprites["bg"].oy
          @sprites["base"].ox = @sprites["bg"].ox
          @sprites["base"].oy = base_h - dist_to_bottom
        end
      end

      # Dynamic elements
      self.drawSky if @data.has_key?("sky")
      self.drawWater if @data.has_key?("water")
      self.drawTrees if @data.has_key?("trees")
      self.drawGrass if @data.has_key?("tallGrass")

      # Custom images (img001, etc.)
      @data.keys.each do |key|
        self.drawImg(key) if key.to_s.start_with?("img")
      end

      # CRITICAL: Always adjust metrics so battlers have valid anchors!
      self.adjustMetrics
      self.daylightTint
    end
  end
end

#-------------------------------------------------------------------------------
# 5. SHADOW AUTHORITY: Keep battler shadows visible during move animations
#-------------------------------------------------------------------------------
class Battle::Scene
  def pbSaveShadows
    yield
  end
end

# Prepend unified authorities to Battle::Scene
if defined?(Battle::Scene)
  Battle::Scene.prepend(BSSUnifiedBackdropControl) unless Battle::Scene.ancestors.include?(BSSUnifiedBackdropControl)
  Battle::Scene.prepend(BSSUnifiedCameraAuthority) unless Battle::Scene.ancestors.include?(BSSUnifiedCameraAuthority)
end

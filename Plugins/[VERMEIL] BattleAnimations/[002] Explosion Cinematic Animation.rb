#===============================================================================
# [VERMEIL] BattleAnimations
# Cinematic override for Explosion
#===============================================================================

module VermeilBattleAnimations
  module_function

  EXPLOSION_BG_BLACK = "Graphics/Battle animations/black_screen"
  EXPLOSION_BG_WHITE = "Graphics/Battle animations/white_screen"
  EXPLOSION_BG_BASE  = "Graphics/Animations/PRAS- Burning BG"
  EXPLOSION_BG_BLAST = "Graphics/Animations/PRAS- Dazzling Gleam"
  EXPLOSION_CHARGE_PARTICLE_ASSETS = [
    "Graphics/Battle animations/ballBurst_particle",
    "Graphics/Animations/PRAS- Explosions"
  ]
  EXPLOSION_BURST_PARTICLE_ASSETS = [
    "Graphics/Animations/Explosion1",
    "Graphics/Animations/030-Explosion01",
    "Graphics/Animations/PRAS- Explosions",
    "Graphics/Battle animations/ballBurst_particle"
  ]
  EXPLOSION_SHOCKWAVE_ASSETS = [
    "Graphics/Battle animations/ballBurst_ring1",
    "Graphics/Battle animations/ballBurst_ring2"
  ]

  EXPLOSION_SE_CHARGE_1 = "Anim/PRSFX- Focus Punch1"
  EXPLOSION_SE_CHARGE_2 = "Anim/PRSFX- Focus Punch2"
  EXPLOSION_SE_RELEASE  = "Anim/Explosion"
  EXPLOSION_SE_BLAST    = "Anim/PRSFX- Rock Wrecker1"

  def resolve_move_id(move)
    return move.id if move.respond_to?(:id)
    data = GameData::Move.try_get(move)
    return data.id if data
    return move
  end

  def first_existing_asset(paths)
    paths.each { |path| return path if pbResolveBitmap(path) }
    return nil
  end

  def divisors_upto(n, max_val = 8)
    ret = []
    (1..max_val).each { |i| ret << i if (n % i).zero? }
    return ret
  end

  def detect_sheet_grid(width, height)
    return [1, 1] if width <= 0 || height <= 0
    return [1, 1] if width == height
    if width >= (height * 2) && (width % height).zero?
      cols = width / height
      return [cols, 1] if cols <= 16
    end
    if height >= (width * 2) && (height % width).zero?
      rows = height / width
      return [1, rows] if rows <= 16
    end
    best = [1, 1]
    best_score = 999_999.0
    divisors_upto(width, 8).each do |cols|
      divisors_upto(height, 8).each do |rows|
        next if cols == 1 && rows == 1
        frame_w = width / cols
        frame_h = height / rows
        next if frame_w < 12 || frame_h < 12
        ratio = frame_w.to_f / frame_h
        ratio_penalty = (Math.log(ratio.abs)).abs
        frame_count = cols * rows
        frame_penalty = (frame_count > 16) ? (frame_count - 16) : 0
        area_penalty = (frame_w * frame_h < 22 * 22) ? 10 : 0
        score = ratio_penalty + frame_penalty + area_penalty
        if score < best_score
          best = [cols, rows]
          best_score = score
        end
      end
    end
    return best
  end

  def sheet_frame_info(path)
    @sheet_frame_cache ||= {}
    return @sheet_frame_cache[path] if @sheet_frame_cache[path]
    resolved = pbResolveBitmap(path)
    return nil if !resolved
    bmp = nil
    begin
      bmp = Bitmap.new(resolved)
      return nil if !bmp || bmp.disposed?
      width  = bmp.width
      height = bmp.height
      cols, rows = detect_sheet_grid(width, height)
      frame_w = width / cols
      frame_h = height / rows
      info = {
        cols: cols, rows: rows, width: width, height: height,
        frame_w: frame_w, frame_h: frame_h, count: cols * rows
      }
      @sheet_frame_cache[path] = info
      return info
    ensure
      bmp.dispose if bmp && !bmp.disposed?
    end
  rescue
    return nil
  end

  def preferred_sheet_frame(path, style = :default)
    info = sheet_frame_info(path)
    return [0, 0, 0, 0] if !info
    count = info[:count]
    idx = case style
          when :charge then [(count / 3), count - 1].min
          when :burst
            center_col = info[:cols] / 2
            center_row = info[:rows] / 2
            (center_row * info[:cols]) + center_col
          else 0
          end
    idx = 0 if idx < 0
    col = idx % info[:cols]
    row = idx / info[:cols]
    sx = col * info[:frame_w]
    sy = row * info[:frame_h]
    return [sx, sy, info[:frame_w], info[:frame_h]]
  end

  def frame_rect(path, frame_index)
    info = sheet_frame_info(path)
    return [0, 0, 0, 0] if !info
    idx = frame_index % info[:count]
    col = idx % info[:cols]
    row = idx / info[:cols]
    return [col * info[:frame_w], row * info[:frame_h], info[:frame_w], info[:frame_h]]
  end

  def battler_front_sprite_path(battler)
    return nil if !battler
    pkmn = nil
    pkmn = battler.visiblePokemon if battler.respond_to?(:visiblePokemon)
    pkmn = battler.pokemon if !pkmn && battler.respond_to?(:pokemon)
    return nil if !pkmn
    species = pkmn.species
    form    = pkmn.form || 0
    gender  = (pkmn.respond_to?(:gender) && pkmn.gender) ? pkmn.gender : 0
    shiny   = pkmn.respond_to?(:shiny?) ? pkmn.shiny? : false
    shadow  = pkmn.respond_to?(:shadowPokemon?) ? pkmn.shadowPokemon? : false
    return GameData::Species.front_sprite_filename(species, form, gender, shiny, shadow)
  rescue
    return nil
  end
end

class Battle::Scene::Animation::VermeilCinematicExplosion < Battle::Scene::Animation
  def initialize(sprites, viewport, user, original_user_hidden = false)
    @user = user
    @original_user_hidden = original_user_hidden
    super(sprites, viewport)
  end

  def createProcesses
    return if !@user
    user_sprite = @sprites["pokemon_#{@user.index}"]
    return if !user_sprite

    center_x = Graphics.width / 2
    center_y = (Graphics.height / 2) + 56
    fx_x = center_x - 8
    fx_y = center_y - 72

    base_bg = nil
    if pbResolveBitmap(VermeilBattleAnimations::EXPLOSION_BG_BASE)
      base_bg = addNewSprite(Graphics.width / 2, Graphics.height / 2, VermeilBattleAnimations::EXPLOSION_BG_BASE,
                             PictureOrigin::CENTER)
      base_bg.setZ(0, 500)
      base_bg.setOpacity(0, 255)
      # Keep visible unless dazzling swap is available.
      base_bg.setVisible(0, true)
    end

    # 2) Front sprite animated mandatory. Build a temporary front battler sprite.
    attacker = build_front_attacker_sprite(user_sprite, center_x, center_y)
    attacker.setZ(0, 690)
    attacker.setVisible(0, true)

    # Normal size for player-front; for battler-front, use x2 momentarily.
    base_zoom = 100
    attacker.setZoom(0, base_zoom)

    # 3) Slow blink 3 times + wait.
    attacker.moveColor(20, 3, Color.new(255, 255, 255, 170))
    attacker.moveColor(23, 3, Color.new(255, 255, 255, 0))
    attacker.moveColor(27, 3, Color.new(255, 255, 255, 200))
    attacker.moveColor(30, 3, Color.new(255, 255, 255, 0))
    attacker.moveColor(34, 3, Color.new(255, 255, 255, 255))
    attacker.moveColor(37, 3, Color.new(255, 255, 255, 0))
    attacker.setSE(20, VermeilBattleAnimations::EXPLOSION_SE_CHARGE_1)
    attacker.setSE(30, VermeilBattleAnimations::EXPLOSION_SE_CHARGE_2)
    # Anticipation before impact.
    attacker.moveZoom(40, 4, base_zoom - 8)
    attacker.moveZoom(44, 2, base_zoom + 24)
    attacker.moveZoom(46, 4, base_zoom)
    attacker.moveDelta(42, 1, -6, 0)
    attacker.moveDelta(43, 1, 12, 0)
    attacker.moveDelta(44, 1, -8, 0)

    # 4) Explosion + dazzling blast background + white light flash.
    blast_bg = nil
    if pbResolveBitmap(VermeilBattleAnimations::EXPLOSION_BG_BLAST)
      blast_bg = addNewSprite(Graphics.width / 2, Graphics.height / 2, VermeilBattleAnimations::EXPLOSION_BG_BLAST,
                              PictureOrigin::CENTER)
      blast_bg.setZ(0, 505)
      blast_bg.setOpacity(0, 0)
      blast_bg.setVisible(0, false)
      # Organic switch: white flash, then hard swap to Dazzling background.
      blast_bg.setVisible(46, true)
      blast_bg.setOpacity(46, 230)
      blast_bg.setOpacity(66, 230)
      blast_bg.setBlendType(46, 0) if blast_bg.respond_to?(:setBlendType)
      base_bg.setVisible(46, false) if base_bg
      # Screen punch on detonation.
      blast_bg.moveDelta(46, 1, 10, 0)
      blast_bg.moveDelta(47, 1, -20, 0)
      blast_bg.moveDelta(48, 1, 14, 0)
      blast_bg.moveDelta(49, 1, -4, 0)
    end

    white = nil
    if pbResolveBitmap(VermeilBattleAnimations::EXPLOSION_BG_WHITE)
      white = addNewSprite(0, 0, VermeilBattleAnimations::EXPLOSION_BG_WHITE)
      white.setZ(0, 760)
      white.setOpacity(0, 0)
      # Double white flash at impact for stronger punch.
      white.moveOpacity(43, 2, 255)
      white.setOpacity(45, 255)
      white.moveOpacity(46, 2, 0)
      white.moveOpacity(48, 1, 200)
      white.moveOpacity(49, 2, 0)
    end

    charge_asset = VermeilBattleAnimations.first_existing_asset(
      VermeilBattleAnimations::EXPLOSION_CHARGE_PARTICLE_ASSETS
    )
    burst_asset = VermeilBattleAnimations.first_existing_asset(
      VermeilBattleAnimations::EXPLOSION_BURST_PARTICLE_ASSETS
    )
    # Keep visual origin consistent: burst starts from the same centered asset as charge.
    burst_asset = charge_asset if charge_asset
    shockwave_asset = VermeilBattleAnimations.first_existing_asset(
      VermeilBattleAnimations::EXPLOSION_SHOCKWAVE_ASSETS
    )
    if charge_asset || burst_asset
      # Charge particles: energy accumulates from outside to inside.
      charge_dirs = [
        [-1.0, 0.0], [1.0, 0.0], [0.0, -1.0], [0.0, 1.0],
        [-0.7, -0.7], [0.7, -0.7], [-0.7, 0.7], [0.7, 0.7],
        [-0.4, -1.0], [0.4, -1.0], [-1.0, 0.4], [1.0, 0.4]
      ]
      if charge_asset
        charge_dirs.each_with_index do |dir, i|
          start_t = 14 + (i % 6) * 3
          radius = 92 + (i / 6) * 14
          start_x = fx_x + (dir[0] * radius).round
          start_y = fx_y + (dir[1] * radius).round
          charge = addNewSprite(start_x, start_y, charge_asset, PictureOrigin::CENTER)
          apply_sheet_frame(charge, charge_asset, :charge)
          charge.setZ(0, 700)
          charge.setOpacity(0, 0)
          charge.setZoom(0, 34)
          charge.setVisible(0, false)
          charge.setVisible(start_t, true)
          charge.moveOpacity(start_t, 3, 200)
          charge.moveXY(start_t, 10, fx_x, fx_y)
          charge.moveZoom(start_t, 10, 62)
          charge.moveOpacity(start_t + 7, 4, 0)
          charge.setVisible(start_t + 12, false)
        end
      end

      if burst_asset
        particles = addNewSprite(fx_x, fx_y, burst_asset, PictureOrigin::CENTER)
        apply_sheet_frame(particles, burst_asset, :charge)
        particles.setZ(0, 720)
        particles.setVisible(0, false)
        particles.setOpacity(0, 0)
        particles.setZoom(0, 24)
        particles.setTone(0, Tone.new(0, 0, 0, 0))
        particles.setVisible(46, true)
        particles.moveOpacity(46, 1, 255)
        particles.moveZoom(46, 5, 210)
        particles.moveTone(46, 2, Tone.new(0, 0, -120, 0))   # Yellow
        particles.moveTone(48, 2, Tone.new(0, -90, -170, 0)) # Orange
        particles.moveTone(50, 2, Tone.new(0, -180, -240, 0))# Red
        particles.moveOpacity(47, 6, 0)
        particles.setVisible(54, false)
      end

      # Shockwave rings: true radial expansion from the impact center.
      if shockwave_asset
        4.times do |i|
          t = 46 + i
          ring = addNewSprite(fx_x, fx_y, shockwave_asset, PictureOrigin::CENTER)
          apply_sheet_frame(ring, shockwave_asset, :burst)
          ring.setZ(0, 718)
          ring.setOpacity(0, 0)
          ring.setZoom(0, 12 + (i * 4))
          ring.setTone(0, Tone.new(0, 0, -100, 0))
          ring.setVisible(0, false)
          ring.setVisible(t, true)
          ring.moveOpacity(t, 1, 255)
          ring.moveZoom(t, 8, 250 + (i * 90))
          ring.moveTone(t, 3, Tone.new(0, -90, -170, 0))
          ring.moveTone(t + 3, 3, Tone.new(0, -180, -240, 0))
          ring.moveOpacity(t + 1, 8, 0)
          ring.setVisible(t + 10, false)
        end
      end

      # Keep a compact center blast so it feels like detonation source.
      if burst_asset
        core_offsets = [[0, 0], [10, -8], [-10, -8], [8, 10], [-8, 10], [0, -12]]
        core_offsets.each_with_index do |ofs, i|
          t = 46 + i
          cloud = addNewSprite(fx_x + ofs[0], fx_y + ofs[1], burst_asset, PictureOrigin::CENTER)
          apply_sheet_frame(cloud, burst_asset, :charge)
          cloud.setZ(0, 725)
          cloud.setOpacity(0, 0)
          cloud.setZoom(0, 22 + (i * 3))
          cloud.setTone(0, Tone.new(0, 0, -110, 0))
          cloud.setVisible(0, false)
          cloud.setVisible(t, true)
          cloud.moveOpacity(t, 1, 255)
          cloud.moveZoom(t, 5, 142 + (i * 10))
          cloud.moveTone(t, 2, Tone.new(0, -90, -170, 0))
          cloud.moveTone(t + 2, 2, Tone.new(0, -180, -240, 0))
          cloud.moveOpacity(t + 1, 6, 0)
          cloud.setVisible(t + 7, false)
        end

        # Debris: 8 directions (cardinal + diagonals), desynced, different sizes.
        debris_dirs = [
          [0.0, -1.0], [0.75, -0.75], [1.0, 0.0], [0.75, 0.75],
          [0.0, 1.0], [-0.75, 0.75], [-1.0, 0.0], [-0.75, -0.75]
        ]
        # Two waves so the burst feels denser than a single ring.
        2.times do |wave|
          debris_dirs.each_with_index do |dir, i|
            t = 46 + wave + (i % 5)
            debris = addNewSprite(fx_x, fx_y, burst_asset, PictureOrigin::CENTER)
            apply_sheet_frame(debris, burst_asset, :charge)
            debris.setZ(0, 730)
            debris.setOpacity(0, 0)
            start_zoom = 12 + ((i + wave) % 4) * 3
            end_zoom = 44 + ((i + wave) % 5) * 11
            debris.setZoom(0, start_zoom)
            debris.setTone(0, Tone.new(0, -90, -170, 0))
            debris.setVisible(0, false)
            debris.setVisible(t, true)
            debris.moveOpacity(t, 1, 255)
            debris.moveZoom(t, 7, end_zoom)
            radius = 40 + (wave * 16) + ((i % 3) * 8)
            debris_dx = (dir[0] * radius).round
            debris_dy = (dir[1] * radius).round + 8
            debris.moveDelta(t, 8, debris_dx, debris_dy)
            debris.moveTone(t + 2, 3, Tone.new(0, -180, -240, 0))
            debris.moveOpacity(t + 2, 7, 0)
            debris.setVisible(t + 10, false)
          end
        end

        # Gray smoke clouds: lifted layer so they don't get buried by the core.
        smoke_offsets_y = [-18, -10, -2, 6, 14, 22]
        2.times do |side|
          dir_x = (side == 0) ? -1 : 1
          smoke_offsets_y.each_with_index do |oy, i|
            t = 48 + (i % 4) + (side * 2)
            smoke = addNewSprite(fx_x, fx_y - 24 + oy, burst_asset, PictureOrigin::CENTER)
            apply_sheet_frame(smoke, burst_asset, :charge)
            smoke.setZ(0, 736)
            smoke.setOpacity(0, 0)
            start_zoom = 16 + (i % 3) * 5
            end_zoom = 54 + (i % 4) * 14
            smoke.setZoom(0, start_zoom)
            # Neutral gray smoke palette.
            smoke.setTone(0, Tone.new(-90, -90, -90, 0))
            smoke.setVisible(0, false)
            smoke.setVisible(t, true)
            smoke.moveOpacity(t, 2, 200)
            smoke.moveZoom(t, 10, end_zoom)
            dx = dir_x * (34 + (i % 3) * 14)
            dy = 4 + (i % 2) * 5
            smoke.moveDelta(t, 10, dx, dy)
            smoke.moveTone(t + 3, 5, Tone.new(-140, -140, -140, 0))
            smoke.moveOpacity(t + 4, 8, 0)
            smoke.setVisible(t + 13, false)
          end
        end

        # Extra smoke using the same 8-direction dispersion as explosion debris.
        smoke_dirs = [
          [0.0, -1.0], [0.75, -0.75], [1.0, 0.0], [0.75, 0.75],
          [0.0, 1.0], [-0.75, 0.75], [-1.0, 0.0], [-0.75, -0.75]
        ]
        smoke_dirs.each_with_index do |dir, i|
          t = 49 + (i % 4)
          puff = addNewSprite(fx_x, fx_y - 8, burst_asset, PictureOrigin::CENTER)
          apply_sheet_frame(puff, burst_asset, :charge)
          puff.setZ(0, 734)
          puff.setOpacity(0, 0)
          puff.setZoom(0, 14 + (i % 3) * 4)
          puff.setTone(0, Tone.new(-100, -100, -100, 0))
          puff.setVisible(0, false)
          puff.setVisible(t, true)
          puff.moveOpacity(t, 1, 210)
          puff.moveZoom(t, 9, 64 + (i % 4) * 12)
          radius = 30 + (i % 3) * 12
          puff.moveDelta(t, 9, (dir[0] * radius).round, (dir[1] * radius).round + 8)
          puff.moveTone(t + 3, 5, Tone.new(-150, -150, -150, 0))
          puff.moveOpacity(t + 3, 7, 0)
          puff.setVisible(t + 12, false)
        end
      end
    end

    attacker.setSE(44, VermeilBattleAnimations::EXPLOSION_SE_RELEASE)
    attacker.setSE(45, VermeilBattleAnimations::EXPLOSION_SE_BLAST)
    attacker.setSE(47, VermeilBattleAnimations::EXPLOSION_SE_BLAST, 90, 90)
    attacker.moveColor(44, 2, Color.new(255, 255, 255, 255))
    attacker.moveColor(46, 4, Color.new(255, 255, 255, 0))
    attacker.moveDelta(46, 1, 8, 0)
    attacker.moveDelta(47, 1, -14, 0)
    attacker.moveDelta(48, 1, 8, 0)
    # Keep attacker visible; it will be hidden naturally by the white fade/restore.

    # Final return fade is handled in scene with a real white overlay block.
  end

  def apply_sheet_frame(picture, asset_path, style = :default)
    return if !picture || !asset_path
    src_x, src_y, src_w, src_h = VermeilBattleAnimations.preferred_sheet_frame(asset_path, style)
    info = VermeilBattleAnimations.sheet_frame_info(asset_path)
    return if src_w <= 0 || src_h <= 0
    if info
      full_w = info[:width]
      full_h = info[:height]
      full_frame = (src_x == 0 && src_y == 0 && src_w == full_w && src_h == full_h)
      oversize = (src_w > 192 || src_h > 192)
      if full_frame || oversize
        crop = [full_w, full_h, 192].min
        crop = [crop, 1].max
        src_w = crop
        src_h = crop
        src_x = ((full_w - src_w) / 2.0).round
        src_y = ((full_h - src_h) / 2.0).round
      end
    end
    picture.setSrc(0, src_x, src_y)
    picture.setSrcSize(0, src_w, src_h)
    picture.setOrigin(0, PictureOrigin::CENTER)
  rescue
  end

  def animate_sheet_frames(picture, asset_path, start_t, duration, style = :burst)
    info = VermeilBattleAnimations.sheet_frame_info(asset_path)
    return if !info || info[:count] <= 1
    frame_count = [duration, info[:count]].min
    base_idx = (style == :burst) ? [info[:count] / 3, 0].max : 0
    frame_count.times do |j|
      idx = base_idx + j
      sx, sy, sw, sh = VermeilBattleAnimations.frame_rect(asset_path, idx)
      picture.setSrc(start_t + j, sx, sy)
      picture.setSrcSize(start_t + j, sw, sh)
    end
  rescue
  end

  def build_front_attacker_sprite(user_sprite, center_x, center_y)
    pkmn = nil
    pkmn = @user.visiblePokemon if @user.respond_to?(:visiblePokemon)
    pkmn = @user.pokemon if !pkmn && @user.respond_to?(:pokemon)
    side_size = @user.battle.pbSideSize(@user.index) rescue 1
    begin
      temp = Battle::Scene::BattlerSprite.new(@viewport, side_size, @user.index, [])
      if pkmn
        begin
          temp.setPokemonBitmap(pkmn, @user, false)
        rescue
          temp.setPokemonBitmap(pkmn, false)
        end
      end
      temp.x = user_sprite.x
      temp.y = user_sprite.y
      temp.visible = true
      @tempSprites.push(temp)
      pic = addSprite(temp, PictureOrigin::BOTTOM)
      pic.setXY(0, center_x, center_y)
      return pic
    rescue
      fallback = addSprite(user_sprite, PictureOrigin::BOTTOM)
      fallback.setXY(0, center_x, center_y)
      return fallback
    end
  end

end

class Battle::Scene
  alias_method :vermeil_explosion_anim_pbUpdate, :pbUpdate unless method_defined?(:vermeil_explosion_anim_pbUpdate)

  def pbUpdate(*args)
    vermeil_explosion_anim_pbUpdate(*args)
    return if !@vermeil_force_hidden_fainted || @vermeil_force_hidden_fainted.empty?
    @vermeil_force_hidden_fainted.keys.each do |idx|
      b = (@battle && @battle.respond_to?(:battlers)) ? @battle.battlers[idx] : nil
      if !b
        @vermeil_force_hidden_fainted.delete(idx)
        next
      end
      @vermeil_force_hidden_fainted[idx] -= 1
      if b.fainted? || b.hp <= 0
        pkmn = @sprites["pokemon_#{idx}"]
        shdw = @sprites["shadow_#{idx}"]
        if pkmn
          pkmn.visible = false if pkmn.respond_to?(:visible=)
          pkmn.opacity = 0 if pkmn.respond_to?(:opacity=)
          if pkmn.respond_to?(:src_rect) && pkmn.src_rect
            pkmn.src_rect.height = 0
          end
        end
        if shdw
          shdw.visible = false if shdw.respond_to?(:visible=)
          shdw.opacity = 0 if shdw.respond_to?(:opacity=)
          if shdw.respond_to?(:src_rect) && shdw.src_rect
            shdw.src_rect.height = 0
          end
        end
      else
        @vermeil_force_hidden_fainted.delete(idx)
        next
      end
      @vermeil_force_hidden_fainted.delete(idx) if @vermeil_force_hidden_fainted[idx] <= 0
    end
  end

  def vermeil_mark_force_hidden_if_fainted(idx, frames = 300)
    return if idx.nil?
    @vermeil_force_hidden_fainted ||= {}
    current = @vermeil_force_hidden_fainted[idx] || 0
    @vermeil_force_hidden_fainted[idx] = [current, frames].max
  end

  def vermeil_force_hide_fainted_now
    return if !@battle || !@battle.respond_to?(:battlers)
    @battle.battlers.each do |b|
      next if !b || (b.hp > 0 && !b.fainted?)
      pkmn = @sprites["pokemon_#{b.index}"]
      shdw = @sprites["shadow_#{b.index}"]
      if pkmn
        pkmn.visible = false if pkmn.respond_to?(:visible=)
        pkmn.opacity = 0 if pkmn.respond_to?(:opacity=)
        if pkmn.respond_to?(:src_rect) && pkmn.src_rect
          pkmn.src_rect.height = 0
        end
      end
      if shdw
        shdw.visible = false if shdw.respond_to?(:visible=)
        shdw.opacity = 0 if shdw.respond_to?(:opacity=)
        if shdw.respond_to?(:src_rect) && shdw.src_rect
          shdw.src_rect.height = 0
        end
      end
    end
  end

  def vermeil_sync_shadows_after_cinematic
    return if !@battle || !@battle.respond_to?(:battlers)
    @battle.battlers.each do |b|
      next if !b
      pkmn = @sprites["pokemon_#{b.index}"]
      shdw = @sprites["shadow_#{b.index}"]
      if b.fainted?
        pkmn.visible = false if pkmn && pkmn.respond_to?(:visible=)
        shdw.visible = false if shdw && shdw.respond_to?(:visible=)
        next
      end
      next if !shdw || !shdw.respond_to?(:visible=)
      pkmn_visible = pkmn && pkmn.respond_to?(:visible) && pkmn.visible
      shdw.visible = pkmn_visible
    end
  end

  def vermeil_white_overlay_in
    overlay = Sprite.new(@viewport)
    overlay.bitmap = Bitmap.new(Graphics.width, Graphics.height)
    overlay.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(255, 255, 255, 255))
    overlay.z = 999
    overlay.opacity = 0
    6.times do |i|
      overlay.opacity = (((i + 1) * 255) / 6.0).round
      pbUpdate
    end
    return overlay
  end

  def vermeil_white_overlay_hold(overlay, frames = 12)
    return if !overlay
    frames = 1 if frames < 1
    frames.times do
      overlay.opacity = 255
      pbUpdate
    end
  end

  def vermeil_white_overlay_out(overlay)
    return if !overlay
    16.times do |i|
      overlay.opacity = (255 - (((i + 1) * 255) / 16.0)).round
      pbUpdate
    end
  end

  def vermeil_dispose_overlay(overlay)
    return if !overlay
    overlay.bitmap&.dispose
    overlay.dispose
  end

  def vermeil_capture_ui_visibility
    state = {}
    @sprites.each do |key, sprite|
      next if !sprite || !sprite.respond_to?(:visible)
      state[key] = sprite.visible
    end
    return state
  end

  def vermeil_hide_ui_for_cinematic
    @sprites.each do |key, sprite|
      next if !sprite || !sprite.respond_to?(:visible=)
      k = key.to_s
      next if k.start_with?("pokemon_") || k.start_with?("shadow_")
      next if k.start_with?("battle_bg") || k.start_with?("base_")
      sprite.visible = false
    end
  end

  def vermeil_restore_ui_visibility(state)
    return if !state
    state.each do |key, vis|
      next if !@sprites[key] || !@sprites[key].respond_to?(:visible=)
      @sprites[key].visible = vis
    end
  end

  def pbPlayCinematicExplosionAnimation(user, _targets)
    return if !user
    ui_state = vermeil_capture_ui_visibility
    white_overlay = nil

    user_sprite = @sprites["pokemon_#{user.index}"]
    old_vis = user_sprite&.visible
    old_x = user_sprite&.x
    old_y = user_sprite&.y
    begin
      pbSaveShadows do
        # Pre-fade to hide battler swap/pop from player's eyes.
        pre_black = nil
        if pbResolveBitmap(VermeilBattleAnimations::EXPLOSION_BG_BLACK)
          pre_black = IconSprite.new(0, 0, @viewport)
          pre_black.setBitmap(VermeilBattleAnimations::EXPLOSION_BG_BLACK)
          pre_black.z = 780
          pre_black.opacity = 0
          14.times do |i|
            pre_black.opacity = ((i + 1) * 255 / 14.0).round
            pbUpdate
          end
          # Hold black so hiding/swap/setup is completely covered.
          14.times { pbUpdate }
        end

        pbToggleDataboxes if respond_to?(:pbToggleDataboxes)
        vermeil_hide_ui_for_cinematic
        user_sprite.visible = false if user_sprite
        # Hide all other battlers before revealing the cinematic layer.
        @sprites.each do |key, sprite|
          next if !sprite || !sprite.respond_to?(:visible=)
          k = key.to_s
          next if !k.start_with?("pokemon_") && !k.start_with?("shadow_")
          next if k == "pokemon_#{user.index}" || k == "shadow_#{user.index}"
          sprite.visible = false
        end
        custom_anim = Animation::VermeilCinematicExplosion.new(@sprites, @viewport, user, true)
        # Give time to fully hide/swap and let background settle under black.
        6.times do
          custom_anim.update
          pbUpdate
        end
        if pre_black
          14.times do |i|
            pre_black.opacity = (255 - (((i + 1) * 255) / 14.0)).round
            custom_anim.update
            pbUpdate
          end
          pre_black.dispose
          pre_black = nil
        end
        loop do
          custom_anim.update
          pbUpdate
          break if custom_anim.animDone?
        end
        # Raise white cover first; state restoration will happen behind it.
        white_overlay = vermeil_white_overlay_in
        custom_anim.dispose
      end
    ensure
      if user_sprite
        user_sprite.visible = old_vis unless old_vis.nil?
        if !old_x.nil? && !old_y.nil?
          user_sprite.x = old_x
          user_sprite.y = old_y
          user_sprite.pbSetOrigin if user_sprite.respond_to?(:pbSetOrigin)
        end
      end
      # Restore generic UI first, then force databoxes visible at the very end.
      vermeil_restore_ui_visibility(ui_state)
      pbRefresh if respond_to?(:pbRefresh)
      pbToggleDataboxes(true) if respond_to?(:pbToggleDataboxes)
      @sprites.each do |key, sprite|
        next if !sprite || !sprite.respond_to?(:visible=)
        k = key.to_s.downcase
        next if !k.start_with?("databox")
        sprite.visible = true
      end
      vermeil_sync_shadows_after_cinematic
      # Give UI time to reappear before HP/damage visuals continue.
      20.times { pbUpdate }
      vermeil_sync_shadows_after_cinematic
      # Keep full white for a moment while all restored elements settle.
      vermeil_white_overlay_hold(white_overlay, 12)
      vermeil_white_overlay_out(white_overlay)
      vermeil_dispose_overlay(white_overlay)
    end
  end
end

class Battle
  alias_method :vermeil_explosion_cinematic_pbAnimation, :pbAnimation unless method_defined?(:vermeil_explosion_cinematic_pbAnimation)

  def pbAnimation(move, user, targets, hitNum = 0)
    move_id = VermeilBattleAnimations.resolve_move_id(move)
    if @showAnims && move_id == :EXPLOSION && @scene.respond_to?(:pbPlayCinematicExplosionAnimation)
      @scene.pbPlayCinematicExplosionAnimation(user, targets)
      return
    end
    vermeil_explosion_cinematic_pbAnimation(move, user, targets, hitNum)
  end
end

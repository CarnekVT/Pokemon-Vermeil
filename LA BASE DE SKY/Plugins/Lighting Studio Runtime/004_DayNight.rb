# encoding: UTF-8
# Lighting Studio day/night v0.9.0 — additive to 001_LightingStudio.rb.
# The real clock is local system time. Internal minutes are stored on
# $PokemonGlobal, which is serialized with save data by Essentials.
module LightingStudioDayNight
  @cached = nil
  @last_tick = nil
  @revision = 0
  @cached_keyframes = nil
  module_function

  def settings
    return @cached if @cached
    cfg = {}
    begin
      if File.file?(LightingStudio::DATA_PATH) &&
         defined?(JSON) && JSON.respond_to?(:parse)
        project = JSON.parse(File.binread(LightingStudio::DATA_PATH))
        cfg = project['timeOfDay'] if project.is_a?(Hash) && project['timeOfDay'].is_a?(Hash)
      end
    rescue StandardError => e
      warn "[Lighting Studio Time] Could not read configuration: #{e.message}"
    end
    @cached = cfg || {}
  end

  def reset_cache
    @cached = nil
    @last_tick = nil
    @cached_keyframes = nil
    @cached_tone_keys = nil
    @active_map_id = nil
    @active_map_data = nil
    @revision = (@revision || 0) + 1
  end

  def revision
    @revision ||= 0
  end

  def current_map_data
    return nil unless defined?($game_map) && $game_map
    id=$game_map.map_id
    if @active_map_id!=id
      @active_map_id=id
      @active_map_data=LightingStudio.load_map(id)
    end
    @active_map_data
  end

  def active_on_map?(map_data)
    cfg = settings
    return false unless cfg.is_a?(Hash) && cfg['enabled'] == true
    return false if !map_data.is_a?(Hash) || map_data['dayNightMode'] == 'ignore'
    true
  end

  def clamp(value, min, max, fallback)
    n = Float(value)
    n.finite? ? [[n,min].max,max].min : fallback
  rescue StandardError
    fallback
  end

  def hour
    cfg = settings
    return Time.now.hour + Time.now.min / 60.0 + Time.now.sec / 3600.0 if cfg['source'] != 'internal'
    now = System.uptime
    if !defined?($PokemonGlobal) || !$PokemonGlobal
      @fallback_minutes ||= clamp(cfg['startHour'],0,23.999,8.0)*60.0
      target = @fallback_minutes
    else
      target = $PokemonGlobal.instance_variable_get(:@ls_daynight_minutes)
      if target.nil?
        target = clamp(cfg['startHour'],0,23.999,8.0)*60.0
        $PokemonGlobal.instance_variable_set(:@ls_daynight_minutes,target)
      end
    end
    delta = @last_tick ? [[now-@last_tick,0.0].max,0.25].min : 0.0
    @last_tick = now
    minutes = (target.to_f+delta*clamp(cfg['minutesPerSecond'],0.001,5.0,0.1)) % 1440.0
    if defined?($PokemonGlobal) && $PokemonGlobal
      $PokemonGlobal.instance_variable_set(:@ls_daynight_minutes,minutes)
    else
      @fallback_minutes = minutes
    end
    minutes/60.0
  end

  def keyframes
    return @cached_keyframes if @cached_keyframes
    raw = settings['keyframes']
    return [] unless raw.is_a?(Array)
    @cached_keyframes = raw.first(48).select { |p| p.is_a?(Hash) && p['color'].to_s =~ /\A#[0-9a-fA-F]{6}\z/ }
       .map do |p|
      { :hour => clamp(p['hour'],0,23.999,0),
        :rgb => LightingStudio.hex_color(p['color']),
        :darkness => clamp(p['darkness'],0,1,0) }
    end.sort_by { |k| k[:hour] }
  end

  def interpolate(hr)
    keys=keyframes
    return nil if keys.length < 2
    h=hr % 24.0
    hi=keys.index { |p| p[:hour]>h } || 0
    high=keys[hi]
    low=keys[(hi-1)%keys.length]
    start=low[:hour]
    finish=high[:hour]+(hi==0 ? 24.0 : 0.0)
    value=h < start ? h+24.0 : h
    span=finish-start
    t=span>0 ? [[(value-start)/span,0.0].max,1.0].min : 0.0
    rgb=3.times.map { |c| (low[:rgb][c]*(1.0-t)+high[:rgb][c]*t).round }
    [rgb, low[:darkness]*(1.0-t)+high[:darkness]*t]
  end

  # A scheduled light fades in and out in GAME minutes. Works across
  # midnight (e.g. 19:00 -> 05:00) without rebuilding light masks or chunks.
  # Disabled/unconfigured schedules preserve legacy lights.
  # Native Pokémon Essentials RGSS tone. Unlike a colored opacity overlay,
  # Tone alters the sprite/map channels without replacing the original palette
  # with a flat blue/green color. Values follow Deo's Eevee Expo technique.
  def native_tone?
    settings['blendMode'] == 'tone'
  end

  def tone_keys
    return @cached_tone_keys if @cached_tone_keys
    raw=settings['keyframes']
    raw=[] unless raw.is_a?(Array)
    @cached_tone_keys=raw.first(48).filter_map do |item|
      next unless item.is_a?(Hash)
      hr=clamp(item['hour'],0.0,23.999,0.0)
      v=item['tone']
      if v.is_a?(Hash)
        channels=[
          clamp(v['red'],-255,255,0).round,
          clamp(v['green'],-255,255,0).round,
          clamp(v['blue'],-255,255,0).round,
          clamp(v['gray'],0,255,0).round
        ]
      else
        # Legacy color/darkness keyframes (pre-v0.9) remain valid: best-effort
        # shade conversion avoids their former color-overpaint appearance.
        rgb=LightingStudio.hex_color(item['color'])
        darkness=clamp(item['darkness'],0,1,0)
        neutral=[-85*darkness,-85*darkness,-85*darkness]
        channels=3.times.map { |i| [[neutral[i]+(rgb[i]-170)*darkness*0.12,-255].max,255].min.round }
        channels << 0
      end
      {:hour=>hr,:tone=>channels}
    end.sort_by { |key| key[:hour] }
  end

  def tone_values(at_hour=nil)
    keys=tone_keys
    return [0,0,0,0] if keys.length < 2
    h=((at_hour.nil? ? hour : at_hour).to_f % 24.0)
    hi=keys.index { |p| p[:hour]>h } || 0
    high=keys[hi];low=keys[(hi-1)%keys.length]
    start=low[:hour];finish=high[:hour]+(hi==0 ? 24.0 : 0.0)
    value=h<start ? h+24.0 : h
    span=finish-start
    t=span>0 ? [[(value-start)/span,0.0].max,1.0].min : 0.0
    4.times.map { |i| (low[:tone][i]*(1.0-t)+high[:tone][i]*t).round }
  end

  def compose_tone(screen_tone,values)
    original=screen_tone || Tone.new(0,0,0,0)
    Tone.new(
      [[original.red+values[0],-255].max,255].min,
      [[original.green+values[1],-255].max,255].min,
      [[original.blue+values[2],-255].max,255].min,
      [[original.gray+values[3],0].max,255].min
    )
  end

  def schedule_factor(schedule, at_hour=nil)
    return 1.0 unless schedule.is_a?(Hash) && schedule['enabled']==true
    return 1.0 unless settings['enabled']==true
    current = ((at_hour.nil? ? hour : at_hour).to_f % 24.0) * 60.0
    first = clamp(schedule['startHour'], 0.0, 23.999, 19.0) * 60.0
    last  = clamp(schedule['endHour'], 0.0, 23.999, 7.0) * 60.0
    span = (last-first) % 1440.0
    return 1.0 if span < 0.0001 # identical endpoints mean all day
    elapsed = (current-first) % 1440.0
    return 0.0 if elapsed >= span
    fade = [clamp(schedule['fadeMinutes'],0.0,120.0,20.0),span/2.0].min
    return 1.0 if fade <= 0.0
    weight = [[elapsed/fade,(span-elapsed)/fade,1.0].min,0.0].max
    weight*weight*(3.0-2.0*weight)
  end

  def ambient_opacity(darkness)
    # A night overlay should shade rather than recolor the entire pixel-art
    # palette; the manual ambient layer (without a clock) is unchanged.
    (clamp(darkness,0.0,1.0,0.0)*170).round
  end

  def ambient(map_data)
    return nil unless active_on_map?(map_data)
    native_tone? ? tone_values : interpolate(hour)
  end

  # Public script hooks. Internal clock time persists in the game save.
  def set_internal_time(hour,minute=0)
    minutes=((hour.to_i%24)*60+(minute.to_i%60)).to_f
    if defined?($PokemonGlobal) && $PokemonGlobal
      $PokemonGlobal.instance_variable_set(:@ls_daynight_minutes,minutes)
    else
      @fallback_minutes=minutes
    end
    @last_tick=System.uptime
    @revision = revision + 1  # Force map overlay refresh after any time jump.
    # Call the attached spriteset directly where available; otherwise the
    # revision makes the next ls_update refresh regardless of its 0.2s timer.
    if defined?($scene) && $scene && $scene.respond_to?(:spriteset)
      scene_spriteset = $scene.spriteset
      scene_spriteset.ls_update_day_night(true) if scene_spriteset.respond_to?(:ls_update_day_night)
    end
  rescue StandardError => e
    warn "[Lighting Studio Time] Immediate update deferred: #{e.message}"
  end

  def current_hour
    hour
  end

  def debug_status(map_data = nil)
    map_data ||= (defined?($game_map) && $game_map) ? LightingStudio.load_map($game_map.map_id) : nil
    lighting = ambient(map_data)
    { :source => settings['source'], :enabled => settings['enabled'],
      :map_id => (defined?($game_map) && $game_map) ? $game_map.map_id : nil,
      :map_mode => map_data.is_a?(Hash) ? map_data['dayNightMode'] : nil,
      :hour => hour.round(3), :ambient => lighting,
      :blend_mode => settings['blendMode'], :revision => revision }
  rescue StandardError => e
    { :error => e.message }
  end
end

# Base de Sky has an independent vanilla PBDayNight tint on its TilemapRenderer.
# It reads the computer's real time. While Lighting Studio owns the active
# map's clock, neutralize only this duplicate per-tile tint: the complete map
# is already toned by Spriteset_Map.viewport (including the player/followers).
# When the map ignores Lighting Studio or its cycle is off, delegate to vanilla.
module LightingStudioVanillaDayNightGuard
  def pbDayNightTint(object)
    if defined?(LightingStudioDayNight) &&
       LightingStudioDayNight.native_tone? &&
       LightingStudioDayNight.active_on_map?(LightingStudioDayNight.current_map_data)
      object.tone.set(0,0,0,0)
      return
    end
    super
  end
end
Object.prepend(LightingStudioVanillaDayNightGuard) unless
  Object.ancestors.include?(LightingStudioVanillaDayNightGuard)


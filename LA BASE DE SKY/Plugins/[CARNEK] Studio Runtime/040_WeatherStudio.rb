#===============================================================================
# Weather Studio Runtime - two visual layers in battle.
# Ambient weather never changes Battle::Field mechanics.
#===============================================================================
module CarnekStudio
  module WeatherStudio
    module_function
    BATTLE_TO_MAP = { :Rain=>:Rain, :Hail=>:Blizzard, :Snowstorm=>:Snow, :Sandstorm=>:Sandstorm,
      :Sun=>:Sun, :HarshSun=>:Sun, :HeavyRain=>:HeavyRain, :StrongWinds=>:Storm, :ShadowSky=>:Fog }
    DEFAULT_CONFIG = {
      "weathers"=>{
        "Fog"=>{"classification"=>"ambient","family"=>"fog","battleWeather"=>"None","persist"=>true,"baseIntensity"=>40},
        "Thunderstorm"=>{"classification"=>"hybrid","family"=>"precipitation","battleWeather"=>"HeavyRain","persist"=>true,"baseIntensity"=>60},
        "ThunderstormPresentColor"=>{"classification"=>"hybrid","family"=>"precipitation","battleWeather"=>"HeavyRain","persist"=>true,"baseIntensity"=>60},
        "BloodRain"=>{"classification"=>"hybrid","family"=>"precipitation","battleWeather"=>"Rain","persist"=>true,"baseIntensity"=>60}
      },
      "compatibility"=>{
        "Fog"=>{"Rain"=>{"mode"=>"blend","ambientIntensity"=>45},"HeavyRain"=>{"mode"=>"blend","ambientIntensity"=>25},"Sun"=>{"mode"=>"suppress","ambientIntensity"=>20},"Sandstorm"=>{"mode"=>"replace","ambientIntensity"=>0},"ShadowSky"=>{"mode"=>"morph","ambientIntensity"=>70}},
        "Thunderstorm"=>{"HeavyRain"=>{"mode"=>"morph","ambientIntensity"=>100}},
        "ThunderstormPresentColor"=>{"HeavyRain"=>{"mode"=>"morph","ambientIntensity"=>100}},
        "BloodRain"=>{"Rain"=>{"mode"=>"morph","ambientIntensity"=>100}}
      }
    }
    def config; @config ||= CarnekStudio.load_json("weather_studio.json", DEFAULT_CONFIG); end
    def weather_cfg(id); config["weathers"][id.to_s] || {}; end
    def ambient_from_overworld
      return :None unless $game_screen
      t=$game_screen.weather_type rescue :None
      cfg=weather_cfg(t)
      return :None if cfg["persist"] == false
      return t if ["ambient","hybrid","atmospheric"].include?(cfg["classification"])
      # Fog is ambient even in projects where it is not present in the JSON yet.
      return :Fog if t == :Fog
      :None
    end
    def relation(ambient, battle_weather)
      c=(config["compatibility"]||{})[ambient.to_s] || {}
      c[battle_weather.to_s] || {"mode"=>"stack","ambientIntensity"=>100}
    end
    def target_ambient_strength(ambient, battle_weather)
      base=(weather_cfg(ambient)["baseIntensity"] || 40).to_i
      r=relation(ambient,battle_weather)
      pct=(r["ambientIntensity"] || 100).to_i
      (base*pct/100.0).round
    end
    def suppress_gameplay_visual?(ambient,battle_weather)
      return false if ambient==:None || battle_weather==:None
      mode=relation(ambient,battle_weather)["mode"].to_s
      mode=="morph"
    end
  end
end
if defined?(Battle::Scene)
  class Battle::Scene
    alias __carnek_ws_init pbInitSprites unless method_defined?(:__carnek_ws_init)
    def pbInitSprites
      __carnek_ws_init
      @carnek_ambient_weather = RPG::Weather.new(@viewport)
      @carnek_gameplay_weather = RPG::Weather.new(@viewport)
      @carnek_ambient_type = CarnekStudio::WeatherStudio.ambient_from_overworld
      @carnek_gameplay_type = :None
      @carnek_last_field_weather = :None
      @carnek_ambient_tone = [0.0,0.0,0.0,0.0]
      @carnek_ambient_tone_target = [0.0,0.0,0.0,0.0]
      carnek_refresh_weather_layers(true)
    end
    alias __carnek_ws_frame pbFrameUpdate unless method_defined?(:__carnek_ws_frame)
    def pbFrameUpdate(cw=nil)
      __carnek_ws_frame(cw)
      field = (@battle && @battle.field) ? @battle.field.weather : :None
      if field != @carnek_last_field_weather
        @carnek_last_field_weather = field
        carnek_refresh_weather_layers(false)
      end
      carnek_update_ambient_tone
      carnek_update_weather_layer(@carnek_ambient_weather)
      carnek_update_weather_layer(@carnek_gameplay_weather)
    end
    alias __carnek_ws_dispose pbDisposeSprites unless method_defined?(:__carnek_ws_dispose)
    def pbDisposeSprites
      @carnek_ambient_weather.dispose rescue nil
      @carnek_gameplay_weather.dispose rescue nil
      __carnek_ws_dispose
    end
    def carnek_refresh_weather_layers(instant=false)
      bw = (@battle && @battle.field) ? @battle.field.weather : :None
      ambient=@carnek_ambient_type || :None
      duration=instant ? 0 : 30
      astr=CarnekStudio::WeatherStudio.target_ambient_strength(ambient,bw)
      if @carnek_ambient_weather
        if duration>0 then @carnek_ambient_weather.fade_in(ambient,astr,duration) else @carnek_ambient_weather.type=ambient; @carnek_ambient_weather.max=astr end
      end
      map_weather=CarnekStudio::WeatherStudio::BATTLE_TO_MAP[bw] || :None
      relation = CarnekStudio::WeatherStudio.relation(ambient,bw)
      if CarnekStudio::WeatherStudio.suppress_gameplay_visual?(ambient,bw)
        map_weather=:None
      end
      @carnek_ambient_tone_target = (relation["mode"].to_s=="morph" && bw==:ShadowSky) ? [-35.0,-20.0,35.0,35.0] : [0.0,0.0,0.0,0.0]
      @carnek_gameplay_type=map_weather
      if @carnek_gameplay_weather
        if duration>0 then @carnek_gameplay_weather.fade_in(map_weather, bw==:None ? 0 : 60, duration) else @carnek_gameplay_weather.type=map_weather; @carnek_gameplay_weather.max=(bw==:None ? 0 : 60) end
      end
      carnek_weather_z
    end
    def carnek_update_weather_layer(sys)
      return unless sys
      old=Tone.new(@viewport.tone.red,@viewport.tone.green,@viewport.tone.blue,@viewport.tone.gray)
      sys.update
      @viewport.tone.set(old.red,old.green,old.blue,old.gray)
      carnek_weather_z
    rescue
    end
    def carnek_weather_z
      [@carnek_ambient_weather,@carnek_gameplay_weather].compact.each_with_index do |sys,idx|
        [sys.instance_variable_get(:@sprites),sys.instance_variable_get(:@new_sprites),sys.instance_variable_get(:@tiles)].compact.each do |arr|
          arr.each { |s| s.z = (idx==0 ? 88 : 90) if s.is_a?(Sprite) }
        end
      end
    end
    def carnek_update_ambient_tone
      @carnek_ambient_tone ||= [0.0,0.0,0.0,0.0]
      @carnek_ambient_tone_target ||= [0.0,0.0,0.0,0.0]
      4.times { |i| @carnek_ambient_tone[i] += (@carnek_ambient_tone_target[i]-@carnek_ambient_tone[i])*0.10 }
      arr=[@carnek_ambient_weather&.instance_variable_get(:@sprites),@carnek_ambient_weather&.instance_variable_get(:@new_sprites),@carnek_ambient_weather&.instance_variable_get(:@tiles)].compact
      tone=Tone.new(*@carnek_ambient_tone.map(&:round))
      arr.each { |sprites| sprites.each { |sp| sp.tone=tone if sp.is_a?(Sprite) } }
    rescue
    end
    def pbSetAmbientWeather(type, intensity=nil, duration=30)
      @carnek_ambient_type=type.to_sym
      intensity ||= CarnekStudio::WeatherStudio.weather_cfg(type)["baseIntensity"] || 40
      @carnek_ambient_weather.fade_in(@carnek_ambient_type,intensity.to_i,duration.to_i)
    end
    def pbClearAmbientWeather(duration=30)
      @carnek_ambient_type=:None
      @carnek_ambient_weather.fade_in(:None,0,duration.to_i)
    end
  end
end
if defined?(MidbattleHandlers)
  MidbattleHandlers.add(:midbattle_triggers,"setAmbientWeather",proc{|battle,i,t,p| h=p.is_a?(Hash)?p:{"type"=>p}; battle.scene.pbSetAmbientWeather(h["type"],h["intensity"],h["duration"]||30)})
  MidbattleHandlers.add(:midbattle_triggers,"addAmbientWeather",proc{|battle,i,t,p| h=p.is_a?(Hash)?p:{"type"=>p}; battle.scene.pbSetAmbientWeather(h["type"],h["intensity"],h["duration"]||30)})
  MidbattleHandlers.add(:midbattle_triggers,"removeAmbientWeather",proc{|battle,i,t,p| battle.scene.pbClearAmbientWeather(30)})
  MidbattleHandlers.add(:midbattle_triggers,"clearAmbientWeather",proc{|battle,i,t,p| battle.scene.pbClearAmbientWeather((p||30).to_i)})
  MidbattleHandlers.add(:midbattle_triggers,"setAmbientIntensity",proc{|battle,i,t,p| h=p.is_a?(Hash)?p:{"intensity"=>p}; battle.scene.pbSetAmbientWeather(battle.scene.instance_variable_get(:@carnek_ambient_type),h["intensity"],h["duration"]||30)})
end

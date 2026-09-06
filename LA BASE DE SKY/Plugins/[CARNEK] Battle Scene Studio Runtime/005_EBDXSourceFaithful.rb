#===============================================================================
# Battle Scene Studio 0.7.8 - EBDX Core
# Clean rebuild from BSS 0.6.73.
#
# Source authority: Elite Battle: DX 1.4.7.1 (E21) supplied with this build.
# The room compositor, environment definitions, vector projection and camera
# lifecycle are transplanted from EBDX. Essentials/DBK/BSS remain responsible
# for battle logic and HUD, while EBDX is the authority for the battle WORLD.
#===============================================================================

# Minimal Luka-compatible helpers required by the transplanted scene code.
class Array
  unless method_defined?(:string_include?)
    def string_include?(val)
      return false if !val.is_a?(String)
      any? { |a| a.is_a?(String) && val.include?(a) }
    end
  end
end
class Hash
  unless method_defined?(:try_key?)
    def try_key?(*args); args.all? { |k| key?(k) && !!self[k] }; end
  end
  unless method_defined?(:get_key)
    def get_key(key); key?(key) ? self[key] : nil; end
  end
end
class Tone
  unless method_defined?(:all)
    def all; (red + green + blue) / 3.0; end
    def all=(val); self.red=val; self.green=val; self.blue=val; end
  end
end
class Color
  def self.black; Color.new(0,0,0); end unless respond_to?(:black)
end

module BSS070EBDXCore
  VERSION = "0.7.8"
  ROOM_SCALE = 2.25
  BATTLE_MOTION_TIMER = 90
  FRAME_RATE = 40
  DISABLE_SCENE_MOTION = false
  ASSET_ROOT = "Graphics/BattleSceneStudio/EBDX"
  CAMERA_MOTION = [
    [132,408,24,302,1,1], [122,294,20,322,1,1], [238,304,26,322,1,1],
    [0,384,26,322,1,1], [198,298,18,282,1,1], [196,306,26,242,0.6,1],
    [156,280,18,226,0.6,1], [60,280,12,388,1,1], [160,286,16,340,1,1]
  ]
  MAIN_FALLBACK = [102,408,32,342,1,1]
  BUILTIN = {}
  TERRAIN = {}
  @next_vectors = []

  class << self
    attr_accessor :position_scene
    def frame_rate; FRAME_RATE; end
    def deep_copy(v)
      Marshal.load(Marshal.dump(v))
    rescue
      v.is_a?(Hash) ? v.inject({}) { |h,(k,x)| h[k]=deep_copy(x); h } : (v.is_a?(Array) ? v.map { |x| deep_copy(x) } : v)
    end
    def bg_hash_map(key)
      {:x=>:ex,:y=>:ey,:bitmap=>:bitmap,:z=>:z,:ox=>:ox,:oy=>:oy,:mirror=>:mirror,
       :zoom=>:param,:opacity=>:opacity,:zoom_x=>:zx,:zoom_y=>:zy,:speed=>:speed,
       :direction=>:direction,:angle=>:angle}[key]
    end
    def get_vector(key, cond=nil)
      return MAIN_FALLBACK.clone if key == :MAIN
      return MAIN_FALLBACK.clone if key == :ENEMY || key == :PLAYER || key == :BATTLER
      MAIN_FALLBACK.clone
    end
    def random_vector(battle, last=nil)
      a = CAMERA_MOTION.map(&:clone)
      a << get_vector(:MAIN,battle)
      a.delete_at(last) if !last.nil? && last.to_i >= 0 && last.to_i < a.length
      a
    end

    # EBDX's authored camera vectors were built around its own compiled battler
    # metrics. BSS deliberately keeps the project's live Essentials/DBK metrics
    # as the positional authority, so full-strength EBDX vectors can be too
    # aggressive after SOS changes side size. These shots preserve the exact
    # EBDX vector geometry but blend it toward MAIN for a continuous Gen 5 feel.
    def blend_vector(base, target, weight)
      w=[[weight.to_f,0.0].max,1.0].min
      row=[]
      6.times do |i|
        b=(base[i] || (i>=4 ? 1.0 : 0.0)).to_f
        t=(target[i] || b).to_f
        row << b + (t-b)*w
      end
      row
    end
    def safe_camera_vectors(battle, mode=:idle)
      main=get_vector(:MAIN,battle)
      return [main.clone] if camera_config["preset"].to_s == "static_gen4"
      ids=case mode.to_s.downcase.to_sym
      when :fight then [0,2,3,8,5,6]
      when :command then [0,3,8,1,2]
      else [0,8,3,2,1,5]
      end
      ids.map { |i| configured_camera_vector(main,CAMERA_MOTION[i],mode) } << main.clone
    end
    def get(key)
      return {} if key == :battlerMetrics
      nil
    end
    def environment_constant(sym)
      name=sym.to_s.upcase
      return BSS070EnvironmentEBDX.const_get(name) if BSS070EnvironmentEBDX.const_defined?(name)
      nil
    rescue
      nil
    end
    def merge!(base, overlay)
      return base if !overlay.is_a?(Hash)
      overlay.each do |k,v|
        if base[k].is_a?(Hash) && v.is_a?(Hash)
          merge!(base[k],v)
        else
          base[k]=deep_copy(v)
        end
      end
      base
    end
    def explicit_name(env)
      n=(env.is_a?(Hash) ? env["ebdxBackdrop"] : nil).to_s.strip
      n="Auto" if n.empty?
      n
    end
    def global_config
      g=(defined?(BSS064) ? BSS064.data["global"] : nil) rescue nil
      g.is_a?(Hash) ? g : {}
    end
    MAP_METADATA_FILE = "Data/BattleSceneStudio/EBDX/map_metadata.json" unless const_defined?(:MAP_METADATA_FILE)
    SCENES_FILE = "Data/BattleSceneStudio/EBDX/scenes.json" unless const_defined?(:SCENES_FILE)
    TEST_OVERRIDE_FILE = "Data/BattleSceneStudio/EBDX/test_override.json" unless const_defined?(:TEST_OVERRIDE_FILE)
    @bss_test_overrides = {} unless defined?(@bss_test_overrides)
    def test_override_for(battle, consume=true)
      return nil if !battle
      # Do not use a rescued nil[index] as control flow here. Essentials debug
      # reports rescued exceptions too, which caused one NoMethodError per frame.
      @bss_test_overrides = {} unless @bss_test_overrides.is_a?(Hash)
      cache=@bss_test_overrides
      key=battle.object_id
      cached=cache[key]
      return cached if cached.is_a?(Hash)
      return nil if !File.exist?(TEST_OVERRIDE_FILE)
      raw=external_json(TEST_OVERRIDE_FILE)
      return nil if !raw.is_a?(Hash) || raw["enabled"]==false
      scene=(raw["scene"] || raw[:scene]).to_s.strip
      return nil if scene.empty?
      row={"scene"=>scene,"oneShot"=>(raw["oneShot"]!=false)}
      cache[key]=row
      if consume && row["oneShot"]
        begin; File.delete(TEST_OVERRIDE_FILE) if File.exist?(TEST_OVERRIDE_FILE); rescue; end
      end
      row
    rescue => e
      BSS064.log("EBDX test override warning: #{e.class}: #{e.message}") if defined?(BSS064)
      nil
    end
    def external_json(path)
      return {} if !File.exist?(path)
      raw=defined?(BSS064) && BSS064.respond_to?(:read_json_file) ? BSS064.read_json_file(path,{}) : {}
      raw.is_a?(Hash) ? raw : {}
    rescue
      {}
    end
    def external_map_metadata
      raw=external_json(MAP_METADATA_FILE)
      maps=raw["maps"] || raw[:maps]
      return maps if maps.is_a?(Hash)
      rows=raw["entries"] || raw[:entries]
      return rows if rows.is_a?(Array)
      raw
    end
    def external_scenes
      raw=external_json(SCENES_FILE)
      rows=raw["scenes"] || raw[:scenes]
      rows.is_a?(Array) ? rows : []
    end
    def camera_config
      d={"preset"=>"gen5_plus","idleStrength"=>28.0,"commandStrength"=>45.0,"fightStrength"=>65.0,"panX"=>100.0,"panY"=>100.0,"angle"=>100.0,"perspective"=>100.0,"zoom"=>100.0,"idleSpeed"=>50.0,"commandSpeed"=>64.0,"fightSpeed"=>76.0,"idleMinFrames"=>120,"idleMaxFrames"=>220,"commandMinFrames"=>70,"commandMaxFrames"=>130,"fightMinFrames"=>50,"fightMaxFrames"=>105,"battlerInfluence"=>100.0,"shadowInfluence"=>100.0,"overscan"=>24.0}
      src=global_config["ebdxCamera"]
      src.each { |k,v| d[k.to_s]=v } if src.is_a?(Hash)
      d
    end
    def camera_strength(mode)
      k=(mode.to_s.downcase.to_sym==:fight ? "fightStrength" : (mode.to_s.downcase.to_sym==:command ? "commandStrength" : "idleStrength"))
      [[camera_config[k].to_f/100.0,0.0].max,1.0].min
    end
    def configured_camera_vector(base,target,mode)
      cfg=camera_config; w=camera_strength(mode)
      scales=[cfg["panX"].to_f/100.0,cfg["panY"].to_f/100.0,cfg["angle"].to_f/100.0,cfg["perspective"].to_f/100.0,cfg["zoom"].to_f/100.0,cfg["zoom"].to_f/100.0]
      6.times.map do |i|
        b=(base[i] || (i>=4 ? 1.0 : 0.0)).to_f;t=(target[i] || b).to_f
        b+(t-b)*w*scales[i]
      end
    end
    def camera_inc(mode)
      cfg=camera_config;k=(mode.to_s.downcase.to_sym==:fight ? "fightSpeed" : (mode.to_s.downcase.to_sym==:command ? "commandSpeed" : "idleSpeed"));p=[[cfg[k].to_f,1.0].max,100.0].min
      0.005 + p*0.00035
    end
    def camera_duration(mode)
      cfg=camera_config;pre=(mode.to_s.downcase.to_sym==:fight ? "fight" : (mode.to_s.downcase.to_sym==:command ? "command" : "idle"));lo=[cfg[pre+"MinFrames"].to_i,20].max;hi=[cfg[pre+"MaxFrames"].to_i,lo].max;lo+(hi>lo ? rand(hi-lo+1) : 0)
    end
    def global_scene_engine
      mode=global_config["battleSceneEngine"].to_s.downcase
      return "vanilla" if ["vanilla","project","essentials","off"].include?(mode)
      return "blueprint" if ["blueprint","mixed","per_battle"].include?(mode)
      "ebdx"
    end
    def global_default_backdrop
      # v0.8.14: the editor has always authored this value as `ebdxBackdrop`.
      # Older runtime builds only read the legacy `ebdxDefaultBackdrop`, which
      # made the game silently fall back to map/biome Auto even while the
      # composer preview showed the selected custom scene. Read both keys, with
      # the current editor key taking authority.
      cfg=global_config || {}
      raw=(cfg["ebdxBackdrop"] || cfg[:ebdxBackdrop] ||
           cfg["ebdxDefaultBackdrop"] || cfg[:ebdxDefaultBackdrop]).to_s.strip
      raw="Auto" if raw.empty? || raw.downcase=="inherit"
      raw
    end
    def current_map_id
      return $game_map.map_id.to_i if defined?($game_map) && $game_map && $game_map.respond_to?(:map_id)
      0
    rescue
      0
    end
    # BSS visual map metadata. New builds store rows as:
    #   [{"mapId"=>79,"backdrop"=>"Water"}, ...]
    # Legacy text mappings are still accepted for old projects.
    def bss_map_backdrop
      id=current_map_id
      return nil if id<=0
      ext=external_map_metadata
      if ext.is_a?(Hash)
        row=ext[id.to_s] || ext[id]
        # JSON object keys are strings, but older/generated caches may contain
        # Integer keys. Never call to_sym on a numeric map id.
        if row.nil?
          pair=ext.find { |k,v| k.to_s == id.to_s } rescue nil
          row=pair[1] if pair
        end
        if row.is_a?(Hash)
          name=(row["scene"] || row[:scene] || row["backdrop"] || row[:backdrop] || row["BattleEnv"] || row[:BattleEnv]).to_s.strip
          if !name.empty? && !["auto","inherit"].include?(name.downcase)
            found=BUILTIN.keys.find { |k| k.to_s.downcase==name.downcase };return found || name
          end
        elsif row
          name=row.to_s.strip;found=BUILTIN.keys.find { |k| k.to_s.downcase==name.downcase };return found || name if !name.empty? && name.downcase!="auto"
        end
      elsif ext.is_a?(Array)
        row=ext.find { |r| r.is_a?(Hash) && (r["mapId"] || r[:mapId] || r["id"] || r[:id]).to_i==id }
        if row
          name=(row["scene"] || row[:scene] || row["backdrop"] || row[:backdrop]).to_s.strip
          found=BUILTIN.keys.find { |k| k.to_s.downcase==name.downcase };return found || name if !name.empty? && !["auto","inherit"].include?(name.downcase)
        end
      end
      rows=global_config["ebdxMapMetadata"]
      if rows.is_a?(Array)
        row=rows.find do |r|
          r.is_a?(Hash) && (r["mapId"] || r[:mapId] || r["id"] || r[:id]).to_i==id
        end
        if row
          name=(row["backdrop"] || row[:backdrop] || row["BattleEnv"] || row[:BattleEnv]).to_s.strip
          if !name.empty? && name.downcase!="auto" && name.downcase!="inherit"
            found=BUILTIN.keys.find { |k| k.to_s.downcase==name.downcase }
            return found || name
          end
        end
      end
      text=global_config["ebdxMapBackdropsText"].to_s
      text.each_line do |line|
        row=line.sub(/#.*/,"").strip
        next if row.empty?
        m=row.match(/\A(\d+)\s*(?:=|:|=>)\s*([A-Za-z0-9_ -]+?)\s*\z/)
        next if !m || m[1].to_i!=id
        name=m[2].to_s.strip
        found=BUILTIN.keys.find { |k| k.to_s.downcase==name.downcase }
        return found || name
      end
      nil
    rescue
      nil
    end
    # Compatibility with EBDX's own map metadata cache. If a project already has
    # Data/maps.ebdx, honor BattleEnv exactly like EBDX instead of forcing users
    # to duplicate their map setup in BSS.
    def original_ebdx_map_backdrop
      id=current_map_id
      return nil if id<=0 || !File.exist?("Data/maps.ebdx")
      raw=load_data("Data/maps.ebdx") rescue nil
      return nil if !raw.is_a?(Hash)
      entry=raw[id] || raw[id.to_s]
      return nil if !entry.is_a?(Hash)
      sections=[]
      begin
        sections << "spring" if defined?(pbIsSpring) && pbIsSpring
        sections << "summer" if defined?(pbIsSummer) && pbIsSummer
        sections << "autumn" if defined?(pbIsAutumn) && pbIsAutumn
        sections << "winter" if defined?(pbIsWinter) && pbIsWinter
      rescue
      end
      sections << "__pk__"
      sections.each do |section|
        sec=entry[section] || entry[section.to_s.to_sym] || entry[section.upcase] || entry[section.to_s.upcase.to_sym]
        next if !sec.is_a?(Hash)
        env=sec["BattleEnv"] || sec[:BattleEnv] || sec["BATTLEENV"] || sec[:BATTLEENV]
        env=env[0] if env.is_a?(Array)
        next if env.nil? || env.to_s.strip.empty?
        name=env.to_s.strip
        aliases={"OUTDOOR"=>"Field","DARKCAVE"=>"CaveDark","INDOOR"=>"IndoorA","DISCO"=>"DanceFloor","MOUNTAINLAKE"=>"MountainLake","DIMENSION"=>"Dimension","CHAMPION"=>"Champion","STAGE"=>"Stage","DARKNESS"=>"Darkness","MAGMA"=>"Magma","SKY"=>"Sky","SNOW"=>"Snow","UNDERWATER"=>"Underwater","FOREST"=>"Forest","WATER"=>"Water","CAVE"=>"Cave","MOUNTAIN"=>"Mountain"}
        name=aliases[name.upcase] || name
        found=BUILTIN.keys.find { |k| k.to_s.downcase==name.downcase }
        return found || name
      end
      nil
    rescue => e
      BSS064.log("EBDX maps.ebdx read warning: #{e.class}: #{e.message}") if defined?(BSS064)
      nil
    end
    def map_backdrop
      bss_map_backdrop || original_ebdx_map_backdrop
    end
    def active_for_battle?(battle)
      return false if !battle
      return true if test_override_for(battle)
      env=(battle.respond_to?(:bss_environment_config) ? battle.bss_environment_config : nil) rescue nil
      env={} if !env.is_a?(Hash)
      global_mode=global_scene_engine
      # The global selector is a true master switch for quick A/B testing.
      return true if global_mode=="ebdx"
      return false if global_mode=="vanilla"
      mode=env["sceneMode"].to_s.downcase
      return true  if mode=="ebdx"
      return false if ["project","vanilla","essentials","off"].include?(mode)
      false
    rescue
      false
    end
    def custom_environment(name)
      ext=external_scenes
      if ext.is_a?(Array)
        row=ext.find { |r| r.is_a?(Hash) && (r["id"] || r[:id]).to_s.downcase==name.to_s.downcase }
        data=row && (row["data"] || row[:data]);return deep_copy(data) if data.is_a?(Hash)
      end
      rows=global_config["ebdxCustomEnvironments"]
      return nil if !rows.is_a?(Array)
      row=rows.find { |r| r.is_a?(Hash) && (r["id"] || r[:id]).to_s.downcase==name.to_s.downcase }
      data=row && (row["data"] || row[:data])
      data.is_a?(Hash) ? deep_copy(data) : nil
    rescue
      nil
    end
    def environment_for(scene)
      battle=scene.instance_variable_get(:@battle) rescue nil
      env=(battle && battle.respond_to?(:bss_environment_config)) ? battle.bss_environment_config : {}
      env={} if !env.is_a?(Hash)
      test=test_override_for(battle)
      selected=explicit_name(env)
      explicit=(selected.downcase!="auto")
      key=selected
      contextual_auto=false
      if test && !(test["scene"] || test[:scene]).to_s.strip.empty?
        key=(test["scene"] || test[:scene]).to_s.strip
        explicit=true
      elsif !explicit
        # Priority: BSS map override -> original EBDX maps.ebdx -> global test
        # backdrop -> contextual EBDX environment/terrain resolution.
        mapped=map_backdrop
        fallback=global_default_backdrop
        # v0.8.26: editor tests no longer alter global configuration. The old
        # ebdxBackdropForceGlobal flag is deliberately ignored so a stale test
        # from older builds cannot keep overriding map/context metadata.
        if mapped
          key=mapped
        elsif fallback.to_s.downcase!="auto"
          key=fallback
        else
          key=auto_environment_name(battle,env)
          contextual_auto=true
        end
      end
      canonical=BUILTIN.keys.find { |x| x.to_s.downcase==key.to_s.downcase } || key
      data=custom_environment(canonical) || deep_copy(BUILTIN[canonical] || BUILTIN["Field"])
      # Only contextual Auto may merge TerrainTag. A Blueprint, map mapping,
      # maps.ebdx BattleEnv or global test backdrop is an authored EBDX room and
      # must never be rewritten by Dirt/Grass/Water from Essentials.
      if contextual_auto
        terrain=auto_terrain_name(battle)
        merge!(data, TERRAIN[terrain]) if terrain && TERRAIN[terrain]
      end
      custom=env["backgroundGraphic"].to_s.strip.tr("\\","/")
      if !custom.empty? && custom =~ /\AGraphics\/.+\.(?:png|gif|jpg|jpeg|webp|bmp)\z/i
        data["backdrop"]=custom
      end
      data
    rescue => e
      BSS064.log("EBDX environment resolve warning: #{e.class}: #{e.message}") if defined?(BSS064)
      deep_copy(BUILTIN["Field"] || {"backdrop"=>"Field","sky"=>true})
    end
    def auto_environment_name(battle,env={})
      raw=(env["battleback"] rescue "").to_s
      BUILTIN.keys.each { |k| return k if raw.downcase.include?(k.downcase) }
      e=(battle.environment rescue nil)
      s=e.to_s.downcase
      return "Water" if s.include?("water")
      return "Cave" if s.include?("cave")
      return "Snow" if s.include?("snow") || s.include?("ice")
      return "Sand" if s.include?("sand")
      return "Forest" if s.include?("forest") || s.include?("grass")
      return "Mountain" if s.include?("rock") || s.include?("mountain")
      "Field"
    end
    def auto_terrain_name(battle)
      s=(battle.environment rescue nil).to_s.downcase
      return "water" if s.include?("water")
      return "tallgrass" if s.include?("tallgrass") || s.include?("grass")
      return "dirt" if s.include?("dirt")
      return "concrete" if s.include?("concrete") || s.include?("paved")
      return "mountain" if s.include?("rock") || s.include?("mountain")
      nil
    end
    def log
      @logger ||= Object.new.tap do |obj|
        def obj.warn(msg); BSS064.log(msg) if defined?(BSS064); end
      end
    end
    def playCommonAnimation(*args)
      false
    end
    def fallback_screen_position(i,battle=nil)
      side=i.to_i%2
      rank=i.to_i/2
      if side==0
        [[160,360,50],[95,310,45],[225,405,55]][rank] || [160,360,50]
      else
        [[480,190,50],[550,245,55],[415,145,45]][rank] || [480,190,50]
      end
    end
  end
end

# Exact EBDX vector projection/update semantics, kept private to BSS.
class BSS070EBDXVector
  attr_reader :x,:y,:angle,:scale,:x2,:y2
  attr_accessor :zoom1,:zoom2,:inc,:set,:battle
  def initialize(x=0,y=0,angle=0,scale=1,zoom1=1,zoom2=1)
    @battle=false; @x=x.to_f; @y=y.to_f; @angle=angle.to_f; @scale=scale.to_f
    @zoom1=zoom1.to_f; @zoom2=zoom2.to_f; @inc=0.2
    @set=[@x,@y,@angle,@scale,@zoom1,@zoom2]; @locked=false; @force=false; @constant=1
    calculate
  end
  def calculate
    a=@angle*(Math::PI/180); @x2=@x+Math.cos(a)*@scale; @y2=@y-Math.sin(a)*@scale
  end
  def spoof(*args)
    x,y,a,s,z1,z2 = args[0].is_a?(Array) ? args[0] : args
    a=a.to_f*(Math::PI/180); [x.to_f+Math.cos(a)*s.to_f,y.to_f-Math.sin(a)*s.to_f]
  end
  def angle=(v); @angle=v.to_f; calculate; end
  def scale=(v); @scale=v.to_f; calculate; end
  def x=(v); @x=v.to_f; @set[0]=@x; calculate; end
  def y=(v); @y=v.to_f; @set[1]=@y; calculate; end
  def force; @force=true; end
  def reset; @inc=0.2; set(BSS070EBDXCore.get_vector(:MAIN,@battle)); end
  def set(*args)
    @force=false
    row=args[0].is_a?(Array) ? args[0] : args
    return if row.length<5
    row=row.clone; row << 1 if row.length<6
    @set=row.map(&:to_f); @constant=rand(4)+1
  end
  def setXY(x,y); @set[0]=x.to_f; @set[1]=y.to_f; end
  # BSS 0.7.8: animation ownership needs a deterministic EBDX baseline.
  # EBDX itself frequently jumps to a purpose-authored vector before sendout/
  # move sequences; interpolating from the Fight-menu shot made BAS/SOS inherit
  # an arbitrary zoom and then scale it again.
  def snap(*args)
    row=args[0].is_a?(Array) ? args[0] : args
    return if row.length<5
    row=row.clone; row << 1 if row.length<6
    @x,@y,@angle,@scale,@zoom1,@zoom2=row[0,6].map(&:to_f)
    @set=[@x,@y,@angle,@scale,@zoom1,@zoom2]
    @force=false; @constant=1
    calculate
    self
  end
  def locked?; @locked; end
  def lock; @locked=!@locked; end
  def update
    return if @locked
    @x+=((@set[0]-@x)*@inc); @y+=((@set[1]-@y)*@inc)
    @angle+=((@set[2]-@angle)*@inc); @scale+=((@set[3]-@scale)*@inc)
    @zoom1+=((@set[4]-@zoom1)*@inc); @zoom2+=((@set[5]-@zoom2)*@inc)
    calculate
  end
  def get; [@x,@y,@angle,@scale,@zoom1,@zoom2]; end
  def finished?; ((@set[0]-@x)*@inc).abs <= 0.00001*@constant; end
end

class BSS070EBDXSprite < Sprite
  attr_reader :storedBitmap
  attr_accessor :direction,:speed,:toggle,:end_x,:end_y,:param,:skew_d,:ex,:ey,:zx,:zy
  def initialize(viewport=nil); super(viewport); default!; end
  def default!; @speed=1;@toggle=1;@end_x=0;@end_y=0;@ex=0;@ey=0;@zx=1;@zy=1;@param=1;@direction=1; end
  def width; bitmap ? bitmap.width : 0; end
  def height; bitmap ? bitmap.height : 0; end
  def zoom; zoom_x; end
  def zoom=(v); self.zoom_x=v;self.zoom_y=v; end
  def center!(snap=false); self.ox=width/2;self.oy=height/2;if snap&&viewport;self.x=viewport.rect.width/2;self.y=viewport.rect.height/2;end;end
  def bottom!; self.ox=width/2;self.oy=height;end
  def create_rect(w,h,c); self.bitmap=Bitmap.new(w,h);bitmap.fill_rect(0,0,w,h,c);end
  def setBitmap(file,*args); self.bitmap=file.is_a?(Bitmap) ? file : pbBitmap(file); end
  def memorize_bitmap(b=nil); @storedBitmap=(b || bitmap).clone if (b || bitmap); end
  def restore_bitmap; self.bitmap=@storedBitmap.clone if @storedBitmap; end
  def x_mid; @calMidX || (bitmap ? bitmap.width/2 : ox); end
  def skew(angle=90)
    return if !bitmap || angle==@skew_d
    src=@storedBitmap || bitmap
    pi=angle*(Math::PI/180); extra=(angle==90 ? 0 : ((src.height-1)/Math.tan(pi)).abs.to_i)
    out=Bitmap.new(src.width+extra,src.height)
    src.height.times do |i|
      y=src.height-i; x=(angle==90 ? 0 : (i/Math.tan(pi)).to_i)
      out.blt(x,y,src,Rect.new(0,y,src.width,1)) if y>=0 && y<src.height
    end
    self.bitmap=out; @calMidX=(angle<=90 ? src.width/2 : out.width-src.width/2); @skew_d=angle
  rescue
    @skew_d=angle
  end
  def colorize(c,amt=255)
    return if !c
    self.color=Color.new(c.red,c.green,c.blue,amt) rescue nil
  end
end

class BSS070EBDXAnimatedSprite < BSS070EBDXSprite
  def setBitmap(file,scale=1,speed=2)
    src=file.is_a?(Bitmap) ? file : pbBitmap(file)
    side=src.height
    @frames=[]
    count=[(src.width.to_f/side).ceil,1].max
    count.times do |i|
      bmp=Bitmap.new(side*scale.to_i,side*scale.to_i)
      bmp.stretch_blt(bmp.rect,src,Rect.new(i*side,0,[side,src.width-i*side].min,side))
      @frames << bmp
    end
    @anim_index=0;@anim_tick=0;@anim_wait=[speed.to_i,1].max
    self.bitmap=@frames[0].clone
  end
  def update
    return if !@frames || @frames.empty?
    @anim_tick+=1;return if @anim_tick<@anim_wait
    @anim_tick=0;@anim_index=(@anim_index+1)%@frames.length
    begin; self.bitmap.dispose if bitmap && !bitmap.disposed?; rescue; end
    self.bitmap=@frames[@anim_index].clone
  end
  def dispose
    @frames.each{|b| begin;b.dispose if b&&!b.disposed?;rescue;end} if @frames
    @frames=[]
    super
  end
end

class BSS070EBDXScrollingSprite < BSS070EBDXSprite
  attr_accessor :vertical,:pulse,:min_o,:max_o
  def setBitmap(val,vertical=false,pulse=false)
    src=val.is_a?(Bitmap) ? val : pbBitmap(val); @vertical=!!vertical;@pulse=!!pulse
    @direction=1 if @direction.nil?;@frame=0.0;@speed=32 if @speed.nil?;@min_o=0;@max_o=255;@gopac=1
    if @vertical
      self.bitmap=Bitmap.new(src.width,src.height*2);2.times{|i|bitmap.blt(0,src.height*i,src,src.rect)}
      self.src_rect.set(0,@direction>0 ? 0 : src.height,src.width,src.height)
    else
      self.bitmap=Bitmap.new(src.width*2,src.height);2.times{|i|bitmap.blt(src.width*i,0,src,src.rect)}
      self.src_rect.set(@direction>0 ? 0 : src.width,0,src.width,src.height)
    end
  end
  def update
    return if !bitmap
    @scroll_accum ||= 0.0
    @scroll_accum += @speed.to_f.abs
    pixels=@scroll_accum.floor
    @scroll_accum -= pixels
    if pixels>0
      shift=pixels * (@direction.to_f<0 ? -1 : 1)
      if @vertical
        self.src_rect.y+=shift; h=self.src_rect.height
        self.src_rect.y-=h while self.src_rect.y>=h
        self.src_rect.y+=h while self.src_rect.y<0
      else
        self.src_rect.x+=shift; w=self.src_rect.width
        self.src_rect.x-=w while self.src_rect.x>=w
        self.src_rect.x+=w while self.src_rect.x<0
      end
      if @pulse
        self.opacity-=@gopac*pixels
        @gopac*=-1 if opacity<=@min_o || opacity>=@max_o
      end
    end
  end
end
class BSS070EBDXSheetSprite < BSS070EBDXSprite
  attr_accessor :speed
  def initialize(viewport,frames=1);@frames=[frames.to_i,1].max;@cur=0;@tick=0;@vertical=false;super(viewport);end
  def setBitmap(file,vertical=false);self.bitmap=file.is_a?(Bitmap)?file:pbBitmap(file);@vertical=!!vertical;if @vertical;src_rect.height=bitmap.height/@frames;else;src_rect.width=bitmap.width/@frames;end;end
  def update;return if !bitmap;@tick+=1;wait=[@speed.to_i,1].max;return if @tick<wait;@tick=0;@cur=(@cur+1)%@frames;if @vertical;src_rect.y=@cur*src_rect.height;else;src_rect.x=@cur*src_rect.width;end;end
end
class BSS070EBDXRainbowSprite < BSS070EBDXSprite
  attr_accessor :speed
  def setBitmap(val,speed=1);@source=(val.is_a?(Bitmap)?val:pbBitmap(val)).clone;@speed=speed.to_f;self.bitmap=@source.clone;@hue=0;end
  def update;return if !@source;@hue=(@hue+[1,@speed.abs].max)%360;self.bitmap.dispose if bitmap && !bitmap.disposed?;self.bitmap=@source.clone;bitmap.hue_change(@hue.to_i);end
end

#===============================================================================
#  Elite Battle: DX
#    by Luka S.J.
# ----------------
#  Pre-defined battle environment configurations
#
#  Not all configurations are used by default.
#  Edit the appropriate battle scene here to have it reflected
#  or add your own ones.
#===============================================================================
module BSS070EnvironmentEBDX
  #-----------------------------------------------------------------------------
  CAVE = {
    "backdrop" => "Cave", "img001" => {
      :scrolling => true, :speed => 2, :direction => -1,
      :bitmap => "decor006",
      :oy => 0, :z => 3, :flat => true, :opacity => 155
    }, "img002" => {
      :scrolling => true, :speed => 1, :direction => 1,
      :bitmap => "decor009",
      :oy => 0, :z => 3, :flat => true, :opacity => 96
    }, "img003" => {
      :scrolling => true, :speed => 0.5, :direction => 1,
      :bitmap => "fog",
      :oy => 0, :z => 4, :flat => true
    }
  }
  #-----------------------------------------------------------------------------
  DARKCAVE = {
    "backdrop" => "CaveDark", "img003" => {
      :scrolling => true, :speed => 0.5, :direction => 1,
      :bitmap => "fog",
      :oy => 0, :z => 4, :flat => true
    }, "bubbles" => "bubbleDark"
  }
  #-----------------------------------------------------------------------------
  WATER = { "backdrop" => "Water", "sky" => true, "water" => true }
  #-----------------------------------------------------------------------------
  UNDERWATER = {
    "backdrop" => "Underwater", "lightsC" => true, "img001" => {
      :bitmap => "forestShade", :z => 1, :flat => true,
      :oy => 0, :y => 94, :sheet => true, :frames => 2, :speed => 16
    }, "tallGrass" => {
      :elements => 5, :bitmap => "seaWeed",
      :x => [124,274,62,248,275],
      :y => [160,140,185,246,174],
      :z => [2,1,17,27,17],
      :zoom => [0.5,0.15,0.6,1,0.5],
      :mirror => [false,true,true,false,true]
    }, "bubbles" => true, "outdoor" => false, "underwater" => true
  }
  #-----------------------------------------------------------------------------
  FOREST = {
    "backdrop" => "Forest", "lightsC" => true, "img001" => {
      :bitmap => "forestShade", :z => 1, :flat => true,
      :oy => 0, :y => 94, :sheet => true, :frames => 2, :speed => 16
    }, "trees" => {
      :bitmap => "treePine", :colorize => false, :elements => 8,
      :x => [92,248,300,40,138,216,274,318],
      :y => [132,132,144,118,112,118,110,110],
      :zoom => [1,1,1.1,0.9,0.8,0.85,0.75,0.75],
      :z => [2,2,2,1,1,1,1,1],
    }, "outdoor" => false
  }
  #-----------------------------------------------------------------------------
  INDOOR = {
    "backdrop" => "IndoorA", "img001" => {
      :bitmap => "decor007",
      :oy => 0, :z => 1, :flat => true, :scrolling => true, :speed => 0.5
    }, "img002" => {
      :bitmap => "decor008",
      :oy => 0, :z => 1, :flat => true, :scrolling => true, :direction => -1
    }, "lightsA" => true, "outdoor" => false
  }
  #-----------------------------------------------------------------------------
  OUTDOOR = {
    "backdrop" => "Field", "sky" => true, "trees" => {
      :elements => 9,
      :x => [150,271,78,288,176,42,118,348,321],
      :y => [108,117,118,126,126,128,136,136,145],
      :zoom => [0.44,0.44,0.59,0.59,0.59,0.64,0.85,0.7,1],
      :mirror => [false,false,true,true,true,false,false,true,false]
    }
  }
  #-----------------------------------------------------------------------------
  DISCO = {
    "backdrop" => "DanceFloor", "img001" => {
      :bitmap => "discoBg",
      :ox => 0, :flat => true, :rainbow => true, :speed => 8
    }, "lightsB" => true, "img002" => {
      :bitmap => "crowd",
      :oy => 32, :y => 102, :z => 2, :flat => false, :sheet => true,
      :vertical => true, :speed => 8, :frames => 2
    }
  }
  #-----------------------------------------------------------------------------
  NET = {
    "backdrop" => "Net", "img001" => {
      :scrolling => true, :vertical => true, :speed => 1,
      :bitmap => "decor003d",
      :oy => 180, :y => 90, :flat => true
    }, "img002" => {
      :bitmap => "crowd_d",
      :oy => 32, :y => 112, :z => 2, :flat => false, :sheet => true,
      :vertical => true, :speed => 8, :frames => 2
    }
  }
  #-----------------------------------------------------------------------------
  MOUNTAIN = {
    "backdrop" => "Mountain", "sky" => true, "trees" => {
      :elements => 8, :bitmap => "treeC", :colorize => "slight",
      :x => [271,78,288,176,42,118,348,321],
      :y => [117,118,122,122,127,127,128,132],
      :zoom => [0.44,0.59,0.59,0.59,0.64,0.85,0.7,1],
      :mirror => [false,true,true,true,false,false,true,false]
    }, "img001" => {
      :bitmap => "mountainC",
      :x => 192, :y => 107
    }
  }
  #-----------------------------------------------------------------------------
  MOUNTAINLAKE = {
    "backdrop" => "Field", "sky" => true, "trees" => {
      :elements => 9,
      :x => [150,271,78,288,176,42,118,348,321],
      :y => [108,117,118,122,122,127,127,128,132],
      :zoom => [0.44,0.44,0.59,0.59,0.59,0.64,0.85,0.7,1],
      :mirror => [false,false,true,true,true,false,false,true,false]
    }, "img001" => {
      :bitmap => "mountain",
      :x => 192, :y => 107
    }, "base" => "Water", "water" => true
  }
  #-----------------------------------------------------------------------------
  DIMENSION = {
    "backdrop" => "Sapphire",
    "vacuum" => "dark006",
    "img001" => {
      :scrolling => true, :vertical => true, :speed => 1,
      :bitmap => "decor003a",
      :oy => 180, :y => 90, :flat => true
    }, "img002" => {
      :bitmap => "shade",
      :oy => 100, :y => 98, :flat => false
    }, "img003" => {
      :scrolling => true, :speed => 16,
      :bitmap => "decor005",
      :oy => 0, :y => 4, :z => 4, :flat => true
    }, "img004" => {
      :scrolling => true, :speed => 16, :direction => -1,
      :bitmap => "decor006",
      :oy => 0, :z => 4, :flat => true
    }, "img005" => {
      :scrolling => true, :speed => 0.5,
      :bitmap => "base001a",
      :oy => 0, :y => 122, :z => 1, :flat => true
    }
  }
  #-----------------------------------------------------------------------------
  CHAMPION = {
    "backdrop" => "Champion",
    "lightsA" => true,
    "img001" => {
      :scrolling => true, :vertical => true, :speed => 1,
      :bitmap => "decor003",
      :oy => 180, :y => 90, :z => 1, :flat => true
    }, "img002" => {
      :bitmap => "decor004",
      :oy => 100, :y => 98, :z => 2, :flat => false
    }, "img003" => {
      :scrolling => true, :speed => 16,
      :bitmap => "decor005",
      :oy => 0, :y => 4, :z => 4, :flat => true
    }, "img004" => {
      :scrolling => true, :speed => 16, :direction => -1,
      :bitmap => "decor006",
      :oy => 0, :z => 4, :flat => true
    }, "img005" => {
      :scrolling => true, :speed => 0.5,
      :bitmap => "base001",
      :oy => 0, :y => 122, :z => 1, :flat => true
    }, "img006" => {
      :bitmap => "pillars001",
      :y => 128, :x => 144, :z => 3
    }, "img007" => {
      :bitmap => "pillars002",
      :y => 192, :x => 144, :z => 18
    },
  }
  #-----------------------------------------------------------------------------
  STAGE = {
    "backdrop" => "IndoorB", "spinLights" => true, "lightsA" => true,
    "img001" => {
      :scrolling => true, :speed => 1,
      :bitmap => "decor001",
      :oy => 0, :z => 1, :flat => true
    }, "img002" => {
      :scrolling => true, :speed => 1, :direction => -1,
      :bitmap => "decor002",
      :oy => 0, :z => 1, :flat => true
    },
  }
  #-----------------------------------------------------------------------------
  DARKNESS = {
    "backdrop" => "Darkness",
    "img001" => {
      :bitmap => "dark001",
      :oy => 70, :ox => 70, :y => 128, :x => 248, :z => 2, :effect => "rotate", :zoom => 0.75
    }, "img002" => {
      :bitmap => "dark002",
      :oy => 120, :ox => 120, :y => 128, :x => 242, :z => 3, :direction => -1, :effect => "rotate", :zoom => 0.75
    }, "img003" => {
      :bitmap => "dark003",
      :oy => 110, :ox => 110, :y => 128, :x => 234, :z => 4, :effect => "rotate"
    }, "img004" => {
      :scrolling => true, :speed => 0.5,
      :bitmap => "darkFog",
      :oy => 0, :y => 0, :z => 5, :flat => true
    }, "vacuum" => true
  }
  #-----------------------------------------------------------------------------
  MAGMA = {
    "backdrop" => "Cave", "img001" => {
      :scrolling => true, :speed => 2, :direction => -1,
      :bitmap => "decor006",
      :oy => 0, :z => 3, :flat => true, :opacity => 155
    }, "img002" => {
      :scrolling => true, :speed => 1, :direction => 1,
      :bitmap => "decor009",
      :oy => 0, :z => 3, :flat => true, :opacity => 96
    }, "img003" => {
      :scrolling => true, :speed => 0.5, :direction => 1,
      :bitmap => "fog",
      :oy => 0, :z => 4, :flat => true
    }, "bubbles" => "bubbleRed", "img005" => {
      :scrolling => true, :speed => 0.5, :direction => -1,
      :bitmap => "base001",
      :oy => 0, :y => 122, :z => 1, :flat => true
    }
  }
  #-----------------------------------------------------------------------------
  SKY = {
    "backdrop" => "sky", "trees" => {
        :bitmap => "cluster", :colorize => false, :elements => 12,
        :x => [26,6,44,4,136,104,372,342,236,180,214,282],
        :y => [184,210,216,258,188,278,212,284,234,238,258,170],
        :mirror => [false,false,true,true,false,false,true,false,false,false,false,false],
        :zoom => [1,1,1,1,1,1,1,1,1,1,1,0.7],
        :z => [2,2,2,2,2,2,2,2,2,2,2,2],
      }, "sky" => true, "noshadow" => true, "img001" => {
        :scrolling => true, :speed => 0.5,
        :bitmap => "base001c",
        :oy => 0, :y => 122, :z => 3, :flat => true
      }
  }
  #-----------------------------------------------------------------------------
  SNOW = {
    "backdrop" => "Snow", "sky" => true, "trees" => {
      :elements => 9,
      :x => [150,271,78,288,176,42,118,348,321],
      :y => [108,117,118,126,126,128,136,136,145],
      :zoom => [0.44,0.44,0.59,0.59,0.59,0.64,0.85,0.7,1],
      :mirror => [false,false,true,true,true,false,false,true,false],
      :colorize => "slight", :bitmap => "treeB"
    }, "img001" => {
      :bitmap => "mountainB",
      :x => 192, :y => 107
    }
  }
end
#===============================================================================
#  Extra additions to the battle scene based on terrain
#===============================================================================
module BSS070TerrainEBDX
  #-----------------------------------------------------------------------------
  MOUNTAIN = { "img001" => { :bitmap => "mountain", :x => 192, :y => 107 } }
  #-----------------------------------------------------------------------------
  PUDDLE = { "base" => "Puddle" }
  #-----------------------------------------------------------------------------
  DIRT = { "base" => "Dirt" }
  #-----------------------------------------------------------------------------
  TALLGRASS = {
    "tallGrass" => {
      :elements => 7,
      :x => [124,274,204,62,248,275,182],
      :y => [160,140,140,185,246,174,170],
      :z => [2,1,2,17,27,17,17],
      :zoom => [0.7,0.35,0.5,1,1.5,0.7,1],
      :mirror => [false,true,false,true,false,true,false]
    }
  }
  #-----------------------------------------------------------------------------
  CONCRETE = { "base" => "Concrete" }
  #-----------------------------------------------------------------------------
  WATER = { "base" => "Water", "water" => true }
end

BSS070EBDXCore::BUILTIN.merge!({
  "Field"=>BSS070EnvironmentEBDX::OUTDOOR,"Forest"=>BSS070EnvironmentEBDX::FOREST,
  "Cave"=>BSS070EnvironmentEBDX::CAVE,"CaveDark"=>BSS070EnvironmentEBDX::DARKCAVE,
  "Water"=>BSS070EnvironmentEBDX::WATER,"Underwater"=>BSS070EnvironmentEBDX::UNDERWATER,
  "IndoorA"=>BSS070EnvironmentEBDX::INDOOR,"DanceFloor"=>BSS070EnvironmentEBDX::DISCO,
  "Net"=>BSS070EnvironmentEBDX::NET,"Mountain"=>BSS070EnvironmentEBDX::MOUNTAIN,
  "MountainLake"=>BSS070EnvironmentEBDX::MOUNTAINLAKE,"Dimension"=>BSS070EnvironmentEBDX::DIMENSION,
  "Champion"=>BSS070EnvironmentEBDX::CHAMPION,"Stage"=>BSS070EnvironmentEBDX::STAGE,
  "Darkness"=>BSS070EnvironmentEBDX::DARKNESS,"Magma"=>BSS070EnvironmentEBDX::MAGMA,
  "Sky"=>BSS070EnvironmentEBDX::SKY,"Snow"=>BSS070EnvironmentEBDX::SNOW,
  "City"=>{"backdrop"=>"City"},"Sand"=>{"backdrop"=>"Sand"},
  "IndoorB"=>{"backdrop"=>"IndoorB"},"Sapphire"=>{"backdrop"=>"Sapphire"}
})
BSS070EBDXCore::TERRAIN.merge!({
  "mountain"=>BSS070TerrainEBDX::MOUNTAIN,"puddle"=>BSS070TerrainEBDX::PUDDLE,
  "dirt"=>BSS070TerrainEBDX::DIRT,"tallgrass"=>BSS070TerrainEBDX::TALLGRASS,
  "concrete"=>BSS070TerrainEBDX::CONCRETE,"water"=>BSS070TerrainEBDX::WATER
})

#===============================================================================
# EBDX Battle Core compatibility layer
# Source-faithful helpers required by BattleSceneRoom/Vector.
# Guarded so existing project implementations remain authoritative.
#===============================================================================
class Battle
  def doublebattle?; return (pbSideSize(0) > 1 || pbSideSize(1) > 1); end unless method_defined?(:doublebattle?)
  def triplebattle?; return (pbSideSize(0) > 2 || pbSideSize(1) > 2); end unless method_defined?(:triplebattle?)
  def pbMaxSize(index = nil)
    return [pbSideSize(0), pbSideSize(1)].max if index.nil?
    return pbSideSize(index)
  end unless method_defined?(:pbMaxSize)
end

class BSS070EBDXRoom
  attr_reader :data
  attr_accessor :dynamax
  #-----------------------------------------------------------------------------
  # class constructor
  #-----------------------------------------------------------------------------
  def initialize(viewport, scene, data)
    @viewport = viewport
    @scene = scene
    @battle = @scene.battle
    @doublebattle = @battle.doublebattle?
    @sprites = {}
    @fpIndex = 0
    @wind = 90
    @wWait = 0
    @toggle = 0.5
    # Continuous sub-frame phase for foliage. Original EBDX redraws/skews the
    # bitmap in discrete integer steps; at 640x480 that reads as visible ticks.
    # Keep the EBDX wind state for authored img effects, while trees/grass use a
    # smooth bottom-pivot sway that never rebuilds their bitmaps.
    @wind_phase = rand * Math::PI * 2.0
    @disposed = false
    @strongwind = false
    @dynamax = false
    @weather = nil
    @focused = true
    @queued = nil
    @data = data
    @backup = data.clone
    @defaultvector = BSS070EBDXCore.get_vector(:MAIN, @battle)
    @sunny = false
    # draws elements based on data
    self.refresh(data)
  end
  #-----------------------------------------------------------------------------
  # applies data hash to object
  #-----------------------------------------------------------------------------
  def bss076_dispose_owned_sprites!
    return if !@sprites.is_a?(Hash)
    @sprites.keys.clone.each do |key|
      sprite=@sprites[key] rescue nil
      begin
        sprite.dispose if sprite && !(sprite.disposed? rescue false)
      rescue
      end
    end
    @sprites.clear
  end
  def refresh(*args)
    unless args[0].is_a?(Hash)
      @sprites[args[0]] = args[1] if args[0].is_a?(String) && args.length > 1
      return
    end
    @fpIndex = 0
    # disposes sprites if they exist
    bss076_dispose_owned_sprites!
    sx, sy = @scene.vector.spoof(@defaultvector)
    # void sprite
    @sprites["void"] = BSS070EBDXSprite.new(@viewport)
    @sprites["void"].z = -10
    # The vanilla-sized void was transformed by BAS' render camera together with
    # the room. A centered Aura shot could therefore move its right edge inside
    # the viewport and expose black. Keep a generous EBDX-owned safety canvas.
    @overscan_pad = [(@viewport.width * 0.5).to_i, 192].max
    @sprites["void"].bitmap = Bitmap.new(@viewport.width + @overscan_pad*2, @viewport.height + @overscan_pad*2)
    @sprites["void"].x = -@overscan_pad
    @sprites["void"].y = -@overscan_pad
    # draws backdrop
    @sprites["bg"] = BSS070EBDXSprite.new(@viewport)
    @sprites["bg"].z = 0
    # draws base
    @baseBmp = nil
    # draws elements from data block (prority added to predefined modules)
    for key in ["backdrop", "base", "water", "spinningLights", "outdoor", "sky", "trees", "tallGrass", "spinLights",
               "lightsA", "lightsB", "lightsC", "vacuum", "bubbles"] # to sort the order
      next if !@data.has_key?(key)
      case key
      when "backdrop" # adds custom background image
        path = pbResolveBitmap(@data["backdrop"]) ? @data["backdrop"] : "Graphics/BattleSceneStudio/EBDX/Battlebacks/battlebg/" + @data["backdrop"]
        tbmp = pbBitmap(path)
        @sprites["bg"].bitmap = Bitmap.new(tbmp.width, tbmp.height)
        @sprites["bg"].bitmap.blt(0, 0, tbmp, tbmp.rect)
        tbmp.dispose
      when "base" # blt base onto backdrop
        str = pbResolveBitmap(@data["base"]) ? @data["base"] : "Graphics/BattleSceneStudio/EBDX/Battlebacks/base/" + @data["base"]
        @baseBmp = pbBitmap(str) if str
      when "sky" # adds dynamic sky to scene
        self.drawSky
      when "trees" # adds array of trees to scene
        self.drawTrees
      when "tallGrass" # adds array of tall grass to scene
        self.drawGrass
      when "spinLights" # adds PWT styled spinning base lights
        self.drawSpinLights
      when "lightsA" # adds PWT styled stage lights
        self.drawLightsA
      when "lightsB" # adds disco styled stage lights
        self.drawLightsB
      when "lightsC" # adds ambiental scene lights
        self.drawLightsC
      when "water" # adds water animation effect
        self.drawWater
      when "vacuum"
        self.vacuumWaves(@data[key]) # draws vacuum waves
      when "bubbles"
        self.bubbleStream(@data[key]) # draws bubble particles
      end
    end
    # draws additional modules where sequencing is disregarded
    for key in @data.keys
      if key.include?("img")
        self.drawImg(key)
      end
    end
    # applies backdrop positioning
    if @sprites["bg"].bitmap
      @sprites["bg"].center!
      @sprites["bg"].ox = sx/1.5 - 16
      @sprites["bg"].oy = sy/1.5 + 16
      # EBDX authored its camera math around a 384x308 world. Custom BSS rooms
      # can deliberately provide a wider/taller canvas so lateral/zoom shots do
      # not expose the edge. Keep the original EBDX logical 384x308 region in
      # the centre of that canvas instead of treating pixel 0 as the old origin.
      if @data["wideWorld"] == true || @sprites["bg"].bitmap.width > 384 || @sprites["bg"].bitmap.height > 308
        logical_w = 384.0
        logical_h = 308.0
        extra_x = [(@sprites["bg"].bitmap.width.to_f  - logical_w) / 2.0, 0.0].max
        extra_y = [(@sprites["bg"].bitmap.height.to_f - logical_h) / 2.0, 0.0].max
        @sprites["bg"].ox += extra_x
        @sprites["bg"].oy += extra_y
        @bss_wide_world_origin = [extra_x, extra_y]
      else
        @bss_wide_world_origin = [0.0, 0.0]
      end
      if @baseBmp
        @sprites["bg"].bitmap.blt(0, @sprites["bg"].bitmap.height - @baseBmp.height, @baseBmp, @baseBmp.rect)
      end
      c1 = @sprites["bg"].bitmap.get_pixel(0, 0)
      c2 = @sprites["bg"].bitmap.get_pixel(0, @sprites["bg"].bitmap.height-1)
      vw=@sprites["void"].bitmap.width; vh=@sprites["void"].bitmap.height
      split=[@overscan_pad.to_i + @viewport.height/2, vh].min
      @sprites["void"].bitmap.fill_rect(0, 0, vw, split, c1)
      @sprites["void"].bitmap.fill_rect(0, split, vw, vh-split, c2)
    end
    # battler sprite positioning
    self.adjustMetrics
    # applies daylight tinting
    self.daylightTint
  end
  #-----------------------------------------------------------------------------
  # sets color of sprite to match the environment
  #-----------------------------------------------------------------------------
  def setColor(target, sprite, color = true)
    return if !target.bitmap || !sprite.ex || !sprite.ey
    c = target.bitmap.get_pixel(sprite.ex, sprite.ey)
    a = (color == "slight") ? 128 : 255
    sprite.colorize(c, a)
  end
  #-----------------------------------------------------------------------------
  # battle room frame update
  #-----------------------------------------------------------------------------
  def update
    return if self.disposed?
    # updates to the spatial warping with respect to the scene vector
    @sprites["bg"].x = @scene.vector.x2
    @sprites["bg"].y = @scene.vector.y2
    sx, sy = @scene.vector.spoof(@defaultvector)
    @sprites["bg"].zoom_x = @scale*((@scene.vector.x2 - @scene.vector.x)*1.0/(sx - @defaultvector[0])*1.0)**0.6
    @sprites["bg"].zoom_y = @scale*((@scene.vector.y2 - @scene.vector.y)*1.0/(sy - @defaultvector[1])*1.0)**0.6
    clamp_camera_to_viewport!
    # updates the vacuum waves
    for j in 0...3
      next if j > @fpIndex/50 || !@sprites["ec#{j}"]
      if @sprites["ec#{j}"].param <= 0
        @sprites["ec#{j}"].param = 1.5
        @sprites["ec#{j}"].opacity = 0
        @sprites["ec#{j}"].ex = 234
      end
      @sprites["ec#{j}"].opacity += (@sprites["ec#{j}"].param < 0.75 ? -4 : 4)/self.delta
      @sprites["ec#{j}"].ex += [1, 2/self.delta].max if (@fpIndex*self.delta)%4 == 0 && @sprites["ec#{j}"].ex < 284
      @sprites["ec#{j}"].ey -= [1, 2/self.delta].min if (@fpIndex*self.delta)%4 == 0 && @sprites["ec#{j}"].ey > 108
      @sprites["ec#{j}"].param -= 0.01/self.delta
    end
    # updates bubble particles
    for j in 0...18
      next if !@sprites["bubble#{j}"]
      if @sprites["bubble#{j}"].ey <= -32
        r = rand(5) + 2
        @sprites["bubble#{j}"].param = 0.16 + 0.01*rand(32)
        @sprites["bubble#{j}"].ey = @sprites["bg"].bitmap.height*0.25 + rand(@sprites["bg"].bitmap.height*0.75)
        @sprites["bubble#{j}"].ex = 32 + rand(@sprites["bg"].bitmap.width - 64)
        @sprites["bubble#{j}"].end_y = 64 + rand(72)
        @sprites["bubble#{j}"].end_x = @sprites["bubble#{j}"].ex
        @sprites["bubble#{j}"].toggle = rand(2) == 0 ? 1 : -1
        @sprites["bubble#{j}"].speed = 1 + 2/((r + 1)*0.4)
        @sprites["bubble#{j}"].z = [2,15,25][rand(3)] + rand(6) - (@focused ? 0 : 100)
        @sprites["bubble#{j}"].opacity = 0
      end
      min = @sprites["bg"].bitmap.height/4
      max = @sprites["bg"].bitmap.height/2
      scale = (2*Math::PI)/((@sprites["bubble#{j}"].bitmap.width/64.0)*(max - min) + min)
      @sprites["bubble#{j}"].opacity += 4 if @sprites["bubble#{j}"].opacity < @sprites["bubble#{j}"].end_y
      @sprites["bubble#{j}"].ey -= [1, @sprites["bubble#{j}"].speed/self.delta].max
      @sprites["bubble#{j}"].ex = @sprites["bubble#{j}"].end_x + @sprites["bubble#{j}"].bitmap.width*0.25*Math.sin(@sprites["bubble#{j}"].ey*scale)*@sprites["bubble#{j}"].toggle
    end
    # update weather particles
    self.updateWeather
    # positions all elements according to the battle backdrop
    self.position
    # updates skyline
    self.updateSky
    # Shadow sprites stay owned by Essentials/Animated Pokemon System. EBDX only
    # applies the room policy to those real shadow sprites instead of expecting
    # DynamicPokemonSprite#noshadow=, which does not exist in this project.
    @scene.bss070_ebdx_apply_shadow_policy(@data.has_key?("noshadow") && @data["noshadow"] == true) if @scene.respond_to?(:bss070_ebdx_apply_shadow_policy)
    # advances a continuous foliage phase every scene frame
    @wind_phase += (@strongwind ? 0.085 : 0.035)
    @wind_phase -= Math::PI*2.0 if @wind_phase > Math::PI*2.0
    # adjusts for wind affected elements
    if @strongwind
      @wind -= @toggle*2
      @toggle *= -1 if @wind < 65 || (@wind >= 70 && @toggle < 0)
    else
      @wWait += 1
      if @wWait > BSS070EBDXCore.frame_rate*5
        mod = @toggle*(2 + (@wind >= 88 && @wind <= 92 ? 2 : 0))
        @wind -= mod
        @toggle *= -1 if @wind <= 80 || @wind >= 100
        @wWait = 0 if @wWait > BSS070EBDXCore.frame_rate*5 + 33
      end
    end
    # additional metrics
    @fpIndex += 1
    @fpIndex = 150 if @fpIndex > 255*self.delta
  end
  #-----------------------------------------------------------------------------
  # Keep EBDX camera vectors, but never expose the authored 384x308 boundary.
  # This is a room-level safety clamp (not a second camera and not a Vanilla
  # layer), so every world element/battler still follows the same EBDX matrix.
  #-----------------------------------------------------------------------------
  def clamp_camera_to_viewport!
    bg=@sprites["bg"]; return if !bg || !bg.bitmap
    cfg=(BSS070EBDXCore.camera_config rescue {})
    margin=(cfg["overscan"] || 24).to_f
    # BAS applies its camera after the room update for the rendered frame. Reserve
    # extra real pixels while that external camera owns the shot so an EBDX-center
    # Aura/BAS pan cannot uncover the authored 384x308 boundary.
    bas_active=(@scene.instance_variable_get(:@bss070_ebdx_bas_frame) rescue false)
    margin += [64.0, @viewport.width*0.10].max if bas_active
    # A position clamp alone cannot cover both sides when a zoom-out makes the
    # backdrop narrower than the viewport. Increase both axes by one uniform
    # factor, preserving EBDX's perspective ratio rather than stretching X/Y.
    zx=bg.zoom_x.to_f; zy=bg.zoom_y.to_f
    zx=0.0001 if zx.abs<0.0001; zy=0.0001 if zy.abs<0.0001
    need_x=(@viewport.width + margin*2.0) / bg.bitmap.width.to_f
    need_y=(@viewport.height + margin*2.0) / bg.bitmap.height.to_f
    factor=[1.0, need_x/zx, need_y/zy].max
    if factor>1.0
      bg.zoom_x=zx*factor; bg.zoom_y=zy*factor
    end
    left=bg.x-bg.ox*bg.zoom_x
    right=left+bg.bitmap.width*bg.zoom_x
    top=bg.y-bg.oy*bg.zoom_y
    bottom=top+bg.bitmap.height*bg.zoom_y
    bg.x-=left+margin if left>-margin
    right=bg.x-bg.ox*bg.zoom_x+bg.bitmap.width*bg.zoom_x
    bg.x+=(@viewport.width+margin-right) if right<@viewport.width+margin
    bg.y-=top+margin if top>-margin
    bottom=bg.y-bg.oy*bg.zoom_y+bg.bitmap.height*bg.zoom_y
    bg.y+=(@viewport.height+margin-bottom) if bottom<@viewport.height+margin
  end

  #-----------------------------------------------------------------------------
  # positions all the elements inside of the room
  #-----------------------------------------------------------------------------
  def position
    for key in @sprites.keys
      next if key == "bg" || key == "0" || key == "void" || key.include?("w_sunny") || key.include?("w_sand") || key.include?("w_fog")
      # updates fancy light effects
      if key.include?("sLight")
        i = key.gsub("sLight","").to_i
        if @sprites["sLight#{i}"] && @scene.vector
          x, y = self.stageLightPos(i)
          @sprites["sLight#{i}"].ex = x
          @sprites["sLight#{i}"].ey = y
          @sprites["sLight#{i}"].update
        end
      end
      x = @sprites["bg"].x - (@sprites["bg"].ox - @sprites[key].ex)*@sprites["bg"].zoom_x
      y = @sprites["bg"].y - (@sprites["bg"].oy - @sprites[key].ey)*@sprites["bg"].zoom_y
      z = @sprites[key].param * @sprites["bg"].zoom_x
      @sprites[key].x = x
      @sprites[key].y = y
      if ["sky", "base", "water"].string_include?(key) || (key.include?("img") && @data[key].try_key?(:flat))
        @sprites[key].zoom_x = @sprites["bg"].zoom_x * (@sprites[key].zx ? @sprites[key].zx : 1)
        @sprites[key].zoom_y = @sprites["bg"].zoom_y * (@sprites[key].zy ? @sprites[key].zy : 1)
      elsif key.include?("sLight") && @sprites[key] && @scene.vector
        z = ((@scene.vector.zoom1**0.6) * ((i%2 == 0) ? 2 : 1) * 1.25)
        @sprites[key].zoom_x = z * @sprites["bg"].zoom_x * @sprites[key].zx
        @sprites[key].zoom_y = z * @sprites["bg"].zoom_y * @sprites[key].zy
      else
        @sprites[key].zoom = z
      end
      # Smooth foliage. Trees/grass pivot from their authored bottom origin and
      # keep fractional motion, avoiding EBDX's integer bitmap-skew ticks. Custom
      # img wind effects retain the source EBDX skew behavior for compatibility.
      if key.include?("tree")
        i=key.gsub("tree","").to_i
        phase=@wind_phase + i*0.61
        amp=@strongwind ? 1.85 : 0.70
        @sprites[key].angle=Math.sin(phase)*amp
      elsif key.include?("grass")
        i=key.gsub("grass","").to_i
        phase=@wind_phase*1.18 + i*0.37
        amp=@strongwind ? 2.40 : 1.05
        @sprites[key].angle=Math.sin(phase)*amp
      elsif key.include?("img") && @data[key] && @data[key].has_key?(:effect) && @data[key][:effect] == "wind"
        @sprites[key].skew(@wind)
        @sprites[key].ox = @sprites[key].x_mid
      end
      # effect for rotating elements
      if key.include?("img") && (@data[key].has_key?(:effect) && @data[key][:effect] == "rotate")
        @sprites[key].angle += @sprites[key].direction * @sprites[key].speed/self.delta
      end
      # effect for lighting updates
      if key.include?("aLight") || key.include?("cLight")
        @sprites[key].opacity -= @sprites[key].toggle*@sprites[key].speed/self.delta
        @sprites[key].toggle *= -1 if @sprites[key].opacity <= 95 || @sprites[key].opacity >= @sprites[key].end_x*255
      end
      if key.include?("bLight")
        if @wWait*self.delta % @sprites[key].speed == 0
          @sprites[key].bitmap = @sprites[key].storedBitmap.clone
          @sprites[key].bitmap.hue_change((rand(8)*45/self.delta).round)
          @sprites[key].opacity = (rand(4) < 2 ? 192 : 0)
        end
      end
      @sprites[key].update
    end
  end
  #-----------------------------------------------------------------------------
  # loads all the necessary elements for the outdoor skybox
  #-----------------------------------------------------------------------------
  def drawSky
    # drawing additional skylines
    key = "Day"
    if @data.try_key?("outdoor")
      key = "Dawn" if PBDayNight.isEvening? || PBDayNight.isMorning?
      key = "Night" if PBDayNight.isNight?
    end
    @sprites["sky"] = BSS070EBDXSprite.new(@viewport)
    @sprites["sky"].bitmap = pbBitmap("Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/sky#{key}")
    @sprites["sky"].oy = @sprites["sky"].bitmap.height
    @sprites["sky"].ex = 0
    @sprites["sky"].ey = @sprites["sky"].oy
    @sprites["sky"].param = 1
    # loop for drawing clouds
    for i in [1,0]
      @sprites["cloud#{i}"] = BSS070EBDXScrollingSprite.new(@viewport)
      @sprites["cloud#{i}"].setBitmap("Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/cloud#{i+1}")
      @sprites["cloud#{i}"].speed = [0.5, 0.5, 0.25][i]
      @sprites["cloud#{i}"].direction = [1, -1, 1][i]
      @sprites["cloud#{i}"].oy = @sprites["cloud#{i}"].bitmap.height
      @sprites["cloud#{i}"].ex = 0
      @sprites["cloud#{i}"].ey = [98, 91, 30][i]
      @sprites["cloud#{i}"].param = 1
      @sprites["cloud#{i}"].visible = !PBDayNight.isNight? || !@data.try_key?("outdoor")
      self.setColor(@sprites["sky"], @sprites["cloud#{i}"])
    end
    # draws the sun
    if !(PBDayNight.isNight? && @data.try_key?("outdoor"))
      @sprites["sun"] = BSS070EBDXSprite.new(@viewport)
      @sprites["sun"].bitmap = pbBitmap("Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/sun")
      @sprites["sun"].ox = @sprites["sun"].bitmap.width/2
      @sprites["sun"].oy = @sprites["sun"].bitmap.height*4
      @sprites["sun"].ex = 208
      @sprites["sun"].ey = @sprites["sky"].ey - 3
      @sprites["sun"].param = 1
    end
    # loop for the stars
    for i in 0...24
      break if !(PBDayNight.isNight? && @data.try_key?("outdoor"))
      @sprites["star#{i}"] = BSS070EBDXSprite.new(@viewport)
      @sprites["star#{i}"].bitmap = pbBitmap("Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/star")
      @sprites["star#{i}"].center!
      @sprites["star#{i}"].ex = rand(@sprites["sky"].bitmap.width)
      @sprites["star#{i}"].ey = rand(@sprites["sky"].bitmap.height - 24)
      @sprites["star#{i}"].speed = rand(4) + 1
      @sprites["star#{i}"].param = 0.6 + rand(41)/100.0
      @sprites["star#{i}"].opacity = 125
      @sprites["star#{i}"].end_x = 185 + rand(71)
      @sprites["star#{i}"].toggle = 2
    end
  end
  #-----------------------------------------------------------------------------
  # tints all the elements inside of the scene based on daytime conditions
  #-----------------------------------------------------------------------------
  def daylightTint
    return if !@data.try_key?("sky", "outdoor")
    # apply daytime shading
    for key in @sprites.keys
      next if key.include?("trainer") || key.include?("battler")
      next if key.include?("sky") || key.include?("sun") || key.include?("star") || key.include?("cloud") ||  key.include?("Light") || (@data[key].is_a?(Hash) && @data[key].has_key?(:shading) && !@data[key][:shading])
      if PBDayNight.isNight? && !@sunny
        @sprites[key].tone = Tone.new(-120, -100, -60)
      elsif (PBDayNight.isEvening? || PBDayNight.isMorning?) && !@sunny
        @sprites[key].tone = Tone.new(-16, -52, -56)
      else
        @sprites[key].tone = Tone.new(0, 0, 0)
      end
    end
  end
  #-----------------------------------------------------------------------------
  # frame update for the skybox
  #-----------------------------------------------------------------------------
  def updateSky
    return if !@data.try_key?("sky", "outdoor")
    minutes = Time.now.hour*60 + Time.now.min
    # animates twinkling stars
    for i in 0...24
      break if !(PBDayNight.isNight? && @data.try_key?("outdoor"))
      next if !@sprites["star#{i}"]
      @sprites["star#{i}"].opacity += @sprites["star#{i}"].toggle * @sprites["star#{i}"].speed/self.delta
      @sprites["star#{i}"].toggle *= -1 if @sprites["star#{i}"].opacity <= 125 || @sprites["star#{i}"].opacity >= @sprites["star#{i}"].end_x
    end
    # applies sun positioning if it is rendered
    return if !@sprites["sun"]
    if PBDayNight.isEvening?
      oy = 92 - 68*(minutes - 17*60.0)/(3*60.0)
    elsif PBDayNight.isMorning?
      oy = 24 + 68*(minutes - 5*60.0)/(5*60.0)
    else
      oy = @sprites["sun"].bitmap.height*4
    end
    oy = 23 if oy < 23
    @sprites["sun"].src_rect.height = oy
    @sprites["sun"].oy = oy
  end
  #-----------------------------------------------------------------------------
  # set weather data
  #-----------------------------------------------------------------------------
  def setWeather
    # loop once
    for wth in [["Rain", [:Rain, :HeavyRain]], ["Snow", :Hail], ["StrongWind", :StrongWinds], ["Sunny", [:Sun, :HarshSun]], ["Sandstorm", :Sandstorm], ["Fog", :Fog]]
      proceed = false
      for cond in (wth[1].is_a?(Array) ? wth[1] : [wth[1]])
        proceed = true if @battle.pbWeather == cond
      end
      eval("delete" + wth[0]) unless proceed
      eval("draw"  + wth[0]) if proceed
    end
  end
  #-----------------------------------------------------------------------------
  # frame update for the weather particles
  #-----------------------------------------------------------------------------
  def updateWeather
    self.setWeather
    harsh = [:HEAVYRAIN, :HARSHSUN].include?(@battle.pbWeather)
    # snow particles
    for j in 0...72
      next if !@sprites["w_snow#{j}"]
      if @sprites["w_snow#{j}"].opacity <= 0
        z = rand(32)
        @sprites["w_snow#{j}"].param = 0.24 + 0.01*rand(z/2)
        @sprites["w_snow#{j}"].ey = -rand(64)
        @sprites["w_snow#{j}"].ex = 32 + rand(@sprites["bg"].bitmap.width - 64)
        @sprites["w_snow#{j}"].end_x = @sprites["w_snow#{j}"].ex
        @sprites["w_snow#{j}"].toggle = rand(2) == 0 ? 1 : -1
        @sprites["w_snow#{j}"].speed = 1 + 2/((rand(5) + 1)*0.4)
        @sprites["w_snow#{j}"].z = z - (@focused ? 0 : 100)
        @sprites["w_snow#{j}"].opacity = 255
      end
      min = @sprites["bg"].bitmap.height/4
      max = @sprites["bg"].bitmap.height/2
      scale = (2*Math::PI)/((@sprites["w_snow#{j}"].bitmap.width/64.0)*(max - min) + min)
      @sprites["w_snow#{j}"].opacity -= @sprites["w_snow#{j}"].speed/self.delta
      @sprites["w_snow#{j}"].ey += [1, @sprites["w_snow#{j}"].speed/self.delta].max
      @sprites["w_snow#{j}"].ex = @sprites["w_snow#{j}"].end_x + @sprites["w_snow#{j}"].bitmap.width*0.25*Math.sin(@sprites["w_snow#{j}"].ey*scale)*@sprites["w_snow#{j}"].toggle
    end
    # rain particles
    for j in 0...72
      next if !@sprites["w_rain#{j}"]
      if @sprites["w_rain#{j}"].opacity <= 0
        z = rand(32)
        @sprites["w_rain#{j}"].param = 0.24 + 0.01*rand(z/2)
        @sprites["w_rain#{j}"].ox = 0
        @sprites["w_rain#{j}"].ey = -rand(64)
        @sprites["w_rain#{j}"].ex = 32 + rand(@sprites["bg"].bitmap.width - 64)
        @sprites["w_rain#{j}"].speed = 3 + 2/((rand(5) + 1)*0.4)
        @sprites["w_rain#{j}"].z = z - (@focused ? 0 : 100)
        @sprites["w_rain#{j}"].opacity = 255
      end
      @sprites["w_rain#{j}"].opacity -= @sprites["w_rain#{j}"].speed*(harsh ? 3 : 2)/self.delta
      @sprites["w_rain#{j}"].ox += [1, @sprites["w_rain#{j}"].speed*(harsh ? 8 : 6)/self.delta].max
    end
    # sun particles
    for j in 0...3
      next if !@sprites["w_sunny#{j}"]
      #next if j > @shine["count"]/6
      @sprites["w_sunny#{j}"].zoom_x += 0.04*[0.5, 0.8, 0.7][j]/self.delta
      @sprites["w_sunny#{j}"].zoom_y += 0.03*[0.5, 0.8, 0.7][j]/self.delta
      @sprites["w_sunny#{j}"].opacity += (@sprites["w_sunny#{j}"].zoom_x < 1 ? 8 : -12)/self.delta
      if @sprites["w_sunny#{j}"].opacity <= 0
        @sprites["w_sunny#{j}"].zoom_x = 0
        @sprites["w_sunny#{j}"].zoom_y = 0
        @sprites["w_sunny#{j}"].opacity = 0
      end
    end
    # sandstorm particles
    for j in 0...2
      next if !@sprites["w_sand#{j}"]
      @sprites["w_sand#{j}"].update
    end
    # fog particles
    for j in 0...2
      next if !@sprites["w_fog#{j}"]
      @sprites["w_fog#{j}"].update
    end
  end
  #-----------------------------------------------------------------------------
  # reads data from hashtable and draws all tree objects in room
  #-----------------------------------------------------------------------------
  def drawTrees(data = @data["trees"])
    return if !data.has_key?(:elements)
    bmp = data.has_key?(:bitmap) ? data[:bitmap] : "tree"
    bmp = pbBitmap("Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/#{bmp}")
    for i in 0...data[:elements]
      @sprites["tree#{i}"] = BSS070EBDXSprite.new(@viewport)
      x0 = data.has_key?(:mirror) && data[:mirror][i] ? bmp.width : 0
      x1 = data.has_key?(:mirror) && data[:mirror][i] ? -bmp.width : bmp.width
      @sprites["tree#{i}"].bitmap = Bitmap.new(bmp.width,bmp.height)
      @sprites["tree#{i}"].bitmap.stretch_blt(bmp.rect,bmp,Rect.new(x0,0,x1,bmp.height))
      @sprites["tree#{i}"].bottom!
      @sprites["tree#{i}"].ex = data.has_key?(:x) ? data[:x][i] : 0
      @sprites["tree#{i}"].ey = data.has_key?(:y) ? data[:y][i] : 0
      @sprites["tree#{i}"].z = data.has_key?(:z) ? data[:z][i] : 1
      @sprites["tree#{i}"].param = data.has_key?(:zoom) ? data[:zoom][i] : 1
      color = data.has_key?(:colorize) ? data[:colorize] : true
      self.setColor(@sprites["bg"], @sprites["tree#{i}"], color) if color
      @sprites["tree#{i}"].memorize_bitmap
    end; bmp.dispose
  end
  #-----------------------------------------------------------------------------
  # reads data from hashtable and draws all grass objects in room
  #-----------------------------------------------------------------------------
  def drawGrass(data = @data["tallGrass"])
    return if !data.has_key?(:elements)
    bmp = data.has_key?(:bitmap) ? data[:bitmap] : "tallGrass"
    bmp = pbBitmap("Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/#{bmp}")
    for i in 0...data[:elements]
      @sprites["grass#{i}"] = BSS070EBDXSprite.new(@viewport)
      x0 = data.has_key?(:mirror) && data[:mirror][i] ? bmp.width : 0
      x1 = data.has_key?(:mirror) && data[:mirror][i] ? -bmp.width : bmp.width
      @sprites["grass#{i}"].bitmap = Bitmap.new(bmp.width,bmp.height)
      @sprites["grass#{i}"].bitmap.stretch_blt(bmp.rect,bmp,Rect.new(x0,0,x1,bmp.height))
      @sprites["grass#{i}"].bottom!
      @sprites["grass#{i}"].ex = data.has_key?(:x) ? data[:x][i] : 0
      @sprites["grass#{i}"].ey = data.has_key?(:y) ? data[:y][i] : 0
      @sprites["grass#{i}"].z = data[:z][i] if data.has_key?(:z)
      @sprites["grass#{i}"].param = data.has_key?(:zoom) ? data[:zoom][i] : 1
      color = data.has_key?(:colorize) ? data[:colorize] : true
      self.setColor(@sprites["bg"], @sprites["grass#{i}"], color) if color
      @sprites["grass#{i}"].memorize_bitmap
    end; bmp.dispose
  end
  #-----------------------------------------------------------------------------
  # function to draw a custom room object based on user-defined parameters
  #-----------------------------------------------------------------------------
  def drawImg(key)
    data = @data[key]
    if data.try_key?(:scrolling) # simple scrolling panorama
      @sprites["#{key}"] = BSS070EBDXScrollingSprite.new(@viewport)
    elsif data.try_key?(:sheet) # simple animated sprite sheets
      @sprites["#{key}"] = BSS070EBDXSheetSprite.new(@viewport,data.get_key(:frames).nil? ? 1 : data[:frames])
    elsif data.try_key?(:animated) # EBS styled sprite sheets
      @sprites["#{key}"] = BSS070EBDXAnimatedSprite.new(@viewport)
    elsif data.try_key?(:rainbow) # hue changing sprite
      @sprites["#{key}"] = BSS070EBDXRainbowSprite.new(@viewport)
    else # regular sprite
      @sprites["#{key}"] = BSS070EBDXSprite.new(@viewport)
    end
    @sprites["#{key}"].default!; keys = data.keys;
    if keys.include?(:bitmap) # prioritizes bitmap key from sorted array
      keys.delete(:bitmap); keys.insert(0,:bitmap)
    end
    for m in keys # interprets each parameter
      k = BSS070EBDXCore.bg_hash_map(m); next if k.nil? # if parameter can be mapped
      if k == :bitmap # applies bitmap
        path = pbResolveBitmap(data[m]) ? data[m] : "Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/" + data[m]
        if data.try_key?(:scrolling) || data.try_key?(:animated) || data.try_key?(:rainbow) || data.try_key?(:sheet)
          @sprites["#{key}"].setBitmap(path,((data.try_key?(:animated) || data.try_key?(:rainbow)) ? 1 : data.get_key(:vertical)))
        else
          @sprites["#{key}"].bitmap = pbBitmap(path)
        end; next
      end # otherwise applies parameter data
      @sprites["#{key}"].send("#{k}=",data[m]) if @sprites["#{key}"].respond_to?(k)
    end
    @sprites["#{key}"].z = 40 if @sprites["#{key}"].z > 40 # caps Z value
    @sprites["#{key}"].bottom! if @sprites["#{key}"].bitmap && !data.try_key?(:ox) && !data.try_key?(:oy) # sets the anchor to bottom middle, unless otherwise defined
    # check if should apply color
    if data.try_key?(:colorize)
      self.setColor(@sprites["bg"], @sprites["#{key}"]) if data[:colorize] == true
      @sprites["#{key}"].colorize(data[:colorize], data[:colorize].alpha) if data[:colorize].is_a?(Color)
    end
    @sprites["#{key}"].memorize_bitmap # saves the sprite's bitmap just in case
  end
  #-----------------------------------------------------------------------------
  # loads the animated elements for PWT styled base lights
  #-----------------------------------------------------------------------------
  def drawSpinLights
    for i in 0...2
      @sprites["sLight#{i}"] = BSS070EBDXAnimatedSprite.new(@viewport)
      @sprites["sLight#{i}"].default!
      @sprites["sLight#{i}"].setBitmap("Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/lightDecor",1)
      @sprites["sLight#{i}"].z = 1
      @sprites["sLight#{i}"].center!
      @sprites["sLight#{i}"].zx = 1
      @sprites["sLight#{i}"].zy = 0.35
    end
  end
  #-----------------------------------------------------------------------------
  # elements for stage lights style A
  #-----------------------------------------------------------------------------
  def drawLightsA(img = true)
    lgt = img.is_a?(String) ? img : "lightA"
    for i in 0...4
      @sprites["aLight#{i}"] = BSS070EBDXSprite.new(@viewport)
      @sprites["aLight#{i}"].bitmap = pbBitmap("Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/#{lgt}")
      @sprites["aLight#{i}"].ex = [183, 135, 70, 0][i]
      @sprites["aLight#{i}"].ey = [-2, -15, -15, -16][i]
      @sprites["aLight#{i}"].param = [0.8, 1, 1.25, 1.4][i]
      @sprites["aLight#{i}"].z = [10, 10, 18, 18][i]
      @sprites["aLight#{i}"].opacity = [0.5, 0.7, 0.9, 1][i]*255
      @sprites["aLight#{i}"].end_x = [0.5, 0.7, 0.9, 1][i]
      @sprites["aLight#{i}"].speed = 1*(1 + rand(4))
      @sprites["aLight#{i}"].toggle = 1
    end
  end
  #-----------------------------------------------------------------------------
  # elements for stage lights style B
  #-----------------------------------------------------------------------------
  def drawLightsB(img = true)
    lgt = img.is_a?(String) ? img : "lightB"
    for i in 0...6
      @sprites["bLight#{i}"] = BSS070EBDXSprite.new(@viewport)
      @sprites["bLight#{i}"].bitmap = pbBitmap("Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/#{lgt}")
      @sprites["bLight#{i}"].ox = @sprites["bLight#{i}"].bitmap.width/2
      @sprites["bLight#{i}"].ex = [40,104,146,210,256,320][i]
      @sprites["bLight#{i}"].ey = -8
      @sprites["bLight#{i}"].mirror = (i%2 == 1)
      @sprites["bLight#{i}"].speed = (2 + rand(3))*3
      @sprites["bLight#{i}"].memorize_bitmap
      @sprites["bLight#{i}"].param = 1
      @sprites["bLight#{i}"].z = 3
      @sprites["bLight#{i}"].opacity = 0
    end
  end
  #-----------------------------------------------------------------------------
  # elements for ambiental lights style C
  #-----------------------------------------------------------------------------
  def drawLightsC
    for i in 0...8
      c = [2,3,1,3,2,3,1,3]; l = (100-rand(51))/100.0
      @sprites["cLight#{i}"] = BSS070EBDXSprite.new(@viewport)
      @sprites["cLight#{i}"].bitmap = pbBitmap("Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/lightC#{c[i]}")
      @sprites["cLight#{i}"].ex = [-2,10,40,60,100,118,160,168][i]
      @sprites["cLight#{i}"].ey = [-22,-46,-8,-32,-14,-40,0,-58][i]
      @sprites["cLight#{i}"].param = 1
      @sprites["cLight#{i}"].z = 10
      @sprites["cLight#{i}"].opacity = l*255
      @sprites["cLight#{i}"].end_x = l
      @sprites["cLight#{i}"].speed = 1*(1 + rand(4))
      @sprites["cLight#{i}"].toggle = 1
    end
  end
  #-----------------------------------------------------------------------------
  # adds subtle water animation to terrain
  #-----------------------------------------------------------------------------
  def drawWater
    for i in 0...2
      @sprites["water#{i}"] = BSS070EBDXScrollingSprite.new(@viewport)
      @sprites["water#{i}"].setBitmap("Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/water#{i}")
      @sprites["water#{i}"].speed = 0.5
      @sprites["water#{i}"].direction = 1
      @sprites["water#{i}"].ex = 0
      @sprites["water#{i}"].ey = 146
      @sprites["water#{i}"].param = 1
      @sprites["water#{i}"].mirror = i > 0
    end
  end
  #-----------------------------------------------------------------------------
  # draws vacuum waves
  #-----------------------------------------------------------------------------
  def vacuumWaves(img = true)
    lgt = img.is_a?(String) ? img : "dark004"
    for j in 0...3
      @sprites["ec#{j}"] = BSS070EBDXSprite.new(@viewport)
      @sprites["ec#{j}"].bitmap = pbBitmap("Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/#{lgt}")
      @sprites["ec#{j}"].center!
      @sprites["ec#{j}"].ex = 234
      @sprites["ec#{j}"].ey = 128
      @sprites["ec#{j}"].param = 1.5
      @sprites["ec#{j}"].opacity = 0
      @sprites["ec#{j}"].z = 1
    end
  end
  #-----------------------------------------------------------------------------
  # draws bubble stream
  #-----------------------------------------------------------------------------
  def bubbleStream(img = true)
    lgt = img.is_a?(String) ? img : "bubble"
    for j in 0...18
      @sprites["bubble#{j}"] = BSS070EBDXSprite.new(@viewport)
      @sprites["bubble#{j}"].bitmap = pbBitmap("Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/#{lgt}")
      @sprites["bubble#{j}"].center!
      @sprites["bubble#{j}"].default!
      @sprites["bubble#{j}"].ey = -32
      @sprites["bubble#{j}"].opacity = 0
    end
  end
  #-----------------------------------------------------------------------------
  # check if sky should be tinted lighter
  #-----------------------------------------------------------------------------
  def weatherTint?
    for wth in [:Hail, :Sun, :HarshSun]
      return true if @battle.pbWeather == wth
    end
    return false
  end
  #-----------------------------------------------------------------------------
  # sunny weather handlers
  #-----------------------------------------------------------------------------
  def drawSunny
    @sunny = true
    # refresh daylight tinting
    if @weather != @battle.pbWeather
      @weather = @battle.pbWeather
      self.daylightTint
    end
    # apply sky tone
    if @sprites["sky"]
      @sprites["sky"].tone.all += 16 if @sprites["sky"].tone.all < 96
      for i in 0..1
        @sprites["cloud#{i}"].tone.all += 16 if @sprites["cloud#{i}"].tone.all < 96
      end
    end
    # draw particles
    for i in 0...3
      next if @sprites["w_sunny#{i}"]
      @sprites["w_sunny#{i}"] = BSS070EBDXSprite.new(@viewport)
      @sprites["w_sunny#{i}"].z = 100
      @sprites["w_sunny#{i}"].bitmap = pbBitmap("Graphics/BattleSceneStudio/EBDX/Weather/ray001")
      @sprites["w_sunny#{i}"].oy = @sprites["w_sunny#{i}"].bitmap.height/2
      @sprites["w_sunny#{i}"].angle = 290 + [-10, 32, 10][i]
      @sprites["w_sunny#{i}"].zoom_x = 0
      @sprites["w_sunny#{i}"].zoom_y = 0
      @sprites["w_sunny#{i}"].opacity = 0
      @sprites["w_sunny#{i}"].x = [-2, 20, 10][i]
      @sprites["w_sunny#{i}"].y = [-4, -24, -2][i]
    end
  end
  def deleteSunny
    @sunny = false
    # refresh daylight tinting
    if @weather != @battle.pbWeather
      @weather = @battle.pbWeather
      self.daylightTint
    end
    # apply sky tone
    if @sprites["sky"] && !weatherTint?
      @sprites["sky"].tone.all -= 4 if @sprites["sky"].tone.all > 0
      for i in 0..1
        @sprites["cloud#{i}"].tone.all -= 4 if @sprites["cloud#{i}"].tone.all > 0
      end
    end
    for j in 0...3
      next if !@sprites["w_sunny#{j}"]
      @sprites["w_sunny#{j}"].dispose
      @sprites.delete("w_sunny#{j}")
    end
  end
  #-----------------------------------------------------------------------------
  # sandstorm weather handlers
  #-----------------------------------------------------------------------------
  def drawSandstorm
    for j in 0...2
      next if @sprites["w_sand#{j}"]
      @sprites["w_sand#{j}"] = BSS070EBDXScrollingSprite.new(@viewport)
      @sprites["w_sand#{j}"].default!
      @sprites["w_sand#{j}"].z = 100
      @sprites["w_sand#{j}"].setBitmap("Graphics/BattleSceneStudio/EBDX/Weather/sandstorm#{j}")
      @sprites["w_sand#{j}"].speed = 32
      @sprites["w_sand#{j}"].direction = j == 0 ? 1 : -1
    end
  end
  def deleteSandstorm
    for j in 0...2
      next if !@sprites["w_sand#{j}"]
      @sprites["w_sand#{j}"].dispose
      @sprites.delete("w_sand#{j}")
    end
  end
  #-----------------------------------------------------------------------------
  # fog weather handlers
  #-----------------------------------------------------------------------------
  def drawFog
    for j in 0...2
      next if @sprites["w_fog#{j}"]
      @sprites["w_fog#{j}"] = BSS070EBDXScrollingSprite.new(@viewport)
      @sprites["w_fog#{j}"].default!
      @sprites["w_fog#{j}"].z = 100
      @sprites["w_fog#{j}"].setBitmap("Graphics/BattleSceneStudio/EBDX/Weather/fog#{j}", false, true)
      @sprites["w_fog#{j}"].speed = 2 - j
      @sprites["w_fog#{j}"].min_o = 105
      @sprites["w_fog#{j}"].max_o = 205
      @sprites["w_fog#{j}"].opacity = 205
      @sprites["w_fog#{j}"].direction = j == 0 ? 1 : -1
    end
  end
  def deleteFog
    for j in 0...2
      next if !@sprites["w_fog#{j}"]
      @sprites["w_fog#{j}"].dispose
      @sprites.delete("w_fog#{j}")
    end
  end
  #-----------------------------------------------------------------------------
  # snow weather handlers
  #-----------------------------------------------------------------------------
  def drawSnow
    for j in 0...72
      next if @sprites["w_snow#{j}"]
      @sprites["w_snow#{j}"] = BSS070EBDXSprite.new(@viewport)
      @sprites["w_snow#{j}"].bitmap = pbBitmap("Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/snow")
      @sprites["w_snow#{j}"].center!
      @sprites["w_snow#{j}"].default!
      @sprites["w_snow#{j}"].opacity = 0
    end
  end
  def deleteSnow
    for j in 0...72
      next if !@sprites["w_snow#{j}"]
      @sprites["w_snow#{j}"].dispose
      @sprites.delete("w_snow#{j}")
    end
  end
  #-----------------------------------------------------------------------------
  # rain weather handlers
  #-----------------------------------------------------------------------------
  def drawRain
    harsh = @battle.pbWeather == :HEAVYRAIN
    # apply sky tone
    if @sprites["sky"]
      @sprites["sky"].tone.all -= 2 if @sprites["sky"].tone.all > -16
      @sprites["sky"].tone.gray += 16 if @sprites["sky"].tone.gray < 128
      for i in 0..1
        @sprites["cloud#{i}"].tone.all -= 2 if @sprites["cloud#{i}"].tone.all > -16
        @sprites["cloud#{i}"].tone.gray += 16 if @sprites["cloud#{i}"].tone.gray < 128
      end
    end
    for j in 0...72
      next if @sprites["w_rain#{j}"]
      @sprites["w_rain#{j}"] = BSS070EBDXSprite.new(@viewport)
      @sprites["w_rain#{j}"].create_rect(harsh ? 28 : 24, 3, Color.white)
      @sprites["w_rain#{j}"].default!
      @sprites["w_rain#{j}"].angle = 80
      @sprites["w_rain#{j}"].oy = 2
      @sprites["w_rain#{j}"].opacity = 0
    end
  end
  def deleteRain
    # apply sky tone
    if @sprites["sky"]
      @sprites["sky"].tone.all += 2 if @sprites["sky"].tone.all < 0
      @sprites["sky"].tone.gray -= 16 if @sprites["sky"].tone.gray > 0
      for i in 0..1
        @sprites["cloud#{i}"].tone.all += 2 if @sprites["cloud#{i}"].tone.all < 0
        @sprites["cloud#{i}"].tone.gray -= 16 if @sprites["cloud#{i}"].tone.gray > 0
      end
    end
    for j in 0...72
      next if !@sprites["w_rain#{j}"]
      @sprites["w_rain#{j}"].dispose
      @sprites.delete("w_rain#{j}")
    end
  end
  #-----------------------------------------------------------------------------
  # strong wind weather handlers
  #-----------------------------------------------------------------------------
  def drawStrongWind; @strongwind = true; end
  def deleteStrongWind; @strongwind = false; end
  #-----------------------------------------------------------------------------
  # records the proper positioning
  #-----------------------------------------------------------------------------
  def adjustMetrics
    @scale = BSS070EBDXCore::ROOM_SCALE
    # EBDX owns projection/camera. BSS keeps the proven 0.6.73 native battler
    # layout as the neutral metric, then converts that neutral point into the
    # EBDX room coordinate system. This prevents SOS side-size changes, DBK and
    # Animated Pokemon renderers from fighting a second hard-coded metric table.
    indexes = (-2..7).to_a
    indexes.each do |j|
      @sprites["battler#{j}"] = BSS070EBDXSprite.new(@viewport)
      @sprites["battler#{j}"].default!
      @sprites["shadow#{j}"] = BSS070EBDXSprite.new(@viewport)
      @sprites["shadow#{j}"].default!
      @sprites["trainer_#{j}"] = BSS070EBDXSprite.new(@viewport)
      @sprites["trainer_#{j}"].default!
      i = j
      i = 0 if j == -2
      i = 1 if j == -1
      pos = @scene.respond_to?(:bss070_ebdx_native_position_for) ? @scene.bss070_ebdx_native_position_for(i, true) : nil
      pos ||= BSS070EBDXCore.fallback_screen_position(i, @battle)
      ex, ey = screen_to_room(pos[0], pos[1])
      @sprites["battler#{j}"].ex = ex
      @sprites["battler#{j}"].ey = ey
      @sprites["battler#{j}"].z = (pos[2] || 50).to_i
      @sprites["battler#{j}"].param = 1
      spos = @scene.respond_to?(:bss070_ebdx_native_shadow_position_for) ? @scene.bss070_ebdx_native_shadow_position_for(i, true) : nil
      spos ||= pos
      sex, sey = screen_to_room(spos[0], spos[1])
      @sprites["shadow#{j}"].ex = sex
      @sprites["shadow#{j}"].ey = sey
      @sprites["shadow#{j}"].z = (spos[2] || 3).to_i
      @sprites["shadow#{j}"].param = 1
      tpos = @scene.respond_to?(:bss070_ebdx_native_trainer_position_for) ? @scene.bss070_ebdx_native_trainer_position_for(i) : nil
      tpos ||= pos
      tex, tey = screen_to_room(tpos[0], tpos[1])
      @sprites["trainer_#{j}"].ex = tex
      @sprites["trainer_#{j}"].ey = tey
      @sprites["trainer_#{j}"].z = (tpos[2] || 40).to_i
      @sprites["trainer_#{j}"].param = 1
    end
  end

  def screen_to_room(x, y)
    sx, sy = @scene.vector.spoof(@defaultvector)
    ox = sx / 1.5 - 16
    oy = sy / 1.5 + 16
    ex = ox + (x.to_f - sx.to_f) / BSS070EBDXCore::ROOM_SCALE
    ey = oy + (y.to_f - sy.to_f) / BSS070EBDXCore::ROOM_SCALE
    [ex, ey]
  end

  def recalibrate_metrics!
    # Keep all authored environmental sprites and their animation phases. Only
    # the invisible battler/trainer metric anchors are recalculated after an SOS
    # changes side size.
    keys = @sprites.keys.select { |k| k.start_with?("battler") || k.start_with?("shadow") || k.start_with?("trainer_") }
    keys.each do |k|
      begin; @sprites[k].dispose if @sprites[k] && !@sprites[k].disposed?; rescue; end
      @sprites.delete(k)
    end
    adjustMetrics
    position
  end
  #-----------------------------------------------------------------------------
  # disposes of all sprites
  #-----------------------------------------------------------------------------
  def dispose
    return if @disposed
    bss076_dispose_owned_sprites!
    @disposed = true
  end
  #-----------------------------------------------------------------------------
  # checks if room is disposed
  #-----------------------------------------------------------------------------
  def disposed?; return @disposed; end
  #-----------------------------------------------------------------------------
  # compatibility layers for scene transitions
  #-----------------------------------------------------------------------------
  def color; return @viewport.color; end
  def color=(val); @viewport.color = val; end
  def visible
    bg=@sprites["bg"] rescue nil
    bg ? (bg.visible rescue false) : false
  end
  def visible=(val)
    @sprites.keys.clone.each do |key|
      sp=@sprites[key] rescue nil
      sp.visible=val if sp && sp.respond_to?(:visible=) && !(sp.disposed? rescue false)
    end
  end
  #-----------------------------------------------------------------------------
  # compatibility layer for move animations with backgrounds
  #-----------------------------------------------------------------------------
  def defocus
    return if @sprites["bg"].z < 0
    for key in @sprites.keys
      @sprites[key].z -= 100
    end
    @focused = false
  end
  def focus
    return if @sprites["bg"].z >= 0
    for key in @sprites.keys
      @sprites[key].z += 100
    end
    @focused = true
  end
  #-----------------------------------------------------------------------------
  # battler sprite positioning
  #-----------------------------------------------------------------------------
  def delta; return 1.0; end
  def scale_y; return @sprites["bg"].zoom_y; end
  def battler(i); return @sprites["battler#{i}"]; end
  def shadow(i); return @sprites["shadow#{i}"]; end
  def trainer(i); return @sprites["trainer_#{i}"]; end
  def shadows_enabled?; return !(@data.has_key?("noshadow") && @data["noshadow"] == true); end
  def stageLightPos(j)
    data = BSS070EBDXCore.get(:battlerMetrics)
    return if data.nil?
    x = 0; y = 0
    for param in [:X, :Y, :Z]
      next if data[j].nil? || !data[j].has_key?(param)
      dat = data[j][param]
      x = dat[0] if param == :X
      y = dat[0] if param == :Y
    end
    return x, y
  end
  def spoof(vector, index = 1)
    target = self.battler(index)
    bx, by = @scene.vector.spoof(vector)
    # updates to the spatial warping with respect to the scene vector
    dx, dy = @scene.vector.spoof(@defaultvector)
    bzoom_x = @scale*((bx - vector[0])*1.0/(dx - @defaultvector[0])*1.0)**0.6
    bzoom_y = @scale*((by - vector[1])*1.0/(dy - @defaultvector[1])*1.0)**0.6
    x = bx - (@sprites["bg"].ox - target.ex)*bzoom_x
    y = by - (@sprites["bg"].oy - target.ey)*bzoom_y
    return x, y
  end
  #-----------------------------------------------------------------------------
  # change out the data hash and redraw battle environment
  #-----------------------------------------------------------------------------
  def reconfigure(data, transition = Color.black, userIndex = 0, targetIndex = 0, hitnum = 0)
    data = BSS070EBDXCore.environment_constant(data) if data.is_a?(Symbol)
    # failsafe
    if !data.is_a?(Hash)
      BSS070EBDXCore.log.warn("Unable to load battle environment for: #{data}")
      return
    end
    # if with transition
    if transition.is_a?(Symbol)
      @queued = data.clone
      return BSS070EBDXCore.playCommonAnimation(transition, @scene, userIndex, targetIndex, hitnum)
    end
    # construct transition animation object
    trans = BSS070EBDXSprite.new(@viewport) if !transition.nil?
    if transition.is_a?(Color)
      trans.create_rect(@viewport.width, @viewport.height, transition)
    elsif transition.is_a?(String)
      trans.bitmap = pbBitmap(transition)
    end
    trans.opacity = 0  if !transition.nil?
    # push elements out of focus
    self.defocus
    # fade through transition element
    if !transition.nil?
      8.times { trans.opacity += 32; @scene.wait }
    end
    # set new data Hash
    @data = data.clone
    self.refresh(data)
    self.defocus
    # fade through transition element
    if !transition.nil?
      8.times { trans.opacity -= 32; @scene.wait }
    end
    self.focus
    # dispose of transition element
    trans.dispose if !transition.nil?
  end
  #-----------------------------------------------------------------------------
  # change out data hash (simple)
  #-----------------------------------------------------------------------------
  def configure
    return if @queued.nil? || !@queued.is_a?(Hash)
    @data = @queued.clone
    self.refresh(@data)
    @queued = nil
  end
  #-----------------------------------------------------------------------------
  # reset to original data hash
  #-----------------------------------------------------------------------------
  def reset(transition = Color.black)
    self.reconfigure(@backup, transition)
  end
  #-----------------------------------------------------------------------------
end

#===============================================================================
# BSS/EBDX bridge: EBDX is world authority; BSS/DBK HUD stays screen-space.
#===============================================================================
module BSS070EBDXSceneBridge
  attr_reader :vector

  def bss070_ebdx_active?
    BSS070EBDXCore.active_for_battle?(@battle)
  end

  def bss070_ebdx_camera_enabled?
    env=(@battle.respond_to?(:bss_environment_config) ? @battle.bss_environment_config : nil) rescue nil
    !env.is_a?(Hash) || env["ebdxCamera"]!=false
  end

  def bss070_ebdx_ensure_core
    return false if !bss070_ebdx_active?
    main=BSS070EBDXCore.get_vector(:MAIN,@battle)
    if !@vector.is_a?(BSS070EBDXVector)
      @vector=BSS070EBDXVector.new(*main);@vector.battle=@battle;@vector.set(main)
      @bss070_ebdx_idle_timer=0;@bss070_ebdx_last_motion=nil;@bss070_ebdx_org_pos=main.clone
      @bss070_ebdx_anchor_cache={};@bss070_ebdx_shadow_anchor_cache={};@bss070_ebdx_side_signature=nil;@bss070_ebdx_suspend_depth=0
      @bss070_ebdx_camera_mode=:idle;@bss070_ebdx_motion_due=0
    end
    if !@bss070_ebdx_room || (@bss070_ebdx_room.disposed? rescue true)
      @bss070_ebdx_room=BSS070EBDXRoom.new(@viewport,self,BSS070EBDXCore.environment_for(self))
    end
    # EBDX original registers the whole room as battlebg. Doing the same makes
    # Essentials fades and BAS/Aura cameras transform the complete scene instead
    # of treating the backdrop as an unrelated overlay.
    @sprites["battlebg"]=@bss070_ebdx_room if @sprites.is_a?(Hash)
    bss070_ebdx_hide_native_backdrops
    bss070_ebdx_install_bas_bridge
    true
  rescue => e
    BSS064.log("EBDX core init warning: #{e.class}: #{e.message}") if defined?(BSS064)
    false
  end

  # Backdrop creation is intentionally NOT wrapped. New Animation Editor uses
  # alias-based hooks here; a prepend+super wrapper causes alias -> prepend ->
  # alias recursion. EBDX initializes on the first scene update instead.

  def bss070_ebdx_hide_native_backdrops
    return if !@sprites
    ["battle_bg","battle_bg2","base_0","base_1"].each do |key|
      sp=@sprites[key] rescue nil;next if !sp
      sp.visible=false if sp.respond_to?(:visible=);sp.opacity=0 if sp.respond_to?(:opacity=)
    end
  end

  def bss070_ebdx_native_sprite(index)
    @sprites["pokemon_#{index}"] rescue nil
  end

  def bss070_ebdx_native_shadow_sprite(index)
    @sprites["shadow_#{index}"] rescue nil
  end

  def bss070_ebdx_sprite_loaded?(sprite)
    return false if !sprite || (sprite.disposed? rescue true)
    if sprite.respond_to?(:iconBitmap)
      return false if sprite.iconBitmap.nil?
    end
    return false if sprite.respond_to?(:bitmap) && sprite.bitmap.nil?
    true
  rescue
    false
  end

  def bss070_ebdx_side_signature
    return [] if !@battle || !@battle.respond_to?(:battlers)
    @battle.battlers.each_index.map do |i|
      [i,(@battle.pbSideSize(i) rescue 1),
       bss070_ebdx_sprite_loaded?(bss070_ebdx_native_sprite(i)),
       bss070_ebdx_sprite_loaded?(bss070_ebdx_native_shadow_sprite(i))]
    end
  end

  def bss070_ebdx_neutral_battler_position(index, side=nil)
    idx=index.to_i; side=(side || (@battle.pbSideSize(idx) rescue 1)).to_i
    begin
      p=Battle::Scene.pbBattlerPosition(idx,side) if Battle::Scene.respond_to?(:pbBattlerPosition)
      return [p[0].to_f,p[1].to_f] if p && p.length>=2
    rescue
    end
    p=BSS070EBDXCore.fallback_screen_position(idx,@battle)
    [p[0].to_f,p[1].to_f]
  end

  def bss070_ebdx_native_position_for(index,probe=false)
    idx=index.to_i;sp=bss070_ebdx_native_sprite(idx);side=(@battle.pbSideSize(idx) rescue 1).to_i
    loaded=bss070_ebdx_sprite_loaded?(sp)
    key=[(sp ? sp.object_id : 0),idx,side,loaded]
    cached=@bss070_ebdx_anchor_cache && @bss070_ebdx_anchor_cache[key]
    return cached[0,3] if cached && !probe
    vals=nil
    # Never probe an unloaded animated battler. Its pbSetPosition intentionally
    # returns before assigning coordinates, which previously cached [0,0] and
    # made the player's send-out disappear until SOS/Boss forced recalibration.
    if loaded && sp.respond_to?(:pbSetPosition)
      old=[sp.x,sp.y,sp.z,(sp.zoom_x rescue nil),(sp.zoom_y rescue nil)]
      begin
        sp.sideSize=side if sp.respond_to?(:sideSize=)
        sp.pbSetPosition
        vals=[sp.x.to_f,sp.y.to_f,sp.z.to_i,(sp.zoom_x rescue 1.0).to_f,(sp.zoom_y rescue 1.0).to_f]
      ensure
        sp.x=old[0] if sp.respond_to?(:x=);sp.y=old[1] if sp.respond_to?(:y=);sp.z=old[2] if sp.respond_to?(:z=)
        sp.zoom_x=old[3] if !old[3].nil? && sp.respond_to?(:zoom_x=);sp.zoom_y=old[4] if !old[4].nil? && sp.respond_to?(:zoom_y=)
      end
    end
    if !vals
      pos=bss070_ebdx_neutral_battler_position(idx,side)
      vals=[pos[0],pos[1],(sp && (sp.z rescue nil) ? sp.z : 50).to_i,
            (sp && (sp.zoom_x rescue nil) ? sp.zoom_x : 1.0).to_f,
            (sp && (sp.zoom_y rescue nil) ? sp.zoom_y : 1.0).to_f]
    end
    @bss070_ebdx_anchor_cache ||= {};@bss070_ebdx_anchor_cache[key]=vals
    vals[0,3]
  rescue
    p=bss070_ebdx_neutral_battler_position(index)
    [p[0],p[1],50]
  end

  def bss070_ebdx_native_shadow_position_for(index,probe=false)
    idx=index.to_i;sp=bss070_ebdx_native_shadow_sprite(idx);side=(@battle.pbSideSize(idx) rescue 1).to_i
    loaded=bss070_ebdx_sprite_loaded?(sp)
    key=[(sp ? sp.object_id : 0),idx,side,loaded]
    cached=@bss070_ebdx_shadow_anchor_cache && @bss070_ebdx_shadow_anchor_cache[key]
    return cached[0,3] if cached && !probe
    vals=nil
    if loaded && sp.respond_to?(:pbSetPosition)
      old=[sp.x,sp.y,sp.z,(sp.zoom_x rescue nil),(sp.zoom_y rescue nil)]
      begin
        sp.sideSize=side if sp.respond_to?(:sideSize=)
        sp.pbSetPosition
        vals=[sp.x.to_f,sp.y.to_f,sp.z.to_i,(sp.zoom_x rescue 1.0).to_f,(sp.zoom_y rescue 1.0).to_f]
      ensure
        sp.x=old[0] if sp.respond_to?(:x=);sp.y=old[1] if sp.respond_to?(:y=);sp.z=old[2] if sp.respond_to?(:z=)
        sp.zoom_x=old[3] if !old[3].nil? && sp.respond_to?(:zoom_x=);sp.zoom_y=old[4] if !old[4].nil? && sp.respond_to?(:zoom_y=)
      end
    end
    if !vals
      pos=bss070_ebdx_neutral_battler_position(idx,side)
      vals=[pos[0],pos[1],3,(sp && (sp.zoom_x rescue nil) ? sp.zoom_x : 1.0).to_f,
            (sp && (sp.zoom_y rescue nil) ? sp.zoom_y : 0.25).to_f]
    end
    @bss070_ebdx_shadow_anchor_cache ||= {};@bss070_ebdx_shadow_anchor_cache[key]=vals
    vals[0,3]
  rescue
    p=bss070_ebdx_neutral_battler_position(index)
    [p[0],p[1],3]
  end

  def bss070_ebdx_native_trainer_position_for(index)
    # Trainer sprites are left compatible with the renderer supplied by the
    # project. Their neutral point is sampled, then EBDX projects that point.
    t=(index.to_i/2);sp=@sprites["trainer_#{t}"] rescue nil
    return [sp.x,sp.y,sp.z] if sp && !(sp.disposed? rescue true)
    bss070_ebdx_native_position_for(index)
  rescue
    bss070_ebdx_native_position_for(index)
  end

  def bss070_ebdx_anchor_scale(index)
    sp=bss070_ebdx_native_sprite(index);return [1.0,1.0] if !sp
    side=(@battle.pbSideSize(index) rescue 1).to_i;key=[sp.object_id,index.to_i,side,bss070_ebdx_sprite_loaded?(sp)]
    vals=@bss070_ebdx_anchor_cache && @bss070_ebdx_anchor_cache[key]
    bss070_ebdx_native_position_for(index) if !vals
    vals=@bss070_ebdx_anchor_cache && @bss070_ebdx_anchor_cache[key]
    vals ? [vals[3].to_f,vals[4].to_f] : [(sp.zoom_x rescue 1.0).to_f,(sp.zoom_y rescue 1.0).to_f]
  end

  def bss070_ebdx_shadow_anchor_scale(index)
    sp=bss070_ebdx_native_shadow_sprite(index);return [1.0,0.25] if !sp
    side=(@battle.pbSideSize(index) rescue 1).to_i;key=[sp.object_id,index.to_i,side,bss070_ebdx_sprite_loaded?(sp)]
    vals=@bss070_ebdx_shadow_anchor_cache && @bss070_ebdx_shadow_anchor_cache[key]
    bss070_ebdx_native_shadow_position_for(index) if !vals
    vals=@bss070_ebdx_shadow_anchor_cache && @bss070_ebdx_shadow_anchor_cache[key]
    vals ? [vals[3].to_f,vals[4].to_f] : [(sp.zoom_x rescue 1.0).to_f,(sp.zoom_y rescue 0.25).to_f]
  end

  def bss070_ebdx_invalidate_anchors
    @bss070_ebdx_side_signature=nil
    @bss070_ebdx_anchor_cache={}
    @bss070_ebdx_shadow_anchor_cache={}
  end

  def bss070_ebdx_recalibrate_if_needed
    sig=bss070_ebdx_side_signature
    return if sig==@bss070_ebdx_side_signature
    @bss070_ebdx_side_signature=sig
    @bss070_ebdx_anchor_cache={}
    @bss070_ebdx_shadow_anchor_cache={}
    @bss070_ebdx_room.recalibrate_metrics! if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
  end

  def bss070_ebdx_apply_shadow_policy(hide=false)
    return if !@battle || !@sprites
    @bss070_ebdx_shadow_policy_hidden ||= {}
    @battle.battlers.each_index do |i|
      sh=bss070_ebdx_native_shadow_sprite(i);next if !sh || (sh.disposed? rescue true)
      if hide
        if sh.respond_to?(:visible) && sh.visible
          @bss070_ebdx_shadow_policy_hidden[i]=true
          sh.visible=false if sh.respond_to?(:visible=)
        end
      elsif @bss070_ebdx_shadow_policy_hidden.delete(i)
        mon=bss070_ebdx_native_sprite(i)
        sh.visible=(mon ? (mon.visible rescue true) : true) if sh.respond_to?(:visible=)
      end
    end
  rescue
  end

  def bss070_ebdx_camera_config; BSS070EBDXCore.camera_config; end

  def bss070_ebdx_camera_enter(mode)
    return if !@vector || !bss070_ebdx_camera_enabled?
    @bss070_ebdx_camera_mode=mode.to_s.downcase.to_sym
    @bss070_ebdx_motion_due=0
    @bss070_ebdx_last_motion=nil
    bss070_ebdx_choose_camera_target(true)
  end

  def bss070_ebdx_camera_leave
    return if !@vector
    # Leaving Command/Fight no longer teleports the camera to MAIN.  The current
    # shot becomes the start of the idle motion, so attacks/turn changes are fluid.
    @bss070_ebdx_camera_mode=:idle
    @bss070_ebdx_motion_due=BSS070EBDXCore.camera_duration(:idle)
    @bss070_ebdx_last_motion=nil
    @vector.inc=BSS070EBDXCore.camera_inc(:idle)
  end

  def bss070_ebdx_choose_camera_target(immediate=false)
    mode=(@bss070_ebdx_camera_mode || :idle).to_s.downcase.to_sym
    rows=BSS070EBDXCore.safe_camera_vectors(@battle,mode)
    return if !rows || rows.empty?
    choices=(0...rows.length).to_a
    # The last row is MAIN. On entering Command/Fight, guarantee a visible
    # camera move instead of randomly choosing the neutral shot.
    choices.delete(rows.length-1) if immediate && mode!=:idle && choices.length>1
    choices.delete(@bss070_ebdx_last_motion) if !@bss070_ebdx_last_motion.nil? && choices.length>1
    idx=choices[rand(choices.length)]
    @bss070_ebdx_last_motion=idx
    @vector.inc=BSS070EBDXCore.camera_inc(mode)
    @vector.set(rows[idx])
    @bss070_ebdx_motion_due=BSS070EBDXCore.camera_duration(mode)
  end

  # BSS 0.7.8 - give Essentials/SOS transition builders EBDX coordinates while
  # they create their PictureEx processes. This avoids visually travelling toward
  # the vanilla base coordinates before snapping back to the room.
  def bss070_ebdx_with_position_context
    old=BSS070EBDXCore.position_scene
    BSS070EBDXCore.position_scene=self
    yield
  ensure
    BSS070EBDXCore.position_scene=old
  end

  def bss070_ebdx_snap_animation_baseline(vector_key=:MAIN)
    return if !bss070_ebdx_ensure_core || !@vector
    row=BSS070EBDXCore.get_vector(vector_key,@battle)
    @vector.snap(row) if @vector.respond_to?(:snap)
    @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
    bss070_ebdx_apply_world_alignment
  rescue => e
    BSS064.log("EBDX animation baseline warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def bss070_ebdx_apply_world_alignment
    return if @bss070_ebdx_suspend_depth.to_i>0 || @bss070_ebdx_bas_frame
    return if !@bss070_ebdx_room || !@vector
    bss070_ebdx_recalibrate_if_needed
    main=BSS070EBDXCore.get_vector(:MAIN,@battle);main_zoom=main[4].to_f;main_zoom=1.0 if main_zoom==0
    zoom_factor=(@vector.zoom1.to_f/main_zoom)**0.75
    @battle.battlers.each_index do |i|
      sp=bss070_ebdx_native_sprite(i);next if !sp || (sp.disposed? rescue true)
      anchor=@bss070_ebdx_room.battler(i);next if !anchor
      base=bss070_ebdx_anchor_scale(i);cfg=bss070_ebdx_camera_config
      native=bss070_ebdx_neutral_battler_position(i)
      inf=[[cfg["battlerInfluence"].to_f/100.0,0.0].max,1.5].min
      sp.x=native[0]+(anchor.x-native[0])*inf if sp.respond_to?(:x=);sp.y=native[1]+(anchor.y-native[1])*inf if sp.respond_to?(:y=)
      sp.zoom_x=base[0]*(1.0+(zoom_factor-1.0)*inf) if sp.respond_to?(:zoom_x=)
      sp.zoom_y=base[1]*(1.0+(zoom_factor-1.0)*inf) if sp.respond_to?(:zoom_y=)
      sp.z=[(sp.z rescue 50).to_i,50+i].max if sp.respond_to?(:z=)
      # Move the project's real Animated Pokemon shadow through the very same
      # room projection. Visibility/bitmap/opacity remain owned by that plugin.
      sh=bss070_ebdx_native_shadow_sprite(i)
      if sh && !(sh.disposed? rescue true) && bss070_ebdx_sprite_loaded?(sh)
        if @bss070_ebdx_room.respond_to?(:shadows_enabled?) && !@bss070_ebdx_room.shadows_enabled?
          sh.visible=false if sh.respond_to?(:visible=)
        else
          sa=@bss070_ebdx_room.shadow(i)
          if sa
            sb=bss070_ebdx_shadow_anchor_scale(i);cfg=bss070_ebdx_camera_config;sinf=[[cfg["shadowInfluence"].to_f/100.0,0.0].max,1.5].min
            sn=bss070_ebdx_native_shadow_position_for(i)
            sh.x=sn[0]+(sa.x-sn[0])*sinf if sh.respond_to?(:x=);sh.y=sn[1]+(sa.y-sn[1])*sinf if sh.respond_to?(:y=)
            sh.zoom_x=sb[0]*(1.0+(zoom_factor-1.0)*sinf) if sh.respond_to?(:zoom_x=)
            sh.zoom_y=sb[1]*(1.0+(zoom_factor-1.0)*sinf) if sh.respond_to?(:zoom_y=)
            # Room scenery is z<=27 in the original EBDX data. Keep the real DBK
            # shadow above the floor/environment but below its battler.
            sh.z=[(sh.z rescue 3).to_i,30+i].max if sh.respond_to?(:z=)
          end
        end
      end
    end
    if @battle.opponent
      @battle.opponent.each_index do |t|
        sp=@sprites["trainer_#{t}"] rescue nil;next if !sp || (sp.disposed? rescue true)
        anchor=@bss070_ebdx_room.trainer(t*2+1);next if !anchor
        sp.x=anchor.x if sp.respond_to?(:x=);sp.y=anchor.y if sp.respond_to?(:y=)
      end
    end
  rescue => e
    BSS064.log("EBDX world alignment warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def bss070_ebdx_tick(advance_camera=true,align=true)
    return if !bss070_ebdx_ensure_core
    bss070_ebdx_hide_native_backdrops
    # Room animation always advances. Camera does not advance while BAS/native
    # move code owns battler transforms, preventing double-camera drift.
    @vector.update if advance_camera && bss070_ebdx_camera_enabled? && @bss070_ebdx_suspend_depth.to_i<=0 && !@bss070_ebdx_bas_frame
    @bss070_ebdx_room.update
    bss070_ebdx_apply_world_alignment if align
    if advance_camera && bss070_ebdx_camera_enabled? && @bss070_ebdx_suspend_depth.to_i<=0 && !@bss070_ebdx_bas_frame
      @bss070_ebdx_idle_timer=@bss070_ebdx_idle_timer.to_i+1
      @bss070_ebdx_motion_due=@bss070_ebdx_motion_due.to_i-1
      # Source EBDX waits 90 seconds before its first random vector. For a Gen 5
      # presentation that is visibly alive during normal command selection, use
      # restrained source-vector shots every few seconds. Full-strength BAS/native
      # animation camera still gets exclusive ownership through suspend_world.
      if @bss070_ebdx_motion_due<=0 && @vector.finished?
        bss070_ebdx_choose_camera_target
      end
    end
  end

  def pbUpdate(*args,&block)
    result=super
    if bss070_ebdx_active?
      # SOS joins, send-outs, recalls and other native scene animations own the
      # battler coordinates while @animations is non-empty. Keep the EBDX room
      # alive, but freeze its camera/alignment until that animation hands control
      # back. This is the same ownership rule used for BAS below.
      native_owned=(respond_to?(:inPartyAnimation?) && inPartyAnimation?) rescue false
      bss070_ebdx_tick(!native_owned,!native_owned)
    end
    result
  end

  def pbCommandMenu(*args,&block)
    bss070_ebdx_camera_enter(:command) if bss070_ebdx_active? && bss070_ebdx_ensure_core
    super
  ensure
    bss070_ebdx_camera_leave if bss070_ebdx_active? && @vector
  end

  def pbFightMenu(*args,&block)
    bss070_ebdx_camera_enter(:fight) if bss070_ebdx_active? && bss070_ebdx_ensure_core
    super
  ensure
    bss070_ebdx_camera_leave if bss070_ebdx_active? && @vector
  end

  def bss070_ebdx_suspend_world
    outer=@bss070_ebdx_suspend_depth.to_i<=0
    @bss081_camera_before_animation=@vector.get if outer && @vector && @vector.respond_to?(:get)
    @bss070_ebdx_suspend_depth=@bss070_ebdx_suspend_depth.to_i+1
    yield
  ensure
    @bss070_ebdx_suspend_depth=[@bss070_ebdx_suspend_depth.to_i-1,0].max
    if @bss070_ebdx_suspend_depth==0 && @vector
      saved=@bss081_camera_before_animation
      @vector.snap(saved) if saved && @vector.respond_to?(:snap)
      @bss081_camera_before_animation=nil
      @vector.inc=BSS070EBDXCore.camera_inc(:idle)
      @bss070_ebdx_camera_mode=:idle
      @bss070_ebdx_motion_due=BSS070EBDXCore.camera_duration(:idle)
      @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
      bss070_ebdx_apply_world_alignment
    end
  end

  def pbAnimation(*args,&block); return super unless bss070_ebdx_active?; bss070_ebdx_suspend_world { super }; end
  def pbCommonAnimation(*args,&block); return super unless bss070_ebdx_active?; bss070_ebdx_suspend_world { super }; end

  def bss070_ebdx_install_bas_bridge
    return if @bss070_ebdx_bas_bridge_installed
    sc=singleton_class
    if respond_to?(:bas_runtime_pump_frame) && !sc.ancestors.include?(BSS070EBDXBASPumpBridge)
      sc.prepend(BSS070EBDXBASPumpBridge)
    end
    if respond_to?(:pbPlayBattleAnimationStudio) && !sc.ancestors.include?(BSS070EBDXStudioAnimationBridge)
      sc.prepend(BSS070EBDXStudioAnimationBridge)
    end
    @bss070_ebdx_bas_bridge_installed=true
  rescue
  end

  # EBDX-authored transition ownership. The room remains the spatial authority
  # while Essentials keeps its compatible Poké Ball/shiny/databox implementation.
  def pbSendOutBattlers(sendOuts,startBattle=false,*args,&block)
    return super unless bss070_ebdx_active? && bss070_ebdx_ensure_core
    key=:MAIN
    if startBattle && sendOuts && !sendOuts.empty?
      raw=sendOuts[0][0] rescue nil
      idx=raw.respond_to?(:index) ? raw.index : raw
      key=(@battle.opposes?(idx) rescue false) ? :ENEMY : :SENDOUT
    end
    bss070_ebdx_snap_animation_baseline(key)
    bss070_ebdx_with_position_context { super(sendOuts,startBattle,*args,&block) }
  ensure
    begin
      if bss070_ebdx_active? && @vector
        @vector.inc=BSS070EBDXCore.camera_inc(:idle)
        @vector.set(BSS070EBDXCore.get_vector(:MAIN,@battle))
        @bss070_ebdx_camera_mode=:idle
        @bss070_ebdx_motion_due=BSS070EBDXCore.camera_duration(:idle)
      end
    rescue
    end
  end

  def pbRecall(idxBattler,*args,&block)
    return super unless bss070_ebdx_active? && bss070_ebdx_ensure_core
    bss070_ebdx_with_position_context { super(idxBattler,*args,&block) }
  end

  def bss_pbSOSJoin(idx_battler,*args,&block)
    return super unless bss070_ebdx_active? && bss070_ebdx_ensure_core
    bss070_ebdx_with_position_context { super(idx_battler,*args,&block) }
  ensure
    begin
      if bss070_ebdx_active?
        bss070_ebdx_invalidate_anchors
        bss070_ebdx_recalibrate_if_needed if @bss070_ebdx_room
        @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
        bss070_ebdx_apply_world_alignment if respond_to?(:bss070_ebdx_apply_world_alignment)
      end
    rescue
    end
  end

  def pbChangePokemon(*args,&block)
    result=super
    if bss070_ebdx_active?
      bss070_ebdx_invalidate_anchors
      bss070_ebdx_recalibrate_if_needed if @bss070_ebdx_room
    end
    result
  end

  # EBDX can outlive an early Escape teardown by a few frames. Essentials'
  # pbShowWindow assumes every window key still exists, which is not true after
  # plugins dispose UI early. In EBDX mode only, use nil-safe visibility writes.
  def pbShowWindow(windowType)
    return super unless bss070_ebdx_active?
    pairs={"messageBox"=>Battle::Scene::MESSAGE_BOX,"messageWindow"=>Battle::Scene::MESSAGE_BOX,"commandWindow"=>Battle::Scene::COMMAND_BOX,"fightWindow"=>Battle::Scene::FIGHT_BOX,"targetWindow"=>Battle::Scene::TARGET_BOX}
    pairs.each do |key,type|
      sp=@sprites[key] rescue nil
      sp.visible=(windowType==type) if sp && sp.respond_to?(:visible=) && !(sp.disposed? rescue false)
    end
  end

  def pbDisposeSprites(*args,&block)
    room=@bss070_ebdx_room
    begin;room.dispose if room && !(room.disposed? rescue true);rescue;end
    begin;@sprites.delete("battlebg") if @sprites.is_a?(Hash) && @sprites["battlebg"].equal?(room);rescue;end
    @bss070_ebdx_room=nil
    super
  end
end

module BSS070EBDXBASPumpBridge
  def bas_runtime_pump_frame(player)
    if respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
      @bss070_ebdx_bas_frame=true
      # EBDX scenery itself never freezes during BAS. Only the camera vector and
      # battler alignment are suspended while BAS owns them.
      bss070_ebdx_tick(false,false) if respond_to?(:bss070_ebdx_tick)
    end
    super
  ensure
    @bss070_ebdx_bas_frame=false
  end
end
module BSS070EBDXStudioAnimationBridge
  def pbPlayBattleAnimationStudio(*args,&block)
    return super unless respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    bss070_ebdx_suspend_world { super }
  end
  def pbPlayBattleAnimationStudioCustom(*args,&block)
    return super unless respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    bss070_ebdx_suspend_world { super }
  end
end

begin
  Battle::Scene.prepend(BSS070EBDXSceneBridge) if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS070EBDXSceneBridge)
rescue => e
  BSS064.log("EBDX scene bridge install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

# BSS 0.7.8 - hard visual-slot normalization + EBDX transition coordinates.
# Dynamic SOS can expose a new battler index before the side-size cache is final.
# Never index the project BATTLER_OFFSET arrays with an impossible slot.
if defined?(Battle::Scene) && Battle::Scene.respond_to?(:pbBattlerPosition)
  class << Battle::Scene
    unless method_defined?(:bss076_original_pbBattlerPosition)
      alias_method :bss076_original_pbBattlerPosition, :pbBattlerPosition
    end
    def pbBattlerPosition(index, sideSize=1)
      idx=index.to_i
      size=sideSize.to_i; size=1 if size<1; size=3 if size>3
      local=idx/2
      # If creation is one frame ahead of @sideSizes, grow only as far as the
      # supported triples canvas. Indices beyond triples reuse the third visual
      # slot instead of ever addressing nil in *_OFFSET_2/3 arrays.
      size=[size,local+1].max if local<3
      size=3 if size>3 || local>=3
      visual_local=[[local,0].max,size-1].min
      visual_idx=(idx & 1) + visual_local*2
      ctx=(defined?(BSS070EBDXCore) ? BSS070EBDXCore.position_scene : nil) rescue nil
      if ctx && ctx.respond_to?(:bss070_ebdx_active?) && ctx.bss070_ebdx_active?
        room=ctx.instance_variable_get(:@bss070_ebdx_room) rescue nil
        anchor=room.battler(visual_idx) rescue nil
        return [anchor.x.to_f,anchor.y.to_f] if anchor
      end
      bss076_original_pbBattlerPosition(visual_idx,size)
    rescue => e
      # Last-resort neutral coordinates are still preferable to raising from the
      # project's offset table during an SOS insertion frame.
      if (idx & 1)==0
        [const_defined?(:PLAYER_BASE_X) ? const_get(:PLAYER_BASE_X) : 160, const_defined?(:PLAYER_BASE_Y) ? const_get(:PLAYER_BASE_Y) : 360]
      else
        [const_defined?(:FOE_BASE_X) ? const_get(:FOE_BASE_X) : 480, const_defined?(:FOE_BASE_Y) ? const_get(:FOE_BASE_Y) : 190]
      end
    end
  end
end


# BSS 0.7.6 - safe sprite-hash teardown for cooperating scene objects.
# Essentials iterates the live Hash, but EBDX/BAS/BSS scene objects are allowed
# to unregister their helper keys from #dispose. Snapshotting the keys preserves
# the exact dispose semantics without Ruby's "can't add a new key during iteration".
def pbDisposeSpriteHash(sprites)
  return if !sprites
  sprites.keys.clone.each do |id|
    begin
      pbDisposeSprite(sprites, id) if sprites.key?(id)
    rescue => e
      BSS064.log("Sprite dispose warning #{id}: #{e.class}: #{e.message}") if defined?(BSS064)
      begin; sprites[id] = nil; rescue; end
    end
  end
  sprites.clear
end

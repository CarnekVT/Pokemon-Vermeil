#===============================================================================
# Battle Scene Studio Runtime 0.6.56
# Source-first rebuild for Pokemon Essentials v21.1.
# JSON parser architecture is the same minimal, dependency-free reader shipped
# by the supplied Battle Animation Studio runtime.
#===============================================================================
module BSSMiniJSON
  class Parser
    def initialize(text)
      @text = text.to_s
      @index = 0
      @length = @text.bytesize
    end
    def parse
      skip_space
      value = parse_value
      skip_space
      error("trailing data") if @index < @length
      value
    end
    def error(message); raise RuntimeError, "JSON parse error at #{@index}: #{message}"; end
    def byte(index = @index); @text.getbyte(index); end
    def skip_space
      while @index < @length
        b = byte
        break unless b == 32 || b == 9 || b == 10 || b == 13
        @index += 1
      end
    end
    def parse_value
      skip_space
      b = byte
      error("unexpected end") unless b
      return parse_object if b == 123
      return parse_array if b == 91
      return parse_string if b == 34
      return parse_number if b == 45 || (b >= 48 && b <= 57)
      return parse_literal("true", true) if b == 116
      return parse_literal("false", false) if b == 102
      return parse_literal("null", nil) if b == 110
      error("unexpected byte #{b}")
    end
    def parse_literal(word, value)
      error("expected #{word}") unless @text.byteslice(@index, word.length) == word
      @index += word.length
      value
    end
    def parse_object
      result = {}; @index += 1; skip_space
      if byte == 125; @index += 1; return result; end
      loop do
        skip_space; error("object key must be a string") unless byte == 34
        key = parse_string; skip_space; error("expected :") unless byte == 58
        @index += 1; result[key] = parse_value; skip_space; b = byte
        if b == 125; @index += 1; break; end
        error("expected , or }") unless b == 44; @index += 1
      end
      result
    end
    def parse_array
      result = []; @index += 1; skip_space
      if byte == 93; @index += 1; return result; end
      loop do
        result << parse_value; skip_space; b = byte
        if b == 93; @index += 1; break; end
        error("expected , or ]") unless b == 44; @index += 1
      end
      result
    end
    def parse_string
      error("expected string") unless byte == 34
      @index += 1; out = String.new; segment = @index; i = @index
      while i < @length
        b = byte(i)
        if b == 34
          out << @text.byteslice(segment, i - segment) if i > segment
          @index = i + 1; return out
        elsif b == 92
          out << @text.byteslice(segment, i - segment) if i > segment
          i += 1; error("unterminated escape") if i >= @length; esc = byte(i)
          case esc
          when 34 then out << '"'
          when 92 then out << "\\"
          when 47 then out << "/"
          when 98 then out << "\b"
          when 102 then out << "\f"
          when 110 then out << "\n"
          when 114 then out << "\r"
          when 116 then out << "\t"
          when 117
            @index = i + 1; out << parse_unicode_escape; i = @index - 1
          else error("invalid escape")
          end
          i += 1; segment = i; next
        elsif b < 32
          error("control character in string")
        end
        i += 1
      end
      error("unterminated string")
    end
    def parse_unicode_escape
      hex = @text.byteslice(@index, 4)
      error("invalid unicode escape") unless hex && hex.length == 4 && hex =~ /\A[0-9a-fA-F]{4}\z/
      @index += 4; code = hex.to_i(16)
      if code >= 0xD800 && code <= 0xDBFF && @text.byteslice(@index, 2) == "\\u"
        low_hex = @text.byteslice(@index + 2, 4)
        if low_hex && low_hex =~ /\A[0-9a-fA-F]{4}\z/
          low = low_hex.to_i(16)
          if low >= 0xDC00 && low <= 0xDFFF
            @index += 6; code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)
          end
        end
      end
      begin; [code].pack("U"); rescue; "?"; end
    end
    def parse_number
      start = @index; i = @index
      while i < @length
        b = byte(i)
        if (b >= 48 && b <= 57) || b == 45 || b == 43 || b == 46 || b == 101 || b == 69
          i += 1
        else
          break
        end
      end
      token = @text.byteslice(start, i - start); error("invalid number") if token.nil? || token.empty?
      @index = i; (token.index(".") || token.index("e") || token.index("E")) ? token.to_f : token.to_i
    end
  end
  def self.parse(text); Parser.new(text).parse; end
end

module BSS064
  VERSION = "0.8.6"
  FORMAT_VERSION = 68
  DATA_FILE = "Data/BattleSceneStudio/battles.json"
  RECOVERY_DATA_FILE = "Data/BattleSceneStudio/battles.recovery.json"
  SOS_GLOBAL_FILE = "Data/BattleSceneStudio/sos_global.json"
  SOS_CATALOG_DIR = "Data/BattleSceneStudio/SOS"
  CONTROL_FILE = "Data/BattleSceneStudio/runtime_control.json"
  ACTIVE_BATTLE_FILE = "Data/BattleSceneStudio/runtime_active_battle.json"
  STATUS_FILE = "Data/BattleSceneStudio/runtime_status.json"
  @cache = nil
  @sos_global_cache = nil
  @sos_catalog_cache = {}
  @running = false
  @last_control_token = nil

  class << self
    attr_accessor :running, :last_control_token

    def log(message)
      PBDebug.log("[BSS #{VERSION}] #{message}") if defined?(PBDebug)
    rescue
    end

    def json_parse(text)
      begin
        require "json" if !defined?(JSON)
        return JSON.parse(text) if defined?(JSON)
      rescue LoadError, StandardError
      end
      BSSMiniJSON.parse(text)
    end

    def json_generate(value)
      case value
      when Hash
        "{" + value.map { |k,v| json_generate(k.to_s) + ":" + json_generate(v) }.join(",") + "}"
      when Array
        "[" + value.map { |v| json_generate(v) }.join(",") + "]"
      when String
        '"' + value.gsub(/(["\\\b\f\n\r\t])/) { |m| { '"'=>'\\"','\\'=>'\\\\',"\b"=>'\\b',"\f"=>'\\f',"\n"=>'\\n',"\r"=>'\\r',"\t"=>'\\t' }[m] } + '"'
      when Symbol then json_generate(value.to_s)
      when Integer, Float then value.to_s
      when TrueClass then "true"
      when FalseClass then "false"
      when NilClass then "null"
      else json_generate(value.to_s)
      end
    end

    def read_json_file(path, fallback={})
      return fallback if !File.exist?(path)
      raw=File.open(path,"rb") { |f| f.read }
      parsed=json_parse(raw)
      parsed.is_a?(Hash) ? parsed : fallback
    rescue => e
      log("JSON load failed #{path}: #{e.class}: #{e.message}")
      fallback
    end

    def clear_cache
      @cache=nil
      @sos_global_cache=nil
      @sos_catalog_cache={}
    end

    def data
      return @cache if @cache
      fallback={"blueprints"=>[],"global"=>{}}
      main=read_json_file(DATA_FILE,fallback)
      recovery=File.exist?(RECOVERY_DATA_FILE) ? read_json_file(RECOVERY_DATA_FILE,fallback) : nil
      main_at=(main.is_a?(Hash) ? main["_bssSavedAt"].to_i : 0)
      recovery_at=(recovery.is_a?(Hash) ? recovery["_bssSavedAt"].to_i : 0)
      if recovery && recovery_at>main_at
        log("Using battles.recovery.json because battles.json is older/locked")
        @cache=recovery
      else
        @cache=main
      end
    end

    def find(key)
      needle=key.to_s
      rows=data["blueprints"].is_a?(Array) ? data["blueprints"] : []
      rows.find { |bp| bp.is_a?(Hash) && (bp["key"].to_s==needle || bp["id"].to_s==needle) }
    end

    def hget(hash,*keys)
      cur=hash
      keys.each { |k| return nil if !cur.is_a?(Hash); cur=cur[k] }
      cur
    end

    # Applies only explicit JSON overrides. Blank/nil fields leave Essentials'
    # normal generated value alone, which keeps ordinary foes/SOS source-faithful.
    def apply_custom_pokemon_fields(pkmn, raw, apply_moves=true)
      return pkmn if !pkmn || !raw.is_a?(Hash)
      begin
        item=raw["item"].to_s.strip.upcase
        if !item.empty? && pkmn.respond_to?(:item=) && (GameData::Item.exists?(item.to_sym) rescue false)
          pkmn.item=item.to_sym
        end
      rescue => e
        log("Custom item ignored: #{e.class}: #{e.message}")
      end
      begin
        ability=raw["ability"].to_s.strip.upcase
        if !ability.empty? && pkmn.respond_to?(:ability=) && (GameData::Ability.exists?(ability.to_sym) rescue false)
          pkmn.ability=ability.to_sym
        end
      rescue => e
        log("Custom ability ignored: #{e.class}: #{e.message}")
      end
      begin
        nature=raw["nature"].to_s.strip.upcase
        if !nature.empty? && pkmn.respond_to?(:nature=) && (GameData::Nature.exists?(nature.to_sym) rescue false)
          pkmn.nature=nature.to_sym
        end
      rescue => e
        log("Custom nature ignored: #{e.class}: #{e.message}")
      end
      begin
        case raw["gender"].to_s.downcase
        when "male"
          pkmn.makeMale if pkmn.respond_to?(:makeMale)
        when "female"
          pkmn.makeFemale if pkmn.respond_to?(:makeFemale)
        end
      rescue => e
        log("Custom gender ignored: #{e.class}: #{e.message}")
      end
      begin
        if raw.key?("happiness") && !raw["happiness"].nil? && raw["happiness"].to_s != "" && pkmn.respond_to?(:happiness=)
          pkmn.happiness=[[raw["happiness"].to_i,0].max,255].min
        end
      rescue => e
        log("Custom happiness ignored: #{e.class}: #{e.message}")
      end
      begin
        pkmn.shiny=(raw["shiny"]==true) if raw.key?("shiny") && pkmn.respond_to?(:shiny=)
      rescue => e
        log("Custom shiny ignored: #{e.class}: #{e.message}")
      end
      stat_keys=[:HP,:ATTACK,:DEFENSE,:SPECIAL_ATTACK,:SPECIAL_DEFENSE,:SPEED]
      begin
        ivs=raw["ivs"].is_a?(Hash) ? raw["ivs"] : {}
        if pkmn.respond_to?(:iv) && pkmn.iv.respond_to?(:[]=)
          stat_keys.each do |stat|
            value=ivs[stat.to_s]
            next if value.nil? || value.to_s==""
            pkmn.iv[stat]=[[value.to_i,0].max,31].min
          end
        end
      rescue => e
        log("Custom IVs ignored: #{e.class}: #{e.message}")
      end
      begin
        evs=raw["evs"].is_a?(Hash) ? raw["evs"] : {}
        if pkmn.respond_to?(:ev) && pkmn.ev.respond_to?(:[]=)
          stat_keys.each do |stat|
            value=evs[stat.to_s]
            next if value.nil? || value.to_s==""
            pkmn.ev[stat]=[[value.to_i,0].max,252].min
          end
        end
      rescue => e
        log("Custom EVs ignored: #{e.class}: #{e.message}")
      end
      begin
        mode=raw["moveMode"].to_s.downcase
        rows=raw["moves"].is_a?(Array) ? raw["moves"] : []
        custom_moves=(mode=="custom") || (mode.empty? && !rows.empty?)
        if apply_moves && custom_moves
          ids=rows.map { |x| x.to_s.strip.upcase }.reject { |x| x.empty? }.first(4)
          ids.select! { |id| GameData::Move.exists?(id.to_sym) rescue false }
          if !ids.empty?
            if pkmn.respond_to?(:forget_all_moves)
              pkmn.forget_all_moves
            elsif pkmn.respond_to?(:moves) && pkmn.moves.respond_to?(:clear)
              pkmn.moves.clear
            end
            ids.each { |id| pkmn.learn_move(id.to_sym) if pkmn.respond_to?(:learn_move) }
          end
        end
      rescue => e
        log("Custom moves ignored: #{e.class}: #{e.message}")
      end
      pkmn.calc_stats if pkmn.respond_to?(:calc_stats)
      pkmn
    end

    def global_sos
      return @sos_global_cache if @sos_global_cache
      @sos_global_cache=read_json_file(SOS_GLOBAL_FILE,{})
    end

    def sos_dataset_id
      id=global_sos["activeDataset"].to_s.downcase
      id="sm_usum" if id.empty?
      id.gsub(/[^a-z0-9_\-]/,"")
    end

    def sos_catalog(dataset=nil)
      id=(dataset || sos_dataset_id).to_s
      return @sos_catalog_cache[id] if @sos_catalog_cache.key?(id)
      path="#{SOS_CATALOG_DIR}/#{id}.json"
      @sos_catalog_cache[id]=read_json_file(path,{"id"=>id,"profiles"=>[],"groups"=>[]})
    end

    def sos_profile(species,form=0)
      sid=species.to_s.upcase; f=form.to_i
      rows=global_sos["overrides"]
      rows=rows.is_a?(Array) ? rows : []
      exact=rows.find { |p| p.is_a?(Hash) && p["species"].to_s.upcase==sid && p["form"].to_i==f }
      return exact if exact
      rows.find { |p| p.is_a?(Hash) && p["species"].to_s.upcase==sid && p["form"].to_i==0 }
    end

    def global_requirement_met?(req)
      return true if !req.is_a?(Hash)
      type=req["type"].to_s; id=req["id"].to_i; value=req["value"].to_i
      case type
      when "", "always" then true
      when "badge_min" then (defined?($player) && $player && $player.respond_to?(:badge_count) ? $player.badge_count.to_i : 0) >= value
      when "badge_max" then (defined?($player) && $player && $player.respond_to?(:badge_count) ? $player.badge_count.to_i : 0) <= value
      when "switch_on" then id>0 && defined?($game_switches) && $game_switches && !!$game_switches[id]
      when "switch_off" then id>0 && defined?($game_switches) && $game_switches && !$game_switches[id]
      when "variable_min" then id>0 && defined?($game_variables) && $game_variables && $game_variables[id].to_i >= value
      when "variable_max" then id>0 && defined?($game_variables) && $game_variables && $game_variables[id].to_i <= value
      when "variable_equals" then id>0 && defined?($game_variables) && $game_variables && $game_variables[id].to_i == value
      when "player_level_min"
        levels=(defined?($player) && $player && $player.respond_to?(:party)) ? $player.party.compact.map { |p| p.level.to_i } : []
        (levels.empty? ? 0 : levels.max) >= value
      when "player_level_max"
        levels=(defined?($player) && $player && $player.respond_to?(:party)) ? $player.party.compact.map { |p| p.level.to_i } : []
        (levels.empty? ? 0 : levels.max) <= value
      when "map_id" then defined?($game_map) && $game_map && $game_map.map_id.to_i == value
      when "day" then defined?(PBDayNight) && PBDayNight.respond_to?(:isDay?) && PBDayNight.isDay?
      when "night" then defined?(PBDayNight) && PBDayNight.respond_to?(:isNight?) && PBDayNight.isNight?
      else true
      end
    rescue
      false
    end

    def global_sos_requirements_met?
      rows=global_sos["requirements"]
      rows=rows.is_a?(Array) ? rows : []
      rows.all? { |req| global_requirement_met?(req) }
    end

    def global_sos_active?
      cfg=global_sos
      return false if cfg["enabled"]!=true
      return false if !global_sos_requirements_met?
      case cfg["mode"].to_s
      when "always" then true
      when "switch"
        id=cfg["switchId"].to_i
        return false if id<=0 || !defined?($game_switches) || !$game_switches
        !!$game_switches[id]
      else false
      end
    rescue
      false
    end

    def write_status(state,extra={})
      payload={"state"=>state.to_s,"runtimeVersion"=>VERSION,"formatVersion"=>FORMAT_VERSION,"time"=>Time.now.to_i}
      payload.merge!(extra) if extra.is_a?(Hash)
      Dir.mkdir("Data/BattleSceneStudio") if !Dir.exist?("Data/BattleSceneStudio") rescue nil
      File.open(STATUS_FILE,"wb") { |f| f.write(json_generate(payload)) }
      true
    rescue => e
      log("Status write failed: #{e.class}: #{e.message}")
      false
    end
  end
end

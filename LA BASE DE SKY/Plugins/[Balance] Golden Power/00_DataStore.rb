#===============================================================================
# Standalone JSON storage shared by Golden/Arcane systems.
# PBS and ChangeDex remain read-only baselines; these files store only mod data.
#===============================================================================
unless defined?(CarnekStandaloneJSON)
  module CarnekStandaloneJSON
    class Reader
      def initialize(text); @s=text.to_s; @i=0; end
      def parse; skip_ws; v=parse_value; skip_ws; v; end
      def parse_value
        skip_ws; ch=@s[@i,1]
        return parse_object if ch=="{"
        return parse_array if ch=="["
        return parse_string if ch=='"'
        return parse_number if ch=="-" || (ch && ch>="0" && ch<="9")
        return literal("true",true) if @s[@i,4]=="true"
        return literal("false",false) if @s[@i,5]=="false"
        return literal("null",nil) if @s[@i,4]=="null"
        raise "Invalid JSON near byte #{@i}"
      end
      def parse_object
        h={}; @i+=1; skip_ws
        if @s[@i,1]=="}"; @i+=1; return h; end
        loop do
          skip_ws; k=parse_string; skip_ws
          raise "Expected ':'" if @s[@i,1] != ":"
          @i+=1; h[k]=parse_value; skip_ws
          ch=@s[@i,1]; @i+=1
          break if ch=="}"
          raise "Expected ','" if ch != ","
        end
        h
      end
      def parse_array
        a=[]; @i+=1; skip_ws
        if @s[@i,1]=="]"; @i+=1; return a; end
        loop do
          a << parse_value; skip_ws
          ch=@s[@i,1]; @i+=1
          break if ch=="]"
          raise "Expected ','" if ch != ","
        end
        a
      end
      def parse_string
        raise "Expected string" if @s[@i,1] != '"'
        @i+=1; out=""
        while @i < @s.length
          ch=@s[@i,1]; @i+=1
          return out if ch=='"'
          if ch=="\\"
            esc=@s[@i,1]; @i+=1
            case esc
            when '"','\\','/' then out << esc
            when 'b' then out << "\b"
            when 'f' then out << "\f"
            when 'n' then out << "\n"
            when 'r' then out << "\r"
            when 't' then out << "\t"
            when 'u'
              code=@s[@i,4].to_i(16); @i+=4
              begin; out << [code].pack("U"); rescue; out << "?"; end
            else; raise "Invalid escape"; end
          else
            out << ch
          end
        end
        raise "Unterminated string"
      end
      def parse_number
        s=@i; @i+=1 if @s[@i,1]=="-"
        @i+=1 while @s[@i,1] && @s[@i,1] =~ /[0-9]/
        if @s[@i,1]=="."; @i+=1; @i+=1 while @s[@i,1] && @s[@i,1] =~ /[0-9]/; end
        if @s[@i,1] =~ /[eE]/; @i+=1; @i+=1 if @s[@i,1] =~ /[+-]/; @i+=1 while @s[@i,1] && @s[@i,1] =~ /[0-9]/; end
        raw=@s[s...@i]; (raw.include?(".") || raw =~ /[eE]/) ? raw.to_f : raw.to_i
      end
      def literal(word,val); raise "Invalid literal" if @s[@i,word.length] != word; @i+=word.length; val; end
      def skip_ws; @i+=1 while @s[@i,1] && @s[@i,1] =~ /\s/; end
    end

    @cache={}
    def self.utf8(raw)
      s=raw.to_s.dup
      s=s.byteslice(3,s.bytesize-3) || "" if s.bytesize>=3 && s.getbyte(0)==0xEF && s.getbyte(1)==0xBB && s.getbyte(2)==0xBF
      begin
        s.force_encoding(Encoding::UTF_8)
        s=s.encode(Encoding::UTF_8,:invalid=>:replace,:undef=>:replace,:replace=>"") unless s.valid_encoding?
      rescue StandardError
      end
      s
    end
    def self.parse(text)
      begin
        require "json" unless defined?(JSON)
        return JSON.parse(text) if defined?(JSON) && JSON.respond_to?(:parse)
      rescue StandardError
      end
      Reader.new(text).parse
    end
    def self.signature(path)
      return nil unless File.file?(path)
      [File.size(path).to_i, File.mtime(path).to_f]
    rescue StandardError
      nil
    end
    def self.load(path, fallback={})
      sig=signature(path); cached=@cache[path]
      return fallback if !sig
      return cached[:doc] if cached && cached[:sig]==sig
      raw=File.open(path,"rb"){|f| f.read}
      doc=parse(utf8(raw)); doc=fallback if !doc.is_a?(Hash)
      @cache[path]={:sig=>sig,:doc=>doc}; doc
    rescue StandardError => e
      echoln("[Carnek JSON] #{path}: #{e.message}") if defined?(echoln)
      fallback
    end
    def self.invalidate(path=nil); path ? @cache.delete(path) : @cache.clear; end
  end
end

module GoldenSystem
  DATA_DIR       = "Data/GoldenSystem"
  SPECIES_JSON   = "#{DATA_DIR}/species.json"
  MOVES_JSON     = "#{DATA_DIR}/golden_moves.json"
  SETTINGS_JSON  = "#{DATA_DIR}/settings.json"
  TRAINERS_JSON  = "#{DATA_DIR}/trainers.json"

  module Data
    @form_proxy_cache={}
    def self.species_document
      # Data lookups can be triggered while Essentials is building species and
      # move objects.  Never recursively re-enter the JSON loader.
      fallback={"schema"=>1,"species"=>{}}
      if @species_document_loading
        return @species_document || fallback
      end
      @species_document_loading=true
      doc=CarnekStandaloneJSON.load(GoldenSystem::SPECIES_JSON,{"schema"=>1,"species"=>{}})
      doc["species"]={} unless doc["species"].is_a?(Hash)
      @species_document=doc
      doc
    ensure
      @species_document_loading=false
    end
    def self.raw_entry(species, form=0)
      key=form.to_i==0 ? species.to_s.upcase : "#{species.to_s.upcase},#{form.to_i}"
      value=species_document["species"][key]
      value.is_a?(Hash) ? value : nil
    end
    def self.deep_merge(a,b)
      ret=(a||{}).dup
      (b||{}).each do |k,v|
        ret[k]=(ret[k].is_a?(Hash) && v.is_a?(Hash)) ? deep_merge(ret[k],v) : v
      end
      ret
    end
    def self.entry(species, form=0)
      base=raw_entry(species,0) || {}
      return base if form.to_i==0
      deep_merge(base,raw_entry(species,form) || {})
    end
    # Editor-only visibility metadata. It follows ChangeDex's "SPECIES,FORM"
    # convention but remains stored in GoldenSystem/species.json.
    def self.hidden_form?(species,form)
      return false if form.to_i<=0
      key="#{species.to_s.upcase},#{form.to_i}"
      list=species_document["hiddenForms"]
      list.is_a?(Array) && list.any?{|v| v.to_s.strip.upcase==key}
    rescue
      false
    end
    def self.visible_form?(species,form); !hidden_form?(species,form); end
    def self.hidden_forms
      list=species_document["hiddenForms"]
      list.is_a?(Array) ? list.map{|v| v.to_s.upcase}.uniq : []
    end
    def self.set_hidden_forms(selection,hidden=true)
      pairs=selection.is_a?(Hash) ? selection.map{|k,v| [k,v]} : Array(selection).map{|k| [k,hidden]}
      doc=species_document
      doc["hiddenForms"]=[] unless doc["hiddenForms"].is_a?(Array)
      pairs.each do |key,value|
        normalized=key.to_s.strip.upcase
        next unless normalized =~ /\A[^,]+,\d+\z/
        if value
          doc["hiddenForms"] << normalized unless doc["hiddenForms"].any?{|v| v.to_s.upcase==normalized}
        else
          doc["hiddenForms"].delete_if{|v| v.to_s.upcase==normalized}
        end
      end
      save_species_document!(doc)
      hidden_forms
    end
    def self.save_species_document!(doc)
      require "json" unless defined?(JSON)
      temp="#{GoldenSystem::SPECIES_JSON}.tmp"
      File.binwrite(temp,JSON.pretty_generate(doc)+"\n")
      File.rename(temp,GoldenSystem::SPECIES_JSON)
      CarnekStandaloneJSON.invalidate(GoldenSystem::SPECIES_JSON)
      @species_document=nil
      @form_proxy_cache={}
      true
    rescue
      begin; File.delete(temp) if temp && File.file?(temp); rescue; end
      false
    end
    def self.import_changedex_hidden_forms!
      path="Data/ChangeDex/config.json"
      config=CarnekStandaloneJSON.load(path,{})
      list=config["hiddenForms"]
      return [] unless list.is_a?(Array)
      set_hidden_forms(list,true)
    end
    def self.golden_type(species,form=0)
      v=entry(species,form)["goldenType"]; return nil if v.nil? || v.to_s.strip.empty?
      id=v.to_s.upcase.to_sym; GameData::Type.exists?(id) ? id : nil
    end
    def self.golden_type_replace(species,form=0)
      v=entry(species,form)["goldenTypeReplace"]; return nil if v.nil? || v.to_s.strip.empty?
      id=v.to_s.upcase.to_sym; GameData::Type.exists?(id) ? id : nil
    end
    def self.form_definition(species,source_form=0)
      raw=entry(species,source_form)["goldenForm"]
      return nil if raw.nil?
      raw={"number"=>raw} if raw.is_a?(Numeric) || raw.is_a?(String)
      return nil unless raw.is_a?(Hash)
      num=(raw["number"] || raw["form"] || raw["targetForm"]).to_i
      return nil if num<=0
      ret=raw.dup; ret["number"]=num; ret
    end
    def self.form_number(species,source_form=0)
      d=form_definition(species,source_form); d ? d["number"].to_i : nil
    end
    def self.stats_hash(raw)
      keys=[:HP,:ATTACK,:DEFENSE,:SPEED,:SPECIAL_ATTACK,:SPECIAL_DEFENSE]
      return nil if raw.nil?
      if raw.is_a?(Array)
        h={}; keys.each_with_index{|k,i| h[k]=raw[i].to_i if !raw[i].nil?}; return h
      end
      return nil unless raw.is_a?(Hash)
      h={}
      keys.each{|k| v=raw[k.to_s] || raw[k.to_s.downcase] || raw[k]; h[k]=v.to_i unless v.nil?}
      h
    end
    def self.build_form_proxy(species, source_form, target_form, definition)
      base=nil
      begin
        candidate=GameData::Species.get_species_form(species,target_form)
        base=candidate if candidate && (!candidate.respond_to?(:form) || candidate.form.to_i==target_form.to_i)
      rescue StandardError
      end
      begin; base ||= GameData::Species.get_species_form(species,source_form); rescue StandardError; end
      begin; base ||= GameData::Species.get(species); rescue StandardError; end
      return base if !base
      cache_key=[species.to_s.upcase,target_form.to_i,source_form.to_i,base.object_id,definition.hash]
      cached=@form_proxy_cache[cache_key]; return cached if cached
      p=base.dup
      p.instance_variable_set(:@form,target_form.to_i)
      name=definition["name"] || definition["formName"]
      if name && !name.to_s.empty?
        p.instance_variable_set(:@real_form_name,name.to_s)
        p.instance_variable_set(:@form_name,name.to_s)
      end
      # Golden Form typing is derived from the source form by default.
      # An explicit goldenForm.types array/string still has priority, but it is
      # no longer required to duplicate goldenType/goldenTypeReplace in JSON.
      types=definition["types"]
      if types.is_a?(String); types=types.split(","); end
      ids=nil
      if types.is_a?(Array) && !types.empty?
        explicit=types.map{|x| x.to_s.upcase.to_sym}.select{|x| GameData::Type.exists?(x)}
        ids=explicit[0,2] if !explicit.empty?
      end
      if !ids || ids.empty?
        source_data=nil
        begin; source_data=GameData::Species.get_species_form(species,source_form); rescue StandardError; end
        begin; source_data ||= GameData::Species.get(species); rescue StandardError; end
        source_types=(source_data && source_data.respond_to?(:types)) ? source_data.types : nil
        ids=(source_types || []).compact[0,2].clone
        golden=golden_type(species,source_form)
        if golden && GameData::Type.exists?(golden) && !ids.include?(golden)
          if ids.length<=1
            ids << golden
          else
            replace=golden_type_replace(species,source_form)
            idx=replace ? ids.index(replace) : nil
            # Legacy/incomplete data should still never create a triple type.
            # If the requested replacement is absent, use the secondary slot,
            # matching Golden Power's established fallback behaviour.
            idx=1 if idx.nil?
            ids[idx]=golden
          end
        end
        ids=ids.compact.uniq[0,2]
      end
      p.instance_variable_set(:@types,ids) if ids && !ids.empty?
      stats=stats_hash(definition["baseStats"])
      if stats && !stats.empty?
        current=(base.base_stats rescue {}).dup
        stats.each{|k,v| current[k]=v}
        p.instance_variable_set(:@base_stats,current)
      end
      ability=definition["ability"]
      if ability && !ability.to_s.strip.empty?
        id=ability.to_s.upcase.to_sym
        if GameData::Ability.exists?(id)
          p.instance_variable_set(:@abilities,[id])
          p.instance_variable_set(:@hidden_abilities,[])
        end
      end
      @form_proxy_cache[cache_key]=p
      p
    end
    def self.reload!
      CarnekStandaloneJSON.invalidate(GoldenSystem::SPECIES_JSON)
      CarnekStandaloneJSON.invalidate(GoldenSystem::MOVES_JSON)
      CarnekStandaloneJSON.invalidate(GoldenSystem::SETTINGS_JSON)
      CarnekStandaloneJSON.invalidate(GoldenSystem::TRAINERS_JSON)
      @species_document=nil
      @species_document_loading=false
      @form_proxy_cache={}
    end
  end
end

#===============================================================================
# Arcane Ability standalone JSON storage.
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
        h={}; @i+=1; skip_ws; if @s[@i,1]=="}"; @i+=1; return h; end
        loop do
          skip_ws; k=parse_string; skip_ws; raise "Expected ':'" if @s[@i,1] != ":"
          @i+=1; h[k]=parse_value; skip_ws; ch=@s[@i,1]; @i+=1; break if ch=="}"; raise "Expected ','" if ch != ","
        end; h
      end
      def parse_array
        a=[]; @i+=1; skip_ws; if @s[@i,1]=="]"; @i+=1; return a; end
        loop do
          a << parse_value; skip_ws; ch=@s[@i,1]; @i+=1; break if ch=="]"; raise "Expected ','" if ch != ","
        end; a
      end
      def parse_string
        raise "Expected string" if @s[@i,1] != '"'; @i+=1; out=""
        while @i<@s.length
          ch=@s[@i,1]; @i+=1; return out if ch=='"'
          if ch=="\\"
            esc=@s[@i,1]; @i+=1
            case esc
            when '"','\\','/' then out << esc
            when 'b' then out << "\b"
            when 'f' then out << "\f"
            when 'n' then out << "\n"
            when 'r' then out << "\r"
            when 't' then out << "\t"
            when 'u'; code=@s[@i,4].to_i(16); @i+=4; begin; out << [code].pack("U"); rescue; out << "?"; end
            else; raise "Invalid escape"; end
          else; out << ch; end
        end
        raise "Unterminated string"
      end
      def parse_number
        s=@i; @i+=1 if @s[@i,1]=="-"; @i+=1 while @s[@i,1] && @s[@i,1]=~/[0-9]/
        if @s[@i,1]=="."; @i+=1; @i+=1 while @s[@i,1] && @s[@i,1]=~/[0-9]/; end
        if @s[@i,1]=~/[eE]/; @i+=1; @i+=1 if @s[@i,1]=~/[+-]/; @i+=1 while @s[@i,1] && @s[@i,1]=~/[0-9]/; end
        raw=@s[s...@i]; (raw.include?(".")||raw=~/[eE]/) ? raw.to_f : raw.to_i
      end
      def literal(w,v); raise "Invalid literal" if @s[@i,w.length]!=w; @i+=w.length; v; end
      def skip_ws; @i+=1 while @s[@i,1] && @s[@i,1]=~/\s/; end
    end
    @cache={}
    def self.utf8(raw); s=raw.to_s.dup; s=s.byteslice(3,s.bytesize-3)||"" if s.bytesize>=3 && s.getbyte(0)==0xEF && s.getbyte(1)==0xBB && s.getbyte(2)==0xBF; begin; s.force_encoding(Encoding::UTF_8); rescue; end; s; end
    def self.parse(text); begin; require "json" unless defined?(JSON); return JSON.parse(text) if defined?(JSON) && JSON.respond_to?(:parse); rescue StandardError; end; Reader.new(text).parse; end
    def self.signature(path); File.file?(path) ? [File.size(path).to_i,File.mtime(path).to_f] : nil; rescue; nil; end
    def self.load(path,fallback={}); sig=signature(path); return fallback if !sig; c=@cache[path]; return c[:doc] if c && c[:sig]==sig; doc=parse(utf8(File.open(path,"rb"){|f| f.read})); doc=fallback if !doc.is_a?(Hash); @cache[path]={:sig=>sig,:doc=>doc}; doc; rescue StandardError=>e; echoln("[Carnek JSON] #{path}: #{e.message}") if defined?(echoln); fallback; end
    def self.invalidate(path=nil); path ? @cache.delete(path) : @cache.clear; end
  end
end

module ArcaneAbilities
  DATA_DIR     = "Data/ArcaneAbilities"
  SPECIES_JSON = "#{DATA_DIR}/species.json"
  module Data
    def self.document
      doc=CarnekStandaloneJSON.load(ArcaneAbilities::SPECIES_JSON,{"schema"=>1,"species"=>{}})
      doc["species"]={} unless doc["species"].is_a?(Hash)
      doc
    end
    def self.raw_entry(species,form=0)
      key=form.to_i==0 ? species.to_s.upcase : "#{species.to_s.upcase},#{form.to_i}"
      value=document["species"][key]
      value.is_a?(Hash) ? value : nil
    end
    def self.ability_for(species,form=0)
      own=raw_entry(species,form)
      if own && own.key?("ability")
        v=own["ability"]; return nil if v.nil? || v.to_s.strip.empty?
        id=v.to_s.upcase.to_sym; return id if GameData::Ability.exists?(id)
      end
      if form.to_i != 0
        base=raw_entry(species,0)
        if base && base.key?("ability")
          v=base["ability"]; return nil if v.nil? || v.to_s.strip.empty?
          id=v.to_s.upcase.to_sym; return id if GameData::Ability.exists?(id)
        end
      end
      nil
    end
    # Editor metadata only: hidden species remain fully playable and keep their
    # Arcane ability; Arcane Studio simply omits them from its visible list.
    def self.hidden?(species,form=0)
      entry=raw_entry(species,form)
      entry && (entry["hidden"]==true || entry["hidden"]==1)
    end
    def self.visible?(species,form=0); !hidden?(species,form); end
    def self.hidden_species
      document["species"].each_with_object([]) do |(key,entry),out|
        out << key if entry.is_a?(Hash) && (entry["hidden"]==true || entry["hidden"]==1)
      end
    end
    def self.set_hidden(species,hidden=true,form=0)
      set_hidden_many({form.to_i==0 ? species.to_s.upcase : "#{species.to_s.upcase},#{form.to_i}"=>hidden})
      !!hidden
    end
    # Supports both a checkbox hash ({"PIKACHU"=>true}) and a multi-select
    # array (["PIKACHU", "EEVEE"]). This is the Arcane Studio hide/show API.
    def self.set_hidden_many(selection,hidden=true)
      pairs=selection.is_a?(Hash) ? selection.map{|k,v| [k,v]} : Array(selection).map{|k| [k,hidden]}
      doc=document
      pairs.each do |key,value|
        normalized=key.to_s.upcase
        entry=doc["species"][normalized]
        entry={} unless entry.is_a?(Hash)
        entry["hidden"]=!!value
        doc["species"][normalized]=entry
      end
      save_document!(doc)
      pairs.map{|key,value| [key.to_s.upcase,!!value]}.to_h
    end
    def self.save_document!(doc)
      require "json" unless defined?(JSON)
      dir=File.dirname(ArcaneAbilities::SPECIES_JSON)
      Dir.mkdir(dir) unless Dir.exist?(dir)
      temp="#{ArcaneAbilities::SPECIES_JSON}.tmp"
      File.binwrite(temp,JSON.pretty_generate(doc)+"\n")
      File.rename(temp,ArcaneAbilities::SPECIES_JSON)
      CarnekStandaloneJSON.invalidate(ArcaneAbilities::SPECIES_JSON)
      true
    rescue
      begin; File.delete(temp) if temp && File.file?(temp); rescue; end
      false
    end
    def self.reload!; CarnekStandaloneJSON.invalidate(ArcaneAbilities::SPECIES_JSON); end
  end
end

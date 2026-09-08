#===============================================================================
# Golden Moves from Data/GoldenSystem/golden_moves.json
#===============================================================================
module GoldenSystem
  module GoldenMoves
    @cache=nil
    def self.reload!; @cache=nil; CarnekStandaloneJSON.invalidate(GoldenSystem::MOVES_JSON); end
    def self.all
      return @cache if @cache
      @cache={}
      doc=CarnekStandaloneJSON.load(GoldenSystem::MOVES_JSON,{"schema"=>1,"moves"=>{}})
      rows=doc["moves"].is_a?(Hash) ? doc["moves"] : {}
      rows.each do |raw_key,value|
        next unless value.is_a?(Hash)
        parts=raw_key.to_s.split("|"); next if parts.length<2
        species=parts[0].to_s.upcase.to_sym; move=parts[1].to_s.upcase.to_sym
        source_form=(parts.length>=3 && parts[2].to_s!="*") ? parts[2].to_i : nil
        data={:species=>species,:move=>move,:source_form=>source_form}
        data[:form]=(value["form"] || value["targetForm"]).to_i if value.key?("form") || value.key?("targetForm")
        data[:name]=value["name"].to_s if value["name"]
        if value["type"]
          t=value["type"].to_s.upcase.to_sym; data[:type]=t if GameData::Type.exists?(t)
        end
        data[:power]=[value["power"].to_i,0].max if value.key?("power")
        data[:accuracy]=[[value["accuracy"].to_i,0].max,100].min if value.key?("accuracy")
        data[:description]=value["description"].to_s if value["description"]
        fc=value["functionCode"] || value["function_code"]
        data[:function_code]=fc.to_s.strip if fc && !fc.to_s.strip.empty?
        data[:effect]=value["effect"].to_s if value["effect"]
        @cache[[species,move,source_form]]=data
      end
      @cache
    end
    def self.get(species,move,source_form=nil)
      return nil if !species || !move
      species=species.to_s.upcase.to_sym; move=move.to_s.upcase.to_sym
      unless source_form.nil?
        exact=all[[species,move,source_form.to_i]]; return exact if exact
      end
      all[[species,move,nil]]
    end
    def self.exists?(species,move,source_form=nil); !get(species,move,source_form).nil?; end
    def self.source_form_for(battler)
      return nil if !battler || !battler.pokemon
      p=battler.pokemon
      return p.pre_golden_form if p.respond_to?(:pre_golden_form) && !p.pre_golden_form.nil?
      p.form
    end
    def self.active_for?(battler,move)
      return false if !battler || !battler.isOnGoldenForm?
      data=get(battler.pokemon.species,move,source_form_for(battler)); return false if !data
      return false if data[:form] && battler.form != data[:form]
      true
    end
    def self.for_battler(battler,move); active_for?(battler,move) ? get(battler.pokemon.species,move,source_form_for(battler)) : nil; end
    def self.info(species,move,source_form=nil)
      data=get(species,move,source_form); return nil if !data
      bits=[]; bits << data[:name] if data[:name] && !data[:name].empty?
      bits << "Tipo: #{GameData::Type.get(data[:type]).name}" if data[:type]
      bits << "Potencia: #{data[:power]}" if data[:power]
      bits << "Precisión: #{data[:accuracy]}" if data[:accuracy]
      bits << "Effect: #{data[:function_code]}" if data[:function_code] && !data[:function_code].empty?
      bits << data[:description] if data[:description] && !data[:description].empty?
      bits.join(" · ")
    end
  end
  module GoldenMoveEffects
    @handlers={}
    def self.add(id,&block); @handlers[id.to_s.upcase.to_sym]=block; end
    def self.trigger(id,phase,move,user,target=nil); h=@handlers[id.to_s.upcase.to_sym] if id; h.call(phase,move,user,target) if h; end
  end
  module BattleMoveGoldenProperties
    # A Golden Move can optionally borrow an existing FunctionCode. The proxy
    # is an instance of that Battle::Move subclass, while the original move
    # keeps its ID/PP/animation and the Golden type/power/accuracy overrides.
    FUNCTION_DELEGATES = {
      :pbOnStartUse => 0,
      :pbMoveFailed? => 0,
      :pbFailsAgainstTarget? => 0,
      :pbBaseDamage => 1,
      :pbBaseDamageMultiplier => 1,
      :pbModifyDamage => 1,
      :pbEffectGeneral => 0,
      :pbEffectAgainstTarget => 0,
      :pbEffectWhenDealingDamage => 0,
      :pbAdditionalEffect => 0,
      :pbEffectAfterAllHits => 0,
      :pbEndOfMoveUsageEffect => 0,
      :pbNumHits => 0,
      :pbFixedDamage => 0,
      :pbCritialOverride => 0,
      :pbCriticalOverride => 0,
      :pbChangeUsageCounters => 0
    }

    def golden_variant_data(user)
      return nil if instance_variable_defined?(:@__golden_function_proxy) && @__golden_function_proxy
      return nil if @__golden_variant_busy
      @__golden_variant_busy=true
      user ? GoldenSystem::GoldenMoves.for_battler(user,@id) : nil
    ensure
      @__golden_variant_busy=false
    end

    def golden_sync_proxy(proxy)
      [:@pp, :@total_pp, :@power, :@accuracy, :@type, :@category, :@priority, :@id, :@name].each do |ivar|
        proxy.instance_variable_set(ivar,instance_variable_get(ivar)) if instance_variable_defined?(ivar)
      end
    end

    def golden_function_proxy(user)
      data=golden_variant_data(user)
      code=data && data[:function_code] ? data[:function_code].to_s.strip : ""
      return nil if code.empty? || code.casecmp("None")==0
      key=[code,@id]
      if @__golden_function_proxy_key != key
        @__golden_function_proxy_key=key
        @__golden_function_proxy_obj=nil
        begin
          klass=Battle::Move.const_get(code)
          if klass.is_a?(Class) && klass <= Battle::Move
            pmove=Pokemon::Move.new(@id)
            proxy=klass.new(@battle,pmove)
            proxy.instance_variable_set(:@__golden_function_proxy,true)
            @__golden_function_proxy_obj=proxy
          end
        rescue NameError, StandardError
          @__golden_function_proxy_obj=nil
        end
      end
      golden_sync_proxy(@__golden_function_proxy_obj) if @__golden_function_proxy_obj
      @__golden_function_proxy_obj
    end

    def golden_delegate_function(method_name,user,*args,&block)
      proxy=golden_function_proxy(user)
      return [false,nil] if !proxy || !proxy.respond_to?(method_name)
      begin
        owner=proxy.class.instance_method(method_name).owner
        return [false,nil] if owner==GoldenSystem::BattleMoveGoldenProperties || owner==Battle::Move
        return [true,proxy.__send__(method_name,*args,&block)]
      rescue NameError
        return [false,nil]
      end
    end

    FUNCTION_DELEGATES.each do |method_name,user_index|
      define_method(method_name) do |*args,&block|
        user=(user_index.nil? ? nil : args[user_index])
        delegated,value=golden_delegate_function(method_name,user,*args,&block)
        return value if delegated
        super(*args,&block)
      end
    end

    def pbCalcType(user)
      data=golden_variant_data(user)
      # Do not call super here.  Enhanced/MegaSignatureAbilities can route its
      # own pbCalcType back through this prepend, causing infinite alternation.
      # @type is the already resolved base move type for non-Golden moves.
      return data[:type] if data && data[:type]
      return @type
    end

    def pbCalcDamage(user,target,numTargets=1)
      data=golden_variant_data(user); old_power=@power; @power=data[:power] if data && data[:power]
      GoldenSystem::GoldenMoveEffects.trigger(data[:effect],:before_damage,self,user,target) if data
      ret=super
      GoldenSystem::GoldenMoveEffects.trigger(data[:effect],:after_damage,self,user,target) if data
      ret
    ensure
      @power=old_power if defined?(old_power)
    end

    def pbAccuracyCheck(user,target)
      data=golden_variant_data(user)
      if data && data[:function_code] && !data.key?(:accuracy)
        delegated,value=golden_delegate_function(:pbAccuracyCheck,user,user,target)
        return value if delegated
      end
      old_accuracy=@accuracy; @accuracy=data[:accuracy] if data && data.key?(:accuracy); super
    ensure
      @accuracy=old_accuracy if defined?(old_accuracy)
    end

    def display_type(battler); data=golden_variant_data(battler); data && data[:type] ? data[:type] : super; end
    def display_damage(battler); data=golden_variant_data(battler); data && data[:power] ? data[:power] : super; end
    def golden_display_name(battler); data=golden_variant_data(battler); (!data || !data[:name] || data[:name].empty?) ? @name : data[:name]; end
  end
  module SameTypeApogee
    def pbCalcDamageMultipliers(user,target,numTargets,type,baseDmg,multipliers)
      ret=super
      if user && user.isOnGoldenPower? && user.pokemon
        gt=user.pokemon.golden_type
        if gt && user.pokemon.types.include?(gt) && type==gt
          multipliers[:power_multiplier] *= GoldenSystem.settings[:same_type_multiplier]
        end
      end
      ret
    end
  end
end
Battle::Move.prepend(GoldenSystem::BattleMoveGoldenProperties)
Battle::Move.prepend(GoldenSystem::SameTypeApogee)

#===============================================================================
# Runtime move-name synchronization.
# DBK and some custom fight menus read Battle::Move#name directly instead of
# calling a contextual display-name helper.  Battle::Move instances belong to
# the battler, so updating their display name is safe and does not touch PBS.
#===============================================================================
module GoldenSystem
  module BattlerGoldenMoveNameSync
    def pbGoldenMoveDisplayLabel(move, original)
      label = original
      if @pokemon && isOnGoldenForm? &&
         move.respond_to?(:golden_display_name) &&
         GoldenSystem::GoldenMoves.active_for?(self, move.id)
        label = move.golden_display_name(self)
      end
      return label
    end

    def pbGoldenMoveShortLabel(label)
      if defined?(Settings) && Settings.const_defined?(:SHORTEN_MOVES) && Settings::SHORTEN_MOVES &&
         label.length > 16
        return label[0..12] + "..."
      end
      return label
    end

    def pbApplyGoldenMoveDisplayName(move, label)
      move.instance_variable_set(:@name, label)
      short = pbGoldenMoveShortLabel(label)
      if move.respond_to?(:short_name=)
        move.short_name = short
      else
        move.instance_variable_set(:@short_name, short)
      end
    end

    def pbSyncGoldenMoveDisplayNames
      return if !@moves
      @moves.each do |move|
        next if !move
        unless move.instance_variable_defined?(:@golden_original_name)
          move.instance_variable_set(:@golden_original_name, move.name)
        end
        original = move.instance_variable_get(:@golden_original_name)
        label = pbGoldenMoveDisplayLabel(move, original)
        pbApplyGoldenMoveDisplayName(move, label)
      end
    end

    def pbUpdate(*args,&block)
      ret=super
      pbSyncGoldenMoveDisplayNames
      return ret
    end
  end
end

Battle::Battler.prepend(GoldenSystem::BattlerGoldenMoveNameSync) unless
  Battle::Battler.ancestors.include?(GoldenSystem::BattlerGoldenMoveNameSync)

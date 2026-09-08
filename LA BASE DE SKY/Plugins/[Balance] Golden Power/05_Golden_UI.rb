
#===============================================================================
# Golden visual indicators for Summary and compatible fight menus.
#===============================================================================
module GoldenSystem
  module SummaryHelpers
    def self.power_preview_types(pkmn)
      return pkmn.types if !pkmn || !pkmn.golden_type || !GameData::Type.exists?(pkmn.golden_type)
      core = pkmn.types[0, 2].compact.clone
      return core if core.include?(pkmn.golden_type)
      if core.length <= 1
        core << pkmn.golden_type
      else
        replace = pkmn.golden_type_replace
        idx = replace ? core.index(replace) : nil
        idx = 1 if idx.nil?
        core[idx] = pkmn.golden_type
      end
      return core.compact.uniq
    end

    def self.type_string(type_ids)
      return _INTL("-") if !type_ids || type_ids.empty?
      return type_ids.map { |id| GameData::Type.get(id).name rescue id.to_s }.join("/")
    end
  end
end

if defined?(PokemonSummary_Scene)
  module GoldenSystem
    module SummaryGoldenMoveInfo
      GOLD_BASE   = Color.new(160, 112, 0)
      GOLD_SHADOW = Color.new(248, 216, 104)
      GOLD_DIM    = Color.new(124, 88, 0)
      GOLD_DIM_S  = Color.new(224, 192, 120)

      def drawPageOne
        ret = super
        return ret if !@pokemon
        lines = []
        if @pokemon.golden_type
          lines << [_INTL("✦ PODER DORADO"), 224, 296, :left, GOLD_BASE, GOLD_SHADOW]
          lines << [_INTL("Tipos: {1} → {2}",
            GoldenSystem::SummaryHelpers.type_string(@pokemon.types),
            GoldenSystem::SummaryHelpers.type_string(GoldenSystem::SummaryHelpers.power_preview_types(@pokemon))
          ), 224, 326, :left, GOLD_DIM, GOLD_DIM_S]
        end
        if @pokemon.hasGoldenForm?
          lines << [_INTL("◆ FORMA DORADA"), 224, 356, :left, GOLD_BASE, GOLD_SHADOW]
          lines << [_INTL("Forma objetivo: {1}", @pokemon.getGoldenForm), 224, 386, :left, GOLD_DIM, GOLD_DIM_S]
        end
        pbDrawTextPositions(@sprites["overlay"].bitmap, lines) if !lines.empty?
        return ret
      end

      def drawSelectedMove(move_to_learn, selected_move)
        ret = super
        return ret if !selected_move || !@pokemon
        data = GoldenSystem::GoldenMoves.get(@pokemon.species, selected_move.id, @pokemon.form)
        return ret if !data

        overlay = @sprites["overlay"].bitmap
        info = GoldenSystem::GoldenMoves.info(@pokemon.species, selected_move.id, @pokemon.form)
        info = _INTL("Tiene una interacción con la Forma Dorada.") if !info || info.empty?
        drawTextEx(
          overlay, 246, 356, 258, 3,
          _INTL("✦ Áureo: {1}", info),
          GOLD_BASE, GOLD_SHADOW
        )
        return ret
      end
    end
  end
  PokemonSummary_Scene.prepend(GoldenSystem::SummaryGoldenMoveInfo)
end

if defined?(Battle::Scene::FightMenu)
  module GoldenSystem
    module FightMenuGoldenIndicators
      def refreshButtonNames
        begin
          battler = @battler || @active_battler || @user
          battler.pbSyncGoldenMoveDisplayNames if battler && battler.respond_to?(:pbSyncGoldenMoveDisplayNames)
        rescue
        end
        ret = super
        begin
          battler = @battler || @active_battler || @user
          buttons = @buttons
          if battler && buttons
            buttons.each_with_index do |button, i|
              move = battler.moves[i] rescue nil
              next if !move
              if !button.instance_variable_defined?(:@golden_original_label)
                original = if button.respond_to?(:name)
                             button.name
                           elsif button.respond_to?(:text)
                             button.text
                           else
                             move.name
                           end
                button.instance_variable_set(:@golden_original_label,original)
              end
              active = move.respond_to?(:golden_variant_data) &&
                       GoldenSystem::GoldenMoves.active_for?(battler,move.id)
              label = if active && move.respond_to?(:golden_display_name)
                        golden_label = move.golden_display_name(battler)
                        if defined?(Settings) && Settings.const_defined?(:SHORTEN_MOVES) && Settings::SHORTEN_MOVES &&
                           golden_label.length > 16
                          golden_label = golden_label[0..12] + "..."
                        end
                        _INTL("✦ {1}", golden_label)
                      else
                        button.instance_variable_get(:@golden_original_label)
                      end
              if button.respond_to?(:name=)
                button.name = label
              elsif button.respond_to?(:text=)
                button.text = label
              elsif button.respond_to?(:setText)
                button.setText(label)
              end
            end
          end
        rescue
        end
        return ret
      end
    end
  end
  Battle::Scene::FightMenu.prepend(GoldenSystem::FightMenuGoldenIndicators)
end

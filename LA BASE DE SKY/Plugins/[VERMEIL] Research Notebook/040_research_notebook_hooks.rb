# encoding: UTF-8
#===============================================================================
# Libreta de Investigación - integración v1.2.2
# IMPORTANTE: este archivo NO modifica PokemonSummaryScreen/PokemonSummary_Scene.
#===============================================================================
module ResearchNotebook
  module Integration
    module_function

    def species_from(value)
      return nil if value.nil?
      if value.respond_to?(:displaySpecies)
        return ResearchNotebook::Repository.normalize_species_id(value.displaySpecies)
      elsif value.respond_to?(:species)
        return ResearchNotebook::Repository.normalize_species_id(value.species)
      end
      return ResearchNotebook::Repository.normalize_species_id(value)
    end

    def owned_battler?(value)
      return value.pbOwnedByPlayer? if value.respond_to?(:pbOwnedByPlayer?)
      if value.respond_to?(:pokemon) && defined?($player) && $player && $player.respond_to?(:party)
        return $player.party.include?(value.pokemon)
      end
      if defined?(Pokemon) && value.is_a?(Pokemon) && defined?($player) && $player && $player.respond_to?(:party)
        return $player.party.include?(value)
      end
      return false
    rescue
      return false
    end

    def arcane_triggered(value, ability = nil, used_by_player = nil)
      species = species_from(value)
      return if !species
      own = used_by_player.nil? ? owned_battler?(value) : used_by_player
      if own
        pbResearchArcaneUsed(species, ability)
      else
        pbResearchArcaneSeen(species, ability)
      end
    end

    def reveal_arcane_for_pokemon(pkmn, force = false)
      return false if !pkmn || !pkmn.respond_to?(:species)
      species = species_from(pkmn)
      return false if !species || !ResearchNotebook::Repository.arcane_capable?(species)
      unlocked = force
      if !unlocked
        begin
          unlocked = ResearchNotebook.progress.pokemon_arcane_unlocked?(pkmn)
        rescue
          unlocked = false
        end
      end
      return false if !unlocked
      ability = ResearchNotebook::Repository.arcane_ability(species)
      ResearchNotebook.progress.mark_arcane_seen(species, ability)
      return true
    end

    def golden_form_activated(value, used_by_player = nil)
      species = species_from(value)
      return if !species
      own = used_by_player.nil? ? owned_battler?(value) : used_by_player
      if own
        pbResearchGoldenFormUsed(species)
      else
        pbResearchGoldenFormSeen(species)
      end
    end

    def golden_power_activated(value, used_by_player = nil)
      species = species_from(value)
      return if !species
      own = used_by_player.nil? ? owned_battler?(value) : used_by_player
      if own
        pbResearchGoldenPowerUsed(species)
      else
        ResearchNotebook.progress.mark_golden_potential(species)
      end
    end
  end
end

def pbResearchArcaneTriggered(battler_or_species, ability = nil, used_by_player = nil)
  ResearchNotebook::Integration.arcane_triggered(battler_or_species, ability, used_by_player)
end

def pbResearchGoldenFormActivated(battler_or_species, used_by_player = nil)
  ResearchNotebook::Integration.golden_form_activated(battler_or_species, used_by_player)
end

def pbResearchGoldenPowerActivated(battler_or_species, used_by_player = nil)
  ResearchNotebook::Integration.golden_power_activated(battler_or_species, used_by_player)
end

#-------------------------------------------------------------------------------
# Té Arcano: usar el objeto con éxito revela la Habilidad Arcana de ESA especie.
# La propagación a evoluciones solo ocurre si comparten exactamente el mismo ID.
#-------------------------------------------------------------------------------
if defined?(ItemHandlers) && ItemHandlers.respond_to?(:triggerUseOnPokemon)
  class << ItemHandlers
    unless method_defined?(:research_notebook_triggerUseOnPokemon)
      alias research_notebook_triggerUseOnPokemon triggerUseOnPokemon
      def triggerUseOnPokemon(item, *args, &block)
        result = research_notebook_triggerUseOnPokemon(item, *args, &block)
        begin
          raw_id = item.respond_to?(:id) ? item.id : item
          item_id = raw_id.to_sym rescue raw_id
          if item_id == ResearchNotebook::Settings::ARCANE_TEA_ITEM && result != false
            pkmn = args.find { |arg| arg && arg.respond_to?(:species) }
            ResearchNotebook::Integration.reveal_arcane_for_pokemon(pkmn, true) if pkmn
          end
        rescue => e
          ResearchNotebook::Repository.log("Registro por Té Arcano: #{e.message}")
        end
        return result
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Evolución: si el Pokémon ya había despertado su Habilidad Arcana, al evolucionar
# se revela la habilidad de la nueva especie. Si es la misma, la familia ya estaba
# compartida; si cambia, esta es la primera vez que corresponde mostrarla.
#-------------------------------------------------------------------------------
if defined?(PokemonEvolutionScene) && PokemonEvolutionScene.method_defined?(:pbEvolution)
  class PokemonEvolutionScene
    alias research_notebook_pbEvolution pbEvolution unless method_defined?(:research_notebook_pbEvolution)
    def pbEvolution(*args, &block)
      old_species = nil
      old_known = false
      old_unlocked = false
      begin
        old_species = @pokemon.species if @pokemon && @pokemon.respond_to?(:species)
        old_known = ResearchNotebook.progress.arcane_seen?(old_species) if old_species
        old_unlocked = ResearchNotebook.progress.pokemon_arcane_unlocked?(@pokemon) if @pokemon
      rescue
      end

      result = research_notebook_pbEvolution(*args, &block)

      begin
        new_species = @pokemon.species if @pokemon && @pokemon.respond_to?(:species)
        if new_species && old_species && new_species != old_species &&
           ResearchNotebook::Repository.arcane_capable?(new_species)
          post_unlocked = ResearchNotebook.progress.pokemon_arcane_unlocked?(@pokemon) rescue false
          if old_known || old_unlocked || post_unlocked
            ResearchNotebook::Integration.reveal_arcane_for_pokemon(@pokemon, true)
          end
        end
      rescue => e
        ResearchNotebook::Repository.log("Registro tras evolución: #{e.message}")
      end
      return result
    end
  end
end

#-------------------------------------------------------------------------------
# Al terminar un combate solo se revisa el equipo, nunca las cajas. Esto permite
# registrar una Habilidad Arcana usada/desbloqueada sin castigar el rendimiento.
#-------------------------------------------------------------------------------
if defined?(EventHandlers)
  EventHandlers.add(:on_end_battle, :research_notebook_party_arcane_sync,
    proc {
      begin
        ResearchNotebook.progress.sync_party_unlocks!
      rescue => e
        ResearchNotebook::Repository.log("Sincronización al terminar combate: #{e.message}")
      end
    }
  )
end

#-------------------------------------------------------------------------------
# Auto-registro visual de Forma Dorada. Solo se compara cuando el JSON proporciona
# un índice de forma numérico. Si `goldenForm` es un Hash sin índice, no intenta
# convertirlo ni adivinarlo; el runtime real debe usar pbResearchGoldenFormActivated.
#-------------------------------------------------------------------------------
if defined?(Battle) && Battle.method_defined?(:pbSetSeen)
  class Battle
    alias research_notebook_pbSetSeen pbSetSeen unless method_defined?(:research_notebook_pbSetSeen)
    def pbSetSeen(battler)
      research_notebook_pbSetSeen(battler)
      return if !battler || !battler.respond_to?(:displaySpecies) || !battler.respond_to?(:displayForm)
      species = battler.displaySpecies
      expected_form = ResearchNotebook::Repository.golden_form_index(species)
      return if expected_form.nil?
      pbResearchGoldenFormSeen(species) if battler.displayForm.to_i == expected_form
    rescue => e
      ResearchNotebook::Repository.log("Auto-registro de Forma Dorada: #{e.message}")
    end
  end
end

#-------------------------------------------------------------------------------
# Menú de pausa. No se usa pbFadeOutIn: la propia Libreta hace su apertura/cierre.
#-------------------------------------------------------------------------------
if defined?(MenuHandlers)
  MenuHandlers.remove(:pause_menu, :research_notebook) if MenuHandlers.respond_to?(:remove)
  MenuHandlers.add(:pause_menu, :research_notebook, {
    "name"      => _INTL(ResearchNotebook::Settings::MENU_NAME),
    "order"     => ResearchNotebook::Settings::MENU_ORDER,
    "condition" => proc {
      next false if !ResearchNotebook::Settings::SHOW_IN_PAUSE_MENU
      next ResearchNotebook.notebook_unlocked?
    },
    "effect"    => proc { |menu|
      pbPlayDecisionSE if defined?(pbPlayDecisionSE)
      pbOpenResearchNotebook
      menu.pbRefresh if menu.respond_to?(:pbRefresh)
      next false
    }
  })
end

#-------------------------------------------------------------------------------
# Debug de desarrollo
#-------------------------------------------------------------------------------
if defined?(MenuHandlers) && ResearchNotebook::Settings::SHOW_IN_DEBUG_MENU
  if MenuHandlers.respond_to?(:remove)
    MenuHandlers.remove(:debug_menu, :research_notebook_open)
    MenuHandlers.remove(:debug_menu, :research_notebook_unlock_test)
    MenuHandlers.remove(:debug_menu, :research_notebook_resync)
  end

  MenuHandlers.add(:debug_menu, :research_notebook_open, {
    "name"        => _INTL("Libreta de Investigación"),
    "parent"      => :main,
    "description" => _INTL("Abre la Libreta de Investigación."),
    "effect"      => proc { pbOpenResearchNotebook }
  })

  MenuHandlers.add(:debug_menu, :research_notebook_unlock_test, {
    "name"        => _INTL("Libreta: desbloquear secciones"),
    "parent"      => :main,
    "description" => _INTL("Desbloquea ambas pestañas para pruebas."),
    "effect"      => proc {
      pbUnlockResearchNotebook
      pbUnlockArcaneNotebook
      pbUnlockGoldenNotebook
      ResearchNotebook.progress.sync_party_unlocks!
      pbMessage(_INTL("Pestañas de la Libreta desbloqueadas."))
    }
  })

  MenuHandlers.add(:debug_menu, :research_notebook_resync, {
    "name"        => _INTL("Libreta: recargar y sincronizar"),
    "parent"      => :main,
    "description" => _INTL("Recarga los datos y revisa equipo y cajas."),
    "effect"      => proc {
      ResearchNotebook::Repository.reload!
      ResearchNotebook.progress.sync_unlocks!
      pbMessage(_INTL("Libreta sincronizada."))
    }
  })
end

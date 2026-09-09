#===============================================================================
# Golden Power ↔ Battle Animation Studio compatibility bridge
#
# External conductor: does not modify Golden Power or BAS core logic.
# Register Studio move animations with IDs like:
#   GOLDEN|SPECIES|MOVE          e.g. GOLDEN|HERACROSS|MEGAHORN
#   GOLDEN|SPECIES|FORM|MOVE      e.g. GOLDEN|HERACROSS|2|MEGAHORN
#   GOLDEN|MOVE                   shared fallback for any species
#
# Optional remaps in Data/GoldenSystem/golden_animations.json
#===============================================================================
module GoldenSystem
  module AnimationBridge
    ANIM_JSON = "Data/GoldenSystem/golden_animations.json"

    @alias_map = nil
    @alias_stamp = nil

    module_function

    def log(message)
      echoln("[GoldenAnimBridge] #{message}") if defined?(echoln)
    rescue
    end

    def file_stamp(path)
      return nil if !File.exist?(path)
      return [File.mtime(path).to_i, File.size(path)]
    rescue
      return nil
    end

    def load_alias_map
      path = ANIM_JSON
      stamp = file_stamp(path)
      if @alias_map.nil? || @alias_stamp != stamp
        @alias_map = {}
        if File.exist?(path) && defined?(CarnekStandaloneJSON)
          doc = CarnekStandaloneJSON.load(path, {"schema" => 1, "aliases" => {}})
          rows = doc["aliases"]
          rows = doc["mappings"] if !rows.is_a?(Hash) && doc["mappings"].is_a?(Hash)
          if rows.is_a?(Hash)
            rows.each do |raw_key, target|
              next if target.nil? || target.to_s.strip.empty?
              @alias_map[raw_key.to_s.upcase] = target.to_s.upcase
            end
          end
        end
        @alias_stamp = stamp
      end
      return @alias_map || {}
    end

    def normalize_move_id(move)
      return move.id.to_s.upcase if move.respond_to?(:id)
      return move.to_s.sub(/^:/, "").upcase
    rescue
      return move.to_s.upcase
    end

    def candidate_keys(battler, move_id)
      return [] if !battler || !battler.respond_to?(:isOnGoldenForm?) || !battler.isOnGoldenForm?
      return [] if !defined?(GoldenSystem::GoldenMoves) ||
                   !GoldenSystem::GoldenMoves.active_for?(battler, move_id)
      species = battler.pokemon.species.to_s.upcase
      move = normalize_move_id(move_id)
      source_form = GoldenSystem::GoldenMoves.source_form_for(battler)
      keys = []
      keys << "GOLDEN|#{species}|#{source_form.to_i}|#{move}" if !source_form.nil?
      keys << "GOLDEN|#{species}|#{move}"
      keys << "GOLDEN|#{move}"
      map = load_alias_map
      keys = keys.flat_map do |key|
        mapped = map[key]
        mapped ? [key, mapped] : [key]
      end
      return keys.uniq
    end

    def play_via_bas(scene, battler, move_id, targets, version)
      return false if !scene || !scene.respond_to?(:pbPlayBattleAnimationStudio)
      candidate_keys(battler, move_id).each do |key|
        return true if scene.pbPlayBattleAnimationStudio(key, battler, targets, version, false)
        return true if scene.pbPlayBattleAnimationStudio(key, battler, targets, version, :custom)
      end
      return false
    end
  end
end

if defined?(Battle)
  module GoldenSystem
    module BattleGoldenAnimationBridge
      def pbAnimation(move, user, targets, hit_num = 0)
        # safety: corta re-entrada en la cadena de prepends de animación
        @__golden_anim_bridge_depth = (@__golden_anim_bridge_depth || 0) + 1
        return super if @__golden_anim_bridge_depth > 1

        begin
          if @showAnims != false && user && @scene &&
             GoldenSystem::AnimationBridge.play_via_bas(@scene, user, move, targets, hit_num)
            return
          end
          super
        ensure
          @__golden_anim_bridge_depth -= 1 if @__golden_anim_bridge_depth && @__golden_anim_bridge_depth > 0
        end
      end
    end
  end

  Battle.prepend(GoldenSystem::BattleGoldenAnimationBridge) unless
    Battle.ancestors.include?(GoldenSystem::BattleGoldenAnimationBridge)
end

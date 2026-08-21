#===============================================================================
# Battle Scenario + Battle Scene Runtime for DBK 1.3.1
#===============================================================================
module CarnekStudio
  module BattleScenarios
    module_function
    def unique_commands(commands)
      out = {}
      counts = Hash.new(0)
      (commands || []).each do |c|
        base = c["action"].to_s
        n = counts[base]; counts[base] += 1
        key = n == 0 ? base : "#{base}_#{n}"
        out[key] = CarnekStudio.ruby_value(c["value"])
      end
      out
    end
    def build(scenario)
      h = {}
      (scenario["events"] || []).each do |ev|
        h[ev["trigger"].to_s] = unique_commands(ev["commands"])
      end
      h
    end
    def register_all
      return unless defined?(MidbattleScripts)
      data = CarnekStudio.load_json("battle_scenarios.json", {"scenarios"=>[]})
      (data["scenarios"] || []).each do |s|
        name = s["id"].to_s.upcase.gsub(/[^A-Z0-9_]/,"_").to_sym
        MidbattleScripts.send(:remove_const, name) if MidbattleScripts.const_defined?(name, false)
        MidbattleScripts.const_set(name, build(s))
      end
    end
  end
  module BattleScenes
    module_function
    def fetch(id)
      data = CarnekStudio.load_json("battle_scenes.json", {"scenes"=>[]})
      (data["scenes"] || []).find { |x| x["id"].to_s == id.to_s }
    end
    def play(battle, idx_battler, idx_target, id)
      s = fetch(id); return false unless s
      (s["steps"] || []).each do |step|
        action = step["action"].to_s
        value = CarnekStudio.ruby_value(step["value"])
        if action == "script"
          eval(value.to_s, TOPLEVEL_BINDING)
        elsif defined?(MidbattleHandlers)
          MidbattleHandlers.trigger(:midbattle_triggers, action, battle, idx_battler, idx_target, value)
        end
      end
      true
    end
  end
end
CarnekStudio::BattleScenarios.register_all
if defined?(MidbattleHandlers)
  MidbattleHandlers.add(:midbattle_triggers, "playBattleScene", proc { |battle, idxBattler, idxTarget, params|
    CarnekStudio::BattleScenes.play(battle, idxBattler, idxTarget, params)
  })
end

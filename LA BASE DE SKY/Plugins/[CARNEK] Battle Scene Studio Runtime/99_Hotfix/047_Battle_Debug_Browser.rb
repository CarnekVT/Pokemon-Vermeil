# frozen_string_literal: true
# Pokemon Vermeil - BSS cinematic/scripted battle QA browser.
# Existing blueprints are not edited; the extra scenarios are generated only
# for testing, using real BSS launcher + dialogue engine.
module BSSDebugBattles
  module_function

  def examples
    [
      ["bss_qa_cinema", "QA · Cámara y diálogo (1v1)", "EEVEE", "PIKACHU", "day", "RoundStartAttack"],
      ["bss_qa_sunset", "QA · Atardecer y tonos (1v1)", "EEVEE", "VENUSAUR", "dawn", "RoundStartAttack"],
      ["bss_qa_night", "QA · Noche y continuidad (1v1)", "EEVEE", "NOCTOWL", "night", "RoundStartAttack"]
    ]
  end

  def triggers(label)
    [
      {"id"=>"qa_intro","event"=>"RoundStartAttack","target"=>"global",
       "speaker"=>"narrator","style"=>"cinematic","textboxType"=>"cinematic",
       "showNamebox"=>false,"text"=>"Prueba BSS: #{label}. Revisa cámara, HUD y luz.",
       "turn"=>1,"repeat"=>false,"playCry"=>false,"screenShake"=>false},
      {"id"=>"qa_turn2","event"=>"RoundStartAttack","target"=>"global",
       "speaker"=>"narrator","style"=>"narrative","textboxType"=>"default",
       "showNamebox"=>false,"text"=>"Segundo turno: comprueba el encuadre al volver del ataque.",
       "turn"=>2,"repeat"=>false,"playCry"=>false,"screenShake"=>false}
    ]
  end

  def test_blueprint(key)
    row=examples.find { |e| e[0]==key.to_s }
    return nil unless row
    base=BSS064.data["blueprints"]
    sample=base.is_a?(Array) ? base.find { |bp| bp.is_a?(Hash) && bp["key"]=="wild_encounter" } : nil
    sample ||= base.find { |bp| bp.is_a?(Hash) } if base.is_a?(Array)
    return nil unless sample
    require "json"
    bp=JSON.parse(JSON.generate(sample))
    bp["key"]=row[0];bp["id"]="debug_#{row[0]}";bp["name"]=row[1]
    bp["setup"] ||= {};bp["setup"]["kind"]="wild"
    bp["setup"]["formation"]="1v1";bp["setup"]["canLose"]=true
    bp["setup"]["noExp"]=true
    bp["teams"] ||= {}
    bp["teams"]["testPlayer"]=[{"species"=>row[2],"level"=>55}]
    bp["teams"]["foes"]=[{"species"=>row[3],"level"=>50}]
    bp["environment"] ||= {}
    bp["environment"]["ebdxCamera"]=true
    # Sky mode stored on the environment; BSS sets the active room's slot.
    # Other environment fields inherit the project's standard backdrop.
    bp["environment"]["skyMode"]=row[4]
    bp["boss"]={"enabled"=>false}
    bp["sos"]={"enabled"=>false}
    bp["dialogues"]={"enabled"=>true,"triggers"=>triggers(row[1])}
    bp
  rescue StandardError => e
    BSS064.log("BSS debug blueprint: #{e.class}: #{e.message}") if defined?(BSS064)
    nil
  end

  def choices
    BSS064.clear_cache
    rows=BSS064.data["blueprints"]
    items=[]
    if rows.is_a?(Array)
      qa, other=rows.partition { |bp| bp.is_a?(Hash) && bp["groupId"].to_s=="bss_qa_suite" }
      (qa+other).each do |bp|
        next unless bp.is_a?(Hash) && !bp["key"].to_s.empty?
        label=(bp["groupId"].to_s=="bss_qa_suite" ? "QA · " : "BSS · ")
        items << [label+bp["name"].to_s, bp["key"].to_s]
      end
    end
    examples.each do |name,title,*other|
      items << [title,name] unless items.any? { |item| item[1]==name }
    end
    items
  end

  def open
    return if !defined?($player) || !$player || ($player.party rescue []).empty?
    return if defined?($game_temp) && $game_temp && ($game_temp.in_battle rescue false)
    items=choices
    return if items.empty?
    names=items.map(&:first) + [_INTL("Cancelar")]
    index=pbMessage(_INTL("Selecciona un combate BSS para probar."),names,names.length-1)
    return if !index || index<0 || index>=items.length
    # Use editor's sandbox mode so testPlayer is honored and party is restored.
    BSS064.run_blueprint(items[index][1],true)
  end
end

module BSSDebugBattleLookup
  def find(key)
    # Saved BSS editor Blueprints always win; only older installs without the
    # QA library use the dynamic fallback.
    super || BSSDebugBattles.test_blueprint(key)
  end
end
if defined?(BSS064) && !BSS064.singleton_class.ancestors.include?(BSSDebugBattleLookup)
  BSS064.singleton_class.prepend(BSSDebugBattleLookup)
end

if defined?(MenuHandlers)
  MenuHandlers.add(:debug_menu,:bss_debug_battle_browser,{
    "name"=>_INTL("Battle Scene Studio · Probar combate"),
    "parent"=>:battle_menu,
    "description"=>_INTL("Elegir cualquier combate BSS o un escenario cinematográfico de prueba."),
    "effect"=>proc { |sprites,viewport| BSSDebugBattles.open; next false }
  })
end

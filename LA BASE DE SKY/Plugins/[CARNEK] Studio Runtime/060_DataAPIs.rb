#===============================================================================
# Generic data access for Quest/Puzzle/Camera/Lighting/Spawn studios.
# These APIs intentionally avoid hard dependencies on one quest/light plugin.
#===============================================================================
module CarnekStudio
  def self.quest(id); fetch_item("quests.json",id); end
  def self.puzzle(id); fetch_item("puzzles.json",id); end
  def self.camera_preset(id); fetch_item("camera_presets.json",id); end
  def self.lighting_preset(id); fetch_item("lighting.json",id); end
  def self.spawn_group(id); fetch_item("spawns.json",id); end
  def self.fetch_item(file,id)
    d=load_json(file,{"items"=>[]}); (d["items"]||[]).find{|x|x["id"].to_s==id.to_s}
  end
end

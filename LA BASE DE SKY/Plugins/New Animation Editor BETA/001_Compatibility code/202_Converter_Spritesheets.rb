def marFindUsedSageGraphicNames
  filenames = []
  GameData::Animation.each do |anim_data|
    next if !anim_data.name || anim_data.name != "Sage anim"
      anim_data.particles.each do |part|
      if !["USER", "TARGET", "Sage/", nil].include?(part[:graphic])
        name = part[:graphic].sub(".png", "").sub(" png", "")
        filenames.push(name)
      end
    end
  end
  filenames.compact!
  filenames.uniq!
  filenames.sort!
  return filenames
end

def marConvertSpritesheets
  filenames = marFindUsedSageGraphicNames
  filenames.each do |file|
    src_name = file.sub("Sage/", "")
    case src_name
    when "T Shock"      then src_name = "T. Shock"
    when "anim sheet 2" then src_name = "anim sheet.2"
    when "finger spoon" then src_name = "finger.spoon"
    when "poi hear mus" then src_name = "poi.hear.mus"
    end
    source = "Graphics/Animations/" + src_name
    destination = "Graphics/Battle Animations/" + file.sub(".png", "").sub(" png", "") + ".png"
    next if pbResolveBitmap(destination)
    marConvertSingleSpritesheet(source, destination)
  end
  echoln "Done!"
end

def marConvertSingleSpritesheet(src, dst)
  echoln "Converting #{src}..."
  if !pbResolveBitmap(src)
    echoln "Can't find file at source!"
    return
  end
  sprite_width = sprite_height = 192
  src_bitmap = RPG::Cache.load_bitmap("", src)
  sprites_wide = src_bitmap.width / sprite_width
  sprites_tall = src_bitmap.height / sprite_height
  total_sprites = sprites_wide * sprites_tall
  dst_bitmap = Bitmap.new(sprites_tall * sprite_width * 5, sprite_height)
  sprites_tall.times do |j|
    dst_bitmap.blt(j * sprite_width * 5, 0, src_bitmap, Rect.new(0, j * sprite_height, sprites_wide * sprite_width, sprite_height))
  end
  dst_bitmap.to_file(dst)
end

#===============================================================================
# Add to Debug menu.
#===============================================================================
# MenuHandlers.add(:debug_menu, :convert_anim_spritesheets, {
#   "name"        => "Convert old anim spritesheets",
#   "parent"      => :data_importer_menu,
#   "description" => "Convert old anim spritesheets in Graphics/Animations/ to new layout.",
#   "effect"      => proc {
#     marConvertSpritesheets
#   }
# })

#===============================================================================
#
#===============================================================================
# def marRemovePngFromGraphicNames
#   GameData::Animation.each do |anim_data|
#     anim_data.particles.each do |part|
#       part[:graphic] = part[:graphic].sub(" png", "") if part[:graphic]
#     end
#   end
#   Compiler.write_all_battle_animations
# end
#
# MenuHandlers.add(:debug_menu, :marRemovePngFromGraphicNames, {
#   "name"        => "marRemovePngFromGraphicNames",
#   "parent"      => :data_importer_menu,
#   "description" => "marRemovePngFromGraphicNames",
#   "effect"      => proc {
#     marRemovePngFromGraphicNames
#   }
# })

#===============================================================================
#
#===============================================================================
# def marRemoveWavFromAudioNames
#   GameData::Animation.each do |anim_data|
#     anim_data.particles.each do |part|
#       next if part[:name] != "SE" || !part[:se]
#       part[:se].each do |command|
#         command[2] = command[2].sub(".wav", "").sub(".WAV", "").sub(".mp3", "").sub(".ogg", "") if command[2]
#         echoln anim_data.move if command[2][/\./]
#       end
#     end
#   end
#   Compiler.write_all_battle_animations
# end
#
# MenuHandlers.add(:debug_menu, :marRemoveWavFromAudioNames, {
#   "name"        => "marRemoveWavFromAudioNames",
#   "parent"      => :data_importer_menu,
#   "description" => "marRemoveWavFromAudioNames",
#   "effect"      => proc {
#     marRemoveWavFromAudioNames
#   }
# })

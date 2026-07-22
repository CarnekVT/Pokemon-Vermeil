#===============================================================================
# Added "if origin" to allow battler sprites to not have their origin changed.
#===============================================================================
#class Battle::Scene::Animation
#  def addSprite(s, origin = PictureOrigin::TOP_LEFT)
#    num = @pictureEx.length
#    picture = PictureEx.new(s.z)
#    picture.x       = s.x
#    picture.y       = s.y
#    picture.visible = s.visible
#    picture.color   = s.color.clone
#    picture.tone    = s.tone.clone
#    picture.setOrigin(0, origin) if origin
#    @pictureEx[num] = picture
#    @pictureSprites[num] = s
#    return picture
#  end
#end

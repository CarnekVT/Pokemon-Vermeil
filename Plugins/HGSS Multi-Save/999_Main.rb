#===============================================================================
#
#===============================================================================
class Scene_DebugIntro
  def main
    Graphics.transition(0)
    UI::Load.new.main
    Graphics.freeze
  end
end

#===============================================================================
#
#===============================================================================
class IntroEventScene
  def close_title_screen(scene, *args)
    fade_out_title_screen(scene)
    UI::Load.new.main
  end
end

#===============================================================================
#
#===============================================================================
def pbCallTitle
  return Scene_DebugIntro.new if $DEBUG && Settings::SKIP_TITLE_SCREEN
  return Scene_Intro.new
end

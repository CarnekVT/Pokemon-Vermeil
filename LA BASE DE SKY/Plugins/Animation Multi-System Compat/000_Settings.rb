#===============================================================================
# Animation Multi-System Compat
#-------------------------------------------------------------------------------
# Lets the New Animation Editor load, parse and preview animations coming from
# several different systems at once:
#   - Standard Pokémon Essentials animations (GameData::Animation / PBS)
#   - Legacy Animations.rxdata (PictureEx) animations
#   - Custom Ruby animations (Battle::Scene::Animation subclasses whose
#     createProcesses uses the PictureEx DSL, e.g. ATTACK1 / ATTACK2)
#   - Elite Battle DX (EBDX) animations (EliteBattle.defineMoveAnimation blocks)
#
# Nothing here overrides existing behaviour. Each system is parsed into the
# editor's normalized model (a GameData::Animation-style hash) so the existing
# AnimationPlayer can preview/edit it. Truly unsupported commands are recorded
# explicitly rather than faked.
#===============================================================================
module AnimationMultisystem
  # Raised/recorded when a source uses a construct we cannot represent yet.
  class UnsupportedCommand < StandardError; end

  module Settings
    # When true, the editor bridge will also surface multi-system animations.
    ENABLED              = true
    # Folders (relative to the project root) scanned for EBDX-style animation
    # definitions. These are *project* folders, not the standalone
    # VermeilOGScripts copy in Downloads.
    EBDX_SOURCE_FOLDERS  = ["Plugins", "Data/Scripts"]
    # Graphics subfolders searched when resolving a referenced graphic.
    GRAPHICS_FOLDERS     = [
      "Graphics/Battle animations",
      "Graphics/Battle animations/EBDX",
      "Graphics/EBDX/Animations/Moves",
      "Graphics/EBDX/Animations/Common",
      "Graphics/Animations",
      "Graphics/Battle"
    ]
    GRAPHIC_EXTENSIONS   = ["png", "gif", "jpg", "jpeg", "xyz"]
  end
end

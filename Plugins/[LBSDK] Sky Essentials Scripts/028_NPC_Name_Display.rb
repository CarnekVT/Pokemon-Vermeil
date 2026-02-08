#===============================================================================
#                              Script : NameBox (ver. 4)
#                              Author : Bezier
#                              Modified by: dracrixco and DPertierra
#-------------------------------------------------------------------------------
#  Shows an auxiliary text box above the dialogue box.
#  To use it, write in a script box the following code:
#     NameBox.load('Name')
#  From version 4, it is recommended to pass the text using single quotes
#  to parse commands. The implemented commands are:
#     NameBox.load('\PN')     # Shows the player's name
#     NameBox.load('\v[n]')   # Shows the contents of variable n
#-------------------------------------------------------------------------------
# - UPDATES -
# 23/02/21 -> Version 2
#   Shows the character's name if /PN is passed as the name to display
# 09/03/21 -> Version 3
#   Uses the same WindowSkin as the message box for the box border
#     Credits for feedback: Pokémon Ultimate (Twitter: @Pkmn_Ultimate)
# 17/06/21 -> Version 4
#   Parses version 1 commands. Must be written with single quotes
#     Shows the character's name if '\PN' is passed
#     Shows the variable name if '\v[num]' is passed where num is
#       the number of the variable to display
#     Credits for feedback: Ravel
#
#-------------------------------------------------------------------------------
#  Step 1: How to integrate it?
#
#  Edit the Kernel.pbMessageDisplay function from the Messages script:
#
#  Add this line more or less in the middle of the function
#     (look for the comment with many # as a reference)
#  [...]
#  ########## Show text #############################
#  NameBox.show(msgwindow) # <- Add this line to show the NameBox.
#  msgwindow.text=text
#  [...]
#
#  And this other line before ending the function
#  [...]
#  end
#    NameBox.hide # <- Add this line to hide the NameBox along with the text box
#    return ret
#  end
#  [...]
#
#-------------------------------------------------------------------------------
#  Step 2: How to use it?
#
#  Make the change from Step 1.
#  Change the name of the skin to use NAMEBOXWINSKIN (below)
#
#  To use it in an event just call the script:
#     NameBox.load("Name")
#
#  This will create a box with the text "Name" and it will be displayed above the
#  dialogue box each time text is written, until it is deactivated.
#
#  To deactivate it, call the script:
#     NameBox.dispose
#
#  If you want to put color to a character, you just have to add an entry
#  in the NPCCOLORS list (below) with the character's name and
#  the colors for the base and shadow of the text.
#
#-------------------------------------------------------------------------------
#  Step 3: Compatibility (Optional)
#
#  If you are using JESS's commands script, which shows a similar box,
#  you must edit this script instead of the Messages one to make
#  all existing texts in already programmed events compatible.
#  Just like in Step 1, you have to add the call to NameBox in the
#  Kernel.pbMessageDisplay function.
#  If you don't find the comment:
#      ########## Show text #############################
#  you will have to look for the line:
#      msgwindow.text=text
#  and make the call to NameBox before assigning the text:
#
#  [...]
#  atTop=(msgwindow.y==0)
#  NameBox.show(msgwindow) # <- Add this line to show the NameBox.
#  msgwindow.text=text
#  [...]
#
#  And this other line before ending the function
#  [...]
#  end
#    NameBox.hide # <- Add this line to hide the NameBox along with the text box
#    return ret
#  end
#  [...]
#===============================================================================

module NameBox

  # Position of the NameBox on screen
  NAMEBOX_X = 14
  NAMEBOX_Y = 228 # + 5
  NAMEBOX_Z = 999
  NAMEBOX_IN_TOP = true

  # IMPORTANTCHARACTER is intended for people who plan to use the
  # Essentials translation system, otherwise, ignore it.
  IMPORTANTCHARACTER = {
    # "Name" => _INTL("Name")
  }

  # CHARACTERNAMES works the same as "IMPORTANTCHARACTER", but it is focused on
  # common names, such as professions or roles.
  # NameBox.CHARACTERNAMES can accept a second parameter to take advantage
  # of CHARACTERNAMES, for example, instead of having.
  # IMPORTANTCHARACTER = {
  #  "Recruit 1" => _INTL("Recruit 1")
  #  "Recruit 2" => _INTL("Recruit 2")
  #  ...
  #  "Recruit N" => _INTL("Recruit N")
  #}
  # You only need
  # IMPORTANTCHARACTER = {
  #  "Recruit" => _INTL("Recruit")
  #}


  CHARACTERNAMES = {
    # "Name" => _INTL("Name")
  }

  # Colors associated with each character
  NPCCOLORS = {
    # "Name" => [BaseColor, Shadow]
    "Prof. Oak" => [Color.new(48,80,200), Color.new(208,208,208)],
    "Candela" => [Color.new(224,8,8), Color.new(208,208,208)]
  }

  # If this is true the NPC name box will be in the same style as the chosen text box
  # If you want to change this behavior and define a specific skin for each name, then you have to change the following constant to false
  USE_TEXT_WINDOW_SKIN_FOR_NAMEBOX = true

  # If USE_TEXT_WINDOW_SKIN_FOR_NAMEBOX is false, then the following skins will be used for NPCs
  NAMEBOX_WINDOW_SKINS_FOR_NPC = {
    "Prof. Oak" => "speech hgss 2",
    "Candela" => "speech hgss 1",
    "Miguel" => "speech hgss 1"
  }

  # If USE_TEXT_WINDOW_SKIN_FOR_NAMEBOX is false, and the NPC is not found in the NAMEBOX_WINDOW_SKINS_FOR_NPC hash,
  # It checks if the following constant is true, it will use the Text Box skin by default as the NameBox skin
  # If it is false, the skin defined in the DEFAULT_NAMEBOXWINSKIN constant will be used
  USE_TEXT_WINDOW_SKIN_AS_DEFAULT = false

  # Name of the skin for the box in "Graphics/Windowskins"
  DEFAULT_NAMEBOXWINSKIN = "speech hgss 2"

  # Loads the NameBox with the indicated name but does not make it visible
  # It will become visible when a dialogue box is shown

  def self.load(name, number = nil)
    @currentName = name.clone
    @currentName = IMPORTANTCHARACTER[name] if IMPORTANTCHARACTER[name]
    @currentName = CHARACTERNAMES[name] if CHARACTERNAMES[name]
    @currentName += " #{number}" if number
    # Old parsing to show character name
    @currentName.gsub!(/\\pn/i,  $player.name) if $player
    # New parsing to show character name
    @currentName.gsub!(/\\[Pp][Nn]/,$player.name) if $player
    # Parses variable with format '\v[n]'
    @currentName.gsub!(/\\v\[([0-9]+)\]/i) { $game_variables[$1.to_i] }
    # Gender-related issues
    @currentName.gsub!(/\\@a/i,"a") if $player&.female?
    @currentName.gsub!(/\\@a/i,"") if $player&.male?
    @currentName.gsub!(/\\@/i,"a") if $player&.female?
    @currentName.gsub!(/\\@/i,"o") if $player&.male?
    @currentName.gsub!(/\\&/i,"o") if $player&.female?
    @currentName.gsub!(/\\&/i,"a") if $player&.male?

    @namebox&.dispose
    @namebox = Window_AdvancedTextPokemon.new(@currentName)
    @namebox.visible = true

    skin = if USE_TEXT_WINDOW_SKIN_FOR_NAMEBOX
             MessageConfig.pbGetSpeechFrame
           else
             NAMEBOX_WINDOW_SKINS_FOR_NPC[@currentName] ||
               (USE_TEXT_WINDOW_SKIN_AS_DEFAULT ? MessageConfig.pbGetSpeechFrame : DEFAULT_NAMEBOXWINSKIN)
           end
    if skin && skin.start_with?("Graphics/Windowskins/")
        @namebox.setSkin(skin)
    else
        @namebox.setSkin("Graphics/Windowskins/#{skin}")
    end


    @namebox.resizeToFit(@namebox.text, Graphics.width)
    @namebox.x = NAMEBOX_X
    @namebox.y = NAMEBOX_Y
    @namebox.z = NAMEBOX_Z if NAMEBOX_IN_TOP
    setTextColor
  end

  # Shows the NameBox (Must be integrated with the Step 1 call)
  def self.show(msgwindow)
    return unless @namebox && msgwindow

    @namebox.viewport = msgwindow.viewport
    @namebox.z = msgwindow.z
    @namebox.visible = true
  end

  # Hides the NameBox but does not destroy it, so it will be shown with the next text
  def self.hide
    @namebox.visible = false if @namebox
  end

  # Destroys the NameBox so it won't be shown with the next text
  def self.dispose
    @namebox&.dispose
    @namebox = nil
  end

  # Returns if the NameBox is active
  def self.isEnabled?
    @namebox != nil
  end

  # Internal function that changes the color of the text associated with the current name
  def self.setTextColor
    return unless @namebox

    colors = NPCCOLORS[@currentName] || getDefaultTextColors(@namebox.windowskin)

    @namebox.baseColor = colors[0]
    @namebox.shadowColor = colors[1]

    # It is necessary to update the text to repaint with the new colors
    @namebox.text = @currentName
  end
end

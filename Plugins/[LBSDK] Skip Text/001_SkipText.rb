#===============================================================================
# * [LBSDK] Skip Text
#===============================================================================
# Enables skipping/fast-forwarding text with Input::ACTION when enabled.
# Set Settings::ENABLE_SKIP_TEXT = true to allow outside of Debug.
#===============================================================================

if defined?(Settings)
  Settings::ENABLE_SKIP_TEXT = false unless Settings.const_defined?(:ENABLE_SKIP_TEXT)
else
  module Settings
    ENABLE_SKIP_TEXT = true
  end
end

module LBSkipText
  def pbMessageDisplay(msgwindow, message, letterbyletter = true, commandProc = nil)
    return if !msgwindow
    oldletterbyletter = msgwindow.letterbyletter
    msgwindow.letterbyletter = (letterbyletter) ? true : false
    ret = nil
    commands = nil
    facewindow = nil
    goldwindow = nil
    coinwindow = nil
    battlepointswindow = nil
    cmdvariable = 0
    cmdIfCancel = 0
    msgwindow.waitcount = 0
    autoresume = false
    text = message.clone
    linecount = (Graphics.height > 400) ? 3 : 2
    ### Text replacement
    text.gsub!(/\\sign\[([^\]]*)\]/i) do      # \sign[something] gets turned into
      next "\\op\\cl\\ts[]\\w[" + $1 + "]"    # \op\cl\ts[]\w[something]
    end
    text.gsub!(/\\\\/, "\5")
    text.gsub!(/\\1/, "\1")
    if $game_actors
      text.gsub!(/\\n\[([1-8])\]/i) { next $game_actors[$1.to_i].name }
    end
    text.gsub!(/\\pn/i,  $player.name) if $player
    text.gsub!(/\\pm/i,  _INTL("${1}", $player.money.to_s_formatted)) if $player
    text.gsub!(/\\n/i,   "\n")
    text.gsub!(/\\\[([0-9a-f]{8,8})\]/i) { "<c2=" + $1 + ">" }
    text.gsub!(/\\pg/i,  "\\b") if $player&.male?
    text.gsub!(/\\pg/i,  "\\r") if $player&.female?
    text.gsub!(/\\pog/i, "\\r") if $player&.male?
    text.gsub!(/\\pog/i, "\\b") if $player&.female?
    text.gsub!(/\\pg/i,  "")
    text.gsub!(/\\pog/i, "")
    male_text_tag = shadowc3tag(MessageConfig::MALE_TEXT_MAIN_COLOR, MessageConfig::MALE_TEXT_SHADOW_COLOR)
    female_text_tag = shadowc3tag(MessageConfig::FEMALE_TEXT_MAIN_COLOR, MessageConfig::FEMALE_TEXT_SHADOW_COLOR)
    text.gsub!(/\\b/i,   male_text_tag)
    text.gsub!(/\\r/i,   female_text_tag)
    text.gsub!(/\\[Ww]\[([^\]]*)\]/) do
      w = $1.to_s
      if w == ""
        msgwindow.windowskin = nil
      else
        msgwindow.setSkin("Graphics/Windowskins/#{w}", false)
      end
      next ""
    end
    isDarkSkin = isDarkWindowskin(msgwindow.windowskin)
    text.gsub!(/\\c\[([0-9]+)\]/i) do
      next getSkinColor(msgwindow.windowskin, $1.to_i, isDarkSkin)
    end
    loop do
      last_text = text.clone
      text.gsub!(/\\v\[([0-9]+)\]/i) { $game_variables[$1.to_i] }
      break if text == last_text
    end
    loop do
      last_text = text.clone
      text.gsub!(/\\l\[([0-9]+)\]/i) do
        linecount = [1, $1.to_i].max
        next ""
      end
      break if text == last_text
    end
    colortag = ""
    if $game_system && $game_system.message_frame != 0
      colortag = getSkinColor(msgwindow.windowskin, 0, true)
    else
      colortag = getSkinColor(msgwindow.windowskin, 0, isDarkSkin)
    end
    text = colortag + text
    ### Controls
    textchunks = []
    controls = []
    while text[/(?:\\(f|ff|ts|cl|me|se|wt|wtnp|ch)\[([^\]]*)\]|\\(g|cn|pt|wd|wm|op|cl|wu|\.|\||\!|\^))/i]
      textchunks.push($~.pre_match)
      if $~[1]
        controls.push([$~[1].downcase, $~[2], -1])
      else
        controls.push([$~[3].downcase, "", -1])
      end
      text = $~.post_match
    end
    textchunks.push(text)
    textchunks.each do |chunk|
      chunk.gsub!(/\005/, "\\")
    end
    textlen = 0
    controls.length.times do |i|
      control = controls[i][0]
      case control
      when "wt", "wtnp", ".", "|"
        textchunks[i] += "\2"
      when "!"
        textchunks[i] += "\1"
      end
      textlen += toUnformattedText(textchunks[i]).scan(/./m).length
      controls[i][2] = textlen
    end
    text = textchunks.join
    appear_timer_start = nil
    appear_duration = 0.5   # In seconds
    haveSpecialClose = false
    specialCloseSE = ""
    startSE = nil
    controls.length.times do |i|
      control = controls[i][0]
      param = controls[i][1]
      case control
      when "op"
        appear_timer_start = System.uptime
      when "cl"
        text = text.sub(/\001\z/, "")   # fix: '$' can match end of line as well
        haveSpecialClose = true
        specialCloseSE = param
      when "f"
        facewindow&.dispose
        facewindow = PictureWindow.new("Graphics/Pictures/#{param}")
      when "ff"
        facewindow&.dispose
        facewindow = FaceWindowVX.new(param)
      when "ch"
        cmds = param.clone
        cmdvariable = pbCsvPosInt!(cmds)
        cmdIfCancel = pbCsvField!(cmds).to_i
        commands = []
        while cmds.length > 0
          commands.push(pbCsvField!(cmds))
        end
      when "wtnp", "^"
        text = text.sub(/\001\z/, "")   # fix: '$' can match end of line as well
      when "se"
        if controls[i][2] == 0
          startSE = param
          controls[i] = nil
        end
      end
    end
    if startSE
      pbSEPlay(pbStringToAudioFile(startSE))
    elsif !appear_timer_start && letterbyletter
      pbPlayDecisionSE
    end
    # Position message window
    pbRepositionMessageWindow(msgwindow, linecount)
    if facewindow
      pbPositionNearMsgWindow(facewindow, msgwindow, :left)
      facewindow.viewport = msgwindow.viewport
      facewindow.z        = msgwindow.z
    end
    atTop = (msgwindow.y == 0)
    # Show text
    msgwindow.text = text
    loop do
      if appear_timer_start
        y_start = (atTop) ? -msgwindow.height : Graphics.height
        y_end = (atTop) ? 0 : Graphics.height - msgwindow.height
        msgwindow.y = lerp(y_start, y_end, appear_duration, appear_timer_start, System.uptime)
        appear_timer_start = nil if msgwindow.y == y_end
      end
      controls.length.times do |i|
        next if !controls[i]
        next if controls[i][2] > msgwindow.position || msgwindow.waitcount != 0
        control = controls[i][0]
        param = controls[i][1]
        case control
        when "f"
          facewindow&.dispose
          facewindow = PictureWindow.new("Graphics/Pictures/#{param}")
          pbPositionNearMsgWindow(facewindow, msgwindow, :left)
          facewindow.viewport = msgwindow.viewport
          facewindow.z        = msgwindow.z
        when "ff"
          facewindow&.dispose
          facewindow = FaceWindowVX.new(param)
          pbPositionNearMsgWindow(facewindow, msgwindow, :left)
          facewindow.viewport = msgwindow.viewport
          facewindow.z        = msgwindow.z
        when "g"      # Display gold window
          goldwindow&.dispose
          goldwindow = pbDisplayGoldWindow(msgwindow)
        when "cn"     # Display coins window
          coinwindow&.dispose
          coinwindow = pbDisplayCoinsWindow(msgwindow, goldwindow)
        when "pt"     # Display battle points window
          battlepointswindow&.dispose
          battlepointswindow = pbDisplayBattlePointsWindow(msgwindow)
        when "wu"
          atTop = true
          msgwindow.y = 0
          pbPositionNearMsgWindow(facewindow, msgwindow, :left)
          if appear_timer_start
            msgwindow.y = lerp(y_start, y_end, appear_duration, appear_timer_start, System.uptime)
          end
        when "wm"
          atTop = false
          msgwindow.y = (Graphics.height - msgwindow.height) / 2
          pbPositionNearMsgWindow(facewindow, msgwindow, :left)
        when "wd"
          atTop = false
          msgwindow.y = Graphics.height - msgwindow.height
          pbPositionNearMsgWindow(facewindow, msgwindow, :left)
          if appear_timer_start
            msgwindow.y = lerp(y_start, y_end, appear_duration, appear_timer_start, System.uptime)
          end
        when "ts"     # Change text speed
          msgwindow.textspeed = (param == "") ? 0 : param.to_i / 80.0
        when "."      # Wait 0.25 seconds
          msgwindow.waitcount += 0.25
        when "|"      # Wait 1 second
          msgwindow.waitcount += 1.0
        when "wt"     # Wait X/20 seconds
          param = param.sub(/\A\s+/, "").sub(/\s+\z/, "")
          msgwindow.waitcount += param.to_i / 20.0
        when "wtnp"   # Wait X/20 seconds, no pause
          param = param.sub(/\A\s+/, "").sub(/\s+\z/, "")
          msgwindow.waitcount = param.to_i / 20.0
          autoresume = true
        when "^"      # Wait, no pause
          autoresume = true
        when "se"     # Play SE
          pbSEPlay(pbStringToAudioFile(param))
        when "me"     # Play ME
          pbMEPlay(pbStringToAudioFile(param))
        end
        controls[i] = nil
      end
      break if !letterbyletter
      Graphics.update
      Input.update
      facewindow&.update
      if autoresume && msgwindow.waitcount == 0
        msgwindow.resume if msgwindow.busy?
        break if !msgwindow.busy?
      end
      if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK)
        if msgwindow.busy?
          pbPlayDecisionSE if msgwindow.pausing?
          msgwindow.resume
        elsif !appear_timer_start
          break
        end
      elsif Input.press?(Input::ACTION) && ($DEBUG || Settings::ENABLE_SKIP_TEXT)
        msgwindow.textspeed = -999
        msgwindow.update
        if msgwindow.busy?
          pbPlayDecisionSE if msgwindow.pausing?
          msgwindow.resume
        elsif !appear_timer_start
          break
        end
      end
      pbUpdateSceneMap
      msgwindow.update
      yield if block_given?
      break if (!letterbyletter || commandProc || commands) && !msgwindow.busy?
    end
    Input.update   # Must call Input.update again to avoid extra triggers
    msgwindow.letterbyletter = oldletterbyletter
    if commands
      $game_variables[cmdvariable] = pbShowCommands(msgwindow, commands, cmdIfCancel)
      $game_map.need_refresh = true if $game_map
    end
    ret = commandProc.call(msgwindow) if commandProc
    goldwindow&.dispose
    coinwindow&.dispose
    battlepointswindow&.dispose
    facewindow&.dispose
    if haveSpecialClose
      pbSEPlay(pbStringToAudioFile(specialCloseSE))
      atTop = (msgwindow.y == 0)
      y_start = (atTop) ? 0 : Graphics.height - msgwindow.height
      y_end = (atTop) ? -msgwindow.height : Graphics.height
      disappear_duration = 0.5   # In seconds
      disappear_timer_start = System.uptime
      loop do
        msgwindow.y = lerp(y_start, y_end, disappear_duration, disappear_timer_start, System.uptime)
        Graphics.update
        Input.update
        pbUpdateSceneMap
        msgwindow.update
        break if msgwindow.y == y_end
      end
    end
    return ret
  end
end

Object.prepend(LBSkipText)

# encoding: utf-8
module PBDebug
  @@log = []
  @@ai_logging_depth = 0
  @@silent_logging_depth = 0

  def self.ai_logging?
    return $DEBUG && Settings::AI_DECISION_LOGGING && @@ai_logging_depth > 0
  end

  # El ámbito limita la salida ampliada a decisiones de IA, no al resto del combate.
  def self.with_ai_logging
    return yield unless $DEBUG && Settings::AI_DECISION_LOGGING
    @@ai_logging_depth += 1
    begin
      yield
    ensure
      @@ai_logging_depth -= 1
    end
  end

  def self.with_silent_logging
    @@silent_logging_depth += 1
    begin
      yield
    ensure
      @@silent_logging_depth -= 1
    end
  end

  def self.log_ai_decision(msg)
    return if @@silent_logging_depth > 0
    return unless ai_logging?
    log_ai("[TRACE] #{msg}")
  end

  def self.logonerr
    begin
      yield
    rescue
      PBDebug.log("")
      PBDebug.log("**Exception: #{$!.message}")
      backtrace = ""
      $!.backtrace.each { |line| backtrace += line + "\r\n" }
      PBDebug.log(backtrace)
      PBDebug.log("")
      pbPrintException($!)   # if $INTERNAL
      PBDebug.flush
    end
  end

  def self.flush
    if $DEBUG && $INTERNAL && @@log.length > 0
      File.open("Data/debuglog.txt", "a+b") { |f| f.write(@@log.join) }
    end
    @@log.clear
  end

  def self.log_battle_event(msg)
    with_ai_logging { log("[BATTLE] [TRACE] #{msg}") }
  end

  def self.log(msg)
    return if @@silent_logging_depth > 0
    battle_event = Settings::AI_DECISION_LOGGING &&
                   msg.start_with?("[HP change]", "[Item triggered]", "[Ability triggered]", "[Lingering effect]")
    if $DEBUG && ($INTERNAL || ai_logging? || battle_event)
      echoln msg.gsub("%", "%%")
      @@log.push(msg + "\r\n")
      PBDebug.flush   # if @@log.length > 1024
    end
  end

  def self.log_header(msg)
    if $DEBUG && $INTERNAL
      echoln Console.markup_style(msg.gsub("%", "%%"), text: :light_purple)
      @@log.push(msg + "\r\n")
      PBDebug.flush   # if @@log.length > 1024
    end
  end

  def self.log_message(msg)
    if $DEBUG && $INTERNAL
      msg = "\"" + msg + "\""
      echoln Console.markup_style(msg.gsub("%", "%%"), text: :dark_gray)
      @@log.push(msg + "\r\n")
      PBDebug.flush   # if @@log.length > 1024
    end
  end

  def self.log_ai(msg)
    return if @@silent_logging_depth > 0
    if $DEBUG && ($INTERNAL || ai_logging?)
      msg = "[AI] " + msg
      echoln msg.gsub("%", "%%")
      @@log.push(msg + "\r\n")
      PBDebug.flush   # if @@log.length > 1024
    end
  end

  def self.log_score_change(amt, msg)
    return if @@silent_logging_depth > 0 || amt == 0
    if $DEBUG && ($INTERNAL || ai_logging?)
      sign = (amt > 0) ? "+" : "-"
      amt_text = sprintf("%3d", amt.abs)
      msg = "     #{sign}#{amt_text}: #{msg}"
      echoln msg.gsub("%", "%%")
      @@log.push(msg + "\r\n")
      PBDebug.flush   # if @@log.length > 1024
    end
  end

  def self.dump(msg)
    if $DEBUG && $INTERNAL
      File.open("Data/dumplog.txt", "a+b") { |f| f.write("#{msg}\r\n") }
    end
  end
end

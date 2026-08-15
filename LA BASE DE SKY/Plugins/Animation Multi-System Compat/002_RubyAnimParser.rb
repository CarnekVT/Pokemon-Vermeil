#===============================================================================
# Parser for custom Ruby animations (PictureEx DSL).
#
# Handles Battle::Scene::Animation subclasses whose createProcesses uses the
# PictureEx vocabulary (addSprite / addNewSprite / setXY / moveXY / moveDelta /
# setZoom / moveOpacity / setAngle / setTone / setColor / setSE / setWait /
# setSrc / src_rect.set). Animation classes are read straight from a chosen
# source file (file-chooser flow). Battler-focused pictures are rebased so their
# keyframes are offsets from the live battler, matching the editor runtime.
#===============================================================================
module AnimationMultisystem
  class RubyAnimParser
    # Parse a single Ruby source file and return an array of Animation objects
    # (one per Battle::Scene::Animation subclass found).
    def self.parse_file(path)
      return [] if !path || !File.exist?(path)
      src = File.read(path)
      out = []
      each_animation_class(src) do |class_name, body|
        anim = Animation.new(
          :type => :move,
          :move => class_name,
          :version => 0,
          :name => class_name,
          :fps => 40,
          :source_system => :ruby,
          :source_file => path,
          :source_metadata => { :class => class_name }
        )
        process(body, anim)
        out << anim
      end
      out
    rescue => e
      []
    end

    # Parse already-extracted createProcesses code.
    def self.parse_code(code, anim)
      process(code.to_s, anim)
      anim
    rescue => e
      anim.add_unsupported("parse_error", "#{e.class}: #{e.message}")
      anim
    end

    #---------------------------------------------------------------------------
    def self.each_animation_class(src)
      # Match "class NAME < Battle::Scene::Animation" ... "end"
      re = /class\s+(\w+)\s*<\s*(?:Battle::Scene::Animation2?|PokeBattle::Scene::Animation)\b/m
      pos = 0
      while m = re.match(src, pos)
        class_name = m[1]
        start = m.end(0)
        depth = 1
        i = start
        # find matching end
        while i < src.length && depth > 0
          if src[i, 3] == "end"
            depth -= 1
            i += 3
            next
          end
          if src[i, 5] == "class" || src[i, 3] == "def" || src[i, 3] == "do" ||
             src[i, 5] == "begin" || src[i, 2] == "if" || src[i, 6] == "unless" ||
             src[i, 4] == "case" || src[i, 5] == "until" || src[i, 5] == "while"
            depth += 1
          end
          i += 1
        end
        body = src[m.end(0)...(i - 3)]
        yield class_name, body
        pos = i
      end
    end

    def self.process(body, anim)
      ctx = Context.new(anim)
      lines = body.lines.to_a
      i = 0
      while i < lines.length
        i = process_line(lines, i, ctx)
      end
      ctx.build_particles
    end

    class Context
      attr_reader :anim, :frame

      def initialize(anim)
        @anim = anim
        @frame = 0
        @pics = {}      # pic var -> { :state, :focus, :graphic, :keys }
      end

      def track(var, focus, graphic = "")
        @pics[var] ||= { :state => default_state, :focus => focus, :graphic => graphic, :keys => {} }
      end

      def record(prop, var, value, frame = nil, duration = 0)
        p = @pics[var]
        return if !p
        fr = frame.nil? ? @frame : frame.to_i
        p[:state][prop] = value
        (p[:keys][prop] ||= []) << [fr, duration.to_i, value]
      end

      def wait(n)
        n = n.to_i
        n = 1 if n < 1
        @frame += n
      end

      def default_state
        { :x => 0, :y => 0, :z => 0, :zoom_x => 100, :zoom_y => 100,
          :opacity => 255, :angle => 0, :visible => true, :tone => nil, :color => nil, :frame => 0 }
      end

      def build_particles
        @pics.each do |_var, p|
          focus = p[:focus]
          if focus == :user || focus == :target || focus == :battler
            role = (focus == :target) ? :target : :user
            part = ParticleBuilder.new_particle(role == :user ? "User" : "Target",
                                                role == :user ? "USER" : "TARGET", role)
          else
            graphic = p[:graphic].to_s
            resolved = GraphicsResolver.resolve(graphic)
            eg = resolved[:found] ? resolved[:editor_graphic] : graphic
            @anim.add_unsupported("graphic_not_found", graphic) if !resolved[:found] && !graphic.empty?
            part = ParticleBuilder.new_particle("fx_#{@anim.particles.length + 1}",
                                                eg.empty? ? "" : eg, focus == :none ? :foreground : focus)
          end
          p[:keys].each do |prop, frames|
            if (focus == :user || focus == :target || focus == :battler) &&
               [:x, :y, :z, :zoom_x, :zoom_y, :angle, :opacity].include?(prop)
              base = frames.first[1]
              frames = frames.map { |fr| [fr[0], fr[1], fr[2].to_i - base.to_i] }
            end
            frames.each do |fr|
              if fr[1].to_i > 0
                ParticleBuilder.move(part, prop, fr[0], fr[1], fr[2])
              else
                ParticleBuilder.set(part, prop, fr[0], fr[2])
              end
            end
          end
          @anim.particles << part
        end
      end
    end

    #---------------------------------------------------------------------------
    # Extract argument list from a call, balancing parentheses so nested calls
    # such as rand(20) survive intact.
    def self.call_args(line)
      i = line.index('(')
      return [] if !i
      depth = 0; j = i
      while j < line.length
        depth += 1 if line[j] == '('
        depth -= 1 if line[j] == ')'
        break if depth == 0 && j > i
        j += 1
      end
      split_args(line[i + 1...j])
    end

    def self.process_line(lines, i, ctx)
      line = lines[i].to_s
      stripped = line.strip

      # addSprite(pic, bitmap, focus) / addSprite(pic, bitmap, @user_sprite)
      if m = stripped.match(/(\w+)\s*=\s*@(?:pic|viewport)\.addSprite\s*\(/)
        var = m[1]
        args = call_args(stripped)
        focus = detect_focus(args[2])
        graphic = clean_graphic(args[1])
        ctx.track(var, focus, graphic)
        return i + 1
      end
      # addNewSprite(x, y, bitmap)  -> foreground absolute
      if m = stripped.match(/(\w+)\s*=\s*@(?:pic|viewport)\.addNewSprite\s*\(/)
        var = m[1]
        args = call_args(stripped)
        graphic = clean_graphic(args[2])
        ctx.track(var, :foreground, graphic)
        ctx.record(:x, var, safe_int(args[0]))
        ctx.record(:y, var, safe_int(args[1]))
        return i + 1
      end
      # addUserSprite / addTargetSprite
      if m = stripped.match(/(\w+)\s*=\s*@(?:pic|viewport)\.add(?:User|Target)Sprite\s*\(/)
        var = m[1]
        focus = stripped.include?("User") ? :user : :target
        ctx.track(var, focus, "")
        return i + 1
      end
      # wait / setWait (advances the implicit frame counter; keyframes below use the
      # explicit delay argument as their frame, matching PictureEx semantics).
      if stripped =~ /setWait\s*\(?(\d+)/ || stripped =~ /\bwait\s*\(?(\d+)/
        ctx.wait($1.to_i)
        return i + 1
      end
      # setSE / setSound(delay, name, volume, pitch)
      if m = stripped.match(/set(?:SE|Sound)\s*\(/)
        args = call_args(stripped)
        name = args[1].to_s.gsub(/["']/, "")
        ctx.anim.audio_events << { :frame => safe_int(args[0]), :name => name,
                                   :volume => (safe_int(args[2], 100) rescue 100),
                                   :pitch => (safe_int(args[3], 100) rescue 100) }
        return i + 1
      end
      # src_rect.set(x, y, w, h) -> :frame (column index)
      if m = stripped.match(/(\w+)\.src_rect\.set\s*\(/)
        args = call_args(stripped)
        handle_src_rect(ctx, m[1], args, 0)
        return i + 1
      end
      # setSrc(delay, x, y, w, h) -> :frame (column index)
      if m = stripped.match(/(\w+)\.setSrc\s*\(/)
        args = call_args(stripped)
        delay = safe_int(args[0])
        handle_src_rect(ctx, m[1], args.drop(1), delay)
        return i + 1
      end
      # setXY(delay, x, y) / moveXY(delay, dur, x, y) / moveDelta(delay, dur, dx, dy)
      if m = stripped.match(/(\w+)\.(setXY|moveXY|moveDelta)\s*\(/)
        var, cmd = m[1], m[2]
        args = call_args(stripped)
        delay = safe_int(args[0])
        if cmd == "setXY"
          xv = coord(ctx, var, args[1]); yv = coord(ctx, var, args[2])
          ctx.record(:x, var, xv, delay)
          ctx.record(:y, var, yv, delay)
        elsif cmd == "moveXY"
          dur = safe_int(args[1], 0)
          xv = coord(ctx, var, args[2]); yv = coord(ctx, var, args[3])
          ctx.record(:x, var, xv, delay, dur)
          ctx.record(:y, var, yv, delay, dur)
        elsif cmd == "moveDelta"
          dur = safe_int(args[1], 0)
          dx = coord(ctx, var, args[2]); dy = coord(ctx, var, args[3])
          st = ctx.instance_variable_get(:@pics)[var][:state]
          cx = st[:x].to_i + dx.to_i
          cy = st[:y].to_i + dy.to_i
          ctx.record(:x, var, cx, delay, dur)
          ctx.record(:y, var, cy, delay, dur)
        end
        return i + 1
      end
      # setZ(delay, z)
      if m = stripped.match(/(\w+)\.setZ\s*\(/)
        args = call_args(stripped)
        ctx.record(:z, m[1], safe_int(args[1]), safe_int(args[0]))
        return i + 1
      end
      # setBlendType(delay, blend)
      if m = stripped.match(/(\w+)\.setBlendType\s*\(/)
        args = call_args(stripped)
        ctx.record(:blending, m[1], safe_int(args[1]), safe_int(args[0]))
        return i + 1
      end
      # setZoomXY(delay, zx, zy) / moveZoomXY(delay, dur, zx, zy)
      if m = stripped.match(/(\w+)\.(set|move)ZoomXY\s*\(/)
        kind = m[2]
        a = call_args(stripped)
        delay = safe_int(a[0])
        if kind == "move"
          dur = safe_int(a[1], 0); zx = a[-2]; zy = a[-1]
        else
          dur = 0; zx = a[1]; zy = a[2]
        end
        ctx.record(:zoom_x, m[1], safe_int(zx, 100), delay, dur)
        ctx.record(:zoom_y, m[1], safe_int(zy, 100), delay, dur)
        return i + 1
      end
      # moveAngle(delay, duration, angle)
      if m = stripped.match(/(\w+)\.moveAngle\s*\(/)
        args = call_args(stripped)
        ctx.record(:angle, m[1], safe_int(args[2]), safe_int(args[0]), safe_int(args[1], 0))
        return i + 1
      end
      # Opcodes the editor cannot represent (recorded, not faked).
      if m = stripped.match(/(\w+)\.(setBitmap|setOrigin|setPokemonBitmap|setCallback|setPictureShow|setPictureHide|moveCallback|setScene|moveScene)\s*\(/)
        ctx.anim.add_unsupported("ruby_command", m[2].to_s)
        return i + 1
      end
      handle_unary(ctx, var_from(stripped), "setZoom", stripped, :zoom_x, :zoom_y) ||
      handle_unary(ctx, var_from(stripped), "moveZoom", stripped, :zoom_x, :zoom_y) ||
      handle_unary(ctx, var_from(stripped), "setOpacity", stripped, :opacity) ||
      handle_unary(ctx, var_from(stripped), "moveOpacity", stripped, :opacity) ||
      handle_unary(ctx, var_from(stripped), "setAngle", stripped, :angle) ||
      handle_unary(ctx, var_from(stripped), "moveAngle", stripped, :angle) ||
      handle_unary(ctx, var_from(stripped), "setVisible", stripped, :visible)
      # Tone / Color
      if m = stripped.match(/(\w+)\.(?:setTone|moveTone)\s*\(/)
        a = call_args(stripped)
        ctx.record(:tone, m[1], ValueHelper.tone_to_string(ValueHelper.parse_tone_args(a.join(","))), safe_int(a[0]))
        return i + 1
      end
      if m = stripped.match(/(\w+)\.(?:setColor|moveColor)\s*\(/)
        a = call_args(stripped)
        ctx.record(:color, m[1], ValueHelper.color_to_string(ValueHelper.parse_color_args(a.join(","))), safe_int(a[0]))
        return i + 1
      end
      i + 1
    rescue
      i + 1
    end

    def self.handle_unary(ctx, var, cmd, stripped, *_props)
      return false if var.nil?
      m = stripped.match(/#{Regexp.escape(var)}\.#{cmd}\s*\(/)
      return false if !m
      args = call_args(stripped)
      delay = safe_int(args[0])
      case cmd
      when "setZoom", "moveZoom"
        # setZoom(delay, zx, zy); moveZoom(delay, dur, zx, zy)
        off = (cmd == "moveZoom") ? 3 : 1
        dur = (cmd == "moveZoom") ? safe_int(args[1], 0) : 0
        ctx.record(:zoom_x, var, safe_int(args[off], 100), delay, dur)
        ctx.record(:zoom_y, var, safe_int(args[off + 1], 100), delay, dur)
      when "setOpacity", "moveOpacity"
        off = (cmd == "moveOpacity") ? 2 : 1
        dur = (cmd == "moveOpacity") ? safe_int(args[1], 0) : 0
        ctx.record(:opacity, var, safe_int(args[off]), delay, dur)
      when "setAngle", "moveAngle"
        off = (cmd == "moveAngle") ? 2 : 1
        dur = (cmd == "moveAngle") ? safe_int(args[1], 0) : 0
        ctx.record(:angle, var, safe_int(args[off]), delay, dur)
      when "setVisible"
        ctx.record(:visible, var, (args[1].to_s.strip == "true"), delay)
      end
      true
    end

    def self.var_from(stripped)
      m = stripped.match(/^(\w+)\./) || stripped.match(/(\w+)\./)
      m ? m[1] : nil
    end

    def self.handle_src_rect(ctx, var, args, delay = 0)
      return if args.length < 4
      cx, cy, w, h = args.map { |a| safe_int(a) }
      return if w <= 0 || h <= 0
      s = ctx.instance_variable_get(:@pics)[var]
      graphic = s ? s[:graphic].to_s : ""
      # The editor only supports a single horizontal row of square cells
      # (cell size = bitmap height). The frame index is the COLUMN in that row.
      if cy != 0
        ctx.anim.add_unsupported("multidimensional_strip", "cy=#{cy}")
      end
      if !graphic.empty?
        resolved = GraphicsResolver.resolve(graphic)
        path = resolved[:found] ? resolved[:path] : nil
        if path && File.exist?(path)
          begin
            bmp = RPG::Cache.load_bitmap("", path) rescue nil
            if bmp && bmp.height > 0 && w != bmp.height
              ctx.anim.add_unsupported("non_square_cells", "cell_w=#{w} bmp_h=#{bmp.height}")
            end
          rescue
            nil
          end
        end
      end
      frame = (cx / w).to_i
      ctx.record(:frame, var, frame, delay)
    end

    def self.detect_focus(arg)
      return :user if arg.to_s.include?("user") || arg.to_s.include?("User")
      return :target if arg.to_s.include?("target") || arg.to_s.include?("Target")
      return :battler if arg.to_s.include?("battler") || arg.to_s.include?("Battler")
      :foreground
    end

    def self.clean_graphic(arg)
      return "" if arg.nil?
      s = arg.to_s.strip
      s = s.gsub(/["']/, "")
      # "Graphics/Battle animations/foo" -> "Battle animations/foo"
      s = s.sub(/^Graphics\/Battle animations\//i, "").sub(/^Graphics\//i, "")
      s
    end

    #---------------------------------------------------------------------------
    def self.coord(ctx, var, expr)
      return 0 if expr.nil?
      s = expr.to_s.dup
      ctx.instance_variable_get(:@pics).each do |v, st|
        s.gsub!(/#{Regexp.escape(v)}\.x\b/, st[:state][:x].to_i.to_s)
        s.gsub!(/#{Regexp.escape(v)}\.y\b/, st[:state][:y].to_i.to_s)
      end
      s.gsub!(/@userSprite\.x|@targetSprite\.x|userSprite\.x|targetSprite\.x/, "0")
      s.gsub!(/@userSprite\.y|@targetSprite\.y|userSprite\.y|targetSprite\.y/, "0")
      s.gsub!(/@userSprite|@targetSprite|userSprite|targetSprite/, "0")
      s = s.gsub(/\.x\b/, "").gsub(/\.y\b/, "")
      s = "0" if s.strip.empty?
      (eval(s) rescue 0).to_i
    rescue
      0
    end

    def self.split_args(str)
      return [] if nil_or_empty?(str)
      out = []; depth = 0; in_str = false; cur = ""
      str.each_char do |c|
        if c == '"' || c == "'"
          in_str = !in_str; cur << c
        elsif c == '(' || c == '['
          depth += 1; cur << c
        elsif c == ')' || c == ']'
          depth -= 1; cur << c
        elsif c == ',' && depth == 0 && !in_str
          out << cur.strip; cur = ""
        else
          cur << c
        end
      end
      out << cur.strip unless cur.strip.empty?
      out
    end

    def self.safe_int(v, fallback = 0)
      return fallback if v.nil?
      s = v.to_s.strip.gsub(/[^0-9\-]/, "")
      s.empty? ? fallback : s.to_i
    rescue
      fallback
    end

    def self.nil_or_empty?(s)
      s.nil? || s.to_s.strip.empty?
    end
  end
end

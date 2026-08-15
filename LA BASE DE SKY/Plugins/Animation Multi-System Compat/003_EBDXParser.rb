#===============================================================================
# Static parser for Elite Battle DX (EBDX) animation blocks.
#
# Unlike the removed runtime recorder, this does NOT execute the animation. It
# reads the block source and translates the EBDX raw-Sprite vocabulary
# (Sprite.new / sprite.x= / sprite.zoom_x= / sprite.opacity= / sprite.tone= /
# sprite.src_rect.set / pbSEPlay / @userSprite / @targetSprite / @scene.wait)
# into the editor's normalized particle/keyframe model. Loops are unrolled by
# repeating their body lines; @scene.wait advances the frame counter. Anything it
# cannot represent is recorded in the animation's unsupported list.
#===============================================================================
module AnimationMultisystem
  class EBDXParser
    # Parse an EBDX definition (from EBDXSourceParser) into a normalized Animation.
    def self.parse(defn)
      anim = Animation.new(
        :type => defn[:type] || :move,
        :move => (defn[:id] || "EBDX").to_s,
        :version => 0,
        :name => (defn[:id] || "EBDX").to_s,
        :fps => 40,
        :source_system => :ebdx,
        :source_file => defn[:source_file],
        :source_line => defn[:source_line],
        :source_metadata => { :species => defn[:species] }
      )
      body = defn[:block_source].to_s
      return anim if body.strip.empty?
      run(body, anim)
      anim
    rescue => e
      anim.add_unsupported("parse_error", "#{e.class}: #{e.message}")
      anim
    end

    # Parse arbitrary block source (used when the editor captures a pasted block).
    def self.parse_source(source, opts = {})
      anim = Animation.new(
        :type => opts[:type] || :move,
        :move => (opts[:move] || "EBDX").to_s,
        :name => (opts[:name] || opts[:move] || "EBDX").to_s,
        :fps => opts[:fps] || 40,
        :source_system => :ebdx,
        :source_file => opts[:source_file],
        :source_line => opts[:source_line]
      )
      run(source.to_s, anim)
      anim
    rescue => e
      anim.add_unsupported("parse_error", "#{e.class}: #{e.message}")
      anim
    end

    #---------------------------------------------------------------------------
    def self.run(body, anim)
      ctx = Context.new(anim)
      lines = body.lines.map { |l| l }.compact
      process(lines, 0, lines.length - 1, ctx)
      ctx.build_particles
    end

    class Context
      attr_reader :anim, :frame, :unsupported, :locals

      def initialize(anim)
        @anim = anim
        @frame = 0
        @sprites = {}        # var name -> { :state => {...}, :role => :fx/:user/:target, :graphic => "" }
        @locals = {}         # loop-index variables (e.g. i) -> current integer value
        @audio = anim.audio_events
        @unsupported = anim.unsupported
      end

      # Register a sprite variable.
      def track(var, role, graphic = "")
        @sprites[var] ||= { :state => default_state, :role => role, :graphic => graphic,
                           :keys => {} }
      end

      def record(prop, var, value)
        s = @sprites[var]
        return if !s
        s[:state][prop] = value
        (s[:keys][prop] ||= []) << [@frame, value]
      end

      def wait(n)
        n = n.to_i
        n = 1 if n < 1
        @frame += n
      end

      def set_unsupported(ctx, detail = nil)
        @unsupported << { :context => ctx.to_s, :detail => detail.to_s }
      end

      def default_state
        { :x => 0, :y => 0, :z => 0, :zoom_x => 100, :zoom_y => 100,
          :opacity => 255, :angle => 0, :visible => true, :tone => nil, :color => nil, :frame => 0 }
      end

      def build_particles
        @sprites.each do |_var, s|
          role = s[:role]
          if role == :user || role == :target
            focus = (role == :user) ? :user : :target
            part = ParticleBuilder.new_particle(role == :user ? "User" : "Target",
                                                role == :user ? "USER" : "TARGET", focus)
          else
            graphic = s[:graphic].to_s
            resolved = GraphicsResolver.resolve(graphic)
            eg = resolved[:found] ? resolved[:editor_graphic] : graphic
            @anim.add_unsupported("graphic_not_found", graphic) if !resolved[:found] && !graphic.empty?
            part = ParticleBuilder.new_particle("fx_#{@anim.particles.length + 1}",
                                                eg.empty? ? "" : eg, :foreground)
          end
          s[:keys].each do |prop, frames|
            # Battler particles: rebase numeric props to offsets from first frame.
            if (role == :user || role == :target) && [:x, :y, :z, :zoom_x, :zoom_y, :angle, :opacity].include?(prop)
              base = frames.first[1]
              frames = frames.map { |fr| [fr[0], fr[1].to_i - base.to_i] }
            end
            frames.each { |fr| ParticleBuilder.set(part, prop, fr[0], fr[1]) }
          end
          @anim.particles << part
        end
      end
    end

    VPAT = '(?:[A-Za-z_]\w*|[A-Za-z_]\w*\["[^"]+"\])'

    def self.role_for_key(key)
      k = key.to_s
      return :user   if k.include?("user")   || k.include?("User")
      return :target if k.include?("target") || k.include?("Target")
      :fx
    end

    #---------------------------------------------------------------------------
    # Recursive line processor.
    def self.process(lines, from, to, ctx)
      i = from
      while i <= to
        line = lines[i].to_s
        i = process_line(lines, i, to, ctx, line)
      end
    end

    def self.process_line(lines, i, to, ctx, line)
      stripped = line.strip
      # Skip the EliteBattle.defineMoveAnimation / defineCommonAnimation wrapper line.
      return i + 1 if stripped.start_with?("EliteBattle.define")
      # Loop headers: unroll by repeating the body, binding the loop variable.
      loop_n = nil
      loop_var = nil
      loop_base = 0
      if m = stripped.match(/^\s*(\d+)\.times\s+(?:do|\{)(\s*\|\s*(\w+)\s*\|)?/)
        loop_n = m[1].to_i
        loop_var = m[2]
      elsif m = stripped.match(/^\s*for\s+(\w+)\s+in\s+(\d+)\s*\.\.\.?(\d+)\s*$/)
        a = m[2].to_i; b = m[3].to_i
        loop_n = stripped.include?("...") ? (b - a) : (b - a + 1)
        loop_var = m[1]
        loop_base = a
      elsif stripped =~ /^\s*while\s+.+/
        loop_n = 1   # unknown bound; unroll once so waits still advance the frame
      end
      if loop_n
        loop_n = 1 if loop_n < 1
        body_start, body_end = find_block(lines, i, to)
        return i if !body_start  # malformed
        loop_n.times do |k|
          ctx.locals[loop_var] = loop_base + k if loop_var
          process(lines, body_start, body_end, ctx)
        end
        ctx.locals.delete(loop_var) if loop_var
        return body_end + 1
      end
      # @scene.wait / wait
      if stripped =~ /@scene\.wait\s*\(?\s*(\d+)/ || stripped =~ /\bwait\s*\(?\s*(\d+)/
        ctx.wait($1.to_i)
        return i + 1
      end
      # pbSEPlay
      if stripped =~ /pbSEPlay\s*\(?\s*["']([^"']+)["']\s*(?:,\s*(\d+))?\s*(?:,\s*(\d+))?/
        ctx.anim.audio_events << { :frame => ctx.frame, :name => $1,
                                   :volume => ($2 || 100).to_i, :pitch => ($3 || 100).to_i }
        return i + 1
      end
      # Battler sprite references via @userSprite / @targetSprite.
      if stripped =~ /@(user|target)Sprite/
        ctx.track("@#{$1}Sprite", role_for_key("@#{$1}Sprite"), "")
      end
      # Assignment from a battler sprite: var = @userSprite
      if m = line.match(/^\s*(\w+)\s*=\s*@(user|target)Sprite\s*$/)
        ctx.track(m[1], role_for_key("@#{$2}Sprite"), "")
        return i + 1
      end
      # Sprite creation: var = Sprite.new(...)  OR  fp["k"] = Sprite.new(...)
      if m = line.match(/^\s*(#{VPAT})\s*=\s*Sprite\.new/)
        ctx.track(m[1], role_for_key(m[1]), "")
        return i + 1
      end
      # Bitmap assignment: var.bitmap = RPG::Cache.picture("path")
      if m = line.match(/(#{VPAT})\.bitmap\s*=\s*(.+)$/)
        var = m[1]
        ctx.track(var, role_for_key(var), "") if !ctx.instance_variable_get(:@sprites)[var]
        if bmp = m[2].match(/["']([^"']+)["']/)
          s = ctx.instance_variable_get(:@sprites)[var]
          s[:graphic] = bmp[1] if s
        end
        return i + 1
      end
      # src_rect.set on a sprite -> :frame (strip cell).
      if m = line.match(/(#{VPAT})\.src_rect\.set\s*\(([^)]*)\)/)
        handle_src_rect(ctx, m[1], split_args(m[2]))
        return i + 1
      end
      # picture.setSrc(delay, x, y, w, h) (custom Ruby variant).
      if m = line.match(/(#{VPAT})\.setSrc\s*\(([^)]*)\)/)
        handle_src_rect(ctx, m[1], split_args(m[2]))
        return i + 1
      end
      # Property assignments: sprite.x = expr / sprite.x += expr
      if m = line.match(/(#{VPAT})\.(\w+)\s*(=|\+=|-=)\s*(.+)$/)
        handle_prop(ctx, m[1], m[2], m[3], m[4])
        return i + 1
      end
      # Ignore-but-known no-ops.
      if stripped =~ /@scene\.moveEntireScene|@vector\.|defocus|focus|still|\.getCenter|setSubstitute|applySpriteProperties|pbDisposeSpriteHash/
        return i + 1
      end
      # Unknown scene/sprite call -> record unsupported (once per signature).
      if stripped =~ /@scene\.(\w+)\(|\.(\w+)\(/
        ctx.set_unsupported("ebdx_command", ($1 || $2).to_s)
        return i + 1
      end
      i + 1
    rescue
      i + 1
    end

    #---------------------------------------------------------------------------
    def self.handle_prop(ctx, var, prop, op, expr)
      return if !ctx.instance_variable_get(:@sprites)[var] && !var.start_with?("@")
      role = ctx.instance_variable_get(:@sprites)[var] && ctx.instance_variable_get(:@sprites)[var][:role]
      cur = current_value(ctx, var, prop)
      val = case prop
            when "x"         then eval_coord(expr, ctx, var) { |_| cur }
            when "y"         then eval_coord(expr, ctx, var) { |_| cur }
            when "z"         then eval_coord(expr, ctx, var) { |_| cur }
            when "zoom_x"    then eval_coord(expr, ctx, var) { |_| cur }
            when "zoom_y"    then eval_coord(expr, ctx, var) { |_| cur }
            when "angle"     then eval_coord(expr, ctx, var) { |_| cur }
            when "opacity"   then eval_coord(expr, ctx, var) { |_| cur }
            when "visible"   then expr.strip == "true"
            when "tone"      then ValueHelper.tone_to_string(ValueHelper.parse_tone_args(expr))
            when "color"     then ValueHelper.color_to_string(ValueHelper.parse_color_args(expr))
            else
              ctx.set_unsupported("ebdx_property", prop)
              return
            end
      # Apply += / -= semantics (computed on the raw EBDX value).
      if op == "+="
        val = cur.to_i + val.to_i if val.is_a?(Numeric)
      elsif op == "-="
        val = cur.to_i - val.to_i if val.is_a?(Numeric)
      end
      mapping = { "x" => :x, "y" => :y, "z" => :z, "zoom_x" => :zoom_x, "zoom_y" => :zoom_y,
                 "angle" => :angle, "opacity" => :opacity, "visible" => :visible,
                 "tone" => :tone, "color" => :color }
      prop_sym = mapping[prop]
      return if !prop_sym
      # Raw Sprite zoom is a multiplier (1.0 = 100%); the editor uses percent.
      recorded = (prop == "zoom_x" || prop == "zoom_y") ? (val.to_f * 100).to_i : val
      ctx.record(prop_sym, var, recorded)
      # Keep the raw value in state so self-referential expressions stay correct.
      sprites = ctx.instance_variable_get(:@sprites)
      sprites[var][:state][prop_sym] = val if sprites[var]
    end

    def self.current_value(ctx, var, prop)
      s = ctx.instance_variable_get(:@sprites)[var]
      s ? (s[:state][prop.to_sym] || 0) : 0
    end

    def self.handle_src_rect(ctx, var, args)
      return if args.length < 4
      cx, cy, w, h = args.map { |a| safe_int(a) }
      return if w <= 0 || h <= 0
      # Editor only supports a single horizontal row of square cells
      # (cell size = bitmap height). Frame index is the COLUMN in that row.
      if cy != 0
        ctx.anim.add_unsupported("multidimensional_strip", "cy=#{cy}")
      end
      graphic = tracked_graphic(ctx, var)
      if !graphic.empty?
        path = GraphicsResolver.resolve(graphic)[:path] rescue nil
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
      ctx.record(:frame, var, (cx / w).to_i)
    end

    def self.tracked_graphic(ctx, var)
      s = ctx.instance_variable_get(:@sprites)[var]
      s ? s[:graphic].to_s : ""
    end

    #---------------------------------------------------------------------------
    # Find the matching end for a block starting at line i (inclusive of body).
    def self.find_block(lines, i, to)
      depth = 0
      j = i
      while j <= to
        line = lines[j].to_s
        depth += opens(line)
        depth -= line.scan(/\bend\b/).length
        if depth <= 0 && j > i
          return [i + 1, j - 1]
        end
        j += 1
      end
      nil
    end

    def self.opens(line)
      c = 0
      c += line.scan(/\bdo\b|\bbegin\b|\bdef\b|\bclass\b|\bmodule\b|\bif\b|\bunless\b|\bcase\b|\bwhile\b|\buntil\b|\bfor\b/).length
      c
    end

    #---------------------------------------------------------------------------
    def self.eval_coord(expr, ctx, var)
      s = expr.to_s.dup
      # Replace tracked var.x / var.y with their current numeric value.
      ctx.instance_variable_get(:@sprites).each do |v, st|
        s.gsub!(/#{Regexp.escape(v)}\.x\b/, st[:state][:x].to_i.to_s)
        s.gsub!(/#{Regexp.escape(v)}\.y\b/, st[:state][:y].to_i.to_s)
      end
      # Replace loop-index variables (e.g. i) with their current value.
      ctx.locals.each do |name, val|
        s.gsub!(/\b#{Regexp.escape(name)}\b/, val.to_i.to_s)
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
      out = []
      depth = 0; in_str = false; cur = ""
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
      s = v.to_s.strip
      return fallback if s.empty?
      s = s.gsub(/[^0-9\-]/, "")
      s.empty? ? fallback : s.to_i
    rescue
      fallback
    end

    def self.nil_or_empty?(s)
      s.nil? || s.to_s.strip.empty?
    end
  end
end

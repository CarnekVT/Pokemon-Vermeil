#===============================================================================
# Battle Scene Studio v0.8.3 - wide authored world coverage.
#===============================================================================
module BSS083WideRoom
  def bss078_extend_room_bitmap!
    bg = @sprites && @sprites["bg"]
    return if !bg || !bg.bitmap || (bg.bitmap.disposed? rescue false)
    return if bg.instance_variable_get(:@bss078_overscanned)
    src = bg.bitmap

    # The visible 384-ish EBDX composition sits in the middle of a much wider
    # world surface. Side pans therefore reveal continuation instead of the edge
    # of the original bitmap. Camera logic is still clamped/contextual, so these
    # margins are safety/world space rather than an invitation to over-pan.
    px = [(@viewport.width * 1.75).to_i, 896].max
    pt = [(@viewport.height * 0.80).to_i, 320].max
    pb = [(@viewport.height * 1.10).to_i, 480].max
    dst = Bitmap.new(src.width + px * 2, src.height + pt + pb)

    top = src.get_pixel([src.width / 2, src.width - 1].min, 0)
    bottom = src.get_pixel([src.width / 2, src.width - 1].min, src.height - 1)
    dst.fill_rect(0, 0, dst.width, pt, top)
    dst.fill_rect(0, pt + src.height, dst.width, pb, bottom)
    dst.blt(px, pt, src, src.rect)

    band = [[src.width / 4, 64].max, src.width].min
    count = [(src.width.to_f / band).ceil, 1].max
    # Left continuation: walk through different source quarters toward the edge
    # instead of cloning one identical strip over and over.
    x = px
    n = 0
    while x > 0
      w = [band, x].min
      sx = ((n % count) * band)
      sx = [sx, src.width - w].min
      x -= w
      dst.blt(x, pt, src, Rect.new(sx, 0, w, src.height))
      n += 1
    end
    # Right continuation mirrors the source-quarter order. No horizontal scale is
    # applied to the authored centre, so perspective/parallax remains coherent.
    x = px + src.width
    n = 0
    while x < dst.width
      w = [band, dst.width - x].min
      sx = src.width - (((n % count) + 1) * band)
      sx = 0 if sx < 0
      sx = [sx, src.width - w].min
      dst.blt(x, pt, src, Rect.new(sx, 0, w, src.height))
      x += w
      n += 1
    end

    old_ox = bg.ox.to_f
    old_oy = bg.oy.to_f
    bg.bitmap = dst
    bg.ox = old_ox + px
    bg.oy = old_oy + pt
    bg.instance_variable_set(:@bss078_overscanned, true)
    bg.instance_variable_set(:@bss083_wide_world, true)
    @bss078_pad_x = px
    @bss078_pad_y = pt

    @sprites.each do |key, sp|
      next if !sp || key == "bg" || key == "void"
      begin
        sp.ex = sp.ex.to_f + px if sp.respond_to?(:ex) && sp.respond_to?(:ex=) && !sp.ex.nil?
        sp.ey = sp.ey.to_f + pt if sp.respond_to?(:ey) && sp.respond_to?(:ey=) && !sp.ey.nil?
      rescue
      end
    end
    begin; src.dispose if src && !(src.disposed? rescue true); rescue; end
  rescue => e
    BSS064.log("BSS083 wide room warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end
end

begin
  BSS070EBDXRoom.prepend(BSS083WideRoom) if defined?(BSS070EBDXRoom) && !BSS070EBDXRoom.ancestors.include?(BSS083WideRoom)
rescue => e
  BSS064.log("BSS083 wide room install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

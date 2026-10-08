class SleepHitBitmap
  def initialize(pkmn, back = false)
    @frames = []
    @current_frame = 0
    @speed = 0
    @done = false
    load_frames(pkmn, back)
  end

  def bitmap; @frames[@current_frame]; end
  def length; @frames.length; end
  def done?; @done || @frames.length <= 1; end

  def update
    return if @done || @frames.length <= 1 || @speed <= 0
    delay = ((@speed / 2.0) * 60).round / 1000.0
    return if System.unscaled_uptime - @last_update < delay
    if @current_frame < @frames.length - 1
      @current_frame += 1
    else
      @done = true
    end
    @last_update = System.unscaled_uptime
  end

  def dispose
    @frames.each(&:dispose)
    @frames.clear
  end

  private

  def load_frames(pkmn, back)
    species = pkmn.species
    form = pkmn.form
    subdir = back ? "Back" : "Front"
    paths = [
      "Graphics/Pokemon/#{subdir}/Sleep/Hit/",
      "Graphics/Pokemon/#{subdir}/Hit/"
    ]
    file = nil
    paths.each do |cdir|
      base = "#{cdir}#{species}"
      %w[.png .gif].each do |e|
        if File.exist?(base + e)
          file = base + e
          break
        end
      end
      break if file
    end
    return if !file
    metrics = GameData::SpeciesMetrics.get_species_form(species, form)
    scale = back ? metrics.back_sprite_scale : metrics.front_sprite_scale
    scale = 1 if !scale || scale < 1
    @speed = back ? metrics.back_sprite_speed : metrics.front_sprite_speed
    full = Bitmap.new(file)
    if full.width > full.height * 2
      fh = full.height
      nf = (full.width.to_f / fh).ceil
      fw = full.width / nf
      nf.times do |i|
        sub = Bitmap.new(fw * scale, fh * scale)
        sub.stretch_blt(Rect.new(0, 0, fw * scale, fh * scale), full, Rect.new(fw * i, 0, fw, fh))
        @frames.push(sub)
      end
    else
      sub = Bitmap.new(full.width * scale, full.height * scale)
      sub.stretch_blt(Rect.new(0, 0, full.width * scale, full.height * scale), full, Rect.new(0, 0, full.width, full.height))
      @frames.push(sub)
    end
    full.dispose
    @last_update = System.unscaled_uptime
  end
end

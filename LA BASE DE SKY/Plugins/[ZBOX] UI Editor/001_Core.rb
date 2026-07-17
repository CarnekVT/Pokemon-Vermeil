# encoding: utf-8
module ZBOX_UIEditor
  @overrides = {}
  @element_cache = {}

  class << self
    attr_reader :overrides
  end

  def self.read_const(klass_name, const_name)
    klass = Object.const_get(klass_name)
    klass.const_get(const_name)
  rescue NameError
    nil
  end

  def self.set_const(klass_name, const_name, value)
    klass = Object.const_get(klass_name)
    klass.const_set(const_name, value)
  rescue NameError
    nil
  end

  def self.make_key(klass_name, const_name)
    "#{klass_name}::#{const_name}"
  end

  def self.get_effective(klass_name, const_name)
    key = make_key(klass_name, const_name)
    return @overrides[key] if @overrides.key?(key)
    read_const(klass_name, const_name)
  end

  def self.set_override(klass_name, const_name, value)
    key = make_key(klass_name, const_name)
    @overrides[key] = value
    set_const(klass_name, const_name, value)
  end

  def self.load_file
    path = ::ZBOX_UIEditor::Settings::OVERRIDES_FILE
    return nil unless File.exist?(path)
    json = File.read(path)
    data = JSON.parse(json)
    data.each do |key, value|
      @overrides[key] = value
      parts = key.split("::")
      set_const(parts[0], parts[1].to_sym, value) if parts.length == 2
    end
    data
  rescue JSON::ParserError => e
    Console.echoln_li "[ZBOX UI Editor] Error loading overrides: #{e.message}"
    nil
  end

  def self.save_file
    path = ::ZBOX_UIEditor::Settings::OVERRIDES_FILE
    File.write(path, JSON.generate(@overrides))
  end

  def self.preview_elements(screen_key)
    screen = ::ZBOX_UIEditor::Settings::SCREENS[screen_key]
    return [] unless screen

    @element_cache[screen_key] ||= begin
      groups = {}
      screen[:elements].each do |elem|
        g = elem[:group] || :default
        groups[g] ||= []
        groups[g] << elem
      end

      preview_list = []
      groups.each do |gid, elems|
        x_elems = elems.select { |e| e[:visual] == :pos_x }
        y_elems = elems.select { |e| e[:visual] == :pos_y }
        w_elems = elems.select { |e| e[:visual] == :size_w || e[:visual] == :size_h }
        val_elems = elems.select { |e| e[:visual] == :val }

        used = []
        x_elems.each do |xe|
          ye = y_elems.find { |y| !used.include?(y[:const]) }
          next unless ye
          used << ye[:const]

          xv = get_effective(xe[:klass], xe[:const]) || 0
          yv = get_effective(ye[:klass], ye[:const]) || 0

          w = nil
          h = nil
          if gid == :box
            ws = w_elems.find { |w| w[:visual] == :size_w }
            hs = w_elems.find { |w| w[:visual] == :size_h }
            w = get_effective(ws[:klass], ws[:const]) if ws
            h = get_effective(hs[:klass], hs[:const]) if hs
          end

          label = xe[:label].sub(/\s+X$/i, "")
          preview_list << { x: xv, y: yv, w: w, h: h, label: label,
                            x_elem: xe, y_elem: ye }
        end

        val_elems.each do |ve|
          v = get_effective(ve[:klass], ve[:const]) || 0
          preview_list << { val: v, label: ve[:label], elem: ve }
        end
      end
      preview_list
    end
  end

  def self.invalidate_cache(screen_key)
    @element_cache.delete(screen_key)
  end

  def self.invalidate_all_cache
    @element_cache.clear
  end
end

if File.exist?(::ZBOX_UIEditor::Settings::OVERRIDES_FILE)
  ZBOX_UIEditor.load_file
end

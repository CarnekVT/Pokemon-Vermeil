#===============================================================================
#  Sky Essentials Core Extensions
#  Luka's Scripting Utilities - Core Data Type Extensions
#===============================================================================

#===============================================================================
#  Array Class Extensions
#===============================================================================
class ::Array
  # Swaps specific indexes
  # @param index1 [Integer]
  # @param index2 [Integer]
  def swap_at(index1, index2)
    val1 = self[index1].clone
    val2 = self[index2].clone
    self[index1] = val2
    self[index2] = val1
  end

  # Pushes value to last index
  # @param val [Object]
  def to_last(val)
    delete(val) if include?(val)
    push(val)
  end

  # @return [Boolean]
  def last?(index)
    (length - 1).eql?(index)
  end

  # @return [Boolean]
  def string_include?(val)
    return false unless val.is_a?(String)

    each do |a|
      return true if a.is_a?(String) && val.include?(a)
    end

    false
  end

  # @param index [Integer]
  # @return [Object]
  def value(index)
    self[index]
  end

  # @return [Boolean]
  def blank?
    empty?
  end

  # @return [Boolean]
  def present?
    !blank?
  end
end

#===============================================================================
#  Hash Class Extensions
#===============================================================================
class ::Hash
  #-----------------------------------------------------------------------------
  #  checks if key has a value
  #-----------------------------------------------------------------------------
  def try_key?(*args)
    args.each do |key|
      return false unless key?(key) && value(key)
    end

    true
  end

  def has_key?(*args)
    try_key?(*args)
  end
  #-----------------------------------------------------------------------------
  #  gets value associated with key
  #-----------------------------------------------------------------------------
  def value(key)
    self[key]
  end

  #-----------------------------------------------------------------------------
  #  gets value associated with key (safe method)
  #-----------------------------------------------------------------------------
  def get_key(key)
    return self.has_key?(key) ? self[key] : nil
  end
  #-----------------------------------------------------------------------------
  #  merges and replace current hash
  #-----------------------------------------------------------------------------
  def deep_merge!(hash)
    # failsafe
    return if !hash.is_a?(Hash)
    for key in hash.keys
      if self[key].is_a?(Hash)
        self[key].deep_merge!(hash[key])
      else
        self[key] = hash[key]
      end
    end
  end
  #-----------------------------------------------------------------------------
  #  merges two hashes
  #-----------------------------------------------------------------------------
  def deep_merge(hash)
    h = self.clone
    # failsafe
    return h if !hash.is_a?(Hash)
    for key in hash.keys
      if self[key].is_a?(Hash)
        h.deep_merge!(hash[key])
      else
        h = hash[key]
      end
    end
    return h
  end
  #-----------------------------------------------------------------------------
  #  merges many hashes into self
  #-----------------------------------------------------------------------------
  def merge_many(*hashes)
    tap do |output|
      hashes.each do |hash|
        hash.each do |key, value|
          output[key] = value
        end
      end
    end
  end

  # @return [Boolean]
  def blank?
    keys.empty?
  end

  # @return [Boolean]
  def present?
    !blank?
  end
end

#===============================================================================
#  File Class Extensions
#===============================================================================
class ::File
  class << self
    # @return [Boolean] safely checks for existing .rxdata file
    def safe_data?(file)
      load_data(file) ? true : false
    rescue StandardError
      false
    end
  end
end

#===============================================================================
#  Numeric Class Extensions
#===============================================================================
class ::Numeric

  #-----------------------------------------------------------------------------
  #  Delta offset for frame rates
  #-----------------------------------------------------------------------------
  def delta(type = :add, round = true)
    d = Graphics.frame_rate/40.0
    a = round ? (self*d).to_i : (self*d)
    s = round ? (self/d).floor : (self/d)
    return type == :add ? a : s
  end
  
  def delta_add(round = true)
    return self.delta(:add, round)
  end
  
  def delta_sub(round = true)
    return self.delta(:sub, round)
  end
  #-----------------------------------------------------------------------------
  #  Superior way to round stuff
  #-----------------------------------------------------------------------------
	alias quick_mafs round
	def round(n = 0)
		# gets the current float to an actually roundable integer
		t = self*(10.0**n)
		# returns the rounded value
		return t.quick_mafs/(10.0**n)
	end

  #-----------------------------------------------------------------------------
  #  interpolate number based on current frame rates
  #-----------------------------------------------------------------------------
  def lerp(inverse: false)
    # time per frame, for a target of 60 FPS
    target = 60.0 / Graphics.average_frame_rate
    target = 1.0 / target if inverse

    self * target
  end

  # @return [Boolean]
  def blank?
    zero?
  end

  # @return [Boolean]
  def present?
    !blank?
  end

  # @return [Integer]
  def minute
    minutes
  end

  # @return [Integer]
  def minutes
    to_i * 60
  end

  # @return [Integer]
  def hour
    hours
  end

  # @return [Integer]
  def hours
    to_i * 60 * 60
  end

  # @return [Integer]
  def day
    days
  end

  # @return [Integer]
  def days
    to_i * 24 * 60 * 60
  end
end

#===============================================================================
#  String Class Extensions
#===============================================================================
class ::String
  # @return [Boolean]
  def blank?
    strip.empty?
  end

  # @return [Boolean]
  def present?
    !blank?
  end

  # @return [Boolean]
  def is_numeric?
    /\A[+-]?\d+(\.\d+)?\z/.match?(self)
  end
end

#===============================================================================
#  NilClass Extensions
#===============================================================================
class ::NilClass
  # @return [Boolean]
  def blank?
    true
  end

  # @return [Boolean]
  def present?
    false
  end
end

#===============================================================================
#  TrueClass/FalseClass Extensions
#===============================================================================
class ::TrueClass
  # @return [Boolean]
  def blank?
    false
  end

  # @return [Boolean]
  def present?
    true
  end
end

class ::FalseClass
  # @return [Boolean]
  def blank?
    true
  end

  # @return [Boolean]
  def present?
    false
  end
end

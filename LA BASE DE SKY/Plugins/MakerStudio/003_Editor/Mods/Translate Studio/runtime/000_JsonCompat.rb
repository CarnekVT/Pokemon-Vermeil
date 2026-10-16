# encoding: UTF-8
# Pure Ruby JSON fallback for embedded Ruby runtimes without the json gem.
module CarnekTranslateJSONFallback
  class ParseError < StandardError; end

  class Parser
    NUMBER = /\G-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/
    def initialize(raw)
      @src = raw.to_s
      @binary = @src.b
      @pos = 0
      @length = @src.bytesize
    end

    def parse
      value = read_value
      skip_space
      raise ParseError, "Unexpected trailing JSON data at byte #{@pos}" if @pos != @length
      value
    end

    private

    def byte
      @src.getbyte(@pos)
    end

    def skip_space
      while @pos < @length && (byte == 32 || byte == 9 || byte == 10 || byte == 13)
        @pos += 1
      end
    end

    def expect(ch)
      raise ParseError, "Expected #{ch.inspect} at byte #{@pos}" if byte != ch.ord
      @pos += 1
    end

    def read_value
      skip_space
      case byte
      when 34 then read_string
      when 123 then read_object
      when 91 then read_array
      when 116 then read_literal('true', true)
      when 102 then read_literal('false', false)
      when 110 then read_literal('null', nil)
      when 45, 48..57 then read_number
      else raise ParseError, "Invalid JSON value at byte #{@pos}"
      end
    end

    def read_literal(word, value)
      raise ParseError, "Invalid JSON literal at byte #{@pos}" unless @src.byteslice(@pos, word.bytesize) == word
      @pos += word.bytesize
      value
    end

    def read_number
      match = NUMBER.match(@binary, @pos)
      raise ParseError, "Invalid JSON number at byte #{@pos}" unless match
      token = match[0]
      @pos = match.end(0)
      token.include?('.') || token.include?('e') || token.include?('E') ? Float(token) : Integer(token)
    end

    def read_string
      expect('"')
      start = @pos
      result = String.new(encoding: Encoding::UTF_8)
      while @pos < @length
        ch = byte
        if ch == 34
          result << @src.byteslice(start, @pos - start)
          @pos += 1
          return result
        elsif ch == 92
          result << @src.byteslice(start, @pos - start)
          @pos += 1
          case byte
          when 34 then result << '"'
          when 92 then result << '\\'
          when 47 then result << '/'
          when 98 then result << "\b"
          when 102 then result << "\f"
          when 110 then result << "\n"
          when 114 then result << "\r"
          when 116 then result << "\t"
          when 117
            @pos += 1
            codepoint = read_unicode_escape
            if (0xD800..0xDBFF).cover?(codepoint)
              raise ParseError, 'Missing low surrogate' if @src.byteslice(@pos, 2) != '\u'
              @pos += 2
              low = read_unicode_escape
              raise ParseError, 'Invalid low surrogate' unless (0xDC00..0xDFFF).cover?(low)
              codepoint = 0x10000 + ((codepoint - 0xD800) << 10) + low - 0xDC00
            elsif (0xDC00..0xDFFF).cover?(codepoint)
              raise ParseError, 'Unexpected low surrogate'
            end
            result << [codepoint].pack('U')
            start = @pos
            next
          else raise ParseError, "Invalid JSON escape at byte #{@pos}"
          end
          @pos += 1
          start = @pos
        elsif ch < 32
          raise ParseError, "Unescaped control character at byte #{@pos}"
        else
          @pos += 1
        end
      end
      raise ParseError, 'Unterminated JSON string'
    end

    def read_unicode_escape
      hex = @src.byteslice(@pos, 4)
      raise ParseError, 'Invalid Unicode escape' unless hex && /\A[0-9a-fA-F]{4}\z/.match?(hex)
      @pos += 4
      hex.to_i(16)
    end

    def read_array
      expect('[')
      skip_space
      if byte == 93
        @pos += 1
        return []
      end
      result = []
      loop do
        result << read_value
        skip_space
        break if byte == 93
        expect(',')
      end
      @pos += 1
      result
    end

    def read_object
      expect('{')
      skip_space
      if byte == 125
        @pos += 1
        return {}
      end
      result = {}
      loop do
        skip_space
        raise ParseError, "Expected string key at byte #{@pos}" if byte != 34
        key = read_string
        skip_space
        expect(':')
        result[key] = read_value
        skip_space
        break if byte == 125
        expect(',')
      end
      @pos += 1
      result
    end
  end

  def self.escape_string(str)
    escaped = str.to_s.gsub(/["\\\x00-\x1f]/) do |char|
      case char
      when '"' then '\"'
      when '\\' then '\\\\'
      when "\b" then '\b'
      when "\f" then '\f'
      when "\n" then '\n'
      when "\r" then '\r'
      when "\t" then '\t'
      else format('\u%04x', char.ord)
      end
    end
    '"' + escaped + '"'
  end

  def self.dump(obj, pretty = false, depth = 0)
    pad = pretty ? '  ' * depth : ''
    next_pad = pretty ? '  ' * (depth + 1) : ''
    space = pretty ? ' ' : ''
    separator = pretty ? ",\n" : ','
    case obj
    when Hash
      return '{}' if obj.empty?
      pairs = obj.map { |k, v| next_pad + escape_string(k) + ':' + space + dump(v, pretty, depth + 1) }
      '{' + (pretty ? "\n" : '') + pairs.join(separator) + (pretty ? "\n#{pad}" : '') + '}'
    when Array
      return '[]' if obj.empty?
      elems = obj.map { |v| next_pad + dump(v, pretty, depth + 1) }
      '[' + (pretty ? "\n" : '') + elems.join(separator) + (pretty ? "\n#{pad}" : '') + ']'
    when String then escape_string(obj)
    when Integer then obj.to_s
    when Float
      raise ArgumentError, 'NaN or Infinity cannot be encoded as JSON' unless obj.finite?
      obj.to_s
    when TrueClass then 'true'
    when FalseClass then 'false'
    when NilClass then 'null'
    else raise TypeError, "Unsupported JSON type: #{obj.class}"
    end
  end
end

unless defined?(JSON) && JSON.respond_to?(:parse) && JSON.respond_to?(:generate) && JSON.respond_to?(:pretty_generate)
  module JSON
    ParserError = CarnekTranslateJSONFallback::ParseError unless const_defined?(:ParserError)
    def self.parse(text, *unused)
      CarnekTranslateJSONFallback::Parser.new(text).parse
    end
    def self.generate(value, *unused)
      CarnekTranslateJSONFallback.dump(value)
    end
    def self.pretty_generate(value, *unused)
      CarnekTranslateJSONFallback.dump(value, true)
    end
  end
end

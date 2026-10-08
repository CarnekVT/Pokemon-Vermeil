# A minimal xUnit runner.
#
# minitest would do this job, but it is not part of every Ruby install (Arch, for
# one, ships it as a separate package), and a test suite that needs a gem
# installed before it runs is a test suite nobody runs. This is the whole thing:
# subclasses of TestCase, methods starting with test_, and the assertions below.

module Assertions
  class Failure < StandardError; end

  def assert(condition, message = nil)
    raise Failure, message || "se esperaba un valor verdadero, llegó #{condition.inspect}" if !condition
    true
  end

  def refute(condition, message = nil)
    raise Failure, message || "se esperaba un valor falso, llegó #{condition.inspect}" if condition
    true
  end

  def assert_equal(expected, actual, message = nil)
    assert expected == actual,
           message || "se esperaba #{expected.inspect}, llegó #{actual.inspect}"
  end

  def refute_equal(unexpected, actual, message = nil)
    refute unexpected == actual, message || "no se esperaba #{unexpected.inspect}"
  end

  def assert_nil(actual, message = nil)
    assert actual.nil?, message || "se esperaba nil, llegó #{actual.inspect}"
  end

  def refute_nil(actual, message = nil)
    refute actual.nil?, message || "no se esperaba nil"
  end

  def assert_empty(collection, message = nil)
    assert collection.empty?, message || "se esperaba vacío, llegó #{collection.inspect}"
  end

  def refute_empty(collection, message = nil)
    refute collection.empty?, message || "se esperaba algo, llegó vacío"
  end

  def assert_includes(collection, member, message = nil)
    assert collection.include?(member),
           message || "#{collection.inspect} no incluye #{member.inspect}"
  end

  def assert_operator(left, operator, right, message = nil)
    assert left.send(operator, right),
           message || "se esperaba #{left.inspect} #{operator} #{right.inspect}"
  end

  def assert_in_delta(expected, actual, delta = 0.001, message = nil)
    assert (expected - actual).abs <= delta,
           message || "se esperaba #{expected} ± #{delta}, llegó #{actual}"
  end

  def assert_raises(klass, message = nil)
    yield
    raise Failure, message || "se esperaba que lanzara #{klass}, no lanzó nada"
  rescue Failure
    raise
  rescue Exception => e
    return e if e.is_a?(klass)
    raise Failure, message || "se esperaba #{klass}, llegó #{e.class}: #{e.message}"
  end

  def flunk(message = "fallo forzado")
    raise Failure, message
  end
end

class TestCase
  include Assertions

  @subclasses = []

  class << self
    attr_reader :subclasses

    def inherited(subclass)
      super
      TestCase.instance_variable_get(:@subclasses) << subclass
    end

    def test_methods
      public_instance_methods(false).grep(/\Atest_/).sort
    end
  end

  def setup; end
  def teardown; end
end

module TestRunner
  Result = Struct.new(:name, :error)

  class << self
    # @param filter [Regexp, nil] only run tests whose "Class#method" matches
    # @param verbose [Boolean] one line per test instead of one character
    # @return [Boolean] whether everything passed
    def run(filter: nil, verbose: false)
      failures, errors, count = [], [], 0
      started = Time.now

      TestCase.subclasses.each do |klass|
        klass.test_methods.each do |method|
          name = "#{klass}##{method}"
          next if filter && !name.match?(filter)
          count += 1
          case outcome = run_one(klass, method)
          when nil          then report(".", "#{name} ok", verbose)
          when Assertions::Failure
            failures << Result.new(name, outcome)
            report("F", "#{name} FALLO", verbose)
          else
            errors << Result.new(name, outcome)
            report("E", "#{name} ERROR", verbose)
          end
        end
      end

      puts "" if !verbose
      print_details("Fallos", failures)
      print_details("Errores", errors)
      puts format("\n%d tests, %d fallos, %d errores, %.2fs",
                  count, failures.size, errors.size, Time.now - started)
      failures.empty? && errors.empty?
    end

    # Parses the command line the same way minitest does for the flags that matter.
    def options_from(argv)
      filter = nil
      if (index = argv.index("-n") || argv.index("--name"))
        pattern = argv[index + 1].to_s
        filter = pattern.start_with?("/") ? Regexp.new(pattern[1..-2]) : Regexp.new(Regexp.escape(pattern))
      end
      { filter: filter, verbose: argv.include?("-v") || argv.include?("--verbose") }
    end

    private

    def run_one(klass, method)
      test = klass.new
      test.setup
      test.send(method)
      nil
    rescue Exception => e
      e
    ensure
      begin
        test&.teardown
      rescue Exception
        nil
      end
    end

    def report(char, line, verbose)
      verbose ? puts(line) : print(char)
      $stdout.flush
    end

    def print_details(title, results)
      return if results.empty?
      puts "\n#{title}:"
      results.each do |result|
        puts "  #{result.name}"
        puts "    #{result.error.class}: #{result.error.message}"
        location = result.error.backtrace&.find { |line| line.include?("/tests/") }
        puts "    en #{location}" if location
      end
    end
  end
end

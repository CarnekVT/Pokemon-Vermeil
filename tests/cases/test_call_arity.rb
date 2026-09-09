# Static check: every call site whose target method can be resolved is made with
# a positional-argument count that method accepts. This catches the "un
# parámetro de más" class of bug — a call that drifted out of sync with its
# `def` — without running the code path.
#
# The AST (Prism) supplies the call sites and their argument counts; the *method*
# is resolved against the already-booted engine, so `attr_accessor`,
# `define_method`, `alias_method`, inherited and mixed-in methods all report
# their real arity and produce no false positives.
#
# A call is checked only when all of these hold, otherwise it is skipped:
#   - the receiver is absent, `self`, or a constant (never an arbitrary expr),
#   - that constant / lexical class resolves to a real Module,
#   - the target method exists, is owned by neither Object nor a core module
#     (so bare top-level `pb*` helpers are not checked), and takes no `*rest`,
#   - the call passes no `*splat`.
# Keyword arguments are not checked; a trailing hash argument counts as either
# zero or one positional, and only a call outside both bounds is flagged.

require "prism"

class TestCallArity < TestCase
  # Call sites the check flags but that are correct: a `file => [names]`
  # allowlist. Add an entry only with a reason.
  IGNORE = {
    # `passability_setup(map_id) if defined?(passability_setup)` — added by a
    # plugin, absent in the base; the guard makes the call safe, and the name
    # resolves to an unrelated method here.
    "Data/Scripts/011_Game classes/005_Game_Map.rb" => %i[passability_setup],
  }.freeze

  # Walks one file, tracking lexical class nesting so a bare call can be resolved
  # against the class it sits in.
  class Collector < Prism::Visitor
    Call = Struct.new(:name, :count, :scope, :singleton, :file, :line)

    attr_reader :calls

    def initialize(file)
      super()
      @file = file
      @calls = []
      @namespaces = []       # e.g. ["Battle", "Battler"] -> "Battle::Battler"
      @singleton = 0         # >0 while inside `class << self`
      @def_singleton = []    # one flag per enclosing `def`
    end

    def visit_class_node(node)   = with_namespace(node) { super }
    def visit_module_node(node)  = with_namespace(node) { super }

    def visit_singleton_class_node(node)
      @singleton += 1
      super
    ensure
      @singleton -= 1
    end

    def visit_def_node(node)
      @def_singleton.push(!node.receiver.nil?)
      super
    ensure
      @def_singleton.pop
    end

    def visit_call_node(node)
      record(node)
      super
    end

    private

    def with_namespace(node)
      name = const_name(node.constant_path)
      return yield if name.nil?
      @namespaces.push(name)
      yield
    ensure
      @namespaces.pop if name
    end

    def record(node)
      recv = node.receiver
      scope =
        if recv.nil? || recv.is_a?(Prism::SelfNode)
          @namespaces.join("::")
        elsif recv.is_a?(Prism::ConstantReadNode) || recv.is_a?(Prism::ConstantPathNode)
          const_name(recv)
        end
      return if scope.nil? && !(recv.nil? || recv.is_a?(Prism::SelfNode))
      return unless (count = positional_count(node.arguments))

      singleton = !recv.nil? && !recv.is_a?(Prism::SelfNode) ||
                  @singleton.positive? || @def_singleton.last
      @calls << Call.new(node.name, count, scope || "", singleton, @file, node.location.start_line)
    end

    # A trailing `foo(k => v)` / `foo(k: v)` is a positional Hash for a method
    # with no keyword params but keywords for one with them; without resolving
    # that here, the count is a range and a call is flagged only when it fits
    # neither end.
    #
    # @return [Range, nil] possible positional-arg counts, nil when a splat hides it
    def positional_count(arguments)
      return (0..0) if arguments.nil?
      fixed = 0
      trailing_hash = false
      arguments.arguments.each do |arg|
        case arg
        when Prism::SplatNode, Prism::ForwardingArgumentsNode then return nil
        when Prism::BlockArgumentNode then next
        when Prism::KeywordHashNode then trailing_hash = true
        else fixed += 1
        end
      end
      fixed..(fixed + (trailing_hash ? 1 : 0))
    end

    def const_name(node)
      case node
      when Prism::ConstantReadNode
        node.name.to_s
      when Prism::ConstantPathNode
        parent = node.parent ? const_name(node.parent) : ""
        parent && (parent.empty? ? node.name.to_s : "#{parent}::#{node.name}")
      end
    end
  end

  def test_calls_use_a_valid_positional_argument_count
    report = []
    checked = 0
    considered = 0

    # The harness leaves $DEBUG on (PluginManager needs it at boot); here it only
    # makes Ruby print every rescued NameError from constant probing.
    was_debug, $DEBUG = $DEBUG, false

    source_files.each do |file|
      result = Prism.parse_file(file)
      next if result.failure?
      collector = Collector.new(rel(file))
      collector.visit(result.value)

      collector.calls.each do |call|
        next if IGNORE[call.file]&.include?(call.name)
        considered += 1
        bounds = resolve(call)
        next if bounds.nil?

        req, opt = bounds
        checked += 1
        # overlap between what the call could pass and what the def accepts
        next if call.count.begin <= req + opt && call.count.end >= req

        passed = call.count.begin == call.count.end ? call.count.begin.to_s : call.count.to_s
        accepts = opt.zero? ? req.to_s : "#{req}..#{req + opt}"
        report << "#{call.file}:#{call.line}: #{call.name} llamado con " \
                  "#{passed} arg(s), acepta #{accepts}"
      end
    end

    assert_empty report,
                 "llamadas con aridad incorrecta (#{checked} verificadas de " \
                 "#{considered} candidatas):\n  " + report.join("\n  ")
  ensure
    $DEBUG = was_debug
  end

  private

  # @return [Array(Integer, Integer), nil] [required, optional], or nil to skip
  def resolve(call)
    mod = call.scope.empty? ? Object : Object.const_get(call.scope)
    return nil unless mod.is_a?(Module)
    meth =
      if call.singleton
        mod.singleton_class.instance_method(call.name)
      else
        mod.instance_method(call.name)
      end
    bounds(meth)
  rescue NameError, TypeError
    nil
  end

  # Owners too broad to trust a name against: core (`to_s`, `send`, `raise`…) and
  # `Object` itself, where every top-level helper and every `method_missing`
  # shim also lives. Skipping `Object` drops arity checks on bare `pb*` helpers,
  # which is the price of no false positives from redefined core methods.
  BASE_OWNERS = [BasicObject, Object, Kernel, Module, Class].freeze

  def bounds(meth)
    return nil if BASE_OWNERS.include?(meth.owner)
    # C methods and the RGSS/MKXP shim (test scaffolding, often a narrower
    # signature than the real runtime) are not the game's code.
    return nil if meth.source_location.nil? || meth.source_location.first.include?("/tests/")

    req = opt = 0
    meth.parameters.each do |type, _|
      case type
      when :req  then req += 1
      when :opt  then opt += 1
      when :rest then return nil
      end
    end
    [req, opt]
  end

  def source_files
    base = TestGame::GAME_DIR
    Dir[File.join(base, "Data", "Scripts", "**", "*.rb")] +
      Dir[File.join(base, "Plugins", "**", "*.rb")]
  end

  def rel(file)
    file.sub("#{TestGame::GAME_DIR}/", "")
  end
end

#!/usr/bin/env ruby
# Runs the whole suite:
#
#   ruby tests/run.rb                     # everything
#   ruby tests/run.rb -n /battle/         # only tests whose name matches
#   ruby tests/run.rb -n TestBoot         # only one class
#   ruby tests/run.rb -v                  # one line per test
#
# Nothing to install: the runner lives in tests/framework.rb.

require_relative "harness"
require_relative "battle_helper"

TestGame.boot

Dir[File.join(__dir__, "cases", "*.rb")].sort.each { |file| require file }

exit(TestRunner.run(**TestRunner.options_from(ARGV)) ? 0 : 1)

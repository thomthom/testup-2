#-------------------------------------------------------------------------------
#
# Copyright 2013-2014 Trimble Navigation Ltd.
# License: The MIT License (MIT)
#
#-------------------------------------------------------------------------------


require 'testup/minitest_setup.rb'

if defined?(Sketchup)
  require 'testup/sketchup_test_utilities.rb'
end


module TestUp

  # Methods used by the test discoverer.
  module TestCaseExtendable

    def test_methods
      tests = public_instance_methods(true).grep(/^test_/i).sort
    end

  end # module TestCaseExtendable


  # Inherit tests from this class to get access to utility methods for SketchUp.
  class TestCase < Minitest::Test

    extend TestCaseExtendable

    if defined?(Sketchup)
      include SketchUpTestUtilities
    end

  end # class

end # module

require_relative 'test_helper'

class EngineTest < ActiveSupport::TestCase
  def test_does_not_include_itself_in_action_controller_base_when_turbolinks_auto_include_is_false
    refute ActionController::Base.included_modules.any? { |m| m.name && m.name.include?('Turbolinks') }
  end
end

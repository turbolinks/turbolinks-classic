require 'rails'
require 'abstract_controller'
require 'abstract_controller/railties/routes_helpers'
require 'action_controller'
require 'turbolinks'

require 'active_support/testing/autorun'
require 'active_support/test_case'
ActiveSupport::TestCase.test_order = :random if ActiveSupport::TestCase.respond_to?(:test_order=)

class TestApplication < Rails::Application
  config.secret_token = Digest::SHA1.hexdigest(Time.now.to_s)
  config.secret_key_base = SecureRandom.hex
  config.eager_load = false

  initialize!

  routes.draw do
    get ':controller(/:action)'
  end
end

module ActionController
  class Base
    extend AbstractController::Railties::RoutesHelpers.with(TestApplication.routes)
  end

  class TestCase
    def before_setup
      @routes = TestApplication.routes
      super
    end
  end
end

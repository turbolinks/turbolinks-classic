require 'rails'
require 'abstract_controller'
require 'abstract_controller/railties/routes_helpers'
require 'action_controller'
require 'turbolinks'

require 'active_support/testing/autorun' if Rails.version >= '4'
require 'active_support/test_case'
ActiveSupport::TestCase.test_order = :random if ActiveSupport::TestCase.respond_to?(:test_order=)

class TestApplication < Rails::Application
  config.secret_token = Digest::SHA1.hexdigest(Time.now.to_s)
  config.secret_key_base = SecureRandom.hex
  config.eager_load = false
  config.turbolinks.auto_include = false

  initialize!

  routes.draw do
    get 'redirect_path', to: redirect('/turbolinks/simple_action')
    get 'redirect_hash', to: redirect(path: '/turbolinks/simple_action')
    get ':controller(/:action)'
  end
end

class TestController < ActionController::Base
  extend AbstractController::Railties::RoutesHelpers.with(TestApplication.routes)
  include Turbolinks::Controller
end

module ActionController
  class TestCase
    setup do
      @routes = TestApplication.routes
    end
  end
end

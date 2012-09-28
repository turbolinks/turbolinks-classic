
require 'turbolinks/redirect'
module Turbolinks
  class Engine < ::Rails::Engine
    initializer :turbolinks_headers do |config|
      ActionController::Base.class_eval do
        include Turbolinks::PushStateFilter
        after_filter :set_push_state_location
      end
    end
  end
end

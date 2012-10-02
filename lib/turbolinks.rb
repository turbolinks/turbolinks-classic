
module Turbolinks
  class Engine < ::Rails::Engine
    initializer :turbolinks_headers do |config|

      require 'turbolinks/redirect'
      require 'turbolinks/xhr_location'

      ActionController::Base.class_eval do
        include Turbolinks::SetXHRCurrentLocation
        after_filter :set_xhr_current_location
      end
    end
  end
end

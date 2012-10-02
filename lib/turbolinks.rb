

module Turbolinks
  class Engine < ::Rails::Engine
    initializer :turbolinks_set_xhr_current_location do |config|

      require 'turbolinks/xhr_current_location'
      ActionController::Base.class_eval do
        include Turbolinks::SetXHRCurrentLocation
        after_filter :set_xhr_current_location
      end

    end

    initializer :turbolinks_set_redirect_to_catch_xhr_referer do |config|

      require 'turbolinks/redirect'
      ActionController::Base.class_eval do
        include RedirectCatchXHRReferer
      end

    end
  end
end

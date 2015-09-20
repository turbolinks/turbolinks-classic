require 'turbolinks/version'
require 'turbolinks/xhr_headers'
require 'turbolinks/xhr_redirect'
require 'turbolinks/xhr_url_for'
require 'turbolinks/cookies'
require 'turbolinks/x_domain_blocker'
require 'turbolinks/redirection'

module Turbolinks
  module Controller
    include XHRHeaders, Cookies, XDomainBlocker, Redirection

    def self.included(base)
      if base.respond_to?(:before_action)
        base.before_action :set_xhr_redirected_to, :set_request_method_cookie
        base.after_action :abort_xdomain_redirect
      else
        base.before_filter :set_xhr_redirected_to, :set_request_method_cookie
        base.after_filter :abort_xdomain_redirect
      end
    end
  end

  class Engine < ::Rails::Engine
    config.turbolinks = ActiveSupport::OrderedOptions.new
    config.turbolinks.auto_include = true

    initializer :turbolinks do |app|
      ActiveSupport.on_load(:action_controller) do
        next if self != ActionController::Base

        if app.config.turbolinks.auto_include
          include Controller
        end

        ActionDispatch::Request.class_eval do
          def referer
            self.headers['X-XHR-Referer'] || super
          end
          alias referrer referer
        end

        require 'action_dispatch/routing/redirection'
        ActionDispatch::Routing::Redirect.class_eval do
          if defined?(prepend)
            prepend XHRRedirect
          else
            include LegacyXHRRedirect
          end
        end
      end

      ActiveSupport.on_load(:action_view) do
        (ActionView::RoutingUrlFor rescue ActionView::Helpers::UrlHelper).module_eval do
          if defined?(prepend) && Rails.version >= '4'
            prepend XHRUrlFor
          else
            include LegacyXHRUrlFor
          end
        end
      end
    end
  end
end

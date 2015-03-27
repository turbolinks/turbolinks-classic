require 'turbolinks/version'
require 'turbolinks/xhr_headers'
require 'turbolinks/xhr_url_for'
require 'turbolinks/cookies'
require 'turbolinks/x_domain_blocker'
require 'turbolinks/redirection'

module Turbolinks
  class Engine < ::Rails::Engine
    initializer :turbolinks do |config|
      ActiveSupport.on_load(:action_controller) do
        ActionController::Base.class_eval do
          include XHRHeaders, Cookies, XDomainBlocker, Redirection

          if respond_to?(:before_action)
            before_action :set_xhr_redirected_to, :set_request_method_cookie
            after_action :abort_xdomain_redirect
          else
            before_filter :set_xhr_redirected_to, :set_request_method_cookie
            after_filter :abort_xdomain_redirect
          end
        end

        ActionDispatch::Request.class_eval do
          def referer
            self.headers['X-XHR-Referer'] || super
          end
          alias referrer referer
        end

        require 'action_dispatch/routing/redirection'
        ActionDispatch::Routing::Redirect.class_eval do
          def call_with_turbolinks(env)
            status, headers, body = call_without_turbolinks(env)

            if env['rack.session'] && env['HTTP_X_XHR_REFERER']
              env['rack.session'][:_turbolinks_redirect_to] = headers['Location']
            end

            [status, headers, body]
          end
          alias_method_chain :call, :turbolinks
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

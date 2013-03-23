module Turbolinks
  module XHRHeaders
    extend ActiveSupport::Concern

    included do
      alias_method_chain :_compute_redirect_to_location, :xhr_referer
    end

    private
      def _compute_redirect_to_location_with_xhr_referer(options)
        if options == :back && request.headers["X-XHR-Referer"]
          _compute_redirect_to_location_without_xhr_referer(request.headers["X-XHR-Referer"])
        else
          _compute_redirect_to_location_without_xhr_referer(options)
        end
      end

      def set_xhr_current_location
        response.headers['X-XHR-Current-Location'] = request.fullpath
      end
  end

  module Cookies
    private
      def set_request_method_cookie
        cookies[:request_method] = request.request_method
      end
  end

  module XDomainBlocker
    private
    def same_origin?(a, b)
      a = URI.parse(a)
      b = URI.parse(b)
      [a.scheme, a.host, a.port] == [b.scheme, b.host, b.port]
    end

    def abort_xdomain_redirect
      to_uri = response.headers['Location'] || ""
      current = request.headers['X-XHR-Referer'] || ""
      unless to_uri.blank? || current.blank? || same_origin?(current, to_uri)
        self.status = 403
      end
    end
  end

  class Engine < ::Rails::Engine
    initializer :turbolinks_xhr_headers do |config|
      ActionController::Base.class_eval do
        include XHRHeaders, Cookies, XDomainBlocker
        before_filter :set_xhr_current_location, :set_request_method_cookie
        after_filter :abort_xdomain_redirect
      end
      
      ActionDispatch::Request.class_eval do
        def referer
          self.headers['X-XHR-Referer'] || super
        end
        alias referrer referer
      end
    end
  end
end

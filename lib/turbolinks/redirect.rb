module ActionController
  module Redirecting
    private

      def _compute_redirect_to_location_with_turbolinks(options)
        if options == :back and request.headers["X-XHR-Referer"]
          _compute_redirect_to_location_without_turbolinks(request.headers["X-XHR-Referer"])
        else
          _compute_redirect_to_location_without_turbolinks(options)
        end
      end

      alias_method_chain :_compute_redirect_to_location, :turbolinks
  end
end

module Turbolinks
  module PushStateFilter
    private
      def set_push_state_location
          response.headers['X-XHR-Location'] = request.fullpath
      end
  end
end

module ActionController
  module Redirecting
    private
      def redirect_to_with_turbolinks(options = {}, response_status = {})
        redirect_to_without_turbolinks(options,response_status)
        flash[:x_push_state_location] = self.location
      end

      def _compute_redirect_to_location_with_turbolinks(options)
        logger.debug "YES IM HERE"
        if options == :back and request.headers["X-Push-State-Referer"]
          _compute_redirect_to_location_without_turbolinks(request.headers["X-Push-State-Referer"])
        else
          _compute_redirect_to_location_without_turbolinks(options)
        end
      end

      alias_method_chain :_compute_redirect_to_location, :turbolinks
      alias_method_chain :redirect_to, :turbolinks
  end
end

module Turbolinks
  module PushStateFilter
    private
      def set_push_state_location
        if flash[:x_push_state_location]
          response.headers['X-Push-State-Location'] = flash[:x_push_state_location]
          flash[:x_push_state_location] = nil
        end
      end
  end
end

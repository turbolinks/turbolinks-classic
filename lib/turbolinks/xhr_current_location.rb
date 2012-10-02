module Turbolinks
  module SetXHRCurrentLocation
    private
      def set_xhr_current_location
        response.headers['X-XHR-Current-Location'] = request.fullpath
      end
  end
end

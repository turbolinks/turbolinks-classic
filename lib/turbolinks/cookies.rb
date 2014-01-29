module Turbolinks
  # Sets a request_method cookie containing the request method of the current request.
  # The Turbolinks script will not initialize if this cookie is set to anything other than GET.
  module Cookies
    private
      def set_request_method_cookie
        cookies[:request_method] = request.request_method
      end
  end
end
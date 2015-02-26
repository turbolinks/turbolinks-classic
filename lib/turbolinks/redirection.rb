module Turbolinks
  # Provides a means of using Turbolinks to perform redirects.  The server
  # will respond with a JavaScript call to Turbolinks.visit(url).
  module Redirection
    extend ActiveSupport::Concern

    def redirect_to(url = {}, response_status = {})
      super(url, response_status)

      if request.xhr? && !request.get?
        perform_turbolinks_visit
      end
    end

    def redirect_via_turbolinks_to(url = {}, response_status = {})
      redirect_to(url, response_status)
      perform_turbolinks_visit
    end

    private

    def perform_turbolinks_visit
      self.status           = 200
      self.response_body    = "Turbolinks.visit('#{location}');"
      response.content_type = Mime::JS
    end
  end
end

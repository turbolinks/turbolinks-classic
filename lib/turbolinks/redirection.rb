module Turbolinks
  # Provides a means of using Turbolinks to perform redirects.  The server
  # will respond with a JavaScript call to Turbolinks.visit(url).
  module Redirection
    extend ActiveSupport::Concern

    def redirect_to(url = {}, response_status = {})
      options = response_status.extract!(:change, :turbolinks)
      super(url, response_status)

      if options[:turbolinks] || (request.xhr? && !request.get?)
        change = ", { change: ['#{Array(options[:change]).join("', '")}'] }" if options[:change]
        self.status           = 200
        self.response_body    = "Turbolinks.visit('#{location}'#{change});"
        response.content_type = Mime::JS
      end
    end
  end
end

module Turbolinks
  # Provides a means of using Turbolinks to perform redirects.  The server
  # will respond with a JavaScript call to Turbolinks.visit(url).
  module Redirection
    extend ActiveSupport::Concern

    def redirect_to(url = {}, response_status = {})
      turbolinks = response_status.delete(:turbolinks)
      options = response_status.extract!(:keep, :change, :flush)
      raise ArgumentError, "cannot combine :keep, :change and :flush options" if options.size > 1

      super(url, response_status)

      if turbolinks || (turbolinks != false && request.xhr? && !request.get?)
        self.status           = 200
        self.response_body    = "Turbolinks.visit('#{location}'#{_turbolinks_js_options(options)});"
        response.content_type = Mime::JS
      end
    end

    private

    def _turbolinks_js_options(options)
      if options[:change]
        ", { change: ['#{Array(options[:change]).join("', '")}'] }"
      elsif options[:keep]
        ", { keep: ['#{Array(options[:keep]).join("', '")}'] }"
      elsif options[:flush]
        ", { flush: true }"
      end
    end
  end
end

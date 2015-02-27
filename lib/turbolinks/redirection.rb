module Turbolinks
  # Provides a means of using Turbolinks to perform renders and redirects.
  # The server will respond with a JavaScript call to Turbolinks.visit/replace().
  module Redirection
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

    def render(*args, &block)
      render_options = args.extract_options!
      turbolinks = render_options.delete(:turbolinks)
      options = render_options.extract!(:keep, :change, :flush)
      raise ArgumentError, "cannot combine :keep, :change and :flush options" if options.size > 1

      super(*args, render_options, &block)

      if turbolinks || (turbolinks != false && options.size > 0 && request.xhr? && !request.get?)
        self.status           = 200
        self.response_body    = "Turbolinks.replace('#{view_context.j(response.body)}'#{_turbolinks_js_options(options)});"
        response.content_type = Mime::JS
      end

      self.response_body
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

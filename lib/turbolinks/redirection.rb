module Turbolinks
  # Provides a means of using Turbolinks to perform renders and redirects.
  # The server will respond with a JavaScript call to Turbolinks.visit/replace().
  module Redirection

    def redirect_to(url = {}, response_status = {})
      turbolinks, options = _extract_turbolinks_options!(response_status)

      value = super(url, response_status)

      if turbolinks || (turbolinks != false && request.xhr? && !request.get?)
        _perform_turbolinks_response "Turbolinks.visit('#{location}'#{_turbolinks_js_options(options)});"
      end

      value
    end

    def render(*args, &block)
      render_options = args.extract_options!
      turbolinks, options = _extract_turbolinks_options!(render_options)

      super(*args, render_options, &block)

      if turbolinks || (turbolinks != false && options.size > 0 && request.xhr? && !request.get?)
        _perform_turbolinks_response "Turbolinks.replace('#{view_context.j(response.body)}'#{_turbolinks_js_options(options)});"
      end

      self.response_body
    end

    def redirect_via_turbolinks_to(url = {}, response_status = {})
      ActiveSupport::Deprecation.warn("`redirect_via_turbolinks_to` is deprecated and will be removed in Turbolinks 3.1. Use redirect_to(url, turbolinks: true) instead.")
      redirect_to(url, response_status.merge!(turbolinks: true))
    end

    private
      def _extract_turbolinks_options!(options)
        turbolinks = options.delete(:turbolinks)
        options = options.extract!(:keep, :change, :flush).delete_if { |_, value| value.nil? }
        raise ArgumentError, "cannot combine :keep, :change and :flush options" if options.size > 1
        [turbolinks, options]
      end

      def _perform_turbolinks_response(body)
        self.status           = 200
        self.response_body    = body
        response.content_type = Mime::JS
      end

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

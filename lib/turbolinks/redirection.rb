module Turbolinks
  # Provides a means of using Turbolinks to perform renders and redirects.
  # The server will respond with a JavaScript call to Turbolinks.visit/replace().
  module Redirection

    def redirect_to(url = {}, response_status = {})
      turbolinks, options = _extract_turbolinks_options!(response_status)
      turbolinks = (request.xhr? && (options.size > 0 || !request.get?)) if turbolinks.nil?

      if turbolinks
        response.content_type = Mime[:js]
      end

      return_value = super(url, response_status)

      if turbolinks
        self.status = 200
        self.response_body = "Turbolinks.visit('#{location}'#{_turbolinks_js_options(options)});"
      end

      return_value
    end

    def render(*args, &block)
      render_options = args.extract_options!
      turbolinks, options = _extract_turbolinks_options!(render_options)
      turbolinks = (request.xhr? && options.size > 0) if turbolinks.nil?

      if turbolinks
        response.content_type = Mime[:js]
      end

      super(*args, render_options, &block)

      if turbolinks
        self.status = 200
        self.response_body = "Turbolinks.replace('#{view_context.j(response.body)}'#{_turbolinks_js_options(options)});"
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

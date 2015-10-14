module Turbolinks
  # Provides a means of using Turbolinks to perform renders and redirects.
  # The server will respond with a JavaScript call to Turbolinks.visit/replace().
  module Redirection
    MUTATION_MODES = [:change, :append, :prepend].freeze

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

        render_options = _normalize_render(*args, render_options, &block)
        body = render_to_body(render_options)

        self.status = 200
        self.response_body = "Turbolinks.replace('#{view_context.j(body)}'#{_turbolinks_js_options(options)});"
      else
        super(*args, render_options, &block)
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
        options = options.extract!(:keep, :change, :append, :prepend, :flush).delete_if { |_, value| value.nil? }

        raise ArgumentError, "cannot combine :keep and :flush options" if options[:keep] && options[:flush]

        MUTATION_MODES.each do |mutation_mode_option|
          raise ArgumentError, "cannot combine :keep and :#{mutation_mode_option} options" if options[:keep] && options[mutation_mode_option]
          raise ArgumentError, "cannot combine :flush and :#{mutation_mode_option} options" if options[:flush] && options[mutation_mode_option]
        end if options[:keep] || options[:flush]

        [turbolinks, options]
      end

      def _turbolinks_js_options(options)
        js_options = {}

        js_options[:change] = Array(options[:change]) if options[:change]
        js_options[:append] = Array(options[:append]) if options[:append]
        js_options[:prepend] = Array(options[:prepend]) if options[:prepend]
        js_options[:keep] = Array(options[:keep]) if options[:keep]
        js_options[:flush] = true if options[:flush]

        ", #{js_options.to_json}" if js_options.present?
      end
  end
end

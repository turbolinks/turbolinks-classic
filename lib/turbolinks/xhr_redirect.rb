module Turbolinks
  module XHRRedirect
    def call(env)
      status, headers, body = super(env)

      if env['rack.session'] && env['HTTP_X_XHR_REFERER']
        env['rack.session'][:_turbolinks_redirect_to] = headers['Location']
      end

      [status, headers, body]
    end
  end

  # TODO: Remove me when support for Ruby < 2 && Rails < 4 is dropped
  module LegacyXHRRedirect
    def self.included(base)
      base.alias_method_chain :call, :turbolinks
    end

    def call_with_turbolinks(env)
      status, headers, body = call_without_turbolinks(env)

      if env['rack.session'] && env['HTTP_X_XHR_REFERER']
        env['rack.session'][:_turbolinks_redirect_to] = headers['Location']
      end

      [status, headers, body]
    end
  end
end

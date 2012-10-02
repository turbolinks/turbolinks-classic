module RedirectCatchXHRReferer
  extend ActiveSupport::Concern

  included do
    alias_method_chain :_compute_redirect_to_location, :turbolinks
  end

  private
    def _compute_redirect_to_location_with_turbolinks(options)
      if options == :back && request.headers["X-XHR-Referer"]
        _compute_redirect_to_location_without_turbolinks(request.headers["X-XHR-Referer"])
      else
        _compute_redirect_to_location_without_turbolinks(options)
      end
    end
end


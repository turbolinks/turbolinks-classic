require_relative 'test_helper'

class RedirectController < ActionController::Base
  def redirect_via_turbolinks_to_url_string
    redirect_via_turbolinks_to 'http://example.com'
  end

  def redirect_via_turbolinks_to_url_hash
    redirect_via_turbolinks_to action: 'action'
  end

  def redirect_via_turbolinks_to_path_and_custom_status
    redirect_via_turbolinks_to '/path', status: 303
  end
end

class RedirectionTest < ActionController::TestCase
  tests RedirectController

  def test_redirect_via_turbolinks_to_url_string
    get :redirect_via_turbolinks_to_url_string
    assert_turbolinks_visit 'http://example.com'
  end

  def test_redirect_via_turbolinks_to_url_hash
    get :redirect_via_turbolinks_to_url_hash
    assert_turbolinks_visit 'http://test.host/redirect/action'
  end

  def test_redirect_via_turbolinks_to_path_and_custom_status
    get :redirect_via_turbolinks_to_path_and_custom_status
    assert_turbolinks_visit 'http://test.host/path'
  end

  private

  def assert_turbolinks_visit(url)
    assert_response 200
    assert_equal "Turbolinks.visit('#{url}');", @response.body
    assert_equal 'text/javascript', @response.content_type
  end
end

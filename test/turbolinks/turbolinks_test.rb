require_relative 'test_helper'

class TurbolinksController < TestController
  def simple_action
    render text: ' '
  end

  def redirect_to_same_origin
    redirect_to "#{request.protocol}#{request.host}/path"
  end

  def redirect_to_different_host
    redirect_to "#{request.protocol}foo.#{request.host}/path"
  end

  def redirect_to_different_protocol
    redirect_to "#{request.protocol == 'http://' ? 'https://' : 'http://'}#{request.host}/path"
  end

  def redirect_to_back
    redirect_to :back
  end

  def redirect_to_unescaped_path
    redirect_to "#{request.protocol}#{request.host}/foo bar"
  end
end

class TurbolinksTest < ActionController::TestCase
  tests TurbolinksController

  def test_request_referer_returns_xhr_referer_or_standard_referer
    @request.env['HTTP_REFERER'] = 'referer'
    assert_equal 'referer', @request.referer

    @request.env['HTTP_X_XHR_REFERER'] = 'xhr-referer'
    assert_equal 'xhr-referer', @request.referer
  end

  def test_url_for_with_back_uses_xhr_referer_when_available
    @request.env['HTTP_REFERER'] = 'referer'
    assert_equal 'referer', @controller.view_context.url_for(:back)

    @request.env['HTTP_X_XHR_REFERER'] = 'xhr-referer'
    assert_equal 'xhr-referer', @controller.view_context.url_for(:back)
  end

  def test_redirect_to_back_uses_xhr_referer_when_available
    @request.env['HTTP_REFERER'] = 'http://test.host/referer'
    get :redirect_to_back
    assert_redirected_to 'http://test.host/referer'

    @request.env['HTTP_X_XHR_REFERER'] = 'http://test.host/xhr-referer'
    get :redirect_to_back
    assert_redirected_to 'http://test.host/xhr-referer'
  end

  def test_sets_request_method_cookie_on_non_get_requests
    post :simple_action
    assert_equal 'POST', cookies[:request_method]
    put :simple_action
    assert_equal 'PUT', cookies[:request_method]
  end

  def test_pops_request_method_cookie_on_get_request
    cookies[:request_method] = 'TEST'
    get :simple_action
    assert_nil cookies[:request_method]
  end

  def test_sets_xhr_redirected_to_header_on_redirect_requests_coming_from_turbolinks
    get :redirect_to_same_origin
    get :simple_action
    assert_nil @response.headers['X-XHR-Redirected-To']

    @request.env['HTTP_X_XHR_REFERER'] = 'http://test.host/'
    get :redirect_to_same_origin
    @request.env['HTTP_X_XHR_REFERER'] = nil
    get :simple_action
    assert_equal 'http://test.host/path', @response.headers['X-XHR-Redirected-To']
  end

  def test_changes_status_to_403_on_turbolinks_requests_redirecting_to_different_origin
    get :redirect_to_different_host
    assert_response :redirect

    get :redirect_to_different_protocol
    assert_response :redirect

    @request.env['HTTP_X_XHR_REFERER'] = 'http://test.host'

    get :redirect_to_different_host
    assert_response :forbidden

    get :redirect_to_different_protocol
    assert_response :forbidden

    get :redirect_to_same_origin
    assert_response :redirect
  end

  def test_handles_invalid_xhr_referer_on_redirection
    @request.env['HTTP_X_XHR_REFERER'] = ':'
    get :redirect_to_same_origin
    assert_response :redirect
  end

  def test_handles_unescaped_same_origin_location_on_redirection
    @request.env['HTTP_X_XHR_REFERER'] = 'http://test.host/'
    get :redirect_to_unescaped_path
    assert_response :redirect
  end

  def test_handles_unescaped_different_origin_location_on_redirection
    @request.env['HTTP_X_XHR_REFERER'] = 'https://test.host/'
    get :redirect_to_unescaped_path
    assert_response :forbidden
  end
end

class TurbolinksIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @session = open_session
  end

  def test_sets_xhr_redirected_to_header_on_redirect_requests_coming_from_turbolinks
    get '/redirect_hash'
    get response.location
    assert_nil response.headers['X-XHR-Redirected-To']

    get '/redirect_hash', nil, { 'HTTP_X_XHR_REFERER' => 'http://www.example.com/' }
    assert_response :redirect
    assert_nil response.headers['X-XHR-Redirected-To']

    get response.location, nil, { 'HTTP_X_XHR_REFERER' => nil }
    assert_equal 'http://www.example.com/turbolinks/simple_action', response.headers['X-XHR-Redirected-To']
    assert_response :ok

    get '/redirect_path', nil, { 'HTTP_X_XHR_REFERER' => 'http://www.example.com/' }
    assert_response :redirect
    assert_nil response.headers['X-XHR-Redirected-To']

    get response.location, nil, { 'HTTP_X_XHR_REFERER' => nil }
    assert_equal 'http://www.example.com/turbolinks/simple_action', response.headers['X-XHR-Redirected-To']
    assert_response :ok
  end
end

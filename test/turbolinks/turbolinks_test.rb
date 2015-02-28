require_relative 'test_helper'

class TurbolinksController < ActionController::Base
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
end

class TurbolinksTest < ActionController::TestCase
  tests TurbolinksController

  def test_request_referer_returns_xhr_referer_or_standard_referer
    @request.headers['Referer'] = 'referer'
    assert_equal 'referer', @request.referer

    @request.headers['X-XHR-Referer'] = 'xhr-referer'
    assert_equal 'xhr-referer', @request.referer
  end

  def test_url_for_with_back_uses_xhr_referer_when_available
    @request.headers['Referer'] = 'referer'
    assert_equal 'referer', @controller.view_context.url_for(:back)

    @request.headers['X-XHR-Referer'] = 'xhr-referer'
    assert_equal 'xhr-referer', @controller.view_context.url_for(:back)
  end

  def test_redirect_to_back_uses_xhr_referer_when_available
    @request.headers['Referer'] = 'http://test.host/referer'
    get :redirect_to_back
    assert_redirected_to 'http://test.host/referer'

    @request.headers['X-XHR-Referer'] = 'http://test.host/xhr-referer'
    get :redirect_to_back
    assert_redirected_to 'http://test.host/xhr-referer'
  end

  def test_sets_request_method_cookie_on_non_get_requests
    post :simple_action
    assert_equal 'POST', cookies[:request_method]
    patch :simple_action
    assert_equal 'PATCH', cookies[:request_method]
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

    @request.headers['X-XHR-Referer'] = 'http://test.host/'
    get :redirect_to_same_origin
    @request.headers['X-XHR-Referer'] = nil
    get :simple_action
    assert_equal 'http://test.host/path', @response.headers['X-XHR-Redirected-To']
  end

  def test_changes_status_to_403_on_turbolinks_requests_redirecting_to_different_origin
    get :redirect_to_different_host
    assert_response :redirect

    get :redirect_to_different_protocol
    assert_response :redirect

    @request.headers['X-XHR-Referer'] = 'http://test.host'

    get :redirect_to_different_host
    assert_response :forbidden

    get :redirect_to_different_protocol
    assert_response :forbidden

    get :redirect_to_same_origin
    assert_response :redirect
  end
end

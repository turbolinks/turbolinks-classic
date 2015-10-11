require_relative 'test_helper'

class RenderController < TestController
  require 'action_view/testing/resolvers'
  self.view_paths = ActionView::FixtureResolver.new('render/action.html.erb' => 'content')

  def simple_render
    render text: 'content'
  end

  def render_action
    render :action
  end

  def simple_render_with_turbolinks
    render text: 'content', turbolinks: true
  end

  def render_action_with_turbolinks_false
    render :action, turbolinks: false
  end

  def render_unsafe_string_with_turbolinks
    render text: "'\">\n\\<\"'", turbolinks: true
  end

  def render_unsafe_string_with_turbolinks_false
    render text: "'\">\n\\<\"'", turbolinks: false
  end

  def render_with_single_change_option
    render text: 'content', change: 'foo'
  end

  def render_with_multiple_change_option
    render :action, change: ['foo', :bar]
  end

  def render_with_single_keep_option
    render action: :action, keep: 'foo'
  end

  def render_with_multiple_keep_option
    render :action, keep: ['foo', :bar]
  end

  def render_with_flush_true
    render :action, flush: true
  end

  def render_with_flush_false
    render action: :action, flush: false
  end
end

class RenderTest < ActionController::TestCase
  tests RenderController

  def test_simple_render_via_get
    get :simple_render
    assert_normal_render 'content'
  end

  def test_simple_render_via_xhr_and_post
    @request.env['HTTP_ACCEPT'] = Mime[:html]
    xhr :post, :simple_render
    assert_normal_render 'content'
  end

  def test_render_action_via_post
    post :render_action
    assert_normal_render 'content'
  end

  def test_render_action_via_xhr_and_put
    @request.env['HTTP_ACCEPT'] = Mime[:html]
    xhr :put, :render_action
    assert_normal_render 'content'
  end

  def test_simple_render_with_turbolinks
    get :simple_render_with_turbolinks
    assert_turbolinks_replace 'content'
  end

  def test_render_action_via_xhr_and_post_with_turbolinks_false
    xhr :post, :render_action_with_turbolinks_false
    assert_normal_render 'content'
  end

  def test_render_unsafe_string_with_turbolinks
    get :render_unsafe_string_with_turbolinks
    assert_turbolinks_replace "\\'\\\">\\n\\\\<\\\"\\'"
  end

  def test_render_unsafe_string_with_turbolinks_false
    get :render_unsafe_string_with_turbolinks_false
    assert_normal_render "'\">\n\\<\"'"
  end

  def test_render_via_xhr_and_post_with_single_change_option_renders_via_turbolinks
    xhr :post, :render_with_single_change_option
    assert_turbolinks_replace 'content', "{ change: ['foo'] }"
  end

  def test_render_via_xhr_and_put_with_multiple_change_option_renders_via_turbolinks
    xhr :put, :render_with_multiple_change_option
    assert_turbolinks_replace 'content', "{ change: ['foo', 'bar'] }"
  end

  def test_render_via_xhr_and_put_with_single_keep_option_renders_via_turbolinks
    xhr :put, :render_with_single_keep_option
    assert_turbolinks_replace 'content', "{ keep: ['foo'] }"
  end

  def test_render_via_xhr_and_delete_with_multiple_keep_option_renders_via_turbolinks
    xhr :delete, :render_with_multiple_keep_option
    assert_turbolinks_replace 'content', "{ keep: ['foo', 'bar'] }"
  end

  def test_simple_render_via_xhr_and_get_does_normal_render
    @request.env['HTTP_ACCEPT'] = Mime[:html]
    xhr :get, :simple_render
    assert_normal_render 'content'
  end

  def test_render_via_xhr_and_get_with_change_option_renders_via_turbolinks
    @request.env['HTTP_ACCEPT'] = Mime[:html]
    xhr :get, :render_with_single_change_option
    assert_turbolinks_replace 'content', "{ change: ['foo'] }"
  end

  def test_render_via_post_and_not_xhr_with_keep_option_does_normal_render
    post :render_with_multiple_keep_option
    assert_normal_render 'content'
  end

  def test_render_with_change_and_keep_raises_argument_error
    assert_raises ArgumentError do
      @controller.render :action, change: :foo, keep: :bar
    end

    assert_raises ArgumentError do
      @controller.render action: :action, change: :foo, keep: :bar
    end
  end

  def test_render_via_xhr_and_post_with_flush_true_renders_via_turbolinks
    xhr :post, :render_with_flush_true
    assert_turbolinks_replace 'content', "{ flush: true }"
  end

  def test_render_via_get_and_not_xhr_with_flush_true_does_normal_render
    get :render_with_flush_true
    assert_normal_render 'content'
  end

  def test_render_via_xhr_and_post_with_flush_false_renders_via_turbolinks
    xhr :post, :render_with_flush_false
    assert_turbolinks_replace 'content'
  end

  def test_render_with_change_and_flush_raises_argument_error
    assert_raises ArgumentError do
      @controller.render :action, change: :foo, flush: true
    end

    assert_raises ArgumentError do
      @controller.render action: :action, change: :foo, flush: true
    end
  end

  def test_render_with_keep_and_flush_raises_argument_error
    assert_raises ArgumentError do
      @controller.render :action, keep: :foo, flush: true
    end

    assert_raises ArgumentError do
      @controller.render action: :action, keep: :foo, flush: true
    end
  end

  def test_render_without_turbolinks_returns_response_body
    @controller.response = @response
    result = @controller.render(text: 'test', turbolinks: false)
    assert_equal ['test'], result
  end

  def test_render_with_turbolinks_returns_response_body
    @controller.response = @response
    result = @controller.render(text: 'test', turbolinks: true)
    assert_equal ["Turbolinks.replace('test');"], result
  end

  private

  def assert_normal_render(content)
    assert_response 200
    assert_equal content, @response.body
    assert_equal 'text/html', @response.content_type
  end

  def assert_turbolinks_replace(content, change = nil)
    change = ", #{change}" if change
    assert_response 200
    assert_equal "Turbolinks.replace('#{content}'#{change});", @response.body
    assert_equal 'text/javascript', @response.content_type
  end
end

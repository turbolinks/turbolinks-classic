require_relative 'test_helper'

class RenderController < ActionController::Base
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
end

class RenderTest < ActionController::TestCase
  tests RenderController

  def test_simple_render_via_get
    get :simple_render
    assert_normal_render 'content'
  end

  def test_simple_render_via_xhr_and_post
    @request.env['HTTP_ACCEPT'] = Mime::HTML
    xhr :post, :simple_render
    assert_normal_render 'content'
  end

  def test_render_action_via_post
    post :render_action
    assert_normal_render 'content'
  end

  def test_render_action_via_xhr_and_patch
    @request.env['HTTP_ACCEPT'] = Mime::HTML
    xhr :patch, :render_action
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

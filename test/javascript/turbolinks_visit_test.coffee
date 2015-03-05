assert = chai.assert

suite 'Turbolinks.visit()', ->
  setup (done) ->
    @iframe = document.createElement('iframe')
    @iframe.style.display = 'none'
    @iframe.setAttribute('src', 'iframe.html')
    document.body.appendChild(@iframe)
    @iframe.onload = =>
      @window = @iframe.contentWindow
      @document = @window.document
      @Turbolinks = @window.Turbolinks
      @location = @window.location
      @history = @window.history
      @$ = (selector) => @document.querySelector(selector)
      done()

  teardown ->
    document.body.removeChild(@iframe)

  test "successful", (done) ->
    body = @$('body')
    permanent = @$('#permanent')
    pageReceivedFired = beforeUnloadFired = false
    @document.addEventListener 'page:receive', =>
      state = turbolinks: true, url: 'http://localhost:9292/javascript/iframe.html'
      assert.deepEqual @history.state, state
      pageReceivedFired = true
    @document.addEventListener 'page:before-unload', =>
      assert.notOk @window.bodyScript
      assert.notOk @$('#new-div')
      assert.notOk @$('body').hasAttribute('new-attribute')
      assert.ok @$('#div')
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token'
      assert.equal @document.title, 'title'
      assert.equal @$('body'), body
      beforeUnloadFired = true
    @document.addEventListener 'page:load', =>
      assert.ok pageReceivedFired
      assert.ok beforeUnloadFired
      assert.ok @window.bodyScript
      assert.notOk @window.headScript
      assert.notOk @window.bodyScriptEvalFalse
      assert.ok @$('#new-div')
      assert.ok @$('body').hasAttribute('new-attribute')
      assert.notOk @$('#div')
      assert.equal @$('#permanent').textContent, 'permanent content'
      assert.equal @$('#temporary').textContent, 'temporary content 2'
      assert.equal @document.title, 'title 2'
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token2'
      assert.notEqual @$('#permanent'), permanent # permanent nodes are cloned
      assert.notEqual @$('body'), body # body is replaced

      state = turbolinks: true, url: 'http://localhost:9292/javascript/iframe2.html'
      assert.deepEqual @history.state, state
      assert.equal @location.href, state.url
      done()
    @Turbolinks.visit('iframe2.html')

  test "successful with :change", (done) ->
    body = @$('body')
    change = @$('#change')
    beforeUnloadFired = false
    @document.addEventListener 'page:before-unload', =>
      assert.equal @$('#change').textContent, 'change content'
      assert.equal @$('[id="change:key"]').textContent, 'change content'
      assert.equal @$('#temporary').textContent, 'temporary content'
      assert.equal @document.title, 'title'
      beforeUnloadFired = true
    @document.addEventListener 'page:load', =>
      assert.ok beforeUnloadFired
      assert.notOk @window.bodyScript
      assert.notOk @window.headScript
      assert.notOk @$('#new-div')
      assert.notOk @$('body').hasAttribute('new-attribute')
      assert.equal @$('#change').textContent, 'change content 2'
      assert.equal @$('[id="change:key"]').textContent, 'change content 2'
      assert.equal @$('#temporary').textContent, 'temporary content 2'
      assert.equal @$('#div').textContent, 'div content'
      assert.equal @$('#permanent').textContent, 'permanent content'
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token'
      assert.equal @document.title, 'title 2'
      assert.notEqual @$('#change'), change # changed nodes are cloned
      assert.equal @$('body'), body
      assert.equal @location.href, 'http://localhost:9292/javascript/iframe2.html'
      done()
    @Turbolinks.visit('iframe2.html', change: ['change'])

  test "error fallback", (done) ->
    unloadFired = false
    @window.addEventListener 'unload', =>
      unloadFired = true
      setTimeout =>
        assert.equal @iframe.contentWindow.location.href, 'http://localhost:9292/javascript/404'
        done()
      , 0
    @Turbolinks.visit('404')

  test "without transition cache", (done) ->
    load = 0
    restoreCalled = false
    @document.addEventListener 'page:load', =>
      load += 1
      if load is 1
        assert.equal @document.title, 'title 2'
        setTimeout (=> @Turbolinks.visit('iframe.html')), 0
      else if load is 2
        assert.notOk restoreCalled
        assert.equal @document.title, 'title'
        done()
    @document.addEventListener 'page:restore', =>
      restoreCalled = true
    @Turbolinks.visit('iframe2.html')

  test "with transition cache", (done) ->
    load = 0
    restoreCalled = false
    @document.addEventListener 'page:load', =>
      load += 1
      if load is 1
        assert.equal @document.title, 'title 2'
        setTimeout (=> @Turbolinks.visit('iframe.html')), 0
      else if load is 2
        assert.ok restoreCalled
        assert.equal @document.title, 'title'
        done()
    @document.addEventListener 'page:restore', =>
      assert.equal load, 1
      assert.equal @document.title, 'title'
      restoreCalled = true
    @Turbolinks.enableTransitionCache()
    @Turbolinks.visit('iframe2.html')

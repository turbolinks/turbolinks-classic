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
    permanent.addEventListener 'click', -> done()
    pageReceivedFired = beforeUnloadFired = afterRemoveFired = false
    @document.addEventListener 'page:receive', =>
      state = turbolinks: true, url: "#{location.origin}/javascript/iframe.html"
      assert.deepEqual @history.state, state
      pageReceivedFired = true
    @document.addEventListener 'page:before-unload', =>
      assert.isUndefined @window.j
      assert.notOk @$('#new-div')
      assert.notOk @$('body').hasAttribute('new-attribute')
      assert.ok @$('#div')
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token'
      assert.equal @document.title, 'title'
      assert.equal @$('body'), body
      beforeUnloadFired = true
    @document.addEventListener 'page:after-remove', (event) =>
      assert.isNull event.data.parentNode
      assert.equal event.data, body
      assert.notEqual permanent, event.data.querySelector('#permanent')
      afterRemoveFired = true
    @document.addEventListener 'page:load', =>
      assert.ok pageReceivedFired
      assert.ok beforeUnloadFired
      assert.ok afterRemoveFired
      assert.equal @window.i, 1
      assert.equal @window.j, 1
      assert.isUndefined @window.headScript
      assert.isUndefined @window.bodyScriptEvalFalse
      assert.ok @$('#new-div')
      assert.ok @$('body').hasAttribute('new-attribute')
      assert.notOk @$('#div')
      assert.equal @$('#permanent').textContent, 'permanent content'
      assert.equal @$('#temporary').textContent, 'temporary content 2'
      assert.equal @document.title, 'title 2'
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token2'
      assert.notEqual @$('body'), body # body is replaced

      state = turbolinks: true, url: "#{location.origin}/javascript/iframe2.html"
      assert.deepEqual @history.state, state
      assert.equal @location.href, state.url

      assert.equal @$('#permanent'), permanent # permanent nodes are transferred
      @$('#permanent').click() # event listeners on permanent nodes should not be lost
    @Turbolinks.visit('iframe2.html')

  test "successful with :change", (done) ->
    body = @$('body')
    change = @$('#change')
    temporary = @$('#temporary')
    beforeUnloadFired = false
    @document.addEventListener 'page:before-unload', =>
      assert.equal @window.i, 1
      assert.equal @$('#change').textContent, 'change content'
      assert.equal @$('[id="change:key"]').textContent, 'change content'
      assert.equal @$('#temporary').textContent, 'temporary content'
      assert.equal @document.title, 'title'
      beforeUnloadFired = true
    @document.addEventListener 'page:load', =>
      assert.ok beforeUnloadFired
      assert.equal @window.i, 2
      assert.isUndefined @window.j
      assert.isUndefined @window.headScript
      assert.isUndefined @window.bodyScriptEvalFalse
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
      assert.notEqual @$('#temporary'), temporary # temporary nodes are cloned
      assert.equal @$('body'), body
      assert.equal @location.href, "#{location.origin}/javascript/iframe2.html"
      done()
    @Turbolinks.visit('iframe2.html', change: ['change'])

  test "error fallback", (done) ->
    unloadFired = false
    @window.addEventListener 'unload', =>
      unloadFired = true
      setTimeout =>
        assert.equal @iframe.contentWindow.location.href, "#{location.origin}/javascript/404"
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
        assert.equal @window.i, 2
        assert.equal @document.title, 'title'
        done()
    @document.addEventListener 'page:restore', =>
      restoreCalled = true
    @Turbolinks.visit('iframe2.html')

  test "with transition cache", (done) ->
    permanent = @$('#permanent')
    permanent.addEventListener 'click', -> done()
    load = 0
    restoreCalled = false
    @document.addEventListener 'page:load', =>
      load += 1
      if load is 1
        assert.ok @$('body').hasAttribute('new-attribute')
        assert.equal @document.title, 'title 2'
        assert.equal @$('#permanent'), permanent
        setTimeout (=> @Turbolinks.visit('iframe.html')), 0
      else if load is 2
        assert.ok restoreCalled
        assert.equal @window.i, 2
        assert.equal @document.title, 'title'
        assert.equal @$('#permanent'), permanent
        @$('#permanent').click() # event listeners on permanent nodes should not be lost
    @document.addEventListener 'page:restore', =>
      assert.equal load, 1
      assert.equal @window.i, 1
      assert.notOk @$('body').hasAttribute('new-attribute')
      assert.equal @document.title, 'title'
      assert.equal @$('#permanent'), permanent
      restoreCalled = true
    @Turbolinks.enableTransitionCache()
    @Turbolinks.visit('iframe2.html')

  test "history.back() cache hit", (done) ->
    @$('#permanent').addEventListener 'click', -> done()
    change = 0
    fetchCalled = false
    @document.addEventListener 'page:change', =>
      change += 1
      if change is 1
        @document.addEventListener 'page:fetch', -> fetchCalled = true
        assert.equal @window.i, 1
        assert.equal @window.j, 1
        assert.equal @document.title, 'title 2'
        assert.notOk @document.querySelector('#div')
        setTimeout =>
          @history.back()
        , 0
      else if change is 2
        assert.notOk fetchCalled
        assert.equal @window.i, 1
        assert.equal @window.j, 1
        assert.equal @document.title, 'title'
        assert.notOk @document.querySelector('#new-div')
        @document.querySelector('#permanent').click()
    @Turbolinks.visit('iframe2.html')

  test "history.back() cache miss", (done) ->
    @$('#permanent').addEventListener 'click', -> done()
    change = 0
    @document.addEventListener 'page:change', =>
      change += 1
      if change is 1
        assert.equal @window.i, 1
        assert.equal @window.j, 1
        assert.equal @document.title, 'title 2'
        assert.notOk @document.querySelector('#div')
        setTimeout =>
          @history.back()
        , 0
      else if change is 2
        assert.equal @window.i, 2
        assert.equal @window.j, 1
        assert.equal @document.title, 'title'
        assert.notOk @document.querySelector('#new-div')
        @window.document.querySelector('#permanent').click()
    @Turbolinks.pagesCached(0)
    @Turbolinks.visit('iframe2.html')

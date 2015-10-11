assert = chai.assert

suite 'Turbolinks.visit()', ->
  setup (done) ->
    @iframe = document.createElement('iframe')
    @iframe.setAttribute('scrolling', 'yes')
    @iframe.setAttribute('style', 'visibility: hidden;')
    @iframe.setAttribute('src', 'iframe.html')
    document.body.appendChild(@iframe)
    @iframe.onload = =>
      @iframe.onload = null
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
    beforeChangeFired = pageReceivedFired = beforeUnloadFired = afterRemoveFired = pageChangeFired = partialLoadFired = false
    @document.addEventListener 'page:before-change', =>
      beforeChangeFired = true
    @document.addEventListener 'page:receive', =>
      state = turbolinks: true, url: "#{location.protocol}//#{location.host}/javascript/iframe.html"
      assert.deepEqual @history.state, state
      assert.ok beforeChangeFired
      pageReceivedFired = true
    @document.addEventListener 'page:before-unload', (event) =>
      assert.isUndefined @window.j
      assert.deepEqual event.data, [body]
      assert.notOk @$('#new-div')
      assert.notOk @$('body').hasAttribute('new-attribute')
      assert.ok @$('#div')
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token'
      assert.equal @document.title, 'title'
      assert.equal @$('body'), body
      beforeUnloadFired = true
    @document.addEventListener 'page:after-remove', (event) =>
      afterRemoveFired = true
    @document.addEventListener 'page:change', (event) =>
      assert.deepEqual event.data, [@document.body]
      pageChangeFired = true
    @document.addEventListener 'page:partial-load', (event) =>
      partialLoadFired = true
    @document.addEventListener 'page:load', (event) =>
      assert.ok pageReceivedFired
      assert.ok beforeUnloadFired
      assert.notOk afterRemoveFired # after-remove isn't called until body is evicted from cache
      assert.ok pageChangeFired
      assert.deepEqual event.data, [@document.body]
      assert.equal @window.i, 1
      assert.equal @window.j, 1
      assert.equal @window.countPerm, 1
      assert.equal @window.countAlways, 1
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

      state = turbolinks: true, url: "#{location.protocol}//#{location.host}/javascript/iframe2.html"
      assert.deepEqual @history.state, state
      assert.equal @location.href, state.url

      assert.equal @$('#permanent'), permanent # permanent nodes are transferred
      setTimeout =>
        assert.notOk partialLoadFired
        @$('#permanent').click() # event listeners on permanent nodes should not be lost
      , 0
    @Turbolinks.visit('iframe2.html')

  test "successful with :change", (done) ->
    body = @$('body')
    change = @$('#change')
    change2 = @$('[id="change:key"]')
    temporary = @$('#temporary')
    beforeUnloadFired = pageChangeFired = loadFired = false
    @document.addEventListener 'page:before-unload', (event) =>
      assert.deepEqual event.data, [temporary, change, change2]
      assert.equal @window.i, 1
      assert.equal @$('#change').textContent, 'change content'
      assert.equal @$('[id="change:key"]').textContent, 'change content'
      assert.equal @$('#temporary').textContent, 'temporary content'
      assert.equal @document.title, 'title'
      beforeUnloadFired = true
    afterRemoveNodes = [temporary, change, change2]
    @document.addEventListener 'page:after-remove', (event) =>
      assert.isNull event.data.parentNode
      assert.equal event.data, afterRemoveNodes.shift()
    @document.addEventListener 'page:change', (event) =>
      assert.deepEqual event.data, [@$('#temporary'), @$('#change'), @$('[id="change:key"]')]
      pageChangeFired = true
    @document.addEventListener 'page:load', (event) =>
      loadFired = true
    @document.addEventListener 'page:partial-load', (event) =>
      assert.ok beforeUnloadFired
      assert.ok pageChangeFired
      assert.equal afterRemoveNodes.length, 0 # after-remove is called immediately on changed nodes
      assert.deepEqual event.data, [@$('#temporary'), @$('#change'), @$('[id="change:key"]')]
      assert.equal @window.i, 1 # only scripts within the changed nodes are re-run
      assert.equal @window.countPerm, 1
      assert.equal @window.countAlways, 2
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
      assert.equal @location.href, "#{location.protocol}//#{location.host}/javascript/iframe2.html"
      setTimeout =>
        assert.notOk loadFired
        done()
      , 0
    @Turbolinks.visit('iframe2.html', change: ['change'])

  test "error fallback", (done) ->
    unloadFired = false
    @window.addEventListener 'unload', =>
      unloadFired = true
      setTimeout =>
        try
          assert.equal @iframe.contentWindow.location.href, "#{location.protocol}//#{location.host}/404"
        catch e
          throw e unless /denied/.test(e.message) # IE
        done()
      , 0
    @Turbolinks.visit('/404')

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
    @$('#div').foo = 'bar'
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
        assert.equal @history.length, @historyLengthOnRestore
        @$('#permanent').click() # event listeners on permanent nodes should not be lost
    @document.addEventListener 'page:restore', =>
      assert.equal load, 1
      assert.equal @window.i, 1
      assert.notOk @$('body').hasAttribute('new-attribute')
      assert.equal @document.title, 'title'
      assert.equal @$('#permanent'), permanent
      assert.equal @$('#div').foo, 'bar' # DOM state is restored
      assert.equal @window.location.pathname.substr(-11), 'iframe.html'
      @historyLengthOnRestore = @history.length
      restoreCalled = true
    @Turbolinks.enableTransitionCache()
    @Turbolinks.visit('iframe2.html')

  test "with same URL, skips transition cache", (done) ->
    restoreCalled = false
    @document.addEventListener 'page:restore', =>
      restoreCalled = true
    @document.addEventListener 'page:load', =>
      assert.notOk restoreCalled
      done()
    @Turbolinks.enableTransitionCache()
    @Turbolinks.visit('iframe.html')

  test "with :change, skips transition cache", (done) ->
    restoreCalled = false
    @document.addEventListener 'page:restore', =>
      restoreCalled = true
    @document.addEventListener 'page:partial-load', =>
      assert.notOk restoreCalled
      done()
    @Turbolinks.enableTransitionCache()
    @Turbolinks.visit('iframe.html', change: 'div')

  test "history.back() cache hit", (done) ->
    @$('#div').addEventListener 'click', -> done()
    change = 0
    fetchCalled = false
    @document.addEventListener 'page:change', =>
      change += 1
      if change is 1
        @document.addEventListener 'page:fetch', -> fetchCalled = true
        assert.equal @window.i, 1
        assert.equal @window.k, 1
        assert.equal @window.j, 1
        assert.equal @document.title, 'title 2'
        assert.notOk @document.querySelector('#div')
        setTimeout =>
          @history.back()
        , 0
      else if change is 2
        assert.notOk fetchCalled
        assert.equal @window.i, 1 # normal scripts are not re-run
        assert.equal @window.k, 2 # data-turbolinks-eval="always" scripts are re-run
        assert.equal @window.j, 1
        assert.equal @document.title, 'title'
        assert.notOk @document.querySelector('#new-div')
        @document.querySelector('#div').click() # event listeners should not be lost
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

  test "with :change, doesn't store page in cache", (done) ->
    @document.addEventListener 'page:partial-load', (event) =>
      assert.equal @$('#change').textContent, 'change content 2'
      setTimeout (=> @history.back()), 0
    @document.addEventListener 'page:load', (event) =>
      assert.equal @$('#change').textContent, 'change content'
      done()
    @Turbolinks.visit('iframe2.html', change: ['change'])

  test "with :change, removes previous page from cache", (done) ->
    @$('#change').foo = 'bar'
    load = 0
    @document.addEventListener 'page:partial-load', (event) =>
      load += 1
      if load is 2
        setTimeout (=> @Turbolinks.visit('iframe2.html', change: 'change:key')), 0
      else if load is 3
        setTimeout (=> @history.back()), 0
    @document.addEventListener 'page:load', (event) =>
      load += 1
      if load is 1
        setTimeout (=> @Turbolinks.visit('iframe.html', change: 'change:key')), 0
      else if load is 4
        assert.isUndefined @$('#change').foo
        done()
    @Turbolinks.visit('iframe2.html')

  test "with :keep, doesn't store page in cache", (done) ->
    @$('#change').foo = 'bar'
    load = 0
    @document.addEventListener 'page:load', (event) =>
      load += 1
      if load is 1
        assert.equal @$('#change').foo, 'bar'
        setTimeout (=> @history.back()), 0
      else if load is 2
        assert.isUndefined @$('#change').foo
        done()
    @Turbolinks.visit('iframe2.html', keep: ['change'])

  test "after-remove callback is called after load when body is evicted from cache", (done) ->
    load = 0
    body1 = @document.body
    body2 = null
    afterRemoveNodes = []
    @document.addEventListener 'page:after-remove', (event) =>
      assert.isNull event.data.parentNode
      afterRemoveNodes.push(event.data)
    @document.addEventListener 'page:load', =>
      load += 1
      if load is 1
        body2 = @document.body
        setTimeout =>
          assert.deepEqual afterRemoveNodes, []
          @Turbolinks.visit('iframe3.html')
        , 0
      else if load is 2
        setTimeout =>
          assert.deepEqual afterRemoveNodes, [body1]
          @Turbolinks.visit('iframe.html')
        , 0
      else if load is 3
        setTimeout =>
          assert.deepEqual afterRemoveNodes, [body1, body2]
          done()
        , 0
    @Turbolinks.pagesCached(1)
    @Turbolinks.visit('iframe2.html')

  test "jquery cleanup", (done) ->
    body = @document.body
    @window.jQuery(body).on 'click', ->
      done new Error("jQuery event wasn't cleaned up")
      done = null
    @document.addEventListener 'page:load', ->
      setTimeout =>
        body.click()
        setTimeout (-> done?()), 0
      , 0
    @Turbolinks.pagesCached(0)
    @Turbolinks.visit('iframe2.html')

  test "with :title set to a value replaces the title with the value", (done) ->
    @document.addEventListener 'page:load', =>
      assert.equal @document.title, 'specified title'
      done()
    @Turbolinks.visit('iframe2.html', title: 'specified title')

  test "with :title set to false doesn't replace the title", (done) ->
    @document.title = 'test'
    @document.addEventListener 'page:load', =>
      assert.equal @document.title, 'test'
      done()
    @Turbolinks.visit('iframe2.html', title: false)

  test "with different-origin URL, forces a normal redirection", (done) ->
    @window.addEventListener 'unload', ->
      done()
    @Turbolinks.visit("http://example.com")

  test "calling preventDefault on the before-change event cancels the visit", (done) ->
    @document.addEventListener 'page:before-change', (event) ->
      event.preventDefault()
      setTimeout (-> done?()), 0
    @document.addEventListener 'page:fetch', =>
      done new Error("visit wasn't cancelled")
      done = null
    @Turbolinks.visit('iframe2.html')

  test "doesn't pushState when URL is the same", (done) ->
    load = 0
    @document.addEventListener 'page:load', =>
      load += 1
      if load is 1
        assert.equal @history.length, @originalHistoryLength
        setTimeout (=> @Turbolinks.visit('iframe.html#test')), 0
      else if load is 2
        assert.equal @history.length, @originalHistoryLength + 1
        done()
    @originalHistoryLength = @history.length
    @Turbolinks.visit('iframe.html')

  test "with #anchor and history.back()", (done) ->
    hashchange = 0
    @window.addEventListener 'hashchange', =>
      hashchange += 1
    @document.addEventListener 'page:load', =>
      assert.equal hashchange, 1
      setTimeout (=> @history.back()), 0
    @document.addEventListener 'page:restore', =>
      assert.equal hashchange, 1
      done()
    @location.href = "#{@location.href}#change"
    setTimeout (=> @Turbolinks.visit('iframe2.html#permanent')), 0

  # Temporary until mocha fixes skip() in async tests or PhantomJS fixes scrolling inside iframes.
  return if navigator.userAgent.indexOf('PhantomJS') != -1

  test "scrolls to target or top by default", (done) ->
    @window.scrollTo(42, 42)
    assert.equal @window.pageXOffset, 42
    assert.equal @window.pageYOffset, 42
    load = 0
    @document.addEventListener 'page:load', =>
      load += 1
      if load is 1
        assert.closeTo @window.pageYOffset, @$('#change').offsetTop, 100
        setTimeout (=> @Turbolinks.visit('iframe.html', scroll: null)), 0
      else if load is 2
        assert.equal @window.pageXOffset, 0
        assert.equal @window.pageYOffset, 0
        done()
    @Turbolinks.visit('iframe2.html#change', scroll: undefined)

  test "restores scroll position on history.back() cache hit", (done) ->
    change = 0
    @document.addEventListener 'page:change', =>
      change += 1
      if change is 1
        setTimeout (=> @history.back()), 0
    @document.addEventListener 'page:restore', =>
      assert.equal change, 2
      assert.equal @window.pageXOffset, 42
      assert.equal @window.pageYOffset, 42
      done()
    @window.scrollTo(42, 42)
    @Turbolinks.visit('iframe2.html')

  test "doesn't restore scroll position on history.back() cache miss", (done) ->
    load = 0
    @document.addEventListener 'page:load', =>
      load += 1
      assert.equal @window.pageXOffset, 0
      assert.equal @window.pageYOffset, 0
      if load is 1
        setTimeout (=> @history.back()), 0
      else if load is 2
        done()
    @window.scrollTo(42, 42)
    @Turbolinks.pagesCached(0)
    @Turbolinks.visit('iframe2.html')

  test "scrolls to top on transition cache hit", (done) ->
    load = 0
    restoreCalled = false
    @document.addEventListener 'page:load', =>
      load += 1
      if load is 1
        @window.scrollTo(8, 8)
        setTimeout (=> @Turbolinks.visit('iframe.html')), 0
      else if load is 2
        assert.ok restoreCalled
        assert.equal @window.pageXOffset, 16
        assert.equal @window.pageYOffset, 16
        done()
    @document.addEventListener 'page:restore', =>
      assert.equal @window.pageXOffset, 0
      assert.equal @window.pageYOffset, 0
      @window.scrollTo(16, 16)
      restoreCalled = true
    @window.scrollTo(4, 4)
    @Turbolinks.enableTransitionCache()
    @Turbolinks.visit('iframe2.html')

  test "scroll to #anchor with :change", (done) ->
    @document.addEventListener 'page:partial-load', =>
      assert.closeTo @window.pageYOffset, @$('#change').offsetTop, 100
      done()
    @Turbolinks.visit('iframe2.html#change', change: ['change'])

  test "doesn't scroll to top with :change", (done) ->
    @window.scrollTo(42, 42)
    @document.addEventListener 'page:partial-load', =>
      assert.equal @window.pageXOffset, 42
      assert.equal @window.pageYOffset, 42
      done()
    @Turbolinks.visit('iframe2.html', change: ['change'])

  test "doesn't scroll to top with scroll: false", (done) ->
    @window.scrollTo(42, 42)
    @document.addEventListener 'page:load', =>
      assert.equal @window.pageXOffset, 42
      assert.equal @window.pageYOffset, 42
      done()
    @Turbolinks.visit('iframe2.html', scroll: false)

assert = chai.assert

suite 'Turbolinks.replace()', ->
  setup (done) ->
    @iframe = document.createElement('iframe')
    @iframe.style.display = 'none'
    @iframe.setAttribute('src', 'iframe.html')
    document.body.appendChild(@iframe)
    @iframe.onload = =>
      @window = @iframe.contentWindow
      @document = @window.document
      @Turbolinks = @window.Turbolinks
      @$ = (selector) => @document.querySelector(selector)
      done()

  teardown ->
    document.body.removeChild(@iframe)

  test "default", (done) ->
    doc = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>new title</title>
        <meta content="new-token" name="csrf-token">
        <script>var headScript = true</script>
      </head>
      <body new-attribute>
        <div id="new-div"></div>
        <div id="permanent" data-turbolinks-permanent>new content</div>
        <div id="temporary" data-turbolinks-temporary>new content</div>
        <script>var bodyScript = true</script>
        <script data-turbolinks-eval="false">var bodyScriptEvalFalse = true</script>
      </body>
      </html>
    """
    body = @$('body')
    permanent = @$('#permanent')
    beforeUnloadFired = false
    @document.addEventListener 'page:before-unload', =>
      assert.notOk @window.bodyScript
      assert.notOk @$('#new-div')
      assert.notOk @$('body').hasAttribute('new-attribute')
      assert.ok @$('#div')
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token'
      assert.equal @document.title, 'title'
      assert.equal @$('body'), body
      beforeUnloadFired = true
    @document.addEventListener 'page:change', =>
      assert.ok beforeUnloadFired
      assert.ok @window.bodyScript
      assert.notOk @window.headScript
      assert.notOk @window.bodyScriptEvalFalse
      assert.ok @$('#new-div')
      assert.ok @$('body').hasAttribute('new-attribute')
      assert.notOk @$('#div')
      assert.equal @$('#permanent').textContent, 'permanent content'
      assert.equal @document.title, 'new title'
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'new-token'
      assert.notEqual @$('#permanent'), permanent # permanent nodes are cloned
      assert.notEqual @$('body'), body # body is replaced
      done()
    @Turbolinks.replace(doc)

  test "with :flush", (done) ->
    doc = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title></title>
      </head>
      <body>
        <div id="permanent" data-turbolinks-permanent>new content</div>
      </body>
      </html>
    """
    beforeUnloadFired = false
    @document.addEventListener 'page:before-unload', =>
      assert.equal @$('#permanent').textContent, 'permanent content'
      beforeUnloadFired = true
    @document.addEventListener 'page:change', =>
      assert.ok beforeUnloadFired
      assert.equal @$('#permanent').textContent, 'new content'
      done()
    @Turbolinks.replace(doc, flush: true)

  test "with :keep", (done) ->
    doc = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title></title>
      </head>
      <body>
        <div id="div">new content</div>
      </body>
      </html>
    """
    beforeUnloadFired = false
    @document.addEventListener 'page:before-unload', =>
      assert.equal @$('#div').textContent, 'div content'
      beforeUnloadFired = true
    @document.addEventListener 'page:change', =>
      assert.ok beforeUnloadFired
      assert.equal @$('#div').textContent, 'div content'
      done()
    @Turbolinks.replace(doc, keep: ['div'])

  test "with :change", (done) ->
    doc = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>new title</title>
        <meta content="new-token" name="csrf-token">
        <script>var headScript = true</script>
      </head>
      <body new-attribute>
        <div id="new-div"></div>
        <div id="div">new content</div>
        <div id="change">new content</div>
        <div id="change:key">new content</div>
        <div id="permanent" data-turbolinks-permanent>new content</div>
        <div id="temporary" data-turbolinks-temporary>new content</div>
        <script>var bodyScript = true</script>
      </body>
      </html>
    """
    body = @$('body')
    change = @$('#change')
    beforeUnloadFired = false
    @document.addEventListener 'page:before-unload', =>
      assert.equal @$('#change').textContent, 'change content'
      assert.equal @$('[id="change:key"]').textContent, 'change content'
      assert.equal @$('#temporary').textContent, 'temporary content'
      assert.equal @document.title, 'title'
      beforeUnloadFired = true
    @document.addEventListener 'page:change', =>
      assert.ok beforeUnloadFired
      assert.notOk @window.bodyScript
      assert.notOk @window.headScript
      assert.notOk @$('#new-div')
      assert.notOk @$('body').hasAttribute('new-attribute')
      assert.equal @$('#change').textContent, 'new content'
      assert.equal @$('[id="change:key"]').textContent, 'new content'
      assert.equal @$('#temporary').textContent, 'new content'
      assert.equal @$('#div').textContent, 'div content'
      assert.equal @$('#permanent').textContent, 'permanent content'
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token'
      assert.equal @document.title, 'new title'
      assert.notEqual @$('#change'), change # changed nodes are cloned
      assert.equal @$('body'), body
      done()
    @Turbolinks.replace(doc, change: ['change'])

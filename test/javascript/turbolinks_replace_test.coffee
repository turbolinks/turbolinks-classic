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
        <script>window.j = window.j || 0; window.j++;</script>
        <script data-turbolinks-eval="false">var bodyScriptEvalFalse = true</script>
      </body>
      </html>
    """
    body = @$('body')
    permanent = @$('#permanent')
    permanent.addEventListener 'click', -> done()
    beforeUnloadFired = afterRemoveFired = false
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
    @document.addEventListener 'page:load', (event) =>
      assert.ok beforeUnloadFired
      assert.ok afterRemoveFired
      assert.deepEqual event.data, [@document.body]
      assert.equal @window.j, 1
      assert.isUndefined @window.headScript
      assert.isUndefined @window.bodyScriptEvalFalse
      assert.ok @$('#new-div')
      assert.ok @$('body').hasAttribute('new-attribute')
      assert.notOk @$('#div')
      assert.equal @$('#permanent').textContent, 'permanent content'
      assert.equal @$('#temporary').textContent, 'new content'
      assert.equal @document.title, 'new title'
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'new-token'
      assert.notEqual @$('body'), body # body is replaced
      assert.equal @$('#permanent'), permanent # permanent nodes are transferred
      @$('#permanent').click() # event listeners on permanent nodes should not be lost
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
    body = @$('body')
    beforeUnloadFired = afterRemoveFired = false
    @document.addEventListener 'page:before-unload', =>
      assert.equal @$('#permanent').textContent, 'permanent content'
      beforeUnloadFired = true
    @document.addEventListener 'page:after-remove', (event) =>
      assert.isNull event.data.parentNode
      assert.equal event.data, body
      assert.ok event.data.querySelector('#permanent')
      afterRemoveFired = true
    @document.addEventListener 'page:change', =>
      assert.ok beforeUnloadFired
      assert.ok afterRemoveFired
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
    body = @$('body')
    div = @$('#div')
    div.addEventListener 'click', -> done()
    beforeUnloadFired = afterRemoveFired = false
    @document.addEventListener 'page:before-unload', =>
      assert.equal @$('#div').textContent, 'div content'
      beforeUnloadFired = true
    @document.addEventListener 'page:after-remove', (event) =>
      assert.isNull event.data.parentNode
      assert.equal event.data, body
      assert.notEqual body, event.data.querySelector('#div')
      afterRemoveFired = true
    @document.addEventListener 'page:change', =>
      assert.ok beforeUnloadFired
      assert.ok afterRemoveFired
      assert.equal @$('#div').textContent, 'div content'
      assert.equal @$('#div'), div # :keep nodes are transferred
      @$('#div').click() # event listeners on :keep nodes should not be lost
    @Turbolinks.replace(doc, keep: ['div'])

  test "with :change", (done) ->
    doc = """
      <!DOCTYPE html>
      <HTML>
      <head>
        <meta charset="utf-8">
        <title>new title</title>
        <meta content="new-token" name="csrf-token">
        <script>var headScript = true</script>
      </head>
      <BODY new-attribute>
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
    temporary = @$('#temporary')
    beforeUnloadFired = false
    @document.addEventListener 'page:before-unload', =>
      assert.equal @window.i, 1
      assert.equal @$('#change').textContent, 'change content'
      assert.equal @$('[id="change:key"]').textContent, 'change content'
      assert.equal @$('#temporary').textContent, 'temporary content'
      assert.equal @document.title, 'title'
      beforeUnloadFired = true
    afterRemoveNodes = [@$('#temporary'), change, @$('[id="change:key"]')]
    @document.addEventListener 'page:after-remove', (event) =>
      assert.isNull event.data.parentNode
      assert.equal event.data, afterRemoveNodes.shift()
    @document.addEventListener 'page:load', (event) =>
      assert.ok beforeUnloadFired
      assert.equal afterRemoveNodes.length, 0
      assert.deepEqual event.data, [@$('#temporary'), @$('#change'), @$('[id="change:key"]')]
      assert.equal @window.i, 2 # scripts are re-run
      assert.isUndefined @window.bodyScript
      assert.isUndefined @window.headScript
      assert.notOk @$('#new-div')
      assert.notOk @$('body').hasAttribute('new-attribute')
      assert.equal @$('#change').textContent, 'new content'
      assert.equal @$('[id="change:key"]').textContent, 'new content'
      assert.equal @$('#temporary').textContent, 'new content'
      assert.equal @$('#div').textContent, 'div content'
      assert.equal @$('#permanent').textContent, 'permanent content'
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token'
      assert.equal @document.title, 'new title'
      assert.notEqual @$('#temporary'), temporary # temporary nodes are cloned
      assert.notEqual @$('#change'), change # changed nodes are cloned
      assert.equal @$('body'), body
      done()
    @Turbolinks.replace(doc, change: ['change'])

  test "with :change and html fragment", (done) ->
    html = """
      <div id="new-div"></div>
      <div id="change">new content<script>var insideScript = true</script></div>
      <div id="change:key">new content</div>
      <script>var outsideScript = true</script>
    """
    body = @$('body')
    change = @$('#change')
    temporary = @$('#temporary')
    afterRemoveNodes = [change, @$('[id="change:key"]')]
    @document.addEventListener 'page:after-remove', (event) =>
      assert.isNull event.data.parentNode
      assert.equal event.data, afterRemoveNodes.shift()
    @document.addEventListener 'page:change', =>
      assert.equal afterRemoveNodes.length, 0
      assert.equal @window.i, 2 # scripts are re-run
      assert.isUndefined @window.outsideScript
      assert.equal @window.insideScript, true
      assert.notOk @$('#new-div')
      assert.equal @$('#div').textContent, 'div content'
      assert.equal @$('#change').firstChild.textContent, 'new content'
      assert.equal @$('[id="change:key"]').textContent, 'new content'
      assert.equal @$('#permanent').textContent, 'permanent content'
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token'
      assert.equal @document.title, 'title'
      assert.equal @$('#temporary'), temporary # temporary nodes are left untouched when not found
      assert.equal @$('#temporary').textContent, 'temporary content'
      assert.notEqual @$('#change'), change # changed nodes are cloned
      assert.equal @$('body'), body
      done()
    @Turbolinks.replace(html, change: ['change'])

  test "with :change and html fragment with temporary node", (done) ->
    html = """
      <div id="div">new div content</div>
      <div id="temporary" data-turbolinks-temporary>new temporary content</div>
    """
    temporary = @$('#temporary')
    afterRemoveNodes = [temporary, @$('#div')]
    @document.addEventListener 'page:after-remove', (event) =>
      assert.isNull event.data.parentNode
      assert.equal event.data, afterRemoveNodes.shift()
    @document.addEventListener 'page:change', =>
      assert.equal afterRemoveNodes.length, 0
      assert.equal @$('#div').textContent, 'new div content'
      assert.equal @$('#temporary').textContent, 'new temporary content'
      assert.notEqual @$('#temporary'), temporary # temporary nodes are cloned when found
      done()
    @Turbolinks.replace(html, change: ['div'])

  test "with :title set to a value replaces the title with the value", (done) ->
    doc = """
      <!DOCTYPE html>
      <html>
      <head>
        <title>new title</title>
      </head>
      <body new-attribute>
        <div id="new-div"></div>
      </body>
      </html>
    """
    body = @$('body')
    permanent = @$('#permanent')
    @document.addEventListener 'page:load', (event) =>
      assert.equal @document.title, 'specified title'
      done()
    @Turbolinks.replace(doc, title: 'specified title')

  test "with :title set to false doesn't replace the title", (done) ->
    doc = """
      <!DOCTYPE html>
      <html>
      <head>
        <title>new title</title>
      </head>
      <body new-attribute>
        <div id="new-div"></div>
      </body>
      </html>
    """
    body = @$('body')
    permanent = @$('#permanent')
    @document.addEventListener 'page:load', (event) =>
      assert.equal @document.title, 'title'
      done()
    @Turbolinks.replace(doc, title: false)

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
    beforeUnloadFired = partialLoadFired = false
    @document.addEventListener 'page:before-unload', =>
      assert.isUndefined @window.j
      assert.notOk @$('#new-div')
      assert.notOk @$('body').hasAttribute('new-attribute')
      assert.ok @$('#div')
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token'
      assert.equal @document.title, 'title'
      assert.equal @$('body'), body
      beforeUnloadFired = true
    @document.addEventListener 'page:partial-load', (event) =>
      partialLoadFired = true
    @document.addEventListener 'page:load', (event) =>
      assert.ok beforeUnloadFired
      assert.notOk partialLoadFired
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
    beforeUnloadFired = partialLoadFired = false
    @document.addEventListener 'page:before-unload', =>
      assert.equal @$('#permanent').textContent, 'permanent content'
      beforeUnloadFired = true
    @document.addEventListener 'page:partial-load', (event) =>
      partialLoadFired = true
    @document.addEventListener 'page:change', =>
      assert.ok beforeUnloadFired
      assert.notOk partialLoadFired
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
    beforeUnloadFired = partialLoadFired = false
    @document.addEventListener 'page:before-unload', =>
      assert.equal @$('#div').textContent, 'div content'
      beforeUnloadFired = true
    @document.addEventListener 'page:partial-load', (event) =>
      partialLoadFired = true
    @document.addEventListener 'page:change', =>
      assert.ok beforeUnloadFired
      assert.notOk partialLoadFired
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
    beforeUnloadFired = loadFired = false
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
      loadFired = true
    @document.addEventListener 'page:partial-load', (event) =>
      assert.ok beforeUnloadFired
      assert.equal afterRemoveNodes.length, 0
      assert.deepEqual event.data, [@$('#temporary'), @$('#change'), @$('[id="change:key"]')]
      assert.equal @window.i, 1 # only scripts within the changed nodes are re-run
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
      setTimeout =>
        assert.notOk loadFired
        done()
      , 0
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
      assert.equal @window.i, 1 # only scripts within the changed nodes are re-run
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
    @document.addEventListener 'page:load', (event) =>
      assert.equal @document.title, 'title'
      done()
    @Turbolinks.replace(doc, title: false)

  # https://connect.microsoft.com/IE/feedback/details/811408/
  test "IE textarea placeholder bug", (done) ->
    doc = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>title</title>
      </head>
      <body>
        <div id="form">
          <textarea placeholder="placeholder" id="textarea1"></textarea>
          <textarea placeholder="placeholder" id="textarea2">placeholder</textarea>
          <textarea id="textarea3">value</textarea>
        </div>
        <div id="permanent" data-turbolinks-permanent><textarea placeholder="placeholder" id="textarea-permanent"></textarea></div>
      </body>
      </html>
    """
    change = 0
    @document.addEventListener 'page:change', =>
      change += 1
      if change is 1
        assert.equal @$('#textarea1').value, ''
        assert.equal @$('#textarea2').value, 'placeholder'
        assert.equal @$('#textarea3').value, 'value'
        assert.equal @$('#textarea-permanent').value, ''
        @Turbolinks.visit('iframe2.html')
      else if change is 2
        assert.equal @$('#textarea-permanent').value, ''
        setTimeout =>
          @window.history.back()
        , 0
      else if change is 3
        assert.equal @$('#textarea1').value, ''
        assert.equal @$('#textarea2').value, 'placeholder'
        assert.equal @$('#textarea3').value, 'value'
        assert.equal @$('#textarea-permanent').value, ''
        @$('#textarea-permanent').value = 'test'
        @Turbolinks.replace(doc, change: ['form'])
      else if change is 4
        assert.equal @$('#textarea1').value, ''
        assert.equal @$('#textarea2').value, 'placeholder'
        assert.equal @$('#textarea3').value, 'value'
        assert.equal @$('#textarea-permanent').value, 'test'
        assert.equal @$('#form').ownerDocument, @document
        done()
    @Turbolinks.replace(doc, flush: true)

  test "works with :change key of node that also has data-turbolinks-temporary", (done) ->
    html = """
      <div id="temporary" data-turbolinks-temporary>new temporary content</div>
    """
    afterRemoveNodes = [@$('#temporary')]
    @document.addEventListener 'page:after-remove', (event) =>
      assert.equal event.data, afterRemoveNodes.shift()
    @document.addEventListener 'page:change', =>
      assert.equal afterRemoveNodes.length, 0
      assert.equal @$('#temporary').textContent, 'new temporary content'
      done()
    @Turbolinks.replace(html, change: ['temporary'])

  test "works with :keep key of node that also has data-turbolinks-permanent", (done) ->
    html = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>title</title>
      </head>
      <body>
        <div id="permanent" data-turbolinks-permanent></div>
      </body>
      </html>
    """
    permanent = @$('#permanent')
    @document.addEventListener 'page:change', =>
      assert.equal @$('#permanent'), permanent
      done()
    @Turbolinks.replace(html, keep: ['permanent'])

  test "doesn't run scripts inside :change nodes more than once", (done) ->
    doc = """
      <!DOCTYPE html>
      <html>
      <head>
        <title>title</title>
      </head>
      <body>
        <div id="change">
          <script>window.count = (window.count || 0) + 1;</script>
          <script data-turbolinks-eval="false">window.count = (window.count || 0) + 1;</script>
        </div>
      </body>
      </html>
    """
    @document.addEventListener 'page:partial-load', =>
      assert.equal @window.count, 1 # using importNode before swapping the nodes would double-eval scripts in Chrome/Safari
      done()
    @Turbolinks.replace(doc, change: ['change'])

  test "appends elements on change when the append option is passed", (done) ->
    doc = """
      <!DOCTYPE html>
      <html>
      <head>
        <title>title</title>
      </head>
      <body>
        <div id="list"><div id="another-list-item">inserted list item</div></div>
      </body>
      </html>
    """
    @Turbolinks.replace(doc, append: ['list'])
    assert.equal @$('#list').children.length, 2 # children is similar to childNodes except it does not include text nodes
    assert.equal @$('#list').children[0].textContent, 'original list item'
    assert.equal @$('#list').children[1].textContent, 'inserted list item'

    done()

  test "prepends elements on change when the prepend option is passed", (done) ->
    doc = """
      <!DOCTYPE html>
      <html>
      <head>
        <title>title</title>
      </head>
      <body>
        <div id="list"><div id="another-list-item">inserted list item</div></div>
      </body>
      </html>
    """
    @Turbolinks.replace(doc, prepend: ['list'])
    assert.equal @$('#list').children.length, 2 # children is similar to childNodes except it does not include text nodes
    assert.equal @$('#list').children[0].textContent, 'inserted list item'
    assert.equal @$('#list').children[1].textContent, 'original list item'

    done()
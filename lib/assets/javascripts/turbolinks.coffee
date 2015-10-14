pageCache               = {}
cacheSize               = 10
transitionCacheEnabled  = false
requestCachingEnabled   = true
progressBar             = null
progressBarDelay        = 400

currentState            = null
loadedAssets            = null

referer                 = null

xhr                     = null

EVENTS =
  BEFORE_CHANGE:  'page:before-change'
  FETCH:          'page:fetch'
  RECEIVE:        'page:receive'
  CHANGE:         'page:change'
  UPDATE:         'page:update'
  LOAD:           'page:load'
  PARTIAL_LOAD:   'page:partial-load'
  RESTORE:        'page:restore'
  BEFORE_UNLOAD:  'page:before-unload'
  AFTER_REMOVE:   'page:after-remove'

isPartialReplacement = (options) ->
  options.change or options.append or options.prepend

fetch = (url, options = {}) ->
  url = new ComponentUrl url

  return if pageChangePrevented(url.absolute)

  if url.crossOrigin()
    document.location.href = url.absolute
    return

  if isPartialReplacement(options) or options.keep
    removeCurrentPageFromCache()
  else
    cacheCurrentPage()

  rememberReferer()
  progressBar?.start(delay: progressBarDelay)

  if transitionCacheEnabled and !isPartialReplacement(options) and cachedPage = transitionCacheFor(url.absolute)
    reflectNewUrl(url)
    fetchHistory cachedPage
    options.showProgressBar = false
    options.scroll = false
  else
    options.scroll ?= false if isPartialReplacement(options) and !url.hash

  fetchReplacement url, options

transitionCacheFor = (url) ->
  return if url is currentState.url
  cachedPage = pageCache[url]
  cachedPage if cachedPage and !cachedPage.transitionCacheDisabled

enableTransitionCache = (enable = true) ->
  transitionCacheEnabled = enable

disableRequestCaching = (disable = true) ->
  requestCachingEnabled = not disable
  disable

fetchReplacement = (url, options) ->
  options.cacheRequest ?= requestCachingEnabled
  options.showProgressBar ?= true

  triggerEvent EVENTS.FETCH, url: url.absolute

  xhr?.abort()
  xhr = new XMLHttpRequest
  xhr.open 'GET', url.formatForXHR(cache: options.cacheRequest), true
  xhr.setRequestHeader 'Accept', 'text/html, application/xhtml+xml, application/xml'
  xhr.setRequestHeader 'X-XHR-Referer', referer

  xhr.onload = ->
    triggerEvent EVENTS.RECEIVE, url: url.absolute

    if doc = processResponse()
      reflectNewUrl url
      reflectRedirectedUrl()
      loadedNodes = changePage extractTitleAndBody(doc)..., options
      if options.showProgressBar
        progressBar?.done()
      updateScrollPosition(options.scroll)
      triggerEvent (if isPartialReplacement(options) then EVENTS.PARTIAL_LOAD else EVENTS.LOAD), loadedNodes
      constrainPageCacheTo(cacheSize)
    else
      progressBar?.done()
      document.location.href = crossOriginRedirect() or url.absolute

  if progressBar and options.showProgressBar
    xhr.onprogress = (event) =>
      percent = if event.lengthComputable
        event.loaded / event.total * 100
      else
        progressBar.value + (100 - progressBar.value) / 10
      progressBar.advanceTo(percent)

  xhr.onloadend = -> xhr = null
  xhr.onerror   = -> document.location.href = url.absolute

  xhr.send()

fetchHistory = (cachedPage, options = {}) ->
  xhr?.abort()
  changePage cachedPage.title, cachedPage.body, null, runScripts: false
  progressBar?.done()
  updateScrollPosition(options.scroll)
  triggerEvent EVENTS.RESTORE

cacheCurrentPage = ->
  currentStateUrl = new ComponentUrl currentState.url

  pageCache[currentStateUrl.absolute] =
    url:                      currentStateUrl.relative,
    body:                     document.body,
    title:                    document.title,
    positionY:                window.pageYOffset,
    positionX:                window.pageXOffset,
    cachedAt:                 new Date().getTime(),
    transitionCacheDisabled:  document.querySelector('[data-no-transition-cache]')?

removeCurrentPageFromCache = ->
  delete pageCache[new ComponentUrl(currentState.url).absolute]

pagesCached = (size = cacheSize) ->
  cacheSize = parseInt(size) if /^[\d]+$/.test size

constrainPageCacheTo = (limit) ->
  pageCacheKeys = Object.keys pageCache

  cacheTimesRecentFirst = pageCacheKeys.map (url) ->
    pageCache[url].cachedAt
  .sort (a, b) -> b - a

  for key in pageCacheKeys when pageCache[key].cachedAt <= cacheTimesRecentFirst[limit]
    onNodeRemoved(pageCache[key].body)
    delete pageCache[key]

replace = (html, options = {}) ->
  loadedNodes = changePage extractTitleAndBody(createDocument(html))..., options
  triggerEvent (if isPartialReplacement(options) then EVENTS.PARTIAL_LOAD else EVENTS.LOAD), loadedNodes

changePage = (title, body, csrfToken, options) ->
  title = options.title ? title
  currentBody = document.body

  if isPartialReplacement(options)
    nodesToAppend = findNodesMatchingKeys(currentBody, options.append) if options.append
    nodesToPrepend = findNodesMatchingKeys(currentBody, options.prepend) if options.prepend

    nodesToReplace = findNodes(currentBody, '[data-turbolinks-temporary]')
    nodesToReplace = nodesToReplace.concat findNodesMatchingKeys(currentBody, options.change) if options.change

    nodesToChange = [].concat(nodesToAppend || [], nodesToPrepend || [], nodesToReplace || [])
    nodesToChange = removeDuplicates(nodesToChange)
  else
    nodesToChange = [currentBody]

  triggerEvent EVENTS.BEFORE_UNLOAD, nodesToChange
  document.title = title if title isnt false

  if isPartialReplacement(options)
    appendedNodes = swapNodes(body, nodesToAppend, keep: false, append: true) if nodesToAppend
    prependedNodes = swapNodes(body, nodesToPrepend, keep: false, prepend: true) if nodesToPrepend
    replacedNodes = swapNodes(body, nodesToReplace, keep: false) if nodesToReplace

    changedNodes = [].concat(appendedNodes || [], prependedNodes || [], replacedNodes || [])
    changedNodes = removeDuplicates(changedNodes)
  else
    unless options.flush
      nodesToKeep = findNodes(currentBody, '[data-turbolinks-permanent]')
      nodesToKeep.push(findNodesMatchingKeys(currentBody, options.keep)...) if options.keep
      swapNodes(body, removeDuplicates(nodesToKeep), keep: true)

    document.body = body
    CSRFToken.update csrfToken if csrfToken?
    setAutofocusElement()
    changedNodes = [body]

  executeScriptTags(getScriptsToRun(changedNodes, options.runScripts))
  currentState = window.history.state

  triggerEvent EVENTS.CHANGE, changedNodes
  triggerEvent EVENTS.UPDATE
  return changedNodes

findNodes = (body, selector) ->
  Array::slice.apply(body.querySelectorAll(selector))

findNodesMatchingKeys = (body, keys) ->
  matchingNodes = []
  for key in (if Array.isArray(keys) then keys else [keys])
    matchingNodes.push(findNodes(body, '[id^="'+key+':"], [id="'+key+'"]')...)

  return matchingNodes

swapNodes = (targetBody, existingNodes, options) ->
  changedNodes = []
  for existingNode in existingNodes
    unless nodeId = existingNode.getAttribute('id')
      throw new Error("Turbolinks partial replace: turbolinks elements must have an id.")

    if targetNode = targetBody.querySelector('[id="'+nodeId+'"]')
      if options.keep
        existingNode.parentNode.insertBefore(existingNode.cloneNode(true), existingNode)
        existingNode = targetNode.ownerDocument.adoptNode(existingNode)
        targetNode.parentNode.replaceChild(existingNode, targetNode)
      else
        if options.append or options.prepend
          firstChild = existingNode.firstChild

          childNodes = Array::slice.call targetNode.childNodes, 0 # a copy has to be made since the list is mutated while processing

          for childNode in childNodes
            if !firstChild or options.append # when the parent node is empty, there is no difference between appending and prepending
              existingNode.appendChild(childNode)
            else if options.prepend
              existingNode.insertBefore(childNode, firstChild)

          changedNodes.push(existingNode)
        else
          existingNode.parentNode.replaceChild(targetNode, existingNode)
          onNodeRemoved(existingNode)
          changedNodes.push(targetNode)

  return changedNodes

onNodeRemoved = (node) ->
  if typeof jQuery isnt 'undefined'
    jQuery(node).remove()
  triggerEvent(EVENTS.AFTER_REMOVE, node)

getScriptsToRun = (changedNodes, runScripts) ->
  selector = if runScripts is false then 'script[data-turbolinks-eval="always"]' else 'script:not([data-turbolinks-eval="false"])'
  script for script in document.body.querySelectorAll(selector) when isEvalAlways(script) or (nestedWithinNodeList(changedNodes, script) and not withinPermanent(script))

isEvalAlways = (script) ->
  script.getAttribute('data-turbolinks-eval') is 'always'

withinPermanent = (element) ->
  while element?
    return true if element.hasAttribute?('data-turbolinks-permanent')
    element = element.parentNode

  return false

nestedWithinNodeList = (nodeList, element) ->
  while element?
    return true if element in nodeList
    element = element.parentNode

  return false

executeScriptTags = (scripts) ->
  for script in scripts when script.type in ['', 'text/javascript']
    copy = document.createElement 'script'
    copy.setAttribute attr.name, attr.value for attr in script.attributes
    copy.async = false unless script.hasAttribute 'async'
    copy.appendChild document.createTextNode script.innerHTML
    { parentNode, nextSibling } = script
    parentNode.removeChild script
    parentNode.insertBefore copy, nextSibling
  return

# Firefox bug: Doesn't autofocus fields that are inserted via JavaScript
setAutofocusElement = ->
  autofocusElement = (list = document.querySelectorAll 'input[autofocus], textarea[autofocus]')[list.length - 1]
  if autofocusElement and document.activeElement isnt autofocusElement
    autofocusElement.focus()

reflectNewUrl = (url) ->
  if (url = new ComponentUrl url).absolute not in [referer, document.location.href]
    window.history.pushState { turbolinks: true, url: url.absolute }, '', url.absolute

reflectRedirectedUrl = ->
  if location = xhr.getResponseHeader 'X-XHR-Redirected-To'
    location = new ComponentUrl location
    preservedHash = if location.hasNoHash() then document.location.hash else ''
    window.history.replaceState window.history.state, '', location.href + preservedHash

crossOriginRedirect = ->
  redirect if (redirect = xhr.getResponseHeader('Location'))? and (new ComponentUrl(redirect)).crossOrigin()

rememberReferer = ->
  referer = document.location.href

rememberCurrentUrlAndState = ->
  window.history.replaceState { turbolinks: true, url: document.location.href }, '', document.location.href
  currentState = window.history.state

updateScrollPosition = (position) ->
  if Array.isArray(position)
    window.scrollTo position[0], position[1]
  else if position isnt false
    if document.location.hash
      document.location.href = document.location.href
      rememberCurrentUrlAndState()
    else
      window.scrollTo 0, 0

clone = (original) ->
  return original if not original? or typeof original isnt 'object'
  copy = new original.constructor()
  copy[key] = clone value for key, value of original
  copy

removeDuplicates = (array) ->
  result = []
  result.push(obj) for obj in array when result.indexOf(obj) is -1
  result

popCookie = (name) ->
  value = document.cookie.match(new RegExp(name+"=(\\w+)"))?[1].toUpperCase() or ''
  document.cookie = name + '=; expires=Thu, 01-Jan-70 00:00:01 GMT; path=/'
  value

uniqueId = ->
  new Date().getTime().toString(36)

triggerEvent = (name, data) ->
  if typeof Prototype isnt 'undefined'
    Event.fire document, name, data, true

  event = document.createEvent 'Events'
  event.data = data if data
  event.initEvent name, true, true
  document.dispatchEvent event

pageChangePrevented = (url) ->
  !triggerEvent EVENTS.BEFORE_CHANGE, url: url

processResponse = ->
  clientOrServerError = ->
    400 <= xhr.status < 600

  validContent = ->
    (contentType = xhr.getResponseHeader('Content-Type'))? and
      contentType.match /^(?:text\/html|application\/xhtml\+xml|application\/xml)(?:;|$)/

  downloadingFile = ->
    (disposition = xhr.getResponseHeader('Content-Disposition'))? and
      disposition.match /^attachment/

  extractTrackAssets = (doc) ->
    for node in doc.querySelector('head').childNodes when node.getAttribute?('data-turbolinks-track')?
      node.getAttribute('src') or node.getAttribute('href')

  assetsChanged = (doc) ->
    loadedAssets ||= extractTrackAssets document
    fetchedAssets  = extractTrackAssets doc
    fetchedAssets.length isnt loadedAssets.length or intersection(fetchedAssets, loadedAssets).length isnt loadedAssets.length

  intersection = (a, b) ->
    [a, b] = [b, a] if a.length > b.length
    value for value in a when value in b

  if not clientOrServerError() and validContent() and not downloadingFile()
    doc = createDocument xhr.responseText
    if doc and !assetsChanged doc
      return doc

extractTitleAndBody = (doc) ->
  title = doc.querySelector 'title'
  [ title?.textContent, doc.querySelector('body'), CSRFToken.get(doc).token ]

CSRFToken =
  get: (doc = document) ->
    node:   tag = doc.querySelector 'meta[name="csrf-token"]'
    token:  tag?.getAttribute? 'content'

  update: (latest) ->
    current = @get()
    if current.token? and latest? and current.token isnt latest
      current.node.setAttribute 'content', latest

createDocument = (html) ->
  if /<(html|body)/i.test(html)
    doc = document.documentElement.cloneNode()
    doc.innerHTML = html
  else
    doc = document.documentElement.cloneNode(true)
    doc.querySelector('body').innerHTML = html
  doc.head = doc.querySelector('head')
  doc.body = doc.querySelector('body')
  doc

# The ComponentUrl class converts a basic URL string into an object
# that behaves similarly to document.location.
#
# If an instance is created from a relative URL, the current document
# is used to fill in the missing attributes (protocol, host, port).
class ComponentUrl
  constructor: (@original = document.location.href) ->
    return @original if @original.constructor is ComponentUrl
    @_parse()

  withoutHash: -> @href.replace(@hash, '').replace('#', '')

  # Intention revealing function alias
  withoutHashForIE10compatibility: -> @withoutHash()

  hasNoHash: -> @hash.length is 0

  crossOrigin: ->
    @origin isnt (new ComponentUrl).origin

  formatForXHR: (options = {}) ->
    (if options.cache then @ else @withAntiCacheParam()).withoutHashForIE10compatibility()

  withAntiCacheParam: ->
    new ComponentUrl(
      if /([?&])_=[^&]*/.test @absolute
        @absolute.replace /([?&])_=[^&]*/, "$1_=#{uniqueId()}"
      else
        new ComponentUrl(@absolute + (if /\?/.test(@absolute) then "&" else "?") + "_=#{uniqueId()}")
    )

  _parse: ->
    (@link ?= document.createElement 'a').href = @original
    { @href, @protocol, @host, @hostname, @port, @pathname, @search, @hash } = @link
    @origin = [@protocol, '//', @hostname].join ''
    @origin += ":#{@port}" unless @port.length is 0
    @relative = [@pathname, @search, @hash].join ''
    @absolute = @href

# The Link class derives from the ComponentUrl class, but is built from an
# existing link element.  Provides verification functionality for Turbolinks
# to use in determining whether it should process the link when clicked.
class Link extends ComponentUrl
  @HTML_EXTENSIONS: ['html']

  @allowExtensions: (extensions...) ->
    Link.HTML_EXTENSIONS.push extension for extension in extensions
    Link.HTML_EXTENSIONS

  constructor: (@link) ->
    return @link if @link.constructor is Link
    @original = @link.href
    @originalElement = @link
    @link = @link.cloneNode false
    super

  shouldIgnore: ->
    @crossOrigin() or
      @_anchored() or
      @_nonHtml() or
      @_optOut() or
      @_target()

  _anchored: ->
    (@hash.length > 0 or @href.charAt(@href.length - 1) is '#') and
      (@withoutHash() is (new ComponentUrl).withoutHash())

  _nonHtml: ->
    @pathname.match(/\.[a-z]+$/g) and not @pathname.match(new RegExp("\\.(?:#{Link.HTML_EXTENSIONS.join('|')})?$", 'g'))

  _optOut: ->
    link = @originalElement
    until ignore or link is document
      ignore = link.getAttribute('data-no-turbolink')?
      link = link.parentNode
    ignore

  _target: ->
    @link.target.length isnt 0


# The Click class handles clicked links, verifying if Turbolinks should
# take control by inspecting both the event and the link. If it should,
# the page change process is initiated. If not, control is passed back
# to the browser for default functionality.
class Click
  @installHandlerLast: (event) ->
    unless event.defaultPrevented
      document.removeEventListener 'click', Click.handle, false
      document.addEventListener 'click', Click.handle, false

  @handle: (event) ->
    new Click event

  constructor: (@event) ->
    return if @event.defaultPrevented
    @_extractLink()
    if @_validForTurbolinks()
      visit @link.href
      @event.preventDefault()

  _extractLink: ->
    link = @event.target
    link = link.parentNode until !link.parentNode or link.nodeName is 'A'
    @link = new Link(link) if link.nodeName is 'A' and link.href.length isnt 0

  _validForTurbolinks: ->
    @link? and not (@link.shouldIgnore() or @_nonStandardClick())

  _nonStandardClick: ->
    @event.which > 1 or
      @event.metaKey or
      @event.ctrlKey or
      @event.shiftKey or
      @event.altKey


class ProgressBar
  className = 'turbolinks-progress-bar'
  # Setting the opacity to a value < 1 fixes a display issue in Safari 6 and
  # iOS 6 where the progress bar would fill the entire page.
  originalOpacity = 0.99

  @enable: ->
    progressBar ?= new ProgressBar 'html'

  @disable: ->
    progressBar?.uninstall()
    progressBar = null

  constructor: (@elementSelector) ->
    @value = 0
    @content = ''
    @speed = 300
    @opacity = originalOpacity
    @install()

  install: ->
    @element = document.querySelector(@elementSelector)
    @element.classList.add(className)
    @styleElement = document.createElement('style')
    document.head.appendChild(@styleElement)
    @_updateStyle()

  uninstall: ->
    @element.classList.remove(className)
    document.head.removeChild(@styleElement)

  start: ({delay} = {})->
    clearTimeout(@displayTimeout)
    if delay
      @display = false
      @displayTimeout = setTimeout =>
        @display = true
      , delay
    else
      @display = true

    if @value > 0
      @_reset()
      @_reflow()

    @advanceTo(5)

  advanceTo: (value) ->
    if value > @value <= 100
      @value = value
      @_updateStyle()

      if @value is 100
        @_stopTrickle()
      else if @value > 0
        @_startTrickle()

  done: ->
    if @value > 0
      @advanceTo(100)
      @_finish()

  _finish: ->
    @fadeTimer = setTimeout =>
      @opacity = 0
      @_updateStyle()
    , @speed / 2

    @resetTimer = setTimeout(@_reset, @speed)

  _reflow: ->
    @element.offsetHeight

  _reset: =>
    @_stopTimers()
    @value = 0
    @opacity = originalOpacity
    @_withSpeed(0, => @_updateStyle(true))

  _stopTimers: ->
    @_stopTrickle()
    clearTimeout(@fadeTimer)
    clearTimeout(@resetTimer)

  _startTrickle: ->
    return if @trickleTimer
    @trickleTimer = setTimeout(@_trickle, @speed)

  _stopTrickle: ->
    clearTimeout(@trickleTimer)
    delete @trickleTimer

  _trickle: =>
    @advanceTo(@value + Math.random() / 2)
    @trickleTimer = setTimeout(@_trickle, @speed)

  _withSpeed: (speed, fn) ->
    originalSpeed = @speed
    @speed = speed
    result = fn()
    @speed = originalSpeed
    result

  _updateStyle: (forceRepaint = false) ->
    @_changeContentToForceRepaint() if forceRepaint
    @styleElement.textContent = @_createCSSRule()

  _changeContentToForceRepaint: ->
    @content = if @content is '' then ' ' else ''

  _createCSSRule: ->
    """
    #{@elementSelector}.#{className}::before {
      content: '#{@content}';
      position: fixed;
      top: 0;
      left: 0;
      z-index: 2000;
      background-color: #0076ff;
      height: 3px;
      opacity: #{@opacity};
      width: #{if @display then @value else 0}%;
      transition: width #{@speed}ms ease-out, opacity #{@speed / 2}ms ease-in;
      transform: translate3d(0,0,0);
    }
    """

ProgressBarAPI =
  enable: ProgressBar.enable
  disable: ProgressBar.disable
  setDelay: (value) -> progressBarDelay = value
  start: (options) -> ProgressBar.enable().start(options)
  advanceTo: (value) -> progressBar?.advanceTo(value)
  done: -> progressBar?.done()

installDocumentReadyPageEventTriggers = ->
  document.addEventListener 'DOMContentLoaded', ( ->
    triggerEvent EVENTS.CHANGE, [document.body]
    triggerEvent EVENTS.UPDATE
  ), true

installJqueryAjaxSuccessPageUpdateTrigger = ->
  if typeof jQuery isnt 'undefined'
    jQuery(document).on 'ajaxSuccess', (event, xhr, settings) ->
      return unless jQuery.trim xhr.responseText
      triggerEvent EVENTS.UPDATE

onHistoryChange = (event) ->
  if event.state?.turbolinks && event.state.url != currentState.url
    previousUrl = new ComponentUrl(currentState.url)
    newUrl = new ComponentUrl(event.state.url)

    if newUrl.withoutHash() is previousUrl.withoutHash()
      updateScrollPosition()
    else if cachedPage = pageCache[newUrl.absolute]
      cacheCurrentPage()
      fetchHistory cachedPage, scroll: [cachedPage.positionX, cachedPage.positionY]
    else
      visit event.target.location.href

initializeTurbolinks = ->
  rememberCurrentUrlAndState()
  ProgressBar.enable()

  document.addEventListener 'click', Click.installHandlerLast, true
  window.addEventListener 'hashchange', rememberCurrentUrlAndState, false
  window.addEventListener 'popstate', onHistoryChange, false

browserSupportsPushState = window.history and 'pushState' of window.history and 'state' of window.history

# Copied from https://github.com/Modernizr/Modernizr/blob/master/feature-detects/history.js
ua = navigator.userAgent
browserIsBuggy =
  (ua.indexOf('Android 2.') != -1 or ua.indexOf('Android 4.0') != -1) and
  ua.indexOf('Mobile Safari') != -1 and
  ua.indexOf('Chrome') == -1 and
  ua.indexOf('Windows Phone') == -1

requestMethodIsSafe = popCookie('request_method') in ['GET','']

browserSupportsTurbolinks = browserSupportsPushState and !browserIsBuggy and requestMethodIsSafe

browserSupportsCustomEvents =
  document.addEventListener and document.createEvent

if browserSupportsCustomEvents
  installDocumentReadyPageEventTriggers()
  installJqueryAjaxSuccessPageUpdateTrigger()

if browserSupportsTurbolinks
  visit = fetch
  initializeTurbolinks()
else
  visit = (url = document.location.href) -> document.location.href = url

# Public API
#   Turbolinks.visit(url)
#   Turbolinks.replace(html)
#   Turbolinks.pagesCached()
#   Turbolinks.pagesCached(20)
#   Turbolinks.cacheCurrentPage()
#   Turbolinks.enableTransitionCache()
#   Turbolinks.disableRequestCaching()
#   Turbolinks.ProgressBar.enable()
#   Turbolinks.ProgressBar.disable()
#   Turbolinks.ProgressBar.start()
#   Turbolinks.ProgressBar.advanceTo(80)
#   Turbolinks.ProgressBar.done()
#   Turbolinks.allowLinkExtensions('md')
#   Turbolinks.supported
#   Turbolinks.EVENTS
@Turbolinks = {
  visit,
  replace,
  pagesCached,
  cacheCurrentPage,
  enableTransitionCache,
  disableRequestCaching,
  ProgressBar: ProgressBarAPI,
  allowLinkExtensions: Link.allowExtensions,
  supported: browserSupportsTurbolinks,
  EVENTS: clone(EVENTS)
}

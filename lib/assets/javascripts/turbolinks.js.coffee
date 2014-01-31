pageCache               = {}
cacheSize               = 10
transitionCacheEnabled  = false

currentState            = null
loadedAssets            = null
htmlExtensions          = ['html']

referer                 = null

createDocument          = null
xhr                     = null


fetch = (url) ->
  rememberReferer()
  cacheCurrentPage()
  reflectNewUrl url

  if transitionCacheEnabled and cachedPage = transitionCacheFor(url)
    fetchHistory cachedPage
    fetchReplacement url
  else
    fetchReplacement url, resetScrollPosition

transitionCacheFor = (url) ->
  cachedPage = pageCache[url]
  cachedPage if cachedPage and !cachedPage.transitionCacheDisabled

enableTransitionCache = (enable = true) ->
  transitionCacheEnabled = enable

fetchReplacement = (url, onLoadFunction = =>) ->  
  triggerEvent 'page:fetch', url: url

  xhr?.abort()
  xhr = new XMLHttpRequest
  xhr.open 'GET', removeHashForIE10compatiblity(url), true
  xhr.setRequestHeader 'Accept', 'text/html, application/xhtml+xml, application/xml'
  xhr.setRequestHeader 'X-XHR-Referer', referer

  xhr.onload = ->
    triggerEvent 'page:receive'

    if doc = processResponse()
      changePage extractTitleAndBody(doc)...
      reflectRedirectedUrl()
      onLoadFunction()
      triggerEvent 'page:load'
    else
      document.location.href = url

  xhr.onloadend = -> xhr = null
  xhr.onerror   = -> document.location.href = url

  xhr.send()

fetchHistory = (cachedPage) ->
  xhr?.abort()
  changePage cachedPage.title, cachedPage.body
  recallScrollPosition cachedPage
  triggerEvent 'page:restore'


cacheCurrentPage = ->
  pageCache[currentState.url] =
    url:                      document.location.href,
    body:                     document.body,
    title:                    document.title,
    positionY:                window.pageYOffset,
    positionX:                window.pageXOffset,
    cachedAt:                 new Date().getTime(),
    transitionCacheDisabled:  document.querySelector('[data-no-transition-cache]')?

  constrainPageCacheTo cacheSize

pagesCached = (size = cacheSize) ->
  cacheSize = parseInt(size) if /^[\d]+$/.test size

constrainPageCacheTo = (limit) ->
  pageCacheKeys = Object.keys pageCache

  cacheTimesRecentFirst = pageCacheKeys.map (url) ->
    pageCache[url].cachedAt
  .sort (a, b) -> b - a

  for key in pageCacheKeys when pageCache[key].cachedAt <= cacheTimesRecentFirst[limit]
    triggerEvent 'page:expire', pageCache[key]
    delete pageCache[key]

changePage = (title, body, csrfToken, runScripts) ->
  document.title = title
  document.documentElement.replaceChild body, document.body
  CSRFToken.update csrfToken if csrfToken?
  executeScriptTags() if runScripts
  currentState = window.history.state
  triggerEvent 'page:change'
  triggerEvent 'page:update'

executeScriptTags = ->
  scripts = Array::slice.call document.body.querySelectorAll 'script:not([data-turbolinks-eval="false"])'
  for script in scripts when script.type in ['', 'text/javascript']
    copy = document.createElement 'script'
    copy.setAttribute attr.name, attr.value for attr in script.attributes
    copy.appendChild document.createTextNode script.innerHTML
    { parentNode, nextSibling } = script
    parentNode.removeChild script
    parentNode.insertBefore copy, nextSibling
  return

removeNoscriptTags = (node) ->
  node.innerHTML = node.innerHTML.replace /<noscript[\S\s]*?<\/noscript>/ig, ''
  node

reflectNewUrl = (url) ->
  if url isnt referer
    window.history.pushState { turbolinks: true, url: url }, '', url

reflectRedirectedUrl = ->
  if location = xhr.getResponseHeader 'X-XHR-Redirected-To'
    preservedHash = if removeHash(location) is location then document.location.hash else ''
    window.history.replaceState currentState, '', location + preservedHash

rememberReferer = ->
  referer = document.location.href

rememberCurrentUrl = ->
  window.history.replaceState { turbolinks: true, url: document.location.href }, '', document.location.href

rememberCurrentState = ->
  currentState = window.history.state

recallScrollPosition = (page) ->
  window.scrollTo page.positionX, page.positionY

resetScrollPosition = ->
  if document.location.hash
    document.location.href = document.location.href
  else
    window.scrollTo 0, 0


# Intention revealing function alias
removeHashForIE10compatiblity = (url) ->
  removeHash url

removeHash = (url) ->
  link = url
  unless url.href?
    link = document.createElement 'A'
    link.href = url
  link.href.replace link.hash, ''

popCookie = (name) ->
  value = document.cookie.match(new RegExp(name+"=(\\w+)"))?[1].toUpperCase() or ''
  document.cookie = name + '=; expires=Thu, 01-Jan-70 00:00:01 GMT; path=/'
  value

triggerEvent = (name, data) ->
  event = document.createEvent 'Events'
  event.data = data if data
  event.initEvent name, true, true
  document.dispatchEvent event

pageChangePrevented = ->
  !triggerEvent 'page:before-change'

processResponse = ->
  clientOrServerError = ->
    400 <= xhr.status < 600

  validContent = ->
    xhr.getResponseHeader('Content-Type').match /^(?:text\/html|application\/xhtml\+xml|application\/xml)(?:;|$)/

  extractTrackAssets = (doc) ->
    for node in doc.head.childNodes when node.getAttribute?('data-turbolinks-track')?
      node.getAttribute('src') or node.getAttribute('href')

  assetsChanged = (doc) ->
    loadedAssets ||= extractTrackAssets document
    fetchedAssets  = extractTrackAssets doc
    fetchedAssets.length isnt loadedAssets.length or intersection(fetchedAssets, loadedAssets).length isnt loadedAssets.length

  intersection = (a, b) ->
    [a, b] = [b, a] if a.length > b.length
    value for value in a when value in b

  if not clientOrServerError() and validContent()
    doc = createDocument xhr.responseText
    if doc and !assetsChanged doc
      return doc

extractTitleAndBody = (doc) ->
  title = doc.querySelector 'title'
  [ title?.textContent, removeNoscriptTags(doc.body), CSRFToken.get(doc).token, 'runScripts' ]

CSRFToken =
  get: (doc = document) ->
    node:   tag = doc.querySelector 'meta[name="csrf-token"]'
    token:  tag?.getAttribute? 'content'

  update: (latest) ->
    current = @get()
    if current.token? and latest? and current.token isnt latest
      current.node.setAttribute 'content', latest

browserCompatibleDocumentParser = ->
  createDocumentUsingParser = (html) ->
    (new DOMParser).parseFromString html, 'text/html'

  createDocumentUsingDOM = (html) ->
    doc = document.implementation.createHTMLDocument ''
    doc.documentElement.innerHTML = html
    doc

  createDocumentUsingWrite = (html) ->
    doc = document.implementation.createHTMLDocument ''
    doc.open 'replace'
    doc.write html
    doc.close()
    doc

  # Use createDocumentUsingParser if DOMParser is defined and natively
  # supports 'text/html' parsing (Firefox 12+, IE 10)
  #
  # Use createDocumentUsingDOM if createDocumentUsingParser throws an exception
  # due to unsupported type 'text/html' (Firefox < 12, Opera)
  #
  # Use createDocumentUsingWrite if:
  #  - DOMParser isn't defined
  #  - createDocumentUsingParser returns null due to unsupported type 'text/html' (Chrome, Safari)
  #  - createDocumentUsingDOM doesn't create a valid HTML document (safeguarding against potential edge cases)
  try
    if window.DOMParser
      testDoc = createDocumentUsingParser '<html><body><p>test'
      createDocumentUsingParser
  catch e
    testDoc = createDocumentUsingDOM '<html><body><p>test'
    createDocumentUsingDOM
  finally
    unless testDoc?.body?.childNodes.length is 1
      return createDocumentUsingWrite


installClickHandlerLast = (event) ->
  unless event.defaultPrevented
    document.removeEventListener 'click', handleClick, false
    document.addEventListener 'click', handleClick, false

handleClick = (event) ->
  unless event.defaultPrevented
    link = extractLink event
    if link.nodeName is 'A' and !ignoreClick(event, link)
      visit link.href unless pageChangePrevented()
      event.preventDefault()


extractLink = (event) ->
  link = event.target
  link = link.parentNode until !link.parentNode or link.nodeName is 'A'
  link

crossOriginLink = (link) ->
  location.protocol isnt link.protocol or location.host isnt link.host

anchoredLink = (link) ->
  ((link.hash and removeHash(link)) is removeHash(location)) or
    (link.href is location.href + '#')

nonHtmlLink = (link) ->
  url = removeHash link
  url.match(/\.[a-z]+(\?.*)?$/g) and not url.match(new RegExp("\\.(?:#{htmlExtensions.join('|')})?(\\?.*)?$", 'g'))

noTurbolink = (link) ->
  until ignore or link is document
    ignore = link.getAttribute('data-no-turbolink')?
    link = link.parentNode
  ignore

targetLink = (link) ->
  link.target.length isnt 0

nonStandardClick = (event) ->
  event.which > 1 or event.metaKey or event.ctrlKey or event.shiftKey or event.altKey

ignoreClick = (event, link) ->
  crossOriginLink(link) or anchoredLink(link) or nonHtmlLink(link) or noTurbolink(link) or targetLink(link) or nonStandardClick(event)

allowLinkExtensions = (extensions...) ->
  htmlExtensions.push extension for extension in extensions
  htmlExtensions


# Delay execution of function long enough to miss the popstate event
# some browsers fire on the initial page load.
bypassOnLoadPopstate = (fn) ->
  setTimeout fn, 500

installDocumentReadyPageEventTriggers = ->
  document.addEventListener 'DOMContentLoaded', ( ->
    triggerEvent 'page:change'
    triggerEvent 'page:update'
  ), true

installJqueryAjaxSuccessPageUpdateTrigger = ->
  if typeof jQuery isnt 'undefined'
    jQuery(document).on 'ajaxSuccess', (event, xhr, settings) ->
      return unless jQuery.trim xhr.responseText
      triggerEvent 'page:update'

installHistoryChangeHandler = (event) ->
  if event.state?.turbolinks
    if cachedPage = pageCache[event.state.url]
      cacheCurrentPage()
      fetchHistory cachedPage
    else
      visit event.target.location.href

initializeTurbolinks = ->
  rememberCurrentUrl()
  rememberCurrentState()
  createDocument = browserCompatibleDocumentParser()

  document.addEventListener 'click', installClickHandlerLast, true

  bypassOnLoadPopstate ->
    window.addEventListener 'popstate', installHistoryChangeHandler, false

# Handle bug in Firefox 26/27 where history.state is initially undefined
historyStateIsDefined =
  window.history.state != undefined or navigator.userAgent.match /Firefox\/2[6|7]/

browserSupportsPushState =
  window.history and window.history.pushState and window.history.replaceState and historyStateIsDefined

browserIsntBuggy =
  !navigator.userAgent.match /CriOS\//

requestMethodIsSafe =
  popCookie('request_method') in ['GET','']

browserSupportsTurbolinks = browserSupportsPushState and browserIsntBuggy and requestMethodIsSafe

browserSupportsCustomEvents =
  document.addEventListener and document.createEvent

if browserSupportsCustomEvents
  installDocumentReadyPageEventTriggers()
  installJqueryAjaxSuccessPageUpdateTrigger()

if browserSupportsTurbolinks
  visit = fetch
  initializeTurbolinks()
else
  visit = (url) -> document.location.href = url

# Public API
#   Turbolinks.visit(url)
#   Turbolinks.pagesCached()
#   Turbolinks.pagesCached(20)
#   Turbolinks.enableTransitionCache()
#   Turbolinks.allowLinkExtensions('md')
#   Turbolinks.supported
@Turbolinks = { visit, pagesCached, enableTransitionCache, allowLinkExtensions, supported: browserSupportsTurbolinks }

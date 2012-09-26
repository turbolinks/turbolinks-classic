visit = (url) ->
  if browserSupportsPushState
    reflectNewUrl url
    fetchReplacement url
  else
    document.location.href = url


fetchReplacement = (url) ->
  xhr = new XMLHttpRequest
  xhr.open 'GET', url, true
  xhr.setRequestHeader 'Accept', 'text/html, application/xhtml+xml, application/xml'
  xhr.onload = -> fullReplacement xhr.responseText, url
  xhr.send()

fullReplacement = (html, url) ->
  replaceHTML html
  triggerPageChange()

reflectNewUrl = (url) ->
  window.history.pushState { turbolinks: true }, "", url

triggerPageChange = ->
  event = document.createEvent 'Events'
  event.initEvent 'page:change', true, true
  document.dispatchEvent event

createDocument = do ->
  createDocumentUsingParser = (html) ->
    (new DOMParser).parseFromString html, "text/html"

  createDocumentUsingWrite = (html) ->
    doc = document.implementation.createHTMLDocument ""
    doc.open "replace"
    doc.write html
    doc.close
    doc

  if window.DOMParser
    testDoc = createDocumentUsingParser "<html><body><p>test"

  if testDoc?.body?.childNodes.length is 1
    createDocumentUsingParser
  else
    createDocumentUsingWrite

replaceHTML = (html) ->
  doc = createDocument html
  originalBody = document.body
  document.documentElement.appendChild doc.body, originalBody
  document.documentElement.removeChild originalBody
  document.title = title.textContent if title = doc.querySelector "title"


extractLink = (event) ->
  link = event.target
  link = link.parentNode until link is document or link.nodeName is 'A'
  link

crossOriginLink = (link) ->
  location.protocol isnt link.protocol or location.host isnt link.host

anchoredLink = (link) ->
  ((link.hash and link.href.replace(link.hash, '')) is location.href.replace(location.hash, '')) or
    (link.href is location.href + '#')

nonHtmlLink = (link) ->
  link.href.match(/\.[a-z]+$/g) and not link.href.match(/\.html?$/g)

noTurbolink = (link) ->
  link.getAttribute('data-no-turbolink')?

newTabClick = (event) ->
  event.which > 1 or event.metaKey or event.ctrlKey

ignoreClick = (event, link) ->
  crossOriginLink(link) or anchoredLink(link) or nonHtmlLink(link) or noTurbolink(link) or newTabClick(event)

handleClick = (event) ->
  link = extractLink event

  if link.nodeName is 'A' and !ignoreClick(event, link)
    visit link.href
    event.preventDefault()


browserSupportsPushState = window.history and window.history.pushState and window.history.replaceState


if browserSupportsPushState
  window.addEventListener 'popstate', (event) ->
    if event.state?.turbolinks
      fetchReplacement document.location.href

  document.addEventListener 'click', (event) ->
    handleClick event

# Call Turbolinks.visit(url) from client code
@Turbolinks = { visit: visit }

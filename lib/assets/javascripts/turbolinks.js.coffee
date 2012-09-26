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

replaceHTML = (html) ->
  doc = document.implementation.createHTMLDocument ""
  doc.open "replace"
  doc.write html
  doc.close()

  originalBody = document.body
  document.documentElement.appendChild doc.body, originalBody
  document.documentElement.removeChild originalBody
  document.title = title.textContent if title = doc.querySelector "title"


extractLink = (event) ->
  link = event.target
  until link is document or link.nodeName is 'A'
    link = link.parentNode
  link

crossOriginLink = (link) ->
  location.protocol isnt link.protocol || location.host isnt link.host

anchoredLink = (link) ->
  ((link.hash && link.href.replace(link.hash, '')) is location.href.replace(location.hash, '')) ||
    (link.href is location.href + '#')

noTurbolink = (link) ->
  link.getAttribute('data-no-turbolink')?

newTabClick = (event) ->
  event.which > 1 || event.metaKey || event.ctrlKey

ignoreClick = (event, link) ->
  crossOriginLink(link) || anchoredLink(link) || noTurbolink(link) || newTabClick(event)

handleClick = (event) ->
  link = extractLink event

  if link.nodeName is 'A' and !ignoreClick(event, link)
    visit link.href
    event.preventDefault()


browserSupportsPushState =
  window.history && window.history.pushState && window.history.replaceState


if browserSupportsPushState
  window.addEventListener 'popstate', (event) ->
    if event.state?.turbolinks
      fetchReplacement document.location.href

  document.addEventListener 'click', (event) ->
    handleClick event

# Call Turbolinks.visit(url) from client code
@Turbolinks = { visit: visit }
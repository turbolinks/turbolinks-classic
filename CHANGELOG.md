## Turbolinks 1.1.1 (April 3, 2013) ##

*   Improve performance of `constrainPageCacheTo`, `executeScriptTags`, and `removeNoscriptTags`
    by not gathering and returning the results of the loop comprehensions.
   
    *Tim Ruffles*

*   Change page without Turbolinks when Turbolinks.visit is called in Chrome on iOS

    *Frank Showalter*

*   Maintain the latest CSRF authenticity token in the `<meta name="csrf-token">` head tag, if it
    exists.
    
    *Nick Reed*
    
## Turbolinks 1.1.0 (March 24, 2013) ##

*   Added Turbolinks::XDomainBlocker module with after_filter to detect cross-domain
    redirects, returning 403 Forbidden so that the client will reissue the request
    without Turbolinks. (XSS Protection)

    *Mala*

*   Remove hash when checking for non-HTML links. (XSS Protection)

    *Nick Reed + Mala*

*   Check Content-Type response header.  Fall back to non-Turbolinks request unless the 
    header is either `text/html`, `application/xhtml+xml`, or `application/xml`. (XSS Protection)
    
    *Nick Reed + Mala*

*   Add a `page:receive` event, triggered the moment the ajax request returns, before any
    processing is done.
    
    *Ben Weintraub*
    
*   Explicitly set `useCapture` flag to default (false) on addEventListener and 
    removeEventListener calls. Removes errors on older browsers where the flag
    was required.
    
    *Matthieu Aussaguel*
    
*   Copy `<noscript>` tag list by slicing so that `removeNoscriptTags` works with
    multiple `<noscript>` tags.
    
    *Lion Vollnhals**

*   Copy `<script>` tag list by slicing so that `executeScriptTags` works in situations
    where a script removes itself from the DOM.
    
    *Nick Reed*

*   Add link to Turbolinks Compatibility project to README.

    *Nick Reed*
    
*   Reflect X-XHR-Referer in `request.referer`

    *Nick Reed*
    
*   Add `createDocumentUsingDOM` method to avoid DOMParser exceptions on certain
    browsers.
    
    *Nick Reed*
    
*   Add jquery.turbolinks note to README

    *Ry Walker*
    
*   Abort XHR on popstate / Maintain history when aborting XHR

    *Nick Reed*
    
## Turbolinks 1.0.0 (January 11, 2013) ##

*   Disable Turbolinks on Chrome for iOS

    *David Estes*

*   Disable Turbolinks after non-GET requests.  Adds a cookie named `request_method`.

    *Nick Reed*
    
*   Abort XHR request if the user clicks another link before it finishes.

    *David Estes*
    
*   Fall back to using `document.location.href = url` when there is an error so the
    applicationCache can be used in offline mode.
    
    *R. Potter*

*   Remove hash from XHR url to fix IE 10 bug.

    *Nick Reed*
    
*   Scroll to anchor link id if link has an anchor tag.

    *Yasuharu Ozaki*
    
*   Allow Turbolinks to function in non-Rails environments.

    *Yasuharu Ozaki*
    
*   Optimize script tag execution by using script injection instead of `window.eval`.
    Deprecates the use of the `data-turbolinks-evaluated` attribute.
    
    *Nick Reed + John-David Dalton*

## Turbolinks 0.6.1 (December 4, 2012) ##

*   Delay existing asset check until it's time to compare them to the fetched page's assets.

    *Nick Reed*

## Turbolinks 0.6.0 (December 4, 2012) ##

*   Only track assets that have a `data-turbolinks-track` attribute.

    *Yasuharu Ozaki*

*   Fix issue where anchors are being dropped from the URL when changing pages

    *Nick Reed*
    
*   Update `extractLink` to safeguard against links that are removed from the DOM 
    when clicked.
    
    *Gleb Mazovetskiy*
    
*   Improve `executeScriptTags` by handling case where `src` attribute is empty
    and using `window.eval` instead of `eval`.
    
    *itzki*
    
*   Add compatibility section to README

    *DHH*
    
*   Add support for executing external script tags in the body

    *Nick Reed*
    
*   Add note to README about dynamically added scripts

    *Manuel Meurer*
    
## Turbolinks 0.5.2 (November 26, 2012) ##

*   Prevent issue with ActionController::Live by moving `set_xhr_current_location`
    from an an after_filter to a before_filter.
    
    *Kentaro Kuribayashi*
    
*   Only execute script tags on XHR request load, not from history fetch.

    *David Estes*
    
*   Use `document.location.reload()` instead of `document.location.href = url` if the 
    assets have changed.
    
    *Yasuharu Ozaki*
    
*   Remove the `samePageLink` method.

    *Yasuharu Ozaki*
    
*   Change the `pageCache` from an array to a hash to fix back button handling when
    window.history.length is > 0 on page load.
    
    *Steven Bristol*

*   Handle case where a node, after being clicked, is removed from the DOM before `extractLink`
    can climb it's tree.
    
    *Steven Bristol*
    
*   Ignore links with a `target` attribute.

    *Steven Bristol*
    
*   Use timestamp to initialize history state position.

    *Yasuharo Ozaki*
    
*   Detect additional asset changes.

    *David Estes*

*   Add `coffee-rails` as a dependency.

    *Rafael Mendonça França*

## Turbolinks 0.5.1 (October 4, 2012) ##

*   Remember assets as soon as possible to prevent dynamic scripts from being checked
    and added.
    
    *David Estes*
    
*   Remove `cloneNode` since there is no need to reset the node's events.

    *David Estes*
    
*   Improve `createDocument` to only determine correct parser once.

    *David Estes*

## Turbolinks 0.5.0 (October 3, 2012) ##

*   Only execute script tags that contain Javascript.

    *Nick Reed*
    
*   Issue a full page load if the assets change.

    *DHH*

*   Detect asset changes.

    *David Estes*
    

#### Refer to the [commit history](commits/master) on GitHub to view changes prior to 0.5.0 ####

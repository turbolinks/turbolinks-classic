Turbolinks
===========

Turbolinks makes following links in your web application faster. Instead of letting the browser recompile the JavaScript and CSS between each page change, it keeps the current page instance alive and replaces only the body and the title in the head. Think CGI vs persistent process.

This is similar to [pjax](https://github.com/defunkt/jquery-pjax), but instead of worrying about what element on the page to replace, and tailoring the server-side response to fit, we replace the entire body. This means that you get the bulk of the speed benefits from pjax (no recompiling of the JavaScript or CSS) without having to tailor the server-side response. It just works.

Do note that this of course means that you'll have a long-running, persistent session with maintained state. That's what's making it so fast. But it also means that you may have to pay additional care not to leak memory or otherwise bloat that long-running state. That should rarely be a problem unless you're doing something really funky, but you do have to be aware of it. Your memory leaking sins will not be swept away automatically by the cleansing page change any more.


How much faster is it really?
-----------------------------

It depends. The more CSS and JavaScript you have, the bigger the benefit of not throwing away the browser instance and recompiling all of it for every page. Just like a CGI script that says "hello world" will be fast, but a CGI script loading Rails on every request will not.

In any case, the benefit ranges from [twice as fast](https://github.com/steveklabnik/turbolinks_test) on apps with little JS/CSS, to [three times as fast](https://github.com/steveklabnik/turbolinks_test/tree/all_the_assets) in apps with lots of it. Of course, your mileage may vary, be dependent on your browser version, the moon cycle, and all other factors affecting performance testing. But at least it's a yardstick.

The best way to find out just how fast it is? Try it on your own application. It hardly takes any effort at all.


No jQuery or any other framework
--------------------------------

Turbolinks is designed to be as light-weight as possible (so you won't think twice about using it even for mobile stuff). It does not require jQuery or any other framework to work. But it works great _with_ jQuery or Prototype or whatever else have you.


Events
------

Since pages will change without a full reload with Turbolinks, you can't by default rely on `DOMContentLoaded` to trigger your JavaScript code or jQuery.ready(). Instead, Turbolinks gives you a range of events to deal with the lifecycle of the page:

* `page:fetch`   starting to fetch the target page (only called if loading fresh, not from cache).
* `page:load`    fetched page is being retrieved fresh from the server.
* `page:restore` fetched page is being retrieved from the 10-slot client-side cache.
* `page:change`  page has changed to the newly fetched version.

So if you wanted to have a client-side spinner, you could listen for `page:fetch` to start it and `page:change` to stop it. If you have DOM transformation that are not idempotent (the best way), you can hook them to happen only on `page:load` instead of `page:change` (as that would run them again on the cached pages).


Initialization
--------------

Turbolinks will be enabled **only** if the server has rendered a `GET` request.

Some examples, given a standard RESTful resource:

* `POST :create` => resource successfully created => redirect to `GET :show`
  * Turbolinks **ENABLED**
* `POST :create` => resource creation failed => render `:new`
  * Turbolinks **DISABLED**

**Why not all request types?** Some browsers track the request method of each page load, but triggering pushState methods don't change this value.  This could lead to the situation where pressing the browser's reload button on a page that was fetched with Turbolinks would attempt a `POST` (or something other than `GET`) because the last full page load used that method.


Opting out of Turbolinks
------------------------

By default, all internal HTML links will be funneled through Turbolinks, but you can opt out by marking links or their parent container with `data-no-turbolink`. For example, if you mark a div with `data-no-turbolink`, then all links inside of that div will be treated as regular links. If you mark the body, every link on that entire page will be treated as regular links.

Note that internal links to files not ending in .html, or having no extension, will automatically be opted out of Turbolinks. So links to /images/panda.gif will just work as expected.

Also, Turbolinks is installed as the last click handler for links. So if you install another handler that calls event.preventDefault(), Turbolinks will not run. This ensures that you can safely use Turbolinks with stuff like `data-method`, `data-remote`, or `data-confirm` from Rails.


Asset change detection
----------------------

You can track certain assets, like application.js and application.css, that you want to ensure are always of the latest version inside a Turbolinks session. This is done by marking those asset links with data-turbolinks-track, like so:

```<link href="/assets/application-9bd64a86adb3cd9ab3b16e9dca67a33a.css" rel="stylesheet" type="text/css" data-turbolinks-track>```

If those assets change URLs (embed an md5 stamp to ensure this), the page will do a full reload instead of going through Turbolinks. This ensures that all Turbolinks sessions will always be running off your latest JavaScript and CSS.

When this happens, you'll technically be requesting the same page twice. Once through Turbolinks to detect that the assets changed, and then again when we do a full redirect to that page.


Evaluating script tags
----------------------

Turbolinks will evaluate any script tags in pages it visit, if those tags do not have a type or if the type is text/javascript. All other script tags will be ignored.


Triggering a Turbolinks visit manually
---------------------------------------

You can use `Turbolinks.visit(path)` to go to a URL through Turbolinks.


Full speed for pushState browsers, graceful fallback for everything else
------------------------------------------------------------------------

Like pjax, this naturally only works with browsers capable of pushState. But of course we fall back gracefully to full page reloads for browsers that do not support it.


Compatibility
-------------

Turbolinks is designed to work with any browser that fully supports pushState and all the related APIs. This includes Safari 6.0+ (but not Safari 5.1.x!), IE10, and latest Chromes and Firefoxes.

Do note that existing JavaScript libraries may not all be compatible with Turbolinks out of the box due to the change in instantiation cycle. You might very well have to modify them to work with Turbolinks' new set of events.


Installation
------------

1. Add `gem 'turbolinks'` to your Gemfile.
1. Run `bundle install`.
1. Add `//= require turbolinks` to your Javascript manifest file (usually found at `app/assets/javascripts/application.js`).
1. Restart your server and you're now using turbolinks!


Credits
-------

Thanks to Chris Wanstrath for his original work on Pjax. Thanks to Sam Stephenson and Josh Peek for their additional work on Pjax and Stacker and their help with getting Turbolinks released. Thanks to David Estes for handling the lion's share of post-release issues and feature requests. And thanks to everyone else who's fixed or reported an issue!
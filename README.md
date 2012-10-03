Turbolinks
===========

Turbolinks makes following links in your web application faster. Instead of letting the browser recompile the JavaScript and CSS between each page change, we keep the current page instance alive and replace only the body and the title in the head (and potentially spend extra HTTP requests checking if the assets are up-to-date). Think CGI vs persistent process.

This is similar to [pjax](https://github.com/defunkt/jquery-pjax), but instead of worrying about what element on the page to replace, and tailoring the server-side response to fit, we replace the entire body. This means that you get the bulk of the speed benefits from pjax (no recompiling of the JavaScript or CSS) without having to tailor the server-side response. It just works.


How much faster is it really?
-----------------------------

It depends. The more CSS and JavaScript you have, the bigger the benefit of not throwing away the browser instance and recompiling all of it for every page. Just like a CGI script that says "hello world" will be fast, but a CGI script loading Rails on every request will not.

In any case, the benefit ranges from [twice as fast](https://github.com/steveklabnik/turbolinks_test) on apps with little JS/CSS, to [three times as fast](https://github.com/steveklabnik/turbolinks_test/tree/all_the_assets) in apps with lots of it. Of course, your mileage may vary, be dependent on your browser version, the moon cycle, and all other factors affecting performance testing. But at least it's a yardstick.


No jQuery or any other framework
--------------------------------

Turbolinks is designed to be as light-weight as possible (so you won't think twice about using it even for mobile stuff). It does not require jQuery or any other framework to work. But it works great _with_ jQuery or Prototype or whatever else have you.


Events
------

Since pages will change without a full reload with Turbolinks, you can't by default rely on `dom:loaded` to trigger your JavaScript code. Instead, Turbolinks gives you a range of events to deal with the lifecycle of the page:

* `page:fetch`   starting to fetch the target page (only called if loading fresh, not from cache).
* `page:load`    fetched page is being retrieved fresh from the server.
* `page:restore` fetched page is being retrieved from the 10-slot client-side cache.
* `page:change`  page has changed to the newly fetched version.

So if you wanted to have a client-side spinner, you could listen for `page:fetch` to start it and `page:change` to stop it. If you have DOM transformation that are not idempotent (the best way), you can hook them to happen only on `page:load` instead of `page:change` (as that would run them again on the cached pages).


Opting out of Turbolinks
------------------------

By default, all internal links will be funneled through Turbolinks, but you can opt out by marking links or their parent container with `data-no-turbolink`. For example, if you mark a div with `data-no-turbolink`, then all links inside of that div will be treated as regular links. If you mark the body, every link on that entire page will be treated as regular links.


Asset change detection
----------------------

Turbolinks will remember what assets were linked or referenced in the head of the initial page. If those assets change, either more or added or existing ones have a new URL, the page will do a full reload instead of going through Turbolinks. This ensures that all Turbolinks sessions will always be running off your latest JavaScript and CSS.

When this happens, you'll technically be requesting the same page twice. Once through Turbolinks to detect that the assets changed, and then again when we do a full redirect to that page.


Triggering a Turbolinks visit manually
---------------------------------------

You can use `Turbolinks.visit(path)` to go to a URL through Turbolinks.


Full speed for pushState browsers, graceful fallback for everything else
------------------------------------------------------------------------

Like pjax, this naturally only works with browsers capable of pushState. But of course we fall back gracefully to full page reloads for browsers that do not support it.


Installation
------------

1. Add `gem 'turbolinks'` to your Gemfile.
1. Run `bundle install`.
1. Add `//= require turbolinks` to your Javascript manifest file (usually found at `app/assets/javascripts/application.js`).
1. Restart your server and you're now using turbolinks!

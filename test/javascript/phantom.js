var fs = require('fs');
var print = function(s) { fs.write('/dev/stdout', s, 'w'); };

var timeoutId = null;
var deferTimeout = function() {
  if (timeoutId) clearTimeout(timeoutId);
  timeoutId = setTimeout(function() {
    console.log("\nTimeout");
    phantom.exit(1);
  }, 5000);
};

var page = require('webpage').create();
page.onError = null;
page.open(require('system').args[1], function() {
  page.evaluate(function() {
    mocha.getTests = function(suite, result) {
      suite = suite || mocha.suite;
      result = result || [];
      result.push.apply(result, suite.tests);
      suite.suites.forEach(function(s) { mocha.getTests(s, result); });
      return result;
    };

    mocha.suite.afterAll(function() {
      mocha.done = true;
    });
  });

  deferTimeout();

  var poll = function() {
    var tests = page.evaluate(function() {
      var result = [];
      mocha.getTests().forEach(function(test) {
        if (test.recorded || !test.state) return;
        test.recorded = true;
        result.push(test.state === 'passed' ? '.' : 'F');
      });
      return result;
    });

    tests.forEach(function(test) {
      print(test);
      deferTimeout();
    });

    var result = page.evaluate(function() {
      if (!mocha.done) return;
      var result = { failures: [] };
      mocha.getTests().forEach(function(test) {
        if (test.state === 'passed') return;
        result.failures.push({title: test.fullTitle(), message: test.err.message});
      });
      result.stats = [].map.call(document.querySelectorAll('li.passes, li.failures, li.duration'), function(el) { return el.textContent; }).join(', ')
      return result;
    });

    if (result) {
      console.log('');
      result.failures.forEach(function(failure) {
        console.log("\n" + failure.title + "\n  " + failure.message);
      });
      console.log(result.stats);
      phantom.exit(result.failures.length === 0 ? 0 : 1);
    } else {
      setTimeout(poll, 100);
    }
  }

  setTimeout(poll, 100);
});

require File.expand_path('../lib/turbolinks/version', __FILE__)

Gem::Specification.new do |s|
  s.name     = 'turbolinks'
  s.version  = Turbolinks::VERSION
  s.author   = 'David Heinemeier Hansson'
  s.email    = 'david@loudthinking.com'
  s.license  = 'MIT'
  s.homepage = 'https://github.com/rails/turbolinks/'
  s.summary  = 'Turbolinks makes following links in your web application faster (use with Rails Asset Pipeline)'
  s.files    = Dir["lib/assets/javascripts/*.js.coffee", "lib/turbolinks.rb", "lib/turbolinks/*.rb", "README.md", "MIT-LICENSE", "test/*"]
  
  s.add_dependency 'coffee-rails'
end

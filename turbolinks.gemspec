Gem::Specification.new do |s|
  s.name    = 'turbolinks'
  s.version = '2.0.0'
  s.author  = 'David Heinemeier Hansson'
  s.email   = 'david@loudthinking.com'
  s.license = 'MIT'
  s.summary = 'Turbolinks makes following links in your web application faster (use with Rails Asset Pipeline)'
  s.files   = Dir["lib/assets/javascripts/*.js.coffee", "lib/turbolinks.rb", "README.md", "MIT-LICENSE", "test/*"]
  
  s.add_dependency 'coffee-rails'
end

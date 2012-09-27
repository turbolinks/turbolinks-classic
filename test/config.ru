require 'sprockets'
require 'coffee-script'

Root = File.expand_path("../..", __FILE__)

Assets = Sprockets::Environment.new do |env|
  env.append_path File.join(Root, "lib", "assets", "javascripts")
end

map "/js" do
  run Assets
end

run Rack::Directory.new(File.join(Root, "test"))

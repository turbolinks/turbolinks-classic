require 'sprockets'
require 'coffee-script'

Root = File.expand_path("../..", __FILE__)

Assets = Sprockets::Environment.new do |env|
  env.append_path File.join(Root, "lib", "assets", "javascripts")
end

map "/js" do
  run Assets
end

map "/500" do
  # throw Internal Server Error (500)
end

map "/withoutextension" do
  run Rack::File.new(File.join(Root, "test", "withoutextension"), "Content-Type" => "text/html")
end

map "/" do
  run Rack::Directory.new(File.join(Root, "test"))
end

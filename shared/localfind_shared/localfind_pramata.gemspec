Gem::Specification.new do |spec|
  spec.name = "localfind_shared"
  spec.version = "0.1.0"
  spec.summary = "Shared authentication and tenant rules for LocalFind services"
  spec.authors = [ "LocalFind" ]
  spec.files = Dir["lib/**/*.rb"]
  spec.require_paths = [ "lib" ]
  spec.add_dependency "activesupport", ">= 7.0"
  spec.add_dependency "jwt", "~> 3.3"
end

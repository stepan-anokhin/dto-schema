lib = File.expand_path("../lib/", __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)
require "dto_schema/version"

Gem::Specification.new do |s|
  s.name        = 'dto_schema'
  s.version     = DTOSchema::VERSION
  s.date        = '2019-10-28'
  s.description = "A small library to validate simple data."
  s.summary     = s.description
  s.authors     = ["Stepan Anokhin"]
  s.email       = 'stepan.anokhin@gmail.com'
  s.files       = %w(dto_schema.gemspec) + Dir["*.md", "lib/**/*.rb"]
  s.homepage    = 'https://github.com/stepan-anokhin/dto-schema'
  s.license     = 'MIT'
  s.required_ruby_version = ">= 2.2.10"
end
lib = File.expand_path("../lib/", __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)
require "dto_schema/version"

Gem::Specification.new do |s|
  s.name        = 'dto_schema'
  s.version     = DTOSchema::VERSION
  s.date        = '2019-10-28'
  s.summary     = "DTO validation schema."
  s.description = "A small library to validate simple data."
  s.authors     = ["Stepan Anokhin"]
  s.email       = 'stepan.anokhin@gmail.com'
  s.files       = ["lib/dto_schema.rb"]
  s.homepage    = 'https://github.com/stepan-anokhin/dto-schema'
  s.license     = 'MIT'
end
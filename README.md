# Ruby DTO-Schema
[![Gem Version](https://badge.fury.io/rb/dto_schema.svg)](https://badge.fury.io/rb/dto_schema)
[![Build Status](https://travis-ci.org/stepan-anokhin/dto-schema.svg?branch=master)](https://travis-ci.org/stepan-anokhin/dto-schema)
[![Coverage Status](https://coveralls.io/repos/github/stepan-anokhin/dto-schema/badge.svg?branch=master)](https://coveralls.io/github/stepan-anokhin/dto-schema?branch=master)

DTO-Schema is a small Ruby library to validate simple data. 

## What is validated?

A notion of `Simple Data` could be defined as follows: 
* `nil` is a simple data
* `String` is a simple data
* `Numeric` is a simple data
* Boolean is a simple data
* `Array` of simple data is a simple data
* `Hash` with symbolic keys and simple-data values is a simple data

## Example 

Define a schema:
```ruby
require 'dto_schema'

schema = DTOSchema::define do
    object :tag do
        required :name, String, check: [:not_empty]
        required :value, String, check: [:not_empty]
    end
  
    object :post do
        required :title, String, check: [:not_empty]
        required :body, String, check: [:not_empty]
        optional :tags, list[:tag]
    end
  
    check :not_empty do |value|
      next "Cannot be empty" if value.empty?
    end 
end
``` 

And then use it to validate data:
```ruby
require 'json'

data = JSON.parse('{"title": 42, "tags":[42, {"name":"", "value":"foo"}]}', symbolize_names: true)
p schema.post.validate data
```

And result will be:
```
{:title=>["Must be a String"], :body=>["Cannot be null"], :tags=>{0=>["Must be object"], 1=>{:name=>["Cannot be empty"]}}}
```


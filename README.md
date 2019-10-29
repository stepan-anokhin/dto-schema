# Ruby DTO-Schema
[![Gem Version](https://badge.fury.io/rb/dto_schema.svg)](https://badge.fury.io/rb/dto_schema)
[![Build Status](https://travis-ci.org/stepan-anokhin/dto-schema.svg?branch=master)](https://travis-ci.org/stepan-anokhin/dto-schema)
[![Coverage Status](https://coveralls.io/repos/github/stepan-anokhin/dto-schema/badge.svg?branch=master)](https://coveralls.io/github/stepan-anokhin/dto-schema?branch=master)

DTO-Schema is a small Ruby library to validate simple data. 

## Installation

```shell script
gem install dto_schema
```

## What is validated?

DTO-Schema a simple data. A notion of `Simple Data` could be defined as follows: 
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

data = JSON.parse('{"tags":[42, {"name":"", "value":"foo"}]}', symbolize_names: true)
p schema.post.validate data
```

And result will be:
```
{:title=>["Cannot be null"], :tags=>{0=>["Must be object"], 1=>{:name=>["Cannot be empty"]}}}
```

## Usage

### Creating a schema

DTO-Schema is defined with `DTOSchema::define` method
```ruby
require 'dto_schema'

schema = DTOSchema::define do
    # schema definition go here ... 
end
```

### Defining a DTO type

Use the `object <name> do <definition> end` method to define a new DTO type:
```ruby
require 'dto_schema'

schema = DTOSchema::define do
  object :post do
    required :title, String 
    optional :body, String
  end
end
```
Each DTO definition provides `required` and `optional` method to declare DTO attributes.

The schema above defines `post` DTO with optional attribute `body` and required attribute `title`.

### Validating data

For each defined DTO schema provides a number of dynamically-generated methods to access it. 
For example if we define a `post` DTO as shown above, the schema will have the 
following methods:
* `post` - to get the *post*-validator
* `post? (data)` - to check if the data has a valid structure 
(equivalent of `schema.post.valid_structure? data`, more on this later)
* `valid_post? (data)` - to check if data is a valid `post` DTO (a short-hand of `schema.post.valid? data`)
* `validate_post (data)` - get the data validation errors (a short-hand of `schema.post.validate data`)

For example:
```ruby
data = {
  body: 42
}
p schema.validate_post data
```
```
{:body=>["Must be a String"], :title=>["Cannot be null"]}
```

### Inline checks
To apply a custom checks to a DTO attributes, `required` and `optional` methods accept
an optional block which is called during validation with an attribute value as an argument. 

A block must return either an Array of error-messages, a single error message or `nil`.

Example:
```ruby
schema = DTOSchema::define do
  object :post do
    required :title, String do |value|
      next "Cannot be empty" if value.empty?
    end

    optional :body, String do |value|
      next "Cannot be empty" if value.empty?
    end
  end
end
```
```ruby
data = {
    title: true,
    body: ""
}
p schema.validate_post data
```
```
{:title=>["Must be a String"], :body=>["Cannot be empty"]}
```

### Reusing checks

You can define and reuse checks using a `check` method. 
Each attribute may have any number of checks.
```ruby
schema = DTOSchema::define do
  object :post do
    required :title, String, check: :not_empty
    optional :body, String, check: [:not_empty]
  end

  check :not_empty do |value|
    next "Cannot be empty" if value.empty?
  end
end
```
This is an equivalent of the previous example. 

### Parametrized checks

Sometimes it is useful to define a parametrized checks. It could be done like this:
```ruby
schema = DTOSchema::define do
  object :post do
    required :title, String, check: check.length(min: 3)
    optional :body, String, check: check.length(max: 2)
  end

  check :length do |value, min: 0, max: nil|
    next "Must contain at least #{min} chars" if value.size < min
    next "Must contain at max #{max} chars" if !max.nil? && value.size > max
  end
end
```
```ruby
data = {
    title: "hi",
    body: "foo"
}
p schema.validate_post data
```
```
{:title=>["Must contain at least 3 chars"], :body=>["Must contain at max 2 chars"]}
```

### Referencing one DTO from another

You may define any number of DTOs and embed one into another. 
To do that you simply use dto name as an attribute type.
```ruby
schema = DTOSchema::define do
  object :book_details do
    required :pages, Numeric
    required :author, String
    required :language, String
  end

  object :book do
    required :title, String
    required :text, String
    required :details, :book_details
  end
end
```
```ruby
data = {
    title: "Moby-Dick",
    text: "Call me Ishmael...",
    details: {
        author: "Herman Melville",
        pages: 768,
    }
}
p schema.validate_book data
```
```
{:details=>{:language=>["Cannot be null"]}}
```

## List attributes

DTO-Schema provides a `list` method to define list-attributes:
```ruby
schema = DTOSchema::define do
  object :book do
    required :title, String
    required :pages, list[String]
  end
end
```
```ruby
data = {
    title: "Moby-Dick",
    pages: ["Call me Ishmael...", 42]
}
p schema.validate_book data
```
```
{:pages=>{1=>["Must be a String"]}}
```

You may reference any DTO as a list item type:
```ruby
schema = DTOSchema::define do
  object :tree do
    required :value, Numeric
    optional :child, list[:tree]
  end
end
```
```ruby
data = {
    value: 42,
    child: [
        {
            value: 12
        },
        {
            value: "wrong!"
        }
    ]
}
p schema.validate_tree data
```
```
{:child=>{1=>{:value=>["Must be a Numeric"]}}}
```
List item type may be any valid type including list itself: `list[list[Numeric]]`.

### List DTO

DTO-Schema allows to declare list as independent DTO type
```ruby
schema = DTOSchema::define do
  object :polygon do
    required :name, String
    optional :vertices, list[:point]
  end

  list :point, Float do |items|
    next "Must contain exactly 2 items" unless items.size == 2
  end
end
```
```ruby
data = {
    name: "My Polygon",
    vertices: [
        [1.0, 2.0],
        [5.0]
    ],
}
p schema.validate_polygon data
p schema.point? [1.0, 2.0]
```
```
{:vertices=>{1=>["Must contain exactly 2 items"]}}
true
```

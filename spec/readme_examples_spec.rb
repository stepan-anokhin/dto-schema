require 'json'
require 'dto_schema'

RSpec.describe "README.md" do
  it "correctly demonstrates motivation" do
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

    data = JSON.parse('{"tags":[42, {"name":"", "value":"foo"}]}', symbolize_names: true)
    expect(schema.post.validate data).to eq({:title => ["Cannot be null"], :tags => {0 => ["Must be object"], 1 => {:name => ["Cannot be empty"]}}})
  end

  it "correctly demonstrates inline checks" do
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

    data = {
        title: true,
        body: ""
    }
    expect(schema.validate_post data).to eq({:title => ["Must be a String"], :body => ["Cannot be empty"]})
  end

  it "correctly demonstrates reusable checks" do
    schema = DTOSchema::define do
      object :post do
        required :title, String, check: :not_empty
        optional :body, String, check: [:not_empty]
      end

      check :not_empty do |value|
        next "Cannot be empty" if value.empty?
      end
    end

    data = {
        title: true,
        body: ""
    }
    expect(schema.validate_post data).to eq({:title => ["Must be a String"], :body => ["Cannot be empty"]})
  end

  it "correctly demonstrates parametrized checks" do
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

    data = {
        title: "hi",
        body: "foo"
    }
    expect(schema.validate_post data).to eq({:title => ["Must contain at least 3 chars"], :body => ["Must contain at max 2 chars"]})
  end

  it "correctly demonstrates DTO cross-references" do
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

    data = {
        title: "Moby-Dick",
        text: "Call me Ishmael...",
        details: {
            author: "Herman Melville",
            pages: 768,
        }
    }
    expect(schema.validate_book data).to eq({:details => {:language => ["Cannot be null"]}})
  end

  it "correctly demonstrate simple list attribute types" do
    schema = DTOSchema::define do
      object :book do
        required :title, String
        required :pages, list[String]
      end
    end

    data = {
        title: "Moby-Dick",
        pages: ["Call me Ishmael...", 42]
    }
    expect(schema.validate_book data).to eq({:pages => {1 => ["Must be a String"]}})
  end

  it "correctly demonstrates list + recursive DTO reference" do
    schema = DTOSchema::define do
      object :tree do
        required :value, Numeric
        optional :child, list[:tree]
      end
    end

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
    expect(schema.validate_tree data).to eq({:child => {1 => {:value => ["Must be a Numeric"]}}})
  end

  it "correctly demonstrates nested lists" do
    schema = DTOSchema::define do
      object :container do
        required :numbers, list[list[Numeric]]
      end
    end

    data = {numbers: [[1, 2, 3], [3, 4, 5]]}
    expect(schema.container? data).to be_truthy
  end

  it "correctly demonstrates list as separate DTO" do
    schema = DTOSchema::define do
      object :polygon do
        required :name, String
        optional :vertices, list[:point]
      end

      list :point, Float do |items|
        next "Must contain exactly 2 items" unless items.size == 2
      end
    end

    data = {
        name: "My Polygon",
        vertices: [
            [1.0, 2.0],
            [5.0]
        ],
    }
    expect(schema.validate_polygon data).to eq({:vertices => {1 => ["Must contain exactly 2 items"]}})
    expect(schema.point? [1.0, 2.0]).to be_truthy
  end

  it "correctly demonstrates invariants" do
    schema = DTOSchema::define do
      object :new_account do
        required :password, String
        required :confirm_password, String

        invariant :confirm_password do |data|
          next "Passwords must be equal" if data[:password] != data[:confirm_password]
        end
      end
    end

    data = {
        password: "foo",
        confirm_password: "bar",
    }
    expect(schema.validate_new_account data).to eq({:confirm_password => ["Passwords must be equal"]})
  end

  it "correctly demonstrates Any and Bool" do
    schema = DTOSchema::define do
      object :envelope do
        required :custom_data, any
        required :flags, list[bool]
      end
    end

    data = {
        custom_data: {
            anything: "whatever"
        },
        flags: [true, false, 42]
    }
    expect(schema.validate_envelope data).to eq({:flags => {2 => ["Must be boolean"]}})
  end

end

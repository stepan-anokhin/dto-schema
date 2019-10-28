require 'dto_schema'

RSpec.describe DTOSchema::Schema do
  it "generate dynamic methods for each defined DTO" do
    schema = DTOSchema::define do
      object(:my_dto) {} # empty dto definition
    end

    expect(schema).to respond_to(:my_dto) # get validator
    expect(schema).to respond_to(:my_dto?) # check valid_structure?
    expect(schema).to respond_to(:valid_my_dto?) # check if the DTO is valid?
    expect(schema).to respond_to(:validate_my_dto) # validate DTO
  end

  it "accepts missing optional fields" do
    schema = DTOSchema::define do
      object :tag do
        optional :name, String
      end
    end

    data = {}
    expect(schema.tag.validate data).to eq({})
  end

  it "verifies optional field type" do
    schema = DTOSchema::define do
      object :tag do
        optional :name, String
      end
    end

    data = {name: 42}
    expect(schema.tag.validate data).to eq({:name => ["Must be a String"]})
  end

  it "verifies required field" do
    schema = DTOSchema::define do
      object :tag do
        required :name, String
      end
    end

    data = {}
    expect(schema.tag.validate data).to eq({:name => ["Cannot be null"]})
  end

  it "verifies multiple required fields" do
    schema = DTOSchema::define do
      object :tag do
        required :name, String
        required :value, String
      end
    end

    data = {}
    expect(schema.tag.validate data).to eq({:name => ["Cannot be null"], :value => ["Cannot be null"]})
  end

  it "verifies different field errors" do
    schema = DTOSchema::define do
      object :tag do
        required :name, String
        required :value, String
      end
    end

    data = {value: 42}
    expect(schema.tag.validate data).to eq({:name => ["Cannot be null"], :value => ["Must be a String"]})
  end

  it "verifies errors for some" do
    schema = DTOSchema::define do
      object :tag do
        required :name, String
        required :value, String
      end
    end

    data = {name: 42, value: "value"}
    expect(schema.tag.validate data).to eq({:name => ["Must be a String"]})
  end

  it "accepts valid required fields" do
    schema = DTOSchema::define do
      object :tag do
        required :name, String
        required :value, String
      end
    end

    data = {name: "foo", value: "bar"}
    expect(schema.tag.validate data).to eq({})
  end

  it "applies simple checks" do
    schema = DTOSchema::define do
      object :tag do
        required :name, String, check: [:not_empty]
      end

      check :not_empty do |value|
        next "Cannot be empty" if value.empty?
      end
    end

    data = {name: ""}
    expect(schema.tag.validate data).to eq({:name => ["Cannot be empty"]})
  end

  it "accepts when simple checks succeed" do
    schema = DTOSchema::define do
      object :tag do
        required :name, String, check: [:not_empty]
      end

      check :not_empty do |value|
        next "Cannot be empty" if value.empty?
      end
    end

    data = {name: "foo"}
    expect(schema.tag.validate data).to eq({})
  end

  it "throw error on unknown check" do
    expect { DTOSchema::define do
      object :tag do
        required :name, String, check: [:undefined_check]
      end
    end }.to raise_error(NameError)
  end

  it "applies parametrized checks" do
    schema = DTOSchema::define do
      object :tag do
        required :name, String, check: [check.length(min: 2, max: 3)]
      end

      check :length do |value, min: 0, max: nil|
        next "Must contain at least #{min} elements" if value.size < min
        next "Must contain at max #{max} elements" if !max.nil? && value.size > max
      end
    end

    too_short = {name: "1"}
    expect(schema.tag.validate too_short).to eq({:name => ["Must contain at least 2 elements"]})

    too_long = {name: "1234"}
    expect(schema.tag.validate too_long).to eq({:name => ["Must contain at max 3 elements"]})
  end

  it "accepts when parametrized checks succeed" do
    schema = DTOSchema::define do
      object :tag do
        required :name, String, check: [check.length(min: 2, max: 3)]
      end

      check :length do |value, min: 0, max: nil|
        next "Must contain at least #{min} elements" if value.size < min
        next "Must contain at max #{max} elements" if !max.nil? && value.size > max
      end
    end

    data = {name: "12"}
    expect(schema.tag.validate data).to eq({})
  end

  it "accepts short syntax for single check" do
    schema = DTOSchema::define do
      object :tag do
        required :name, String, check: :not_empty
      end

      check :not_empty do |value|
        next "Cannot be empty" if value.empty?
      end
    end

    data = {name: ""}
    expect(schema.tag.validate data).to eq({:name => ["Cannot be empty"]})
  end

  it "applies multiple checks" do
    schema = DTOSchema::define do
      object :tag do
        required :name, String, check: [check.length(min: 2), check.length(max: 3)]
      end

      check :length do |value, min: 0, max: nil|
        next "Must contain at least #{min} elements" if value.size < min
        next "Must contain at max #{max} elements" if !max.nil? && value.size > max
      end
    end

    too_short = {name: "1"}
    expect(schema.tag.validate too_short).to eq({:name => ["Must contain at least 2 elements"]})

    too_long = {name: "1234"}
    expect(schema.tag.validate too_long).to eq({:name => ["Must contain at max 3 elements"]})
  end

  it "resolves cross-references" do
    schema = DTOSchema::define do
      object :tag do
        required :name, String, check: :not_empty
        required :value, String, check: :not_empty
      end

      object :post do
        required :title, String, check: :not_empty
        optional :tags, list[:tag]
      end

      check :not_empty do |value|
        next "Cannot be empty" if value.empty?
      end
    end

    data = {
        title: "foo",
        tags: [42]
    }
    expect(schema.post.validate data).to eq({:tags => {0 => ["Must be object"]}})
  end

  it "performs validation of nested objects" do
    schema = DTOSchema::define do
      object :tag do
        required :name, String, check: :not_empty
        required :value, String, check: :not_empty
      end

      object :post do
        required :title, String, check: :not_empty
        optional :tags, list[:tag]
      end

      check :not_empty do |value|
        next "Cannot be empty" if value.empty?
      end
    end

    data = {
        title: "foo",
        tags: [{
                   name: 42,
                   value: "bar"
               }]
    }
    expect(schema.post.validate data).to eq({:tags => {0 => {:name => ["Must be a String"]}}})
  end

  it "throws on unresolved type references" do
    expect { DTOSchema::define do
      object :post do
        required :title, String, check: :not_empty
        optional :tags, list[:tag]
      end
    end }.to raise_error(NameError)
  end

  it "applies invariants" do
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
    expect(schema.new_account.validate data).to eq({:confirm_password => ["Passwords must be equal"]})
  end
end

require_relative 'checks'
require_relative 'validators'

module DTOSchema
  class CheckBinder
    def initialize (schema)
      @schema = schema
    end

    def method_missing (name, args = {})
      check = Checks::CheckReference.new @schema, name
      Checks::BoundCheck.new check, args
    end
  end


  class Schema
    def initialize(&block)
      @validators = {}
      @checks = {}
      @check_binder = CheckBinder.new self
      define(&block)
    end

    def define (&block)
      raise ArgumentError, "Block is expected" if block.nil?
      builder = Builder.new self
      builder.instance_eval &block
      resolve
    end

    def define_validator(name, validator)
      @validators[name] = validator
      generate_methods(name, validator)
    end

    def define_check(name, check)
      @checks[name] = check
    end

    def bind_check
      @check_binder
    end

    def resolve
      @validators.each_value { |validator| validator.resolve }
      @checks.each_value { |check| check.resolve }
      self
    end

    def resolve_validator (name)
      raise NameError, "Undefined validator `#{name}'" unless @validators.include? name
      @validators[name]
    end

    def resolve_check (name)
      raise NameError, "Undefined check `#{name}'" unless @checks.include? name
      @checks[name]
    end

    private

    def generate_methods (name, validator)
      self.define_singleton_method(name) do
        validator
      end

      self.define_singleton_method("#{name}?".to_sym) do |data|
        validator.valid_structure? data
      end

      self.define_singleton_method("validate_#{name}".to_sym) do |data|
        validator.validate data
      end

      self.define_singleton_method("valid_#{name}?".to_sym) do |data|
        validator.valid? data
      end
    end

    class Builder
      def initialize(schema)
        @schema = schema
      end

      def object(name, &definition)
        validator = Validators::ObjectValidator.new @schema
        builder = Validators::ObjectValidator::Builder.new @schema, validator
        builder.instance_eval(&definition)
        @schema.define_validator(name, validator)
        validator
      end

      def list(name, item_type, check: nil, &predicate)
        check = Checks::parse_checks check, @schema
        check << Checks::Check.new(predicate) unless predicate.nil?
        item_validator = Validators::Parse::parse_validator item_type, @schema
        validator = Validators::ListValidator.new @schema, item_validator, check
        @schema.define_validator(name, validator)
        validator
      end

      def check(name = nil, &body)
        raise ArgumentError, "Check definition name is not provided" if name.nil?
        raise ArgumentError, "Check definition is not provided for `#{name}`" if body.nil?
        result = Checks::Check.new(body)
        @schema.define_check(name, result)
        result
      end
    end
  end
end

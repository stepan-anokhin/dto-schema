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
      self.instance_eval &block unless block.nil?
      resolve
    end

    def object(name, &definition)
      validator = Validators::ObjectValidator.new self
      validator.instance_eval(&definition)
      @validators[name] = validator

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

      validator
    end

    def list
      Validators::ListValidator.new self, Validators::AnyValidator.new
    end

    def check(name = nil, &body)
      return @check_binder if name.nil? && body.nil?
      raise ArgumentError, "Check definition name is not provided" if name.nil?
      raise ArgumentError, "Check definition is not provided for `#{name}`" if body.nil?
      result = Checks::Check.new(body)
      @checks[name] = result
      result
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
  end
end

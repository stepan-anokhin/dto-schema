require_relative 'checks'

module DTOSchema
  module Validators

    class BaseValidator
      def resolve
        self
      end

      protected

      def resolve_validator (spec)
        return PrimitiveValidator.new(spec) if primitive? spec
        return spec if validator? spec
        resolve_reference spec if reference? spec
      end

      def primitive? (spec)
        spec.is_a?(Class) && (spec <= Numeric || spec <= String)
      end

      def validator? (spec)
        spec.is_a? BaseValidator
      end

      def reference? (spec)
        spec.is_a? Symbol
      end

      def resolve_reference (ref)
        ValidatorReference.new @schema, ref
      end
    end

    class BoolValidator < BaseValidator
      def valid? (data)
        data.is_a?(TrueClass) || data.is_a?(FalseClass)
      end

      def validate (data)
        return ["Must be boolean"] unless valid? data
        []
      end

      alias :valid_structure? :valid?
    end

    class AnyValidator < BaseValidator
      def valid? (data)
        true
      end

      def validate
        []
      end

      alias :valid_structure? :valid?
    end

    class PrimitiveValidator < BaseValidator
      def initialize (type)
        @type = type
      end

      def valid? (data)
        data.is_a? @type
      end

      def validate (data)
        return ["Must be a #{@type}"] unless valid? data
        []
      end

      alias :valid_structure? :valid?
    end

    class ValidatorReference < BaseValidator
      def initialize (schema, ref)
        @schema, @ref = schema, ref
      end

      def valid? (data)
        resolve.valid? data
      end

      def validate (data)
        resolve.validate data
      end

      def valid_structure? (data)
        resolve.valid_structure? data
      end

      def resolve
        @schema.resolve_validator @ref
      end
    end

    class ListValidator < BaseValidator
      def initialize(schema, item_validator)
        @schema, @item_validator = schema, item_validator
      end

      def valid? (data)
        data.is_a?(Array) && data.all? { |item| @item_validator.valid? item }
      end

      def validate (data)
        return ["Must be an array"] unless data.is_a? Array
        result = {}
        data.each_with_index do |value, i|
          errors = @item_validator.validate value
          result[i] = errors unless errors.empty?
        end
        result
      end

      def valid_structure? (data)
        data.is_a?(Array) && data.all? { |item| @item_validator.valid_structure? item }
      end

      def [] (spec)
        validator = resolve_validator spec
        ListValidator.new @schema, validator
      end

      def resolve
        @item_validator.resolve
        self
      end
    end

    class FieldValidator < BaseValidator
      def initialize(schema, name, required, type, check)
        raise ArgumentError, "'#{name}' cannot have checks as it is not a primitive" unless check.empty? || primitive?(type)
        @schema, @name, @required, @type, @check = schema, name, required, type, check
        @type_validator = resolve_validator type
      end

      def validate (data)
        return ["Cannot be null"] if @required && data.nil?
        return [] if !@required && data.nil?
        return @type_validator.validate data unless primitive? @type
        type_check = @type_validator.validate data
        return type_check unless type_check.empty?
        @check.collect { |check| check.validate data }.flatten(1)
      end

      def valid_structure? (data)
        return !@required if data.nil?
        @type_validator.valid_structure? data
      end

      def valid? (data)
        validate(data).empty?
      end

      def resolve
        @type_validator.resolve
        @check.each { |check| check.resolve }
        self
      end
    end

    class Invariant
      def initialize (fields, block)
        @fields = fields || []
        @check = Checks::Check.new block
      end

      def validate (data)
        errors = @check.validate data
        return {} if errors.empty?
        return errors if @fields.empty?
        result = {}
        @fields.each { |field| result[field] = errors }
        result
      end
    end

    class ObjectValidator < BaseValidator
      def initialize (schema)
        @schema = schema
        @fields = {}
        @invariants = []
      end

      def field (name, required: false, type: AnyValidator.new, check: nil, &validations)
        check ||= []
        check = [check] if check.is_a?(Symbol) || check.is_a?(Checks::BoundCheck)
        check = check.collect { |check_spec| resolve_check check_spec }
        check.append(Check.new validations) unless validations.nil?
        @fields[name] = FieldValidator.new @schema, name, required, type, check
      end

      def required(name, type, check: nil, &validations)
        field(name, required: true, type: type, check: check, &validations)
      end

      def optional(name, type, check: nil, &validations)
        field(name, required: false, type: type, check: check, &validations)
      end

      def validate (data)
        return ["Cannot be null"] if data.nil?
        return ["Must be object"] unless data.is_a? Hash
        result = {}
        @fields.each_pair do |name, validator|
          errors = validator.validate data[name]
          result[name] = errors unless errors.empty?
        end
        return result unless result.empty?
        @invariants.each do |invariant|
          errors = invariant.validate data
          return errors unless errors.empty?
        end
        {}
      end

      def valid? (data)
        validate(data).empty?
      end

      def valid_structure? (data)
        return false unless data.is_a? Hash
        @fields.all? { |name, validator| validator.valid_structure? data[name] }
      end

      def list
        @schema.list
      end

      def check
        @schema.check
      end

      def invariant (fields = nil, &block)
        fields = [] if fields.nil?
        fields = [fields] if fields.is_a? Symbol
        @invariants.append(Invariant.new fields, block)
      end

      def resolve
        @fields.each_value { |field| field.resolve }
        self
      end

      private

      def resolve_check (check)
        return check if check.is_a? BoundCheck
        return Checks::CheckReference.new @schema, check if check.is_a? Symbol
        raise ArgumentError, "Unexpected check type: #{check.class}"
      end
    end


  end
end

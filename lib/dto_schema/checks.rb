module DTOSchema
  module Checks

    # A custom DTO-attribute validation
    class Check
      def initialize (check)
        @check = check
      end

      # Validate attribute value
      def validate (data, args = nil)
        result = @check.call(data) if args.nil?
        result = @check.call(data, args) unless args.nil?
        return result if result.is_a? Array
        return [result] if result.is_a? String
        []
      end

      # Ensure check doesn't have dangling references
      def resolve
        self # simple Check never has references
      end
    end

    # A dynamic reference to a custom Check
    class CheckReference
      def initialize (schema, ref, args = nil)
        @schema, @ref = schema, ref
        @args = args
      end

      # Validate attribute value
      def validate (data, args = nil)
        resolve.validate data, args
      end

      # Get the referent check
      def resolve
        @schema.resolve_check @ref
      end
    end

    # A validation check with bound key-word arguments.
    #
    class BoundCheck
      def initialize (check, args)
        @check = check
        @args = args
      end

      # Validate attribute value
      def validate (data, args = {})
        args = @args.merge(args)
        @check.validate data, args # pass predefined kw-args
      end

      # Ensure the underlying check doesn't have dangling references
      def resolve
        @check.resolve
      end
    end

    # It provides check-binding API:
    #   check.length(min: 2, max: 3)
    class CheckBinder
      def initialize (schema)
        @schema = schema
      end

      # Bind a check by its name passed as dynamic method name.
      # It is this method that implements check-binding API in schema definition.
      def method_missing (name, args = {})
        check = CheckReference.new @schema, name
        BoundCheck.new check, args
      end
    end

    def self.create_check (spec, schema)
      return spec if spec.is_a? Checks::BoundCheck
      return Checks::CheckReference.new schema, spec if spec.is_a? Symbol
      raise ArgumentError, "Unexpected check type: #{spec.class}"
    end

    def self.parse_checks(checks, schema)
      checks ||= []
      checks = [checks] if checks.is_a?(Symbol) || checks.is_a?(BoundCheck)
      checks.collect { |spec| Checks::create_check(spec, schema) }
    end

  end
end

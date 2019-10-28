module DTOSchema
  module Checks

    class Check
      def initialize (check)
        @check = check
      end

      def validate (data, args = nil)
        result = @check.call(data) if args.nil?
        result = @check.call(data, args) unless args.nil?
        return result if result.is_a? Array
        return [result] if result.is_a? String
        []
      end

      def resolve
        self
      end
    end

    class CheckReference
      def initialize (schema, ref, args = nil)
        @schema, @ref = schema, ref
        @args = args
      end

      def validate (data, args = nil)
        resolve.validate data, args
      end

      def resolve
        @schema.resolve_check @ref
      end
    end

    class BoundCheck
      def initialize (check, args)
        @check = check
        @args = args
      end

      def validate (data, args = {})
        args = @args.merge(args)
        @check.validate data, args
      end

      def resolve
        @check.resolve
      end
    end

    class CheckBinder
      def initialize (schema)
        @schema = schema
      end

      def method_missing (name, args = {})
        check = CheckReference.new @schema, name
        BoundCheck.new check, args
      end
    end

  end
end
require_relative 'dto_schema/schema'

module DTOSchema
  def define(&block)
    Schema.new(&block)
  end
end

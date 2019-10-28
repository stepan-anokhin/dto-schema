require_relative 'dto_schema/schema'

module DTOSchema
  def self.define(&block)
    Schema.new(&block)
  end


end

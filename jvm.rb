require 'stringio'

class Reader
  #
  # @param [String] class_file_code
  #
  def initialize(code)
    @io = StringIO.new(code)
  end

  #
  # @param [Integer] n
  #
  # @return [String]
  #
  def read(n)
    @io.read(n)
  end

  #
  # @return [Integer]
  #
  def read_u1
    @io.readbyte
  end

  #
  # @return [Integer]
  #
  def read_u2
    read(2).unpack1('n')
  end

  #
  # @return [Integer]
  #
  def read_u4
    read(4).unpack1('N')
  end

  #
  # @return [Attributes]
  #
  def read_attrs
    attribute_name_index = read_u2
    attribute_length = read_u4
    ClassFile::Attributes.new(attribute_name_index, attribute_length, read(attribute_length))
  end
end

class ClassFile
  OP_GETSTAITC = 0xB2
  OP_LDC = 0x12
  OP_INVOKEVIRTUAL = 0xB6
  OP_RETURN = 0xB1

  # @return [Array<Constant>]
  attr_reader :constant_pool

  # @return [Array<Method>]
  attr_reader :methods

  # @return [Array<Attributes>]
  attr_reader :attributes

  def initialize(constant_pool, methods, attributes)
    @constant_pool = constant_pool
    @methods = methods
    @attributes = attributes
  end

  class Constant
    TAG_CLASS = 0x07
    TAG_FIELDREF = 0x09
    TAG_METHODREF = 0x0A
    TAG_NAMEANDTYPE = 0x0C
    TAG_STRING = 0x08
    TAG_UTF8 = 0x01

    # @return [Integer]
    attr_reader :tag

    def initialize(tag)
      @tag = tag
    end

    class Class < Constant
      attr_reader :name_index

      def initialize(name_index)
        super(TAG_CLASS)
        @name_index = name_index
      end
    end

    class Fieldref < Constant
      # @return [Integer]
      attr_reader :class_index
      # @return [Integer]
      attr_reader :name_and_type_index

      def initialize(class_index, name_and_type_index)
        super(TAG_FIELDREF)
        @class_index = class_index
        @name_and_type_index = name_and_type_index
      end
    end

    class Methodref < Constant
      # @return [Integer]
      attr_reader :class_index
      # @return [Integer]
      attr_reader :name_and_type_index

      def initialize(class_index, name_and_type_index)
        super(TAG_METHODREF)
        @class_index = class_index
        @name_and_type_index = name_and_type_index
      end
    end

    class NameAndType < Constant
      # @return [Integer]
      attr_reader :name_index
      # @return [Integer]
      attr_reader :descriptor_index

      def initialize(name_index, descriptor_index)
        super(TAG_NAMEANDTYPE)
        @name_index = name_index
        @descriptor_index = descriptor_index
      end
    end

    class String < Constant
      # @return [Integer]
      attr_reader :string_index

      def initialize(string_index)
        super(TAG_STRING)
        @string_index = string_index
      end
    end

    class Utf8 < Constant
      # @return [Integer]
      attr_reader :length
      # @return [String]
      attr_reader :bytes

      def initialize(length, bytes)
        super(TAG_UTF8)
        @length = length
        @bytes = bytes
      end
    end
  end

  class Attributes
    # @return [Integer]
    attr_reader :attribute_name_index

    # @return [Integer]
    attr_reader :attribute_length

    # @return [String]
    attr_reader :info

    def initialize(attribute_name_index, attribute_length, info)
      @attribute_name_index = attribute_name_index
      @attribute_length = attribute_length
      @info = info
    end
  end

  class Method
    # @return [Integer]
    attr_reader :access_flags

    # @return [Integer]
    attr_reader :name_index

    # @return [Integer]
    attr_reader :descriptor_index

    # @return [Integer]
    attr_reader :attributes_count
    # @return [Array<Attributes>]
    attr_reader :attributes

    def initialize(access_flags, name_index, descriptor_index, attributes_count, attributes)
      @access_flags = access_flags
      @name_index = name_index
      @descriptor_index = descriptor_index
      @attributes_count = attributes_count
      @attributes = attributes
    end
  end
end

reader = Reader.new(File.read("#{ARGV[0]}.class"))

# parse magic
magic = reader.read(4)
raise "magic is not found #{magic.inspect}" if magic != "\xCA\xFE\xBA\xBE".b

# parse version
reader.read_u2 # major
reader.read_u2 # minor

# parse constant pool
constant_pool_count = reader.read_u2

constant_pool = [nil]
(1...constant_pool_count).each do
  tag = reader.read_u1
  case tag
  when ClassFile::Constant::TAG_CLASS
    constant_pool << ClassFile::Constant::Class.new(reader.read_u2)
  when ClassFile::Constant::TAG_FIELDREF
    constant_pool << ClassFile::Constant::Fieldref.new(reader.read_u2, reader.read_u2)
  when ClassFile::Constant::TAG_METHODREF
    constant_pool << ClassFile::Constant::Methodref.new(reader.read_u2, reader.read_u2)
  when ClassFile::Constant::TAG_NAMEANDTYPE
    constant_pool << ClassFile::Constant::NameAndType.new(reader.read_u2, reader.read_u2)
  when ClassFile::Constant::TAG_STRING
    constant_pool << ClassFile::Constant::String.new(reader.read_u2)
  when ClassFile::Constant::TAG_UTF8
    length = reader.read_u2
    bytes = reader.read(length)
    constant_pool << ClassFile::Constant::Utf8.new(length, bytes)
  else
    raise "undefined constant tag: #{tag}"
  end
end

access_flags = reader.read_u2
reader.read_u2 # this class
reader.read_u2 # super class
_interfaces_count = reader.read_u2
_field_count = reader.read_u2

method_count = reader.read_u2
methods = method_count.times.map do
  access_flags = reader.read_u2
  name_index = reader.read_u2
  descriptor_index = reader.read_u2
  attributes_count = reader.read_u2
  attributes = attributes_count.times.map { reader.read_attrs }
  ClassFile::Method.new(access_flags, name_index, descriptor_index, attributes_count, attributes)
end

attributes_count = reader.read_u2
attributes = attributes_count.times.map { reader.read_attrs }

class_file = ClassFile.new(constant_pool, methods, attributes)

# find main method
main_method = class_file.methods.find do |method|
  constant_pool[method.name_index].bytes == 'main'
end

raise 'main method is not found' if main_method.nil?

# read code attribute
code_attribute = main_method.attributes.find do |attrs|
  constant_pool[attrs.attribute_name_index].bytes == 'Code'
end

raise 'code attribute of main method is not found' if code_attribute.nil?

main_reader = Reader.new(code_attribute.info)

main_reader.read_u2 # max stack
main_reader.read_u2 # max locals
code_length = main_reader.read_u4
code = main_reader.read(code_length)
_exception_table_length = main_reader.read_u2
main_attributes_count = main_reader.read_u2
main_attributes_count.times.map { main_reader.read_attrs } # attributes of main

# initialize builtin classes
classes = {
  'java.lang.System' => {
    'out' => {
      'println' => ->(*args) { puts(args.first.bytes) }
    }
  }
}

# run main method
stack = []
code_reader = Reader.new(code)
loop do
  op_code = code_reader.read_u1
  case op_code
  when ClassFile::OP_GETSTAITC
    stack.push(constant_pool[code_reader.read_u2])
  when ClassFile::OP_LDC
    stack.push(constant_pool[constant_pool[code_reader.read_u1].string_index])
  when ClassFile::OP_INVOKEVIRTUAL
    cp_info = constant_pool[code_reader.read_u2]
    name_and_type = constant_pool[cp_info.name_and_type_index]

    method_name = constant_pool[name_and_type.name_index].bytes
    descriptor = constant_pool[name_and_type.descriptor_index].bytes

    method_args = (descriptor.split(';').size - 1).times.with_object([]) do |_, args|
      args.push(stack.pop)
    end

    context = stack.pop
    base_class = constant_pool[constant_pool[context.class_index].name_index].bytes
    base_class_target = constant_pool[constant_pool[context.name_and_type_index].name_index].bytes
    class_path = base_class.tr('/', '.')
    initiated_class = classes[class_path]
    initiated_class[base_class_target][method_name].call(*method_args)
  when ClassFile::OP_RETURN
    break
  else
    raise "unknown op code: #{op_code}"
  end
end

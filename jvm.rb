require 'stringio'

class ClassFileReader

  #
  # @param [String] class_file_code
  #
  def initialize(class_file_code)
    @io = StringIO.new(class_file_code)
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
    read(2).unpack('n').first
  end

  #
  # @return [Integer]
  #
  def read_u4
    read(4).unpack('N').first
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
      attr_reader :descripor_index

      def initialize(name_index, descripor_index)
        super(TAG_NAMEANDTYPE)
        @name_index = name_index
        @descripor_index = descripor_index
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

reader = ClassFileReader.new(File.read("#{ARGV[0]}.class"))

# parse magic
magic = reader.read(4)
raise "magic is not found #{magic.inspect}" if magic != "\xCA\xFE\xBA\xBE".b

# parse version
major = reader.read_u2
minor = reader.read_u2

# parse constant pool
constant_pool_count = reader.read_u2

constant_pool = [nil]
(1...constant_pool_count).each do |i|
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
this_class = reader.read_u2
super_class = reader.read_u2
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

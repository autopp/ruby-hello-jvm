require 'stringio'

class ClassFileReader

  #
  # @param [String] classfile
  #
  def initialize(classfile)
    @io = StringIO.new(classfile)
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
  when Constant::TAG_CLASS
    constant_pool << Constant::Class.new(reader.read_u2)
  when Constant::TAG_FIELDREF
    constant_pool << Constant::Fieldref.new(reader.read_u2, reader.read_u2)
  when Constant::TAG_METHODREF
    constant_pool << Constant::Methodref.new(reader.read_u2, reader.read_u2)
  when Constant::TAG_NAMEANDTYPE
    constant_pool << Constant::NameAndType.new(reader.read_u2, reader.read_u2)
  when Constant::TAG_STRING
    constant_pool << Constant::String.new(reader.read_u2)
  when Constant::TAG_UTF8
    length = reader.read_u2
    bytes = reader.read(length)
    constant_pool << Constant::Utf8.new(length, bytes)
  else
    raise "undefined constant tag: #{tag}"
  end
end

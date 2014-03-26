require 'aws-sdk'
def stub_s3(buckets, access_key_id, secret_access_key)
  stub(AWS::S3).new( 
      :access_key_id => access_key_id,
      :secret_access_key => secret_access_key).returns(FakeS3.new(buckets))
end

class FakeS3
  attr_accessor :buckets

  def initialize(buckets)
    @buckets = FakeS3Collection.new
    buckets.each do |buck|
     @buckets.add(buck[:bucket],  FakeBucket.new(buck[:bucket],buck[:keys], buck[:does_exist]))
    end

  end

end

# class that mocks bucket and s3 object collection
class FakeS3Collection 
  include Enumerable
  attr_accessor :objects
  def initialize 
    @objects = {} 
  end
  def [](key)
    if @objects.has_key?(key)
      return @objects[key]
    else
      return FakeObject.new("", false)
    end
  end

  def add (key, val)
    @objects[key] = val
  end
  
  def with_prefix(prefix)
    res = FakeS3Collection.new
    @objects.keys.each do |key| 
      if key.index(prefix) == 0
        res.add(key, @objects[key])
      end
    end
    return res
  end

  def each(options = {}, &block)
    @objects.keys.each do |key|
      if @objects[key].does_exist
        block.call(@objects[key])
      end
    end
  end

end

 
# Spec class to mock a fake bucket
class FakeBucket
  attr_accessor :name, :keys, :does_exist, :objects

  def initialize(name, keys, does_exist)
    @name = name
    @keys = keys
    @objects = FakeS3Collection.new
    keys.each do |k|
      @objects.add(k.key,k) 
    end
    @does_exist = does_exist
  end
  

  def exists?
    return @does_exist 
  end

end



# Spec class to mock a fake s3 object
class FakeObject
  attr_accessor :key, :does_exist
  def initialize(key, does_exist)
    @key = key
    @does_exist = does_exist
  end 

  def exists?
    @does_exist
  end

  def read
    return "Content #{@key}"
  end
end

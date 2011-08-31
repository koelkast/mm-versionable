class Version
  include MongoMapper::Document

  key :data, Hash
  key :date, Time
  key :pos, Integer, :index => true
  key :doc_id, ObjectId, :index => true
  
  key :updater_id, ObjectId

  key :type, String
  key :event, String

  def content(key)
    cdata = self.data[key]
    if cdata.respond_to?(:join)
      cdata.join(" ")
    else
      cdata
    end
  end 
  
  def user
    return User.find self.updater_id
  end
  
  def get
    unless defined? @klass
      @klass = self.type.constantize.new
      @klass.attributes = self.data
    end
    
    return @klass
  end
  
  def exists?
    !self.type.constantize.find(self.doc_id).nil?
  end
  
end

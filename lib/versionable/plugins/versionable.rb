autoload :Version, 'versionable/models/version'

module Versionable
  extend ActiveSupport::Concern

  module InstanceMethods
    # Save new versions but only if the data changes
    # def save(options={})
    #   save_version(options.delete(:updater_id)) if self.respond_to?(:rolling_back) && !rolling_back
    #   super
    # end

    # def update_attributes(attrs={}, options={})
    #   # save_version(options.delete(:updater_id)) if self.respond_to?(:rolling_back) && !rolling_back
    #   super attrs
    # end

    def save_version(event = :create)
      if self.respond_to?(:versions)
        version = self.current_version
        version.event = event.to_s.downcase
        if self.versions.empty?
          version.pos = 0
        else
          version.pos = self.versions.last.pos + 1
        end
        if self.version_at(self.version_number).try(:data) != version.data
          puts self.class.to_s + " " + event.to_s
          version.type = self.class.to_s
          if defined? User and User.respond_to?(:current)
            version.updater_id = User.current.id
          end
          version.save

          self.versions.shift if self.versions.count >= @limit
          self.versions << version
          self.version_number = version.pos

          @versions_count = @versions_count.to_i + 1
        end
      end
    end
  end

  module ClassMethods
    def enable_versioning(opts={})
      
      after_create :record_create
      before_update :record_update
      after_destroy :record_destroy

      attr_accessor :rolling_back

      key :version_number, Integer, :default => 0
      
      define_method(:record_create) do
        save_version(:create) if self.respond_to?(:rolling_back) && !rolling_back
      end
      
      define_method(:record_update) do
        save_version(:update) if self.respond_to?(:rolling_back) && !rolling_back
      end
      
      define_method(:record_destroy) do
        save_version(:destroy) if self.respond_to?(:rolling_back) && !rolling_back
      end

      define_method(:versions_count) do
        @versions_count ||= Version.count(:doc_id => self._id.to_s)
      end

      define_method(:versions) do
        @limit ||= opts[:limit] || 10
        @versions ||= Version.all(:doc_id => self._id.to_s, :order => 'pos desc', :limit => @limit).reverse
      end

      define_method(:all_versions) do
        Version.where(:doc_id => self._id.to_s).sort(:pos.desc)
      end

      define_method(:rollback) do |*args|
        pos = args.first #workaround for optional args in ruby1.8
        #The last version is always same as the current version, so -2 instead of -1
        pos = self.versions.count-2 if pos.nil?
        version = self.version_at(pos)

        if version
          self.attributes = version.data
        end

        self.version_number = version.pos
        self
      end

      define_method(:rollback!) do |*args|
        pos = args.first #workaround for optional args in ruby1.8
        self.rollback(pos)

        @rolling_back = true
        save!
        @rolling_back = false

        self
      end

      define_method(:diff) do |key, pos1, pos2, *optional_format|
        format = optional_format.first || :html #workaround for optional args in ruby1.8
        version1 = self.version_at(pos1)
        version2 = self.version_at(pos2)

        Differ.diff_by_word(version1.content(key), version2.content(key)).format_as(format)
      end

      define_method(:current_version) do
        data = self.attributes
        data.except(:version_number, :updated_at, :created_at, :something_strange)
        Version.new(:data => data, :date => Time.now, :doc_id => self._id.to_s)
      end

      define_method(:version_at) do |pos|
        case pos
        when :current
          current_version
        when :first
          index = self.versions.index {|v| v.pos == 0}
          version = self.versions[index] if index
          version ||= Version.first(:doc_id => self._id.to_s, :pos => 0)
          version
        when :last
          #The last version is always same as the current version, so -2 instead of -1
          self.versions[self.versions.count-2]
        when :latest
          self.versions.last
        else
          index = self.versions.index {|v| v.pos == pos}
          version = self.versions[index] if index
          version ||= Version.first(:doc_id => self._id.to_s, :pos => pos)
          version
        end
      end
    end
  end
end

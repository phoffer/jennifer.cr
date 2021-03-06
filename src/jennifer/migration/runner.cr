require "../support"

module Jennifer
  module Migration
    module Runner
      def self.migrate
        Adapter.adapter.ready_to_migrate!
        return if ::Jennifer::Migration::Base::REGISTERED_MIGRATIONS.empty?
        interpolation = {} of String => typeof(Base::REGISTERED_MIGRATIONS[0])
        Base::REGISTERED_MIGRATIONS.each { |m| interpolation[m.version] = m }

        pending = interpolation.keys - Version.all.pluck(:version).map(&.as(String))
        return if pending.empty?
        brocken = Version.where { version.in(pending) }.pluck(:version).map(&.as(String))
        unless brocken.empty?
          puts "Can't run migrations because some of them are older then relase version.\nThey are:"
          brocken.sort.each do |v|
            puts "- #{v}"
          end
          return
        end

        pending.sort.each do |p|
          klass = interpolation[p]
          puts "Migration #{klass}"
          instance = klass.new
          begin
            instance.up
          rescue e
            puts e.message
            puts e.backtrace.join("\n")
            instance.down
            puts "rollbacked"
            raise "described"
          end
          Version.create(version: p)
        end
      rescue e
        puts e.message
        puts e.backtrace.join("\n")
      end

      def self.create
        r = Adapter.adapter_class.create_database
        puts "DB created!"
        r
      end

      def self.drop
        puts Adapter.adapter_class.drop_database
        puts "DB droped"
      end

      def self.rollback(options : Hash(Symbol, DBAny))
        Adapter.adapter.ready_to_migrate!
        return if ::Jennifer::Migration::Base::REGISTERED_MIGRATIONS.empty? || !Version.all.exists?
        interpolation = {} of String => typeof(Base::REGISTERED_MIGRATIONS[0])
        Base::REGISTERED_MIGRATIONS.each { |m| interpolation[m.version] = m }

        versions =
          if options[:count]?
            Version.all.order(version: :desc).limit(options[:count].to_i).pluck(:version)
          elsif options[:to]?
            v = options[:to].to_s
            Version.all.order(version: :desc).where { version > v }.pluck(:version)
          else
            raise ArgumentError.new
          end

        versions.each do |v|
          klass = interpolation[v]
          klass.new.down
          Version.all.where { version.eq(v) }.limit(1).delete
          puts "Droped migration #{v}"
        end
      rescue e
        puts e.message
      end

      def self.generate(name)
        time = Time.now.to_s("%Y%m%d%H%M%S%L")
        migration_name = name.camelcase + time
        str = "class #{migration_name} < Jennifer::Migration::Base\n  def up\n  end\n\n  def down\n  end\nend\n"
        File.write(File.join(Config.migration_files_path.to_s, "#{time}_#{name.underscore}.cr"), str)
        puts "Migration #{migration_name} was generated"
      rescue e
        puts e.message
      end
    end
  end
end

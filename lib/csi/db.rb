# -*- conding: utf-8 -*-

module Csi
  module Db
    # require するDBライブラリ名
    BUNDLED_DRIVERS = %w(oracle postgresql mssql)

    ConnectorSpec = Struct.new(:types, :description, :connection_class)

    # DBアダプタのベースクラス
    class Connection
      @@specs = []
      @@spec_map_by_type = {}

      def self.new_connection(type)
        cs = @@spec_map_by_type[type] or raise "Unknown DB type '#{type}'"
        cs.connection_class.new
      end

      def self.connect(type, connstr, user, pass)
        new_connection(type).tap do |c|
          c.connect(connstr, user, pass)
        end
      end

      def self.add_factory(types, description)
        types = Array(types)
        spec = ConnectorSpec.new(types, description, self)
        @@specs << spec
        registered_types = []
        types.each do |type|
          next if @@spec_map_by_type[type]
          @@spec_map_by_type[type] = spec
          registered_types << type
        end
        spec.types = registered_types
      end

      def self.specs
        @@specs
      end

      def not_supported(*argv)
        puts "`#{__callee__}` is not suppored (#{self.class})"
      end

      ## default implementation

      # connect to DB server
      alias :connect :not_supported
      # disconnect from DB server
      alias :close :not_supported
      # send query to server and receive result
      alias :query :not_supported
      # receive list of available tables
      alias :tables :not_supported
      # receive description of a specified table
      alias :describe :not_supported

      # Additional commands specific to DB connection
      def commands
        []
      end
    end

    class DummyConnection < Connection
      add_factory 'dummy', 'No connect, no query.'
    end

    module_function
    def load_drivers
      begin
        BUNDLED_DRIVERS.each do |d|
          require "csi/db/#{d}"
        end
      rescue LoadError
        STDERR.puts "DB driver load error: #$!"
      end
    end
  end
end

# vim:set ts=2 sw=2 et:


module Csi
  module Db
    class MsConnection < Connection
      add_factory %w(mssql), "MS SQL Server, SQL Database(Azure) Connector"

      def initialize
        require 'tiny_tds'
      rescue LoadError
        raise "Required tiny_tds library is not found. Try 'gem install tiny_tds'."
      end

      def connect(connstr, user, pass)
        host, port, dbname = parse_connstr(connstr)

        azure = (/database\.windows\.net$/ =~ host) ? true : false

        @ttds = TinyTds::Client.new(username: user, password: pass, host: host,
                    port: port, database: dbname, azure: azure)
      end

      def parse_connstr(connstr)
        connparts = connstr.split('/')
        raise "illegal dburl(too many '/'): #{connstr}" if connparts.size > 2
        hostparts = connparts[0].split(':')
        raise "illegal dburl(too many ':'): #{connstr}" if hostparts.size > 2
        return hostparts[0], hostparts[1], connparts[1]
      end

      def exec(sql)
        @ttds.execute sql
      end

      def query(sql)
        MsResult.new exec(sql)
      end

      def tables
        query <<EOS
	SELECT SCHEMA_NAME(schema_id) AS schema_name, name AS table_name 
	FROM sys.tables 
	ORDER BY schema_name, table_name;
EOS
      end

      def describe(obj)
        query <<EOS
SELECT  T.name AS "table", C.name AS "column", U.name AS "type",
        C.max_length as size, IC.index_column_id AS pkey_index,
        C.is_nullable as nullable
FROM      sys.columns       AS C
JOIN      sys.tables        AS T ON C.object_id = T.object_id
JOIN      sys.types         AS U ON C.user_type_id = U.user_type_id
LEFT JOIN sys.indexes       AS I ON C.object_id = I.object_id AND I.is_primary_key = 1
LEFT JOIN sys.index_columns AS IC ON C.object_id = IC.object_id AND C.column_id = IC.column_id AND I.index_id = IC.index_id
WHERE    T.name = '#{obj}'
ORDER BY C.column_id;
EOS
      end

      def close
        @ttds.close if @ttds && !@ttds.closed?
        @ttds = nil
      end
    end
    class MsResult
      def initialize(result)
        @tres = result
      end

      def columns
        @tres.fields
      end

      def size
        @tres.affected_rows
      end

      def each
        @tres.each do |row|
          yield row.values
        end
      end
    end
  end
end


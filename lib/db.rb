# -*- conding: utf-8 -*-


module Csi
  module Db
    class OracleConnection < Connection
      add_factory %w(oracle-oci8 oracle), "Oracle connector using Ruby-OCI8"

      def initialize
        begin
          require 'oci8'
        rescue LoadError
          raise "Required ruby-oci8 library is not found. Try 'gem install ruby-oci8'."
        end
      end

      def connect(connstr, user, pass)
          @ora = OCI8.new(user, pass, connstr)
      end

      def exec(sql)
        @ora.exec(sql)
      end

      def query(sql)
        res = @ora.exec(sql)
        if res.is_a?(OCI8::Cursor)
          OracleCursor.new res
        else
          res
        end
      end

      def close
        @ora.logoff if @ora
        @ora = nil
      end

      def describe(object, type = nil)
        OracleColumns.new @ora.describe_table(object)
      end
    end

    class OracleColumns
      def initialize(table_info)
        @table = table_info
      end

      def size
        @table.num_cols
      end

      def columns
        %w{name type}
      end

      def each
        return to_enum unless block_given?
        @table.columns.each do |col|
          yield [col.name, col.type_string]
        end
      end
    end

    class OracleCursor
      def initialize(cur)
        @cursor = cur
      end

      def columns
        @cursor.get_col_names
      end

      def each
        return to_enum unless block_given?
        while r = @cursor.fetch
          yield convert(r)
        end
      end

      def convert(org)
        apdx = nil
        res = org.map do |c|
          case c
          when OCI8::CLOB
            apdx = "---------- <<CLOB>> ----------\n" + c.read
            "<<CLOB>>"
          else
            c
          end
        end
        res.instance_variable_set :@apdx, apdx
        def res.appendix
          @apdx
        end
        res
      end

      def size
        @cursor.row_count
      end
    end

    class PgConnection < Connection
      add_factory %w(postgres postgresql), "PostgreSQL Connector"

      def initialize
        begin
          require 'pg'
        rescue LoadError
          raise "Required pg library is not found. Try 'gem install pg'."
        end
      end

      def connect(connstr, user, pass)
        host, port, dbname = parse_connstr(connstr)
        params = {
          host: host,
          user: user,
          password: pass
        }
        params[:port] = port if port
        params[:dbname] = dbname if dbname

        @pg = PGconn.open(params)
      end

      def parse_connstr(connstr)
        connparts = connstr.split('/')
        raise "illegal dburl(too many '/'): #{connstr}" if connparts.size > 2
        hostparts = connparts[0].split(':')
        raise "illegal dburl(too many ':'): #{connstr}" if hostparts.size > 2
        return hostparts[0], hostparts[1], connparts[1]
      end

      def exec(sql)
        @pg.exec(sql)
      end

      def query(sql)
        res = @pg.exec(sql)
        if res.is_a?(PGresult)
          PgResult.new res
        else
          res
        end
      end

      def close
        @pg.finish if @pg
        @pg = nil
      end
    end

    class PgResult
      def initialize(res)
        @result = res
      end

      def columns
        @result.fields
      end

      def each
        return to_enum unless block_given?
        @result.each do |r|
          yield convert(r.map{|t| t[1]})
        end
      end

      def convert(org)
        org
      end

      def size
        @result.ntuples
      end
    end
  end
end

# vim:set ts=2 sw=2 et:

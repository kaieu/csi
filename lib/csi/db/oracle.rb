# -*- conding: utf-8 -*-

module Csi
  module Db
    class OracleConnection < Connection
      add_factory %w(oracle-oci8 oracle), "Oracle connector using Ruby-OCI8"

      def initialize
        require 'oci8'
      rescue LoadError
        raise "Required ruby-oci8 library is not found. Try 'gem install ruby-oci8'."
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

      def tables(where = "")
        query <<EOS
	SELECT OWNER, TABLE_NAME
	FROM ALL_TABLES
  #{where}
	ORDER BY OWNER, TABLE_NAME
EOS
      end

      def describe(object, type = nil)
        case object
        when /^(\S+)\.\*$/
          tables "WHERE OWNER='#$1'"
        else
          OracleColumns.new @ora.describe_table(object)
        end
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
        res = org.zip(@cursor.column_metadata).map do |e|
          c = e[0]
          m = e[1]
          if c.is_a?(OCI8::CLOB)
            apdx = "---------- <<CLOB>> ----------\n" + c.read
            "<<CLOB>>"
          elsif m.data_type == :raw
            '0x' + c.unpack("H*").first
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
  end
end

# vim:set ts=2 sw=2 et:

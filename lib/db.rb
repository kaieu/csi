# -*- conding: utf-8 -*-

require 'oci8'

module Csi
  module Db
    if defined?(OCI8)
      class OracleConnection < Connection
        add_factory %w(oracle-oci8 oracle), "Oracle connector using Ruby-OCI8"

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
    end

    class PgConnection < Connection
      add_factory %w(postgres postgresql), "PostgreSQL Connector"
    end
  end
end

# vim:set ts=2 sw=2 et:

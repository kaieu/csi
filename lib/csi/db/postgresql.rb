# -*- conding: utf-8 -*-

module Csi
  module Db
    class PgConnection < Connection
      add_factory %w(postgres postgresql), "PostgreSQL Connector"

      def initialize
        require 'pg'
      rescue LoadError
        raise "Required pg library is not found. Try 'gem install pg'."
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

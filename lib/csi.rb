# csi main module

require 'yaml'
require 'optparse'
#require 'io/console'

require 'csi/dataout'
require 'csi/db'

module Csi
  APPNAME = 'csi'
  APPTITLE = "Common SQL interface"

  # Support XDG Base Directory
  xdg_conf_dir = ENV['XDG_CONFIG_HOME'] || File.join(ENV['HOME'], '.config')
  xdg_cache_dir = ENV['XDG_CACHE_HOME'] || File.join(ENV['HOME'], '.cache')

  DEFAULT_CONFS = [
    File.join(ENV['HOME'], '.csi.conf'),
    File.join(xdg_conf_dir, 'csi', 'config'),
    File.join(ENV['HOME'], 'etc', 'csi.conf'),
  ]

  HISTFILE = if File.directory?(xdg_cache_dir)
    File.join(xdg_cache_dir, 'csi', 'history')
  else
    File.join(ENV['HOME'], '.csi_history')
  end

  RESERVED_WORDS = %w(
    SELECT INSERT UPDATE DELETE TRUNCATE EXECUTE COMMIT ROLLBACK BEGIN
    EXPLAIN ANALYZE CREATE DROP DATABASE TABLE COLUMN SYNONYM ALTER
  )

  # コマンド行オプションの定義
  OPTIONS = {
    pagesize: {
      description: 'show header per <pagesize> rows',
      parser_opt: ['--pagesize=size', 'show header per <pagesize> rows', Integer],
      convert: proc{|v| Integer(v)}
    },
    format: {
      description: "output format type (table, detail)",
      parser_opt: ['--format=type', "Format type: table, detal"],
      convert: proc{|v| v}
    },
    ditto: {
      description: "Use ditto mark",
      parser_opt: ['--ditto', 'Use ditto mark'],
      convert: proc{|v| convert_bool(v)}
    },
    quiet: {
      description: "Quiet mode",
      parser_opt: ["-q", "--quiet", "Quiet mode"],
      convert: proc{|v| convert_bool(v)}
    },
    esc: {
      description: "Decorate with escape sequence",
      parser_opt: ["--esc", "Use escape sequence to decorate output"],
      convert: proc{|v| convert_bool(v)}
    },
  }

  def self.convert_bool(v)
    case v
    when "", nil, "0", "false", "no"
      false
    else
      true
    end
  end

  # 設定ファイル
  module Config
    module_function

    def validate_dbconfs(conf)
      return {} if conf.nil? # allow empty setting

      abort "CONF ERROR: database configuration is not mapping" unless conf.is_a?(Hash)

      invalid = {}
      conf.each do |dbkey, val|
        val ||= {}
        missing = %w(type dburl dbuser dbpass).select{|f| val[f].nil?}
        invalid[dbkey] = missing if missing.size > 0
      end
      invalid.each do |dbkey, missing|
        $stderr.puts "CONF ERROR: database '#{dbkey}' not loaded " +
            "because of missing parameters; " + missing.join(",")
      end
      conf.reject{|k, v| invalid.include?(k)}
    end

    # 設定ファイルを読み込んで :dbconfs, :aliases, :pager を持つハッシュを返す
    def load_rc(*files)
      rc = {}
      loaded = 0
      files.each do |file|
        yaml = YAML.load_file(file)
        aliases = {}
        yaml["sqlalias"] and yaml["sqlalias"].each do |k, v|
          aliases['\\' + k] = v
        end
        rc[:dbconfs]     = validate_dbconfs(yaml["database"])
        rc[:aliases]     = aliases
        rc[:pager]       = yaml["pager"]
        rc[:environment] = yaml["environment"]
        loaded += 1
      end
      rc
    rescue Errno::ENOENT
      raise if loaded == 0
      rc
    end
  end

  # 実行環境
  class Environment
    attr_accessor :conn, :out, :use_pager, :pager, :commands, :aliases, :opts
    attr_accessor :vars, :history, :dbspec, :tmp_out
    def initialize
      reset
    end
    def reset
      @out       = STDOUT
      @use_pager = false
    end
  end

  # 1行入力処理クラス
  class LineInput
    def setup_readline
      begin
        require 'readline'
        if File.exist?(HISTFILE)
          File.readlines(HISTFILE).each do |line|
            Readline::HISTORY << line.chomp
          end
        end
      rescue LoadError
        STDERR.puts "(readline disabled)"
      end
    end

    def getline(prompt)
      r = if defined?(Readline)
        Readline.readline(prompt, true)
      else
        print prompt
        gets
      end
      return r.chomp if r
      puts # for command line
      r
    end

    def add_to_history(item)
      return unless defined?(Readline)
      Readline::HISTORY.push item
    end

    def save
      return unless defined?(Readline)
      history_reverse_map = {}
      Readline::HISTORY.reverse_each do |line|
        history_reverse_map[line] = line
      end
      File.open(HISTFILE, "w") do |f|
        history_reverse_map.values.reverse_each do |line|
          f.puts line
        end
      end
    end
  end

  # SQL文パース処理
  class SqlSlicer
    def initialize
      @buff = []
    end

    def search_delim(line, delim = ";")
      quote = nil
      line.each_char.with_index do |c, i|
        if quote
          quote = nil if c == quote
        elsif c == '"' || c == "'"
          quote = c
        elsif c == delim
          return i
        end
      end
      nil
    end

    def sweep(&b)
      statement = @buff.join("\n")
      b.call statement unless statement.empty?
      @buff = []
    end

    # 各DB固有のストアドプロシージャのように、csi がSQLで1文として扱えない構造の
    # スクリプトの範囲を明示するためのキーワード
    BLOCK_BEGIN_KEYS = %w(\begin --begin)
    BLOCK_END_KEYS = %w(\end --end)

    # 引数newlineを内部バッファに連結し、SQLの1文単位でblockを呼ぶ
    def slice_statement(newline, &b)
      while newline
        if empty? && BLOCK_BEGIN_KEYS.include?(newline)
          @in_block = true
          newline = nil
        elsif @in_block && BLOCK_END_KEYS.include?(newline)
          sweep(&b)
          @in_block = false
          newline = nil
        elsif @in_block
          @buff << newline
          newline = nil
        elsif pos = search_delim(newline)
          @buff << newline[0, pos]
          sweep(&b)
          newline = newline[(pos + 1) .. -1]
        else
          @buff << newline if /^\s*$/ !~ newline
          newline = nil
        end
      end
    end

    def empty?
      @buff.empty? && !@in_block
    end
  end

  class Action
    def initialize(type, &b)
      @type = type
      @proc = b
    end

    def query?
      @type == :query
    end

    def call(*a, &b)
      @proc.call *a, b
    end
  end

  # コマンド入力処理
  class Cui
    PROMPT  = APPNAME + "> "
    PROMPT2 = " " * APPNAME.size + "> "

    class Exit < Exception; end

    attr_accessor :complement_proc
    attr_accessor :prompt
    attr_accessor :prompt2

    def initialize(controller, interactive)
      @controller = controller
      @input = LineInput.new
      @input.setup_readline if interactive

      @prompt = PROMPT
      @prompt2 = PROMPT2

      @inbuf = SqlSlicer.new
    end

    def finalize
      @input.save
    end

    def complement(s)
      complement_proc ? complement_proc.call(s) : s
    end

    def getline(prompt)
      @input.getline prompt
    end

    # 表示環境を整えてから、表示用IOオブジェクト付きでブロックを実行する。
    # 表示環境では、ページャ使用(use_pager)が有効ならページャ経由で起動。
    # また、例外はキャッチされ画面に出して戻る。
    def display_environment(env)
      if env.use_pager
        IO.popen(env.pager, "w") do |io|
          env.out = io
          yield env rescue Errno::EPIPE
        end
      else
        env.out = STDOUT
        yield env
      end
    rescue Interrupt
      puts
    rescue Exception => e
      STDERR.puts "ERROR: #{e}"
      STDERR.puts e.backtrace
    end

    def process_commands(env, inp)
      cmds = env.conn.commands + env.commands
      cmds.each do |cmd|
        next unless cmd[:key] === inp
        res = cmd[:proc].call(@controller, env, inp)
        if res.is_a?(Hash)
          if res[:input]
            inp = res[:input]
          elsif res[:after] == :exit
            raise Exit
          elsif res[:action]
            return res[:action]
          else
            return nil
          end
        else
          return nil
        end
      end
      inp
    end

    def process_alias(env, inp)
      parts = inp.split(/\s+/)
      if env.aliases[parts.first]
        idx = 0
        inp = env.aliases[parts.first].gsub(/\?/) do
          idx += 1
          parts[idx]
        end
      end
      inp
    end

    def command_loop(env)
      inp = @input.getline(@inbuf.empty? ? @prompt : @prompt2)
      return true if /^\s*$/ =~ inp
      env.reset

      inp = process_commands(env, inp) or return true
      if inp.is_a?(Action)
        display_environment(env) do |env|
          yield env, inp
        end
        return true
      end
      inp = process_alias(env, inp)    if @inbuf.empty?
      inp = complement(inp)            if @inbuf.empty?

      @inbuf.slice_statement(inp) do |sql|
        display_environment(env) do |env|
          env.history << sql
          yield env, sql
        end
      end
      true
    rescue Interrupt
      #puts "(interrupted)"
      #false
      puts
      true
    rescue Exit
      false
    end
  end

  class BlackHole
    def method_missing(*arg)
    end
  end

  class Controller

    class DbChangeRequest < Exception
      attr_reader :dbspec
      def initialize(dbspec = nil)
        @dbspec = dbspec
      end
    end

    # コマンド定義
    # key:   コマンド入力行とマッチさせるキー(コマンド名)。===で比較する。
    # name:  key の代わりにヘルプに出すコマンド名 (keyがnilや正規表現などの場合)
    # desc:  ヘルプに出す説明文
    # proc:  コマンド処理ブロック。引数は Controller, Environment, 入力行文字列
    #        結果としてハッシュを返すと後続の処理をコントロールできる。
    # alias: 他のコマンドの別名とする場合、そのコマンドのキーを指定する。
    COMMANDS = [
      { key: '\q',
        desc: "Exit #{APPNAME}",
        proc: proc{{after: :exit}},
      },
      { key:  nil, name: 'C-d', alias: '\q', },
      { key: /^\\c\b/,
        name: '\c [dbspec]',
        desc: 'Change connection to database',
        proc: proc{|ctrl, env, inp|
          /^\\c *(\S+)/ =~ inp
          raise DbChangeRequest, $1
        },
      },
      { key: /\\h\b/,
        name: '\h',
        desc: "Show this help",
        proc: proc{|ctrl, env| ctrl.show_help env},
      },
      { key:  /^null / ,
        name: 'null <cmd>',
        desc: "Output to null",
        proc: proc{|ctrl, env, inp|
          env.tmp_out = BlackHole.new
          { input: inp[5..-1] }
        },
      },
      { key:  /^lv\b/ ,
        name: 'lv <cmd>',
        desc: "Use pager for trailing command",
        proc: proc{|ctrl, env, inp|
          env.use_pager = true
          { input: inp[3..-1] }
        },
      },
      { key: /^\\opt\b/,
        name: '\opt [<var>=<value>]',
        desc: 'show/set option',
        proc: proc{|ctrl, env, inp|
          case inp
          when /^\\opt ([a-z]+)=(.*)$/
            puts "OPTION: #$1 = #$2"
            key = $1.to_sym
            env.opts[key] = OPTIONS[key][:convert].call($2)
          when /^\\opt\s*$/
            env.opts.each do |k, v|
              puts "#{k} = #{v}"
            end
          else
            puts "ERROR: illegal option format"
          end
        },
      },
      { key: '/',
        desc: 'last query',
        proc: proc{|ctrl, env, inp|
          if env.history.empty?
            STDERR.puts "no sql history"
          else
            { input: env.history.last + ";" }
          end
        },
      },
      { key: /^\\d\s*/,
        name: '\d [object name]',
        desc: 'describe schema object(table) or list them (if no params)',
        proc: proc{|ctrl, env, inp|
          if /^\\d\s*(.*)$/ =~ inp
            table = $1
            if table && !table.empty?
              { action: Action.new(:query) {|env| env.conn.describe(table) } }
            else
              { action: Action.new(:query) {|env| env.conn.tables } }
            end
          else
            STDERR.puts "object name needed"
          end
        },
      },
      { key: /^\\his\b/,
        name: '\his',
        desc: 'show sql history',
        proc: proc{|ctrl, env, inp|
          case inp
          when /^\\his\s+(\d+)$/
            puts "his: #$1"
          when /^\\his\s*$/
            env.history.each do |h|
              puts h
            end
          else
            puts "ERROR: illegal option format"
          end
        },
      },
    ]

    def initialize
      COMMANDS.map! do |org|
        if a = org[:alias] and als = COMMANDS.find{|c| c[:key] == a}
          org.delete :alias
          als.merge org
        else
          org
        end
      end
    end

    def query_action(sql, opts)
      Action.new(:query) do |env|
        io = env.out
        io.puts "Query: #{sql}" unless opts[:quiet]
        begin
          res = env.conn.query(sql)
        rescue
          if $!.respond_to?(:parseErrorOffset)
            io.puts " " * ($!.parseErrorOffset + 7) + "^"
          end
          io.puts "Error: #$!"
        end
      end
    end

    def eval_print(env, act, opts)
      act = query_action(act, opts) if act.is_a?(String) 

      start = Time.now
      res = act.call(env)
      elapsed = Time.now - start
      return unless act.query?

      io = env.out
      unless res.respond_to?(:columns)
        io.puts "Result: #{res} in #{elapsed} sec" unless opts[:quiet]
        return
      end
      io.puts "Query returned in #{elapsed} sec" unless opts[:quiet]
      output_class = DataOut::Output.types[env.opts[:format] || "table"]
      output_class.new(env.tmp_out || io, env.opts).display res.columns, res
      env.tmp_out = nil
      io.puts "#{res.size} row(s)" unless opts[:quiet]
      io.puts unless opts[:quiet]
    end

    def to_key(v)
      return nil if v.nil?
      v.chomp!
      Integer(v) rescue v
    end

    def manual_conf(cui)
      {
        'type'   => cui.getline("db type = "),
        'dburl'  => cui.getline("db connection string = "),
        'dbuser' => cui.getline("user = "),
        'dbpass' => cui.getline("password = "),
      }
    end

    def commandline_connection_select(dbconfs, opts)
      dbspec = opts[:dbspec]
      if /^([^:]+):([-_a-zA-Z0-9]+)@(.+)$/ =~ dbspec
        conf = {
          'type'   => $1,
          'dburl'  => $3,
          'dbuser' => $2,
          'dbpass' => opts[:password],
        }
        p conf
        conf['dbpass'] ||= conf['dbuser']
        dbspec = conf['dbuser'] # + '@' + conf['dburl']
        return dbspec, conf
      end
      return to_key(dbspec), dbconfs[dbspec]
    end

    def show_dbconfs(dbconfs, opts)
      header = ["key", "type", "connection string", "user"]
      records = [["0", "manual", "manual", "manual"]] +
        dbconfs.map{|e| k, v = *e; [k, v['type'], v['dburl'], v['dbuser']] }
      DataOut::TableOutput.new(STDOUT, opts).display header, records
    end

    def interactive_connection_select(dbconfs, opts, cui)
      show_dbconfs dbconfs, opts
      while true
        sel = to_key(cui.getline("Choose DB key> "))
        if sel == 0
          dbspec = ""
          conf   = manual_conf(cui)
          return nil, conf
        end
        exit unless sel
        if dbconfs[sel]
          return sel, dbconfs[sel]
        end
      end
    end

    def embed_vars(conf, cui)
      var_names = conf.values.grep(/\$\{(\w+)\}/){$1}.sort.uniq
      vars = {}
      var_names.each do |name|
        vars[name] = cui.getline("Var #{name}:")
      end
      vars.each do |vname, vvalue|
        conf.each do |cname, cvalue|
          cvalue.gsub! /\$\{#{vname}\}/, vvalue
        end
      end
    end

    def select_connection(env, dbconfs, cui, opts = {})
      opts = env.opts.merge(opts)
      if opts[:dbspec]
        dbspec, conf = commandline_connection_select(dbconfs, opts)
      else
        dbspec, conf = interactive_connection_select(dbconfs, opts, cui)
      end
      abort "DB configuration error" unless conf

      embed_vars conf, cui if conf

      begin
        env.conn = Db::Connection.connect(conf['type'], conf['dburl'],
                                          conf['dbuser'], conf['dbpass'])
        env.dbspec = dbspec
        unless opts[:quiet]
          STDERR.puts "connected: #{conf['dbuser']}@#{conf['dburl']} (#{conf['type']})"
          STDERR.puts
        end
      rescue
        abort "CONNECT ERROR: #$!"
      end
    end

    def show_help(env)
      DataOut::TableOutput.new(STDOUT, env.opts).display ['command', 'description'],
        env.commands.map{|c| [c[:name] || c[:key], c[:desc]]} +
        env.aliases.map{|k, v| [k, v]}
    end

    def complement_sql(sql)
      if /\A\s*([A-Za-z0-9_,]+)\s*\z/ =~ sql && !RESERVED_WORDS.include?($1.upcase)
        "SELECT * FROM #{$1.split(/,/).join(" NATURAL JOIN ")};"
      elsif /^\s*\[(.+)\]\s*$/ =~ sql
        case $1
        when /^\s*(.+)\s+in\s+(.+)\s+if\s+(.+)\s*$/i
          "SELECT #$1 FROM #$2 WHERE #$3;"
        when /^\s*(.+)\s+in\s+(.+)\s*$/i
          "SELECT #$1 FROM #$2;"
        when /^\s*(.+)\s*$/
          "SELECT * FROM #$1;"
        end
      else
        sql
      end
    end

    def list_dbtypes
      puts "Supported DB types:"
      Db.load_drivers
      DataOut::TableOutput.new.display ["type names", "description"],
        Db::Connection.specs.map{|s| [s.types.join(", "), s.description]}
    end

    def search_conffile(specified)
      if specified
        unless File.exist?(specified)
          abort "#{specified} is not found."
        end
        return specified
      end
      DEFAULT_CONFS.each do |conffile|
        return conffile if File.exist?(conffile)
      end
      return nil
    end

   def load_conf(opts)
      conffile = search_conffile(opts[:configfile])
      abort "no config file found" unless conffile
      rc = Config.load_rc(conffile, conffile + ".shadow")
      opts[:configfile] = conffile
      rc
    end

    def setup(rc, opts)
      if rc[:environment]
        rc[:environment].each do |k, v|
          ENV[k] = v
        end
      end
      Db.load_drivers

      cui = Cui.new(self, opts[:interactive])
      cui.complement_proc = proc{|s| complement_sql s}
      env = Environment.new.tap do |e|
        e.commands = COMMANDS
        e.aliases  = rc[:aliases]
        e.pager    = rc[:pager]
        e.opts     = opts
        e.history  = []
      end
      select_connection env, rc[:dbconfs], cui, opts

      return env, cui
    end

    def batch_exec(scripts, env, opts)
      scripts.each do |script|
        if script[:file]
          inbuf = SqlSlicer.new
          File.read(script[:file]).lines.each do |l|
            inbuf.slice_statement(l.chomp) do |sql|
              eval_print env, sql, opts
            end
          end
          inbuf.sweep do |sql|
            eval_print env, sql, opts
          end
        end
        if script[:sql]
          eval_print env, complement_sql(script[:sql]).gsub(";", ""), opts
        end
      end
    rescue Errno::EPIPE
      STDERR.puts "#{APPNAME}: broken pipe"
    end

    def command_loop(env, cui, rc, opts)
      cui.prompt = (env.dbspec || APPNAME) + "> "
      cui.command_loop env do |env, sql|
        eval_print env, sql, opts
      end
    rescue DbChangeRequest => e
      env.conn.close
      select_connection env, rc[:dbconfs], cui, dbspec: e.dbspec
      true
    end

    def main(opts)
      STDERR.puts APPNAME + " - " + APPTITLE unless opts[:quiet]

      if opts[:type_list]
        list_dbtypes
        return
      end

      rc = load_conf(opts)
      if opts[:dbconf_list]
        show_dbconfs rc[:dbconfs], opts
        return
      end

      env, cui = setup(rc, opts)

      unless opts[:script].empty?
        batch_exec opts[:script], env, opts
        return
      end

      STDERR.puts "\\h for help" unless opts[:quiet]
      while true
        command_loop env, cui, rc, opts or break
      end
    ensure
      env.conn.close if env && env.conn
      cui.finalize if cui
    end
  end

  def self.parse_esql(esql)
    cond = nil
    esql.sub!(/\s*\[\s*(.*)\s*\]/) do
      ph = $1
      case ph
      when /^\s*(order by|group by|having|where)/i
        cond = ph
      when /\S/
        cond = "WHERE #{ph}"
      end
      ''
    end

    sel = "*"
    esql.sub!(/\s*->\s*(.+)\s*$/) do
      sel = $1
      ''
    end

    esql.gsub!(/(\+?)\((.+)\)\s*(\S+)/) do
      plus = $1
      key = $2
      table = $3
      (plus == '+' ? 'LEFT OUTER' : 'INNER') +
      ' JOIN '+ table +
      (/=/ =~ key ? " ON #{key}" : " USING (#{key})")
    end

    "SELECT #{sel} FROM #{esql} #{cond}"
  end

  def self.parse_argv(argv)
    {}.tap do |opts|
      opts[:script] = []
      OptionParser.new do |op|
        op.on('-c config', '--config=config', "Specify config file") do |config|
          opts[:configfile] = config
        end
        op.on('-f script-file', "SQL Script file") do |file|
          opts[:script] << {:file => file}
        end
        op.on('-d dbspec', "Specify DB by key or DB-spec") do |db|
          opts[:dbspec] = db
        end
        op.on('-p password', "Login password (when '-d' used)") do |pass|
          opts[:password] = pass
        end
        op.on('-e sql', "Specify SQL to be executed") do |sql|
          opts[:script] << {:sql => sql}
        end
        op.on('-E extended sql') do |esql|
          opts[:script] << {:sql => parse_esql(esql)}
        end
        op.on('-L', '--dbtypes', "Show all available db type") do
          opts[:type_list] = true
        end
        op.on('-l', '--dbconfs', "Show all db configurations") do
          opts[:dbconf_list] = true
        end
        op.on('--clob', "Clob detail mode") do
          opts[:appendix] = true
          opts[:pagesize] = 1
        end
        op.on('--count table', "SELECT COUNT(*) FROM table") do |t|
          opts[:script] << {sql: "SELECT COUNT(*) FROM #{t}"}
        end
        op.on('--truncate table', "TRUNCATE TABLE table") do |t|
          opts[:script] << {sql: "TRUNCATE TABLE #{t}"}
        end
        OPTIONS.each do |key, conf|
          next unless conf[:parser_opt]
          op.on(*conf[:parser_opt]) do |val|
            opts[key] = conf[:convert].call(val)
          end
        end
        op.parse! argv
      end

      opts[:interactive] = opts[:script].empty?
    end
  end

  def self.main(argv)
    Controller.new.main parse_argv(argv)
  rescue OptionParser::ParseError => e
    puts "#$0: #{e}"
    exit 1
  end
end

# vim:set ts=2 sw=2 et ft=ruby:

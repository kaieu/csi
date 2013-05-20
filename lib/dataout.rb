# -*- coding: utf-8 -*-

require 'bigdecimal'

class UnicodeEastAsianWidth
  MAPPING = [
    0x0000, :N, 0x0020, :Na, 0x007F, :N, 0x00A1, :A, 0x00A2, :Na, 0x00A4, :A,
    0x00A5, :Na, 0x00A7, :A, 0x00A9, :N, 0x00AA, :A, 0x00AB, :N, 0x00AC, :Na,
    0x00AD, :A, 0x00AF, :Na, 0x00B0, :A, 0x00B5, :N, 0x00B6, :A, 0x00BB, :N,
    0x00BC, :A, 0x00C0, :N, 0x00C6, :A, 0x00C7, :N, 0x00D0, :A, 0x00D1, :N,
    0x00D7, :A, 0x00D9, :N, 0x00DE, :A, 0x00E2, :N, 0x00E6, :A, 0x00E7, :N,
    0x00E8, :A, 0x00EB, :N, 0x00EC, :A, 0x00EE, :N, 0x00F0, :A, 0x00F1, :N,
    0x00F2, :A, 0x00F4, :N, 0x00F7, :A, 0x00FB, :N, 0x00FC, :A, 0x00FD, :N,
    0x00FE, :A, 0x00FF, :N,
    0x0101, :A, 0x0102, :N, 0x0111, :A, 0x0112, :N, 0x0113, :A, 0x0114, :N,
    0x011B, :A, 0x011C, :N, 0x0126, :A, 0x0128, :N, 0x012B, :A, 0x012C, :N,
    0x0131, :A, 0x0134, :N, 0x0138, :A, 0x0139, :N, 0x013F, :A, 0x0143, :N,
    0x0144, :A, 0x0145, :N, 0x0148, :A, 0x014C, :N, 0x014D, :A, 0x014E, :N,
    0x0152, :A, 0x0154, :N, 0x0166, :A, 0x0168, :N, 0x016B, :A, 0x016C, :N,
    0x01CE, :A, 0x01CF, :N, 0x01D0, :A, 0x01D1, :N, 0x01D2, :A, 0x01D3, :N,
    0x01D4, :A, 0x01D5, :N, 0x01D6, :A, 0x01D7, :N, 0x01D8, :A, 0x01D9, :N,
    0x01DA, :A, 0x01DB, :N, 0x01DC, :A, 0x01DD, :N,
    0x0251, :A, 0x0252, :N, 0x0261, :A, 0x0262, :N, 0x02C4, :A, 0x02C5, :N,
    0x02C7, :A, 0x02C8, :N, 0x02C9, :A, 0x02CC, :N, 0x02CD, :A, 0x02CE, :N,
    0x02D0, :A, 0x02D1, :N, 0x02D8, :A, 0x02DC, :N, 0x02DD, :A, 0x02DE, :N,
    0x02DF, :A, 0x02E0, :N,
    0x0300, :A, 0x0370, :N, 0x0391, :A, 0x03AA, :N, 0x03B1, :A, 0x03C2, :N,
    0x03C3, :A, 0x03CA, :N,
    0x0401, :A, 0x0402, :N, 0x0410, :A, 0x0450, :N, 0x0451, :A, 0x0452, :N,

    0x1100, :W, 0x1160, :N, 0x11A3, :W, 0x11A8, :N, 0x11FA, :W, 0x1200, :N,

    0x2010, :A, 0x2011, :N, 0x2013, :A, 0x2017, :N, 0x2018, :A, 0x201A, :N,
    0x201C, :A, 0x201E, :N, 0x2020, :A, 0x2023, :N, 0x2024, :A, 0x2028, :N,
    0x2030, :A, 0x2031, :N, 0x2032, :A, 0x2034, :N, 0x2035, :A, 0x2036, :N,
    0x203B, :A, 0x203C, :N, 0x203E, :A, 0x203F, :N, 0x2074, :A, 0x2075, :N,
    0x207F, :A, 0x2080, :N, 0x2081, :A, 0x2085, :N, 0x20A9, :H, 0x20AA, :N,
    0x20AC, :A, 0x20AD, :N,
    0x2103, :A, 0x2104, :N, 0x2105, :A, 0x2106, :N, 0x2109, :A, 0x210A, :N,
    0x2113, :A, 0x2114, :N, 0x2116, :A, 0x2117, :N, 0x2121, :A, 0x2123, :N,
    0x2126, :A, 0x2127, :N, 0x212B, :A, 0x212C, :N, 0x2153, :A, 0x2155, :N,
    0x215B, :A, 0x215F, :N, 0x2160, :A, 0x216C, :N, 0x2170, :A, 0x217A, :N,
    0x2189, :A, 0x219A, :N, 0x21B8, :A, 0x21BA, :N, 0x21D2, :A, 0x21D3, :N,
    0x21D4, :A, 0x21D5, :N, 0x21E7, :A, 0x21E8, :N,
    0x2200, :A, 0x2201, :N, 0x2202, :A, 0x2204, :N, 0x2207, :A, 0x2209, :N,
    0x220B, :A, 0x220C, :N, 0x220F, :A, 0x2210, :N, 0x2211, :A, 0x2212, :N,
    0x2215, :A, 0x2216, :N, 0x221A, :A, 0x221B, :N, 0x221D, :A, 0x2221, :N,
    0x2223, :A, 0x2224, :N, 0x2225, :A, 0x2226, :N, 0x2227, :A, 0x222D, :N,
    0x222E, :A, 0x222F, :N, 0x2234, :A, 0x2238, :N, 0x223C, :A, 0x223E, :N,
    0x2248, :A, 0x2249, :N, 0x224C, :A, 0x224D, :N, 0x2252, :A, 0x2253, :N,
    0x2260, :A, 0x2262, :N, 0x2264, :A, 0x2268, :N, 0x226A, :A, 0x226C, :N,
    0x226E, :A, 0x2270, :N, 0x2282, :A, 0x2284, :N, 0x2286, :A, 0x2288, :N,
    0x2295, :A, 0x2296, :N, 0x2299, :A, 0x229A, :N, 0x22A5, :A, 0x22A6, :N,
    0x22BF, :A, 0x22C0, :N,
    0x2312, :A, 0x2313, :N, 0x2329, :W, 0x232B, :N,
    0x2460, :A, 0x24EA, :N, 0x24EB, :A,
    0x254C, :N, 0x2550, :A, 0x2574, :N, 0x2580, :A, 0x2590, :N, 0x2592, :A,
    0x2596, :N, 0x25A0, :A, 0x25A2, :N, 0x25A3, :A, 0x25AA, :N, 0x25B2, :A,
    0x25B4, :N, 0x25B6, :A, 0x25B8, :N, 0x25BC, :A, 0x25BE, :N, 0x25C0, :A,
    0x25C2, :N, 0x25C6, :A, 0x25C9, :N, 0x25CB, :A, 0x25CC, :N, 0x25CE, :A,
    0x25D2, :N, 0x25E2, :A, 0x25E6, :N, 0x25EF, :A, 0x25F0, :N,
    0x2605, :A, 0x2607, :N, 0x2609, :A, 0x260A, :N, 0x260E, :A, 0x2610, :N,
    0x2614, :A, 0x2616, :N, 0x261C, :A, 0x261D, :N, 0x261E, :A, 0x261F, :N,
    0x2640, :A, 0x2641, :N, 0x2642, :A, 0x2643, :N, 0x2660, :A, 0x2662, :N,
    0x2663, :A, 0x2666, :N, 0x2667, :A, 0x266B, :N, 0x266C, :A, 0x266E, :N,
    0x266F, :A, 0x2670, :N, 0x269E, :A, 0x26A0, :N, 0x26BE, :A, 0x26C0, :N,
    0x26C4, :A, 0x26CE, :N, 0x26CF, :A, 0x26E2, :N, 0x26E3, :A, 0x26E4, :N,
    0x26E8, :A,
    0x2701, :N, 0x273D, :A, 0x273E, :N, 0x2757, :A, 0x2758, :N, 0x2776, :A,
    0x2780, :N, 0x27E6, :Na, 0x27EE, :N,
    0x2985, :Na, 0x2987, :N,
    0x2B55, :A,
    0x2C00, :N,
    0x2E80, :W,

    0x3000, :F, 0x3001, :W, 0x303F, :N, 0x3041, :W, 0x3248, :A, 0x3250, :W,

    0x4DC0, :N, 0x4E00, :W,

    0xA4D0, :N, 0xA960, :W, 0xA980, :N, 0xAC00, :W,

    0xD800, :N,

    0xE000, :A,

    0xF900, :W, 0xFB00, :N, 0xFE00, :A, 0xFE10, :W, 0xFE20, :N, 0xFE30, :W,
    0xFE70, :N, 0xFF01, :F, 0xFF61, :H, 0xFFE0, :F, 0xFFE8, :H, 0xFFF9, :N,
    0xFFFD, :A,

    0x10000, :N, 0x1B000, :W, 0x1D000, :N, 0x1F100, :A, 0x1F12E, :N, 0x1F130, :A,
    0x1F16A, :N, 0x1F170, :A, 0x1F1E6, :N, 0x1F200, :W, 0x1F300, :N, 0x20000, :W,
    0xE0001, :N, 0xE0100, :A,
  ]

  def self.get_property(codepoint)
    (0 ... MAPPING.size / 2).each do |i|
      return MAPPING[i * 2 + 1] if codepoint < MAPPING[i * 2 + 2]
    end
    nil
  end

  def self.get_width(codepoint)
    prop = get_property(codepoint)
    case prop
    when :Na, :H, :N
      return 1
    when :W, :F, :A
      return 2
    else
      puts "[BUG] ILLEGAL: #{prop}"
      return nil
    end
  end
end

module StringUtils
  module_function
  def decorate(str, esc)
    "\x1b[#{esc}m" + str + "\x1b[0m"
  end

  def fit(str, maxwidth)
    (1 .. maxwidth).each do |n|
      w = str[0, n].width
      return n if w == maxwidth
      return n - 1 if w > maxwidth
    end
    nil
  end

  # 文字列(str)を指定桁数(width)で折り返して配列にして返す。
  def fold(str, width)
    folded = []
    v = str
    while w = fit(v, width)
      folded << v.class.new(v[0, w])
      v = v.class.new(v[w .. -1])
    end
    folded << v unless v.empty?
    folded
  end
end

class String

  WIDTH_CALCULATION = ENV['CSI_EAW'] ? :strict : :fast

  # fixed表示における文字列幅
  def width
    case encoding
    when Encoding::UTF_8
      if WIDTH_CALCULATION == :fast
        # adhocな実装 半角カナ系はずれる(速度のためmap.reduceは使わない)
        chars.inject(0){|s, c| s += (c.bytesize > 1 ) ? 2 : 1}
      else
        codepoints.inject(0){|s, c| s += UnicodeEastAsianWidth.get_width(c)}
      end
    else
      # SJISならこれで問題ない
      bytesize
    end
  end

  def ljust(w, pad = " ")
    (w < width) ? self : self + pad * (w - width)
  end

  def center(w, pad = " ")
    return self if w < width
    lpad = (w - width) / 2
    rpad = w - width - lpad
    return pad * lpad + self + pad * rpad
  end
end

module DataOut
  class Output

    LOCAL_TIMEZONE = Time.now.zone

    def val_to_s(v)
      case v
      when String
        v.gsub(/\r?\n/, "\\n")
      when BigDecimal
        # 最後の.0はとる
        v.to_s('F').gsub(/\.0$/, '')
      when Time
        if v.zone.nil? || v.zone == LOCAL_TIMEZONE
          v.strftime("%F %T")
        else
          v.to_s
        end
      else
        v.to_s
      end
    end

    def self.type(t)
      @@types ||= {}
      @@types[t] = self
    end

    def self.types
      @@types
    end
  end

  # 表形式出力
  class TableOutput < Output
    type "table"

    DITTO = "〃"

    include StringUtils

    def initialize(out = STDOUT, opts = {})
      @out = out
      @opts = opts
      @pagesize = @opts[:pagesize] || 0
      @buffsize = @opts[:buffsize] || 1000
      @maxwidth = @opts[:maxwidth] || default_maxwidth
    end

    def default_maxwidth
      if defined?(IO.console)
        IO.console.winsize[0] / 2
      else
        60
      end
    end

    def format(val, width)
      val = "" if val.nil?
      case val
      when DITTO
        val.center(width)
      when Numeric
        val_to_s(val).rjust(width)
      when String # DecoratedString
        val.class.new(val_to_s(val).ljust(width))
      else
        val_to_s(val).ljust(width)
      end
    end

    def folding(values, widths)
      folded = values.map.with_index{|v, i| fold(val_to_s(v), widths[i])}
      lines_num = folded.map{|l| l.nil? ? 0 : l.size}.max
      (0 ... lines_num).each do |lnum|
        yield folded.map{|v| v[lnum] || ""}, lnum, lines_num
      end
    end

    def putline(values, widths, linetype = :body)
      folding values, widths do |vals, lnum, lines_num|
        vals.each.with_index do |val, i|
          bottom = lnum == lines_num - 1
          s = format(val, widths[i])
          if @opts[:esc]
            case linetype
            when :head
              s = decorate(s, bottom ? '1;4' : '1')
            when :body_last
              s = decorate(s, '4') if bottom
            when :foot
              s = decorate(s, '1')
            end
          end
          @out.print s + " "
        end
        @out.puts
      end
      # TODO appendix 方式じゃなくしたい
      if @opts[:appendix] && values.respond_to?(:appendix) && values.appendix
        values.appendix.lines.each do |l|
          @out.puts "    " + l
        end
        @out.puts
      end
      unless @opts[:esc]
        if linetype == :head or linetype == :body_last
          @out.puts separator(widths).join(" ")
        end
      end
    end

    def separator(widths, char = "-")
      widths.map{|w| char * w}
    end

    # 出力を一旦溜め込むバッファ
    # 指定行数まではprocess_rowを呼びながらバッファリング
    # 指定行数を超えるとバッファした行とそれ以降がoutput_rowで処理される
    class OutputBuffer
      attr_reader :row_idx

      def initialize(opts = {})
        @buffer      = []
        @row_idx     = 0
        @flush_size  = opts[:flush_size] || 100
        if block_given?
          yield self
          finish
        end
      end

      def process_row(&b)
        @process_proc = b
      end

      def output_row(&b)
        @output_proc = b
      end

      def output(row, outtype = nil)
        @output_proc.call row, @row_idx, outtype
      ensure
        @row_idx +=1
      end
      private :output

      def flush(outtype = nil)
        return unless @buffer
        @buffer.each.with_index do |row, i|
          t = nil
          t = :last if outtype == :last && i == @buffer.size - 1
          output row, t
        end
        @buffer = []
        @flush_size = 1
      end
      private :flush

      def buffered_output(row)
        if @buffer
          flush if @buffer.size == @flush_size
          @process_proc.call row
          @buffer << row
        else
          output row, nil
        end
      end

      def finish
        flush :last
      end
    end

    def put_header(keys, widths)
      @out.puts
      putline keys, widths, :head
    end

    def display(keys, rows)
      widths = keys.map{|c| c.width}
      buf = OutputBuffer.new(flush_size: @buffsize) do |buff|
        buff.process_row do |row|
          row.each.with_index do |c, i|
            w = val_to_s(c).width
            w = @maxwidth if w > @maxwidth
            widths[i] = w if w > widths[i]
          end
        end
        buff.output_row do |row, idx, t|
          if idx == 0 || @pagesize > 0 && (idx % @pagesize) == 0
            put_header keys, widths
          end
          putline row, widths, (t == :last ? :body_last : :body)
        end
        prev_row = nil
        rows.each do |row|
          if prev_row && @opts[:ditto]
            mod_row = row.zip(prev_row).map{|r| (r[0] == r[1] && !r[0].nil?) ? DITTO : r[0]}
          else
            mod_row = row
          end
          buff.buffered_output mod_row
          prev_row = row
        end
      end
      put_header keys, widths if buf.row_idx == 0

      # footer
      # putline separator(widths, "-"), widths, :separator if rows.size >= 10
      putline keys, widths, :foot if rows.size >= 40
    end
  end

  # 詳細表示出力
  class DetailOutput < Output
    type "detail"

    def initialize(out, opts = {})
      @out = out
      @opts = opts
    end

    def display(keys, res)
      colwidth = keys.map{|k| k.width}.max
      res.each do |row|
        row.each.with_index do |col, i|
          @out.puts keys[i].ljust(colwidth) + " : " + val_to_s(col)
        end
        @out.puts
      end
    end
  end

  # INSERT文出力
  class InsertSqlOutput < Output
    type "insert"

    def initialize(out, opts = {})
      @out = out
      @opts = opts
    end

    def display(keys, res)
      cols = keys.join(',')
      res.each do |row|
        vals = row.map{|v| "'#{v}'"}.join(',')
        @out.puts "INSERT INTO table_name (#{cols}) VALUES (#{vals});"
      end
    end
  end

  # CSV出力
  class CsvOutput < Output
    type "csv"

    def initialize(out, opts = {})
      @out = out
      @opts = opts
    end

    def display(keys, res)
      @out.puts "#" + keys.join(',')
      res.each do |row|
        @out.puts row.map{|v| escape(v.to_s)}.join(',')
      end
    end

    def escape(v)
      if /[,"\n]/ =~ v
        '"' + v.gsub(/"/, '""') + '"'
      else
        v
      end
    end
  end
end

# vim:set ts=2 sw=2 et:

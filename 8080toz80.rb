# 8080 to Z80 translator
#
# according to http://popolony2k.com.br/xtras/programming/asm/nemesis-lonestar/8080-z80-instruction-set.html
#
def tokenize line
  return Array.new if line.empty?
  starts_with_whitespace = line[0,1].strip.empty?
  tokens = line.split " "
#  puts tokens.inspect
  comment_at = nil
  
  # check for comments
  # any token starting with a ';' ?
  # -> remember index as comment_at
  tokens.each_with_index do |t,i|
    case t[0,1]
    when "\032" # ctrl-z
      tokens[i] = nil
    when ";" # comment
      comment_at = i
      break
    end
  end
  if comment_at
    # reconstruct tokens in case of comment
    tokens[comment_at] = tokens[comment_at][1..-1]
    comment = tokens[comment_at..-1].join(" ") # single-string comment
    tokens = (comment_at == 0) ? Array.new : tokens[0..comment_at-1] # stuff before the comment
    tokens << ";" # insert special 'comment' token
    tokens << comment # complete comment
  end
  tokens.unshift "" if starts_with_whitespace
  tokens
end

def doublereg r
  { "PSW" => "af", "H" => "hl", "D" => "de", "B" => "bc", "SP" => "sp" }[r]
end

def singlereg r
  case r
  when "M"
    "(hl)"
  when "A", "B", "C", "D", "E", "H", "L", "SP"
    r.downcase
  else
    r
  end
end

def expression expr
  r = /[A-Z$][A-Z0-9\.]*|\d+[OQ]?|\s+|,|\'.+\'|[^a-zA-Z\d\s$,]+/i
#  puts "expr(#{expr})"
  result = ""
  expr.scan(r).each do |e|
#    puts "  #{e.inspect}"
    case e
    when /(\d+)O/
      value = $1.to_i(8)
      if value < 0xa0
        result << "%02xh" % value
      else
        result << "%03xh" % value
      end
    when /(\d+)Q/
      value = $1.to_i(8)
      if value < 0xa000
        result << "%04xh" % value
      else
        result << "%05xh" % value
      end
    else
      result << e
    end
#    else
#      raise "Unknown expression >#{expr.inspect}"
#    end
  end
#  puts "\t(#{result})"
  result
end

def convert tokens
  state = :begin
  label = nil
  command = nil
  comment = nil
  args = ""
  loop do
    token = tokens.shift
    case token
    when nil
      break
    when ""
      state = :cmd
      next
    when ";"
      state = :comment
      next
    else
      case state
      when :begin
        if token && token.include?("::")
          label, command = token.split "::"
          label << "::"
          state = :args
        else
          label = token
          state = :cmd
        end
      when :comment
        comment = token
        break
      when :cmd
        command = token
        state = :args
      when :args
        args << " " unless args.empty?
        args << token
      end
    end
  end
  outl = if label || command || comment
    "#{label}\t"
  else
    ""
  end
  case command
    when nil
      # assembler directives
    when "SUBTTL", "IF1", "IF2", "ENDIF", "CSEG", "PAGE", "TITLE",
      ".SALL", ".LIST", ".XLIST", "ORG", "IF", "IFF"
      outl << command
      outl << "\t#{expression(args)}" unless args.empty?
    when "SET"
      outl << "defl #{expression(args)}"
    when "END"
      outl << "end"
    when "EXTRN", "PUBLIC"
      outl << command
      outl << "\t#{expression(args)}" unless args.empty?
    when "DB"
      outl << "defb\t#{expression(args)}"
    when "DC"
      outl << "defm\t#{expression(args)}"
    when "DS"
      outl << "defs\t#{expression(args)}, 0"
    when "DW"
      outl << "defw\t#{expression(args)}"
    when ".PRINTX"
      outl << ".printx\t#{args}"
      # 8080
    when "ACI"
      outl << "adc\ta,#{expression(args)}"
    when "ADC"
      outl << "adc\ta,#{singlereg(args)}"
    when "ADI"
      outl << "add\ta,#{expression(args)}"
    when "ADD"
      outl << "add\ta,#{singlereg(args)}"
    when "ANA"
      outl << "and\t#{singlereg(args)}"
    when "ANI"
      outl << "and\t#{expression(args)}"
    when "CALL"
      outl << "call\t#{expression(args)}"
    when "CC"
      outl << "call\tc,#{expression(args)}"
    when "CM"
      outl << "call\tm,#{expression(args)}"
    when "CMP"
      outl << "cp\t#{singlereg(args)}"
    when "CMA"
      outl << "cpl"
    when "CMC"
      outl << "ccf"
    when "CNC"
      outl << "call\tnc,#{expression(args)}"
    when "CNZ"
      outl << "call\tnz,#{expression(args)}"
    when "CP"
      outl << "call\tp,#{expression(args)}"
    when "CPI"
      outl << "cp\t#{expression(args)}"
    when "CPE"
      outl << "call\tpe,#{expression(args)}"
    when "CPO"
      outl << "call\tpo,#{expression(args)}"
    when "CZ"
      outl << "call\tz,#{expression(args)}"
    when "DAA"
      outl << "daa"
    when "DAD"
      outl << "add\thl,#{doublereg(args)}"
    when "DCR"
      outl << "dec\t#{singlereg(args)}"
    when "DCX"
      outl << "dec\t#{doublereg(args)}"
    when "IN"
      outl << "in\ta,(#{expression(args)})"
    when "INR"
      outl << "inc\t#{singlereg(args)}"
    when "INX"
      outl << "inc\t#{doublereg(args)}"
    when "JMP"
      outl << "jp\t#{expression(args)}"
    when "JC"
      outl << "jp\tc,#{expression(args)}"
    when "JM"
      outl << "jp\tm,#{expression(args)}"
    when "JNC"
      outl << "jp\tnc,#{expression(args)}"
    when "JNZ"
      outl << "jp\tnz,#{expression(args)}"
    when "JP"
      outl << "jp\tp,#{expression(args)}"
    when "JPE"
      outl << "jp\tpe,#{expression(args)}"
    when "JPO"
      outl << "jp\tpo,#{expression(args)}"
    when "JZ"
      outl << "jp\tz,#{expression(args)}"
    when "LDA"
      outl << "ld\ta,(#{expression(args)})"
    when "LDAX"
      outl << "ld\ta,(#{doublereg(args)})"
    when "LHLD"
      outl << "ld\thl,(#{expression(args)})"
    when "LXI"
      r, v = args.split ","
      outl << "ld\t#{doublereg(r)},#{expression(v)}"
    when "MOV"
      r1, r2 = args.split ","
      outl << "ld\t#{singlereg(r1)},#{singlereg(r2)}"
    when "MVI"
      r, v = args.split ","
      outl << "ld\t#{singlereg(r)},#{expression(v)}"
    when "ORA"
      outl << "or\t#{singlereg(args)}"
    when "ORI"
      outl << "or\t#{expression(args)}"
    when "OUT"
      outl << "out\t(#{expression(args)}),a"
    when "PCHL"
      outl << "jp\t(hl)"
    when "POP"
      outl << "pop\t#{doublereg(args)}"
    when "PUSH"
      outl << "push\t#{doublereg(args)}"
    when "RAL"
      outl << "rla"
    when "RAR"
      outl << "rra"
    when "RC"
      outl << "ret\tc"
    when "RET"
      outl << "ret"
    when "RLC"
      outl << "rlca"
    when "RM"
      outl << "ret\tm"
    when "RNC"
      outl << "ret\tnc"
    when "RNZ"
      outl << "ret\tnz"
    when "RP"
      outl << "ret\tp"
    when "RPE"
      outl << "ret\tpe"
    when "RPO"
      outl << "ret\tpo"
    when "RRC"
      outl << "rrca"
    when "RZ"
      outl << "ret\tz"
    when "SBB"
      outl << "sbc\ta,#{singlereg(args)}"
    when "SBI"
      outl << "sbc\ta,#{expression(args)}"
    when "SHLD"
      outl << "ld\t(#{expression(args)}),hl"
    when "SPHL"
      outl << "ld\tsp,hl"
    when "STA"
      outl << "ld\t(#{expression(args)}),a"
    when "STAX"
      outl << "ld\t(#{doublereg(args)}),a"
    when "STC"
      outl << "scf"
    when "SUB"
      outl << "sub\t#{singlereg(args)}"
    when "SUI"
      outl << "sub\t#{expression(args)}"
    when "XCHG"
      outl << "ex\tde,hl"
    when "XTHL"
      outl << "ex\t(sp),hl"
    when "XRA"
      outl << "xor\t#{singlereg(args)}"
    when "XRI"
      outl << "xor\t#{expression(args)}"
    else
      raise "Unknown \"#{line}\""
  end
  if comment
    if args.empty?
      outl << "\t"
    end
    outl << "\t; #{comment}"
  end
  outl
end

def translate asmname
  puts "\t.symlen 6"
  File.open(asmname).each_with_index do |line, num|
    tokens = tokenize line.chomp
    if tokens.nil?
      puts
      next
    end
    begin
      first = tokens.first
      if first == ";"
        outl = line
      else
        outl = convert tokens
      end
    rescue Exception => e
      STDERR.puts "** #{asmname}:#{num+1} - #{line.chomp}\n\t#{e}"
      next
    end
    puts outl
  end
end

ARGV.each do |fname|
  translate fname
end

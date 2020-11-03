class Dotenv
  def self.load(filename)
    inst = self.new filename
    inst.result()
  end

  def self.load(filename, required)
    inst = self.new filename
    h = inst.result()

    required.each do |k|
      if (!h[k])
        raise MissingKey, k
      end
    end

    h
  end

  def initialize(filename)
    @hash = {}

    IO.foreach(filename) do |f|
      f.strip.scan(LINE).each do |key, value|
        if (value) 
          @hash[key.downcase] = value
        end
      end
    end

  end

  def result
    @hash
  end

  LINE = /
    (?:^|\A)              # beginning of line
    \s*                   # leading whitespace
    (?:export\s+)?        # optional export
    ([\w\.]+)             # key
    (?:\s*=\s*?|:\s+?)    # separator
    (                     # optional value begin
      \s*'(?:\\'|[^'])*'  #   single quoted value
      |                   #   or
      \s*"(?:\\"|[^"])*"  #   double quoted value
      |                   #   or
      [^\#\r\n]+          #   unquoted value
    )?                    # value end
    \s*                   # trailing whitespace
    (?:\#.*)?             # optional comment
    (?:$|\z)              # end of line
  /x
end

class Error < StandardError; end

class MissingKey < Error # :nodoc:
  def initialize(key)
    super("Missing required .env key: #{key}")
  end
end
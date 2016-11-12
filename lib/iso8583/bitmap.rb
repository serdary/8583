# Copyright 2009 by Tim Becker (tim.becker@kuriostaet.de)
# MIT License, for details, see the LICENSE file accompaning
# this distribution

module ISO8583

  # This class constructs an object for handling bitmaps
  # with which ISO8583 messages typically begin.
  # Bitmaps are either 8 or 16 bytes long, an extended length
  # bitmap is indicated by the first bit being set.
  # In all likelyhood, you won't be using this class much, it's used
  # transparently by the Message class.
  class Bitmap

    # create a new Bitmap object. In case an iso message
    # is passed in, that messages bitmap will be parsed. If
    # not, this initializes and empty bitmap.
    def initialize(message = nil)
      @bmp = Array.new(128, false)
      if message
        initialize_from_message message
      end
    end
    
    # yield once with the number of each set field.
    def each #:yields: each bit set in the bitmap.
      @bmp.each_with_index { |set, i| yield i+1 if set && i != 0 }
    end
    
    # Returns whether the bit is set or not.
    def [](i)
      @bmp[i-1]
    end

    # Set the bit to the indicated value. Only `true` sets the
    # bit, any other value unsets it.
    def []=(i, value)
      if i > 128 
        raise ISO8583Exception.new("Bits > 128 are not permitted.")
      elsif i < 2
        raise ISO8583Exception.new("Bits < 2 are not permitted (continutation bit is set automatically)")
      end
      @bmp[i-1] = (value == true)
    end

    # Sets bit #i
    def set(i)
      self[i] = true
    end
    
    # Unsets bit #i
    def unset(i)
      self[i] = false
    end

    # Generate the bytes representing this bitmap.
    def to_bytes
      arr = [self.to_s]
      # tricky and ugly, setting bit[1] only when generating to_s...
      count = self[1] ? 128 : 64
      arr.pack("B#{count}")
    end
    alias_method :to_b, :to_bytes

    # Generate a String representation of this bitmap in the form:
    #	01001100110000011010110110010100100110011000001101011011001010
    def to_s
      #check whether any `high` bits are set
      @bmp[0] = false
      65.upto(128) {|i|
        if self[i]
          # if so, set continuation bit
          @bmp[0] = true
          break
        end
      }
      str = "".force_encoding("ASCII-8BIT")
      1.upto(self[1] ? 128 : 64) {|i|
        str << (self[i] ? "1" : "0")
      }
      str
    end


    private

    def initialize_from_message(message)
      # Message's format is a sequence of HEX values: (ie: 822000010000000004000000000000001111194228001234045678301)
      # Below code will treat this sequence as ascii characters, so 8 will be converted to 00111000 which is 56, which is ASCII 8.
      # Because of this, below code will create an incorrect bitmap (in this case a bitmap with only 64 bits).
      # Based on the tests of this gem, it expects a byte sequence (@see BitmapTests#49)
      message = [message].pack('H*')

      bmp = message.unpack("B64")[0]
      if bmp[0,1] == "1"
        bmp = message.unpack("B128")[0]
      end

      0.upto(bmp.length-1) do |i|
        @bmp[i] = (bmp[i,1] == "1")
      end
    end

    class << self
      # Parse the bytes in string and return the Bitmap and bytes remaining in `str`
      # after the bitmap is taken away.
      def parse(str)
        bmp  = Bitmap.new(str)

        # In order to remove 8 or 16 bytes from hex sequence (note that a hex char is a nibble), first convert it to bytes
        # then, remove 8 or 16 bytes depending on the bitmap size and then convert it back.
        str = [str].pack('H*')
        rest = bmp[1] ? str[16, str.length] : str[8, str.length]
        rest = rest.unpack('H*').first
        [ bmp, rest ]
      end
    end
    
  end
end

if __FILE__==$0
  mp = ISO8583::Bitmap.new
  20.step(128,7) {|i| mp.set(i)}
  print mp.to_bytes
end

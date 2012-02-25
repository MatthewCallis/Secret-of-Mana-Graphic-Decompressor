#!/usr/bin/env ruby
# Secret of Mana Graphic Decompression
# http://wiki.superfamicom.org/snes/show/Seiken+Densetsu+2
# by Matthew Callis (http://superfamicom.org/)

if ARGV.size < 2
  puts("[!] I need both an input file and an output file.")
  exit
end

input_file  = ARGV[0]
output_file = ARGV[1]

puts "[*] Input:       #{ARGV[0]}"
puts "[*] Output:      #{ARGV[1]}"

@compression_type
@compressed_data
@uncompressed_size
@uncompressed_data = []

File.open(input_file, "rb") do |f|
  # Determine the compression value.
  bytes = f.read(2)
  @compression_type_byte = bytes[1] << 8 | bytes[0]
  case @compression_type_byte
    when 0
      @compression_type = 0x1F
    when 1
      @compression_type = 0x0F
    when 2
      @compression_type = 0x07
    when 3
      @compression_type = 0x03
    when 4
      @compression_type = 0x01
    when 5
      @compression_type = 0x00
    else
      puts "[!] Unknown compression type!"
      exit
  end
  printf "[*] Format:      %x (%x)\n", @compression_type_byte, @compression_type

  bytes = f.read(2)
  @uncompressed_size = bytes[0] << 8 | bytes[1]
  puts "[*] Output Size: " + "%d bytes" % @uncompressed_size

  @compressed_data = f.read()
  puts "[*] Compressed:  " + "%d bytes" % @compressed_data.length
end



@bytes_to_skip = 0
@compressed_data = @compressed_data.bytes.to_a
@compressed_data.each_with_index do |byte, i|
  # Skipp ahead however many bytes we've already used.
  if @bytes_to_skip > 0
    @bytes_to_skip -= 1
    next
  end

  # Switch based on the byte's size
  if byte < 0x80
    # Read raw data for [byte + 1] bytes starting at the next byte.
    puts "[1] Single Byte Code (%02X)" % byte
    puts "[1] Read Data for %d bytes" % (@compressed_data[i].to_i + 1)
    @bytes_to_skip = (@compressed_data[i].to_i + 1)

    @offset = 0
    until @offset >= @bytes_to_skip
      @uncompressed_data.push(@compressed_data[i + 1 + @offset])
      @offset += 1
    end
  else
    # Read data from the buffer.
    puts "[2] 2-Byte Code (%02X)" % byte
    @bytes_to_skip = 1

    @read_from = @uncompressed_data.length - (((byte.to_i - 0x80) & (@compression_type.to_i)) * 0x100 + (@compressed_data[i+1].to_i + 1))
    @read_length = ((byte.to_i - 0x80) / (@compression_type.to_i + 1) + 3)
    printf "[2] Read %02X (%d) bytes from buffer at %02X (%d)\n", @read_length, @read_length, @read_from, @read_from
    printf "[2] Buffer starts with %02x %02X %02X...\n", @uncompressed_data[@read_from], @uncompressed_data[@read_from+1], @uncompressed_data[@read_from+2]

    @offset = 0
    until @read_length === 0
      @uncompressed_data.push(@uncompressed_data[@read_from + @offset].nil? ? 0 : @uncompressed_data[@read_from + @offset])
      @offset += 1
      @read_length -= 1
    end
  end
end

@uncompressed_actual_size = (@uncompressed_data.map { |x| x.nil? ? '__' : "%02X" % x }.join.length / 2)

printf "[*] Total of %02X (%d) of a predicted %02X (%d)\n", @uncompressed_actual_size, @uncompressed_actual_size, @uncompressed_size, @uncompressed_size

File.open(output_file, "wb") do |output|
  @uncompressed_data.each do |byte|
    output.print byte.chr
  end
end

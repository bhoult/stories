#!/usr/bin/env ruby

# Combines all chapter files into a single Happy_Friday.md

dir = File.dirname(__FILE__)
output_path = File.join(dir, "Happy_Friday.md")

chapter_files = Dir.glob(File.join(dir, "chapter_*.md")).sort

File.open(output_path, "w") do |out|
  chapter_files.each_with_index do |file, i|
    out.write("\n\n") if i > 0
    out.write(File.read(file))
  end
end

puts "Combined #{chapter_files.length} files into #{output_path}"

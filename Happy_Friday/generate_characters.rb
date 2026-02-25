#!/usr/bin/env ruby

# Generates character portrait images from characters.md using flux.py
#
# Usage:
#   ruby generate_characters.rb           # Generate all characters
#   ruby generate_characters.rb 1 3 8     # Generate specific characters by number
#   ruby generate_characters.rb --list    # List characters without generating

require 'json'

PYTHON = File.expand_path("~/programming/ai/.venv/bin/python3")
DRAW_PY = File.expand_path("~/programming/ai/flux.py")
CHARACTERS_MD = File.join(File.dirname(__FILE__), "characters.md")
OUTPUT_DIR = File.join(File.dirname(__FILE__), "images", "characters")

# Portrait dimensions (9:16 vertical)
WIDTH = 1008
HEIGHT = 1792
STEPS = 10

# Style prefix applied to all prompts
STYLE = "Detailed realistic digital portrait illustration, dramatic cinematic lighting, " \
        "muted post-apocalyptic color palette, rural Arkansas setting. "

# Parse characters.md into structured data
def parse_characters(path)
  content = File.read(path)
  characters = []

  # Split into character blocks by heading
  blocks = content.scan(/^## (\d+)\. (.+?)\n(.*?)(?=\n## \d+\.|(?:\n---\s*)*\z)/m)

  blocks.each do |num, name, body|
    char = { number: num.to_i, name: name.strip, body: body.strip }

    # Extract fields
    char[:age] = $1 if body =~ /\*\*Age:\*\*\s*(.+)/
    char[:height] = $1 if body =~ /\*\*Height:\*\*\s*(.+)/
    char[:weight] = $1 if body =~ /\*\*Weight:\*\*\s*(.+)/
    char[:build] = $1 if body =~ /\*\*Build:\*\*\s*(.+)/
    char[:hair] = $1 if body =~ /\*\*Hair:\*\*\s*(.+)/
    char[:skin] = $1 if body =~ /\*\*Skin:\*\*\s*(.+)/
    char[:face] = $1 if body =~ /\*\*Face:\*\*\s*(.+)/
    char[:eyes] = $1 if body =~ /\*\*Eyes:\*\*\s*(.+)/
    char[:clothing] = $1 if body =~ /\*\*Clothing(?:\s*\([^)]*\))?:\*\*\s*(.+)/
    char[:equipment] = $1 if body =~ /\*\*Equipment:\*\*\s*(.+)/
    char[:distinguishing] = $1 if body =~ /\*\*Distinguishing features:\*\*\s*(.+)/
    char[:health] = $1 if body =~ /\*\*Health:\*\*\s*(.+)/

    characters << char
  end

  characters.sort_by { |c| c[:number] }
end

# Build an image-generation prompt from character data
def build_prompt(char)
  parts = [STYLE]

  # Core subject
  parts << "Portrait of #{char[:name].sub(/ — .*/, '')}."

  # Age and build
  if char[:age]
    age = char[:age].sub(/\s*\(.*/, '')
    parts << "#{age} years old." if age =~ /\d/
    parts << "Age #{age}." if age =~ /^\d+s$|^~|^Mid|^Late/i
  end

  parts << "#{char[:build]}." if char[:build]

  # Physical appearance
  if char[:hair]
    hair = char[:hair].sub(/Not specified.*/, '').strip
    parts << "Hair: #{hair}." unless hair.empty?
  end

  if char[:skin]
    skin = char[:skin].sub(/Not specified.*/, '').strip
    parts << "Skin: #{skin}." unless skin.empty?
  end

  if char[:face]
    parts << "Face: #{char[:face]}."
  end

  if char[:eyes]
    parts << "Eyes: #{char[:eyes]}."
  end

  # Clothing - pick the first/primary description
  if char[:clothing]
    clothing = char[:clothing].split(/\n/).first.strip
    parts << "Wearing #{clothing}."
  end

  # Equipment that's visually relevant
  if char[:equipment]
    equip = char[:equipment].split('.').first.strip
    parts << "Carrying #{equip}." unless equip.empty?
  end

  # Distinguishing visual features (trim to first sentence or two)
  if char[:distinguishing]
    feat = char[:distinguishing].split('.')[0..1].join('.').strip
    parts << feat + "." unless feat.empty?
  end

  parts.join(" ")
    .gsub(/\.\./, '.')
    .gsub(/\s+/, ' ')
    .gsub(/"[^"]*"/, '')  # strip quoted text (literary, not useful for image gen)
    .gsub(/\s+/, ' ')
    .strip
end

# --- Main ---

characters = parse_characters(CHARACTERS_MD)

if ARGV.include?("--list")
  characters.each do |c|
    puts "  #{c[:number].to_s.rjust(2)}. #{c[:name]}"
  end
  exit
end

# Filter to specific character numbers if provided
if ARGV.any? { |a| a =~ /^\d+$/ }
  nums = ARGV.select { |a| a =~ /^\d+$/ }.map(&:to_i)
  characters = characters.select { |c| nums.include?(c[:number]) }
end

Dir.mkdir(OUTPUT_DIR) unless Dir.exist?(OUTPUT_DIR)

characters.each do |char|
  slug = char[:name].sub(/ — .*/, '').downcase.gsub(/[^a-z0-9]+/, '_').gsub(/_+$/, '')
  filename = "%02d_%s.jpg" % [char[:number], slug]
  output_path = File.join(OUTPUT_DIR, filename)

  prompt = build_prompt(char)

  puts "=" * 70
  puts "#{char[:number]}. #{char[:name]}"
  puts "   Output: #{output_path}"
  puts "   Prompt: #{prompt[0..120]}..."
  puts

  metadata = {
    character: char[:name],
    character_number: char[:number],
    source: "Happy Friday"
  }.to_json

  cmd = [
    PYTHON,
    DRAW_PY,
    prompt,
    "-o", output_path,
    "-W", WIDTH.to_s,
    "-H", HEIGHT.to_s,
    "-s", STEPS.to_s,
    "-m", metadata
  ]

  system(*cmd)

  if $?.success?
    puts "   Done: #{output_path}"
  else
    puts "   FAILED (exit #{$?.exitstatus})"
  end

  puts
end

puts "Generated #{characters.length} character portraits in #{OUTPUT_DIR}"

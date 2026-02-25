#!/usr/bin/env ruby

# Generates scene illustration images from scene_illustrations.md using flux.py
# Uses character descriptions from characters.md for consistency.
#
# Usage:
#   ruby generate_scenes.rb              # Generate all 30 scenes
#   ruby generate_scenes.rb 1 5 25       # Generate specific chapters
#   ruby generate_scenes.rb --list       # List chapters without generating

require 'json'

PYTHON = File.expand_path("~/programming/ai/.venv/bin/python3")
DRAW_PY = File.expand_path("~/programming/ai/flux.py")
SCENES_MD = File.join(File.dirname(__FILE__), "scene_illustrations.md")
CHARACTERS_MD = File.join(File.dirname(__FILE__), "characters.md")
OUTPUT_DIR = File.join(File.dirname(__FILE__), "images", "scenes")

# Landscape dimensions (16:9)
WIDTH = 1792
HEIGHT = 1008
STEPS = 10

# Consistent style across all scene illustrations
STYLE = "Stylized digital illustration, graphic novel aesthetic, " \
        "muted post-apocalyptic color palette with selective color accents, " \
        "dramatic cinematic composition, atmospheric depth, " \
        "rural Arkansas Ozark setting, autumn October. "

# --- Character description cache ---

def parse_characters(path)
  content = File.read(path)
  chars = {}

  blocks = content.scan(/^## (\d+)\. (.+?)\n(.*?)(?=\n## \d+\.|(?:\n---\s*)*\z)/m)
  blocks.each do |_num, name, body|
    key = name.sub(/ — .*/, '').strip.downcase
    # Build a short visual description from the character data
    parts = []
    parts << $1 if body =~ /\*\*Age:\*\*\s*(.+)/
    parts << $1 if body =~ /\*\*Build:\*\*\s*(.+)/
    parts << "Hair: #{$1}" if body =~ /\*\*Hair:\*\*\s*(.+)/ && $1 !~ /Not specified/
    parts << "Skin: #{$1}" if body =~ /\*\*Skin:\*\*\s*(.+)/ && $1 !~ /Not specified/
    parts << $1 if body =~ /\*\*Face:\*\*\s*(.+)/
    parts << "Wearing #{$1.split("\n").first}" if body =~ /\*\*Clothing(?:\s*\([^)]*\))?:\*\*\s*(.+)/

    desc = parts.join(". ")
      .gsub(/"[^"]*"/, '')
      .gsub(/\s+/, ' ')
      .strip

    chars[key] = desc unless desc.empty?
  end
  chars
end

# --- Scene parsing ---

def parse_scenes(path)
  content = File.read(path)
  scenes = []

  blocks = content.scan(/^## Chapter (\d+): (.+?)\n(.*?)(?=\n## Chapter \d+|\z)/m)

  blocks.each do |num, title, body|
    scene = { number: num.to_i, title: title.strip, body: body.strip }

    scene[:scene] = $1.strip if body =~ /\*\*Scene:\*\*\s*(.+?)(?=\n\*\*|\z)/m
    scene[:characters] = $1.strip if body =~ /\*\*Characters:\*\*\s*(.+?)(?=\n\*\*|\z)/m
    scene[:setting] = $1.strip if body =~ /\*\*Setting:\*\*\s*(.+?)(?=\n\*\*|\z)/m
    scene[:lighting] = $1.strip if body =~ /\*\*Lighting:\*\*\s*(.+?)(?=\n\*\*|\z)/m
    scene[:mood] = $1.strip if body =~ /\*\*Mood:\*\*\s*(.+?)(?=\n\*\*|\z)/m

    scenes << scene
  end

  scenes.sort_by { |s| s[:number] }
end

# --- Prompt builder ---

def build_prompt(scene, char_cache)
  parts = [STYLE]

  # Scene description is the core
  parts << scene[:scene] if scene[:scene]

  # Character descriptions — these contain the physical details
  parts << "Characters: #{scene[:characters]}." if scene[:characters]

  # Setting and lighting add atmosphere
  parts << "Setting: #{scene[:setting]}." if scene[:setting]
  parts << "Lighting: #{scene[:lighting]}." if scene[:lighting]
  parts << "Mood: #{scene[:mood]}." if scene[:mood]

  prompt = parts.join(" ")
    .gsub(/\.\./, '.')
    .gsub(/\s+/, ' ')
    .gsub(/\s*---\s*\.?/, '')  # strip stray markdown separators
    .strip

  prompt
end

# --- Main ---

char_cache = parse_characters(CHARACTERS_MD)
scenes = parse_scenes(SCENES_MD)

if ARGV.include?("--list")
  scenes.each do |s|
    puts "  %2d. Chapter %d: %s" % [s[:number], s[:number], s[:title]]
  end
  exit
end

# Filter to specific chapter numbers
if ARGV.any? { |a| a =~ /^\d+$/ }
  nums = ARGV.select { |a| a =~ /^\d+$/ }.map(&:to_i)
  scenes = scenes.select { |s| nums.include?(s[:number]) }
end

FileUtils.mkdir_p(OUTPUT_DIR) unless Dir.exist?(OUTPUT_DIR)

scenes.each do |scene|
  slug = scene[:title].downcase.gsub(/[^a-z0-9]+/, '_').gsub(/_+$/, '')
  filename = "ch%02d_%s.jpg" % [scene[:number], slug]
  output_path = File.join(OUTPUT_DIR, filename)

  prompt = build_prompt(scene, char_cache)

  puts "=" * 70
  puts "Chapter #{scene[:number]}: #{scene[:title]}"
  puts "   Output: #{output_path}"
  puts "   Prompt: #{prompt[0..120]}..."
  puts

  metadata = {
    chapter: scene[:number],
    title: scene[:title],
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

puts "Generated #{scenes.length} scene illustrations in #{OUTPUT_DIR}"

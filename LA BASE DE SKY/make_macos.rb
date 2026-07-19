#!/usr/bin/env ruby
# make_macos.rb
#
# Packages a Pokemon Essentials project into a macOS .app bundle using a
# prebuilt mkxp-z macOS template.
#
# Requirements:
#   - Z-universal-macos-template.zip in the project root (from GitHub Actions)
#   - Ruby and either `zip` or `tar` in PATH
#
# Usage:
#   ruby make_macos.rb
#   ruby make_macos.rb /path/to/project
#   ruby make_macos.rb /path/to/project /path/to/template.zip "Game Name"

require 'fileutils'
require 'tmpdir'

def run(*args)
  puts ">> #{args.join(' ')}"
  system(*args) or abort "Command failed: #{args.join(' ')}"
end

game_dir = ARGV[0] ? File.expand_path(ARGV[0]) : Dir.pwd
template_zip = ARGV[1] ? File.expand_path(ARGV[1]) : File.join(game_dir, "Z-universal-macos-template.zip")
output_name = ARGV[2]

unless File.exist?(template_zip)
  abort <<~MSG
    Template zip not found: #{template_zip}

    Place Z-universal-macos-template.zip in the project root, or pass the path
    as the second argument:

        ruby make_macos.rb "#{game_dir}" /path/to/Z-universal-macos-template.zip
  MSG
end

puts "Project:  #{game_dir}"
puts "Template: #{template_zip}"

Dir.chdir(game_dir)

# Essentials projects with decompiled scripts must combine them before release
combiner = File.join(game_dir, "scripts_combine.rb")
if File.exist?(combiner)
  puts "Combining scripts..."
  run("ruby", combiner)
end

# Read the game title from Game.ini
game_title = "Game"
game_ini = File.join(game_dir, "Game.ini")
if File.exist?(game_ini)
  File.readlines(game_ini, chomp: true).each do |line|
    if line =~ /^\s*Title\s*=\s*(.+)$/
      game_title = $1.strip
      break
    end
  end
end

puts "Title:    #{game_title}"

# Name the output app
app_name = output_name ? output_name.dup : "#{game_title}.app"
app_name << ".app" unless app_name.end_with?(".app")
app_path = File.join(game_dir, app_name)

# Clean up any previous build
FileUtils.rm_rf(app_path)
tmp_dir = Dir.mktmpdir("mkxpz-macos-")

# Extract the template
run("unzip", "-q", template_zip, "-d", tmp_dir)

# GitHub Actions artifacts are zipped twice; unwrap if needed
apps = Dir.glob(File.join(tmp_dir, "*.app"))
if apps.empty?
  inner_zips = Dir.glob(File.join(tmp_dir, "*.zip"))
  if inner_zips.length == 1
    run("unzip", "-q", inner_zips.first, "-d", tmp_dir)
    apps = Dir.glob(File.join(tmp_dir, "*.app"))
  end
end
abort "No .app bundle found inside #{template_zip}" if apps.empty?

FileUtils.mv(apps.first, app_path)

# Make sure the engine binary is executable
exe = File.join(app_path, "Contents", "MacOS", "Z-universal")
FileUtils.chmod(0755, exe) if File.exist?(exe)

# Prepare Contents/Game
game_dest = File.join(app_path, "Contents", "Game")
FileUtils.rm_rf(game_dest)
FileUtils.mkdir_p(game_dest)

# Things we do not want to copy into the macOS bundle
skip = [
  File.basename(app_path),
  File.basename(__FILE__),
  File.basename(template_zip),
  ".", "..",
  "Game.exe", "Game_Linux", "lib64",
  "mkxp-z.exe", "mkxp-z.x86_64",
  "x64-msvcrt-ruby310.dll", "RGSS104E.dll",
  "libgcc_s_seh-1.dll", "libgomp-1.dll", "libwinpthread-1.dll", "zlib1.dll",
  "animmaker.exe", "extendtext.exe",
  "Game.rxproj", "knownpoint.bmp", "selpoint.bmp",
  ".editorconfig", ".gitignore", ".nomedia", ".vscode",
  "credits.txt", "Essentials Docs Wiki.URL", "LBDS Wiki.URL",
  "Town Map Generator.html", "Partida guardada.desktop", "Partida guardada.lnk",
  "scripts_combine.rb", "scripts_extract.rb"
]

Dir.entries(game_dir).each do |entry|
  next if entry == "." || entry == ".."
  next if skip.include?(entry)
  next if entry.end_with?(".zip", ".tar.gz", ".app", ".dmg", ".desktop", ".lnk")

  src = File.join(game_dir, entry)
  dst = File.join(game_dest, entry)

  if File.directory?(src)
    FileUtils.cp_r(src, dst)
  else
    FileUtils.cp(src, dst)
  end
end

puts "Copied game files into #{game_dest}"

# Remove Windows/Linux leftovers that might be inside copied directories
Dir.glob(File.join(game_dest, "**/*.dll")).each { |f| FileUtils.rm(f) }
Dir.glob(File.join(game_dest, "**/Game.exe")).each { |f| FileUtils.rm(f) }
Dir.glob(File.join(game_dest, "**/Game_Linux")).each { |f| FileUtils.rm(f) }
Dir.glob(File.join(game_dest, "**/lib64")).each { |d| FileUtils.rm_rf(d) }

# Build the distributable archive
output_zip = File.join(game_dir, "#{game_title}-macos.zip")
FileUtils.rm_f(output_zip)

if system("command -v zip > /dev/null 2>&1")
  run("zip", "-r", "--symlinks", output_zip, app_name)
else
  output_tgz = output_zip.sub(/\.zip$/, ".tar.gz")
  FileUtils.rm_f(output_tgz)
  run("tar", "-czvf", output_tgz, app_name)
  output_zip = output_tgz
end

# Cleanup temp dir
FileUtils.rm_rf(tmp_dir)

puts "Done: #{output_zip}"
puts <<~MSG

  Players on macOS should:
    1. Unzip the archive.
    2. Move "#{app_name}" to Applications (not Downloads).
    3. Right-click the app → Open → confirm.
    4. If Gatekeeper blocks it, run:
       xattr -cr "/Applications/#{app_name}"
MSG

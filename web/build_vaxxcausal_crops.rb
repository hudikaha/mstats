#!/usr/bin/ruby
# coding: utf-8

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'tmpdir'

ROOT = File.expand_path(__dir__)
ASSET_DIR = File.join(ROOT, 'src', 'vaxxcausal')
RAW_DIR = File.join(ASSET_DIR, 'raw')
AUDIT_DIR = File.join(ASSET_DIR, 'audit')
MANIFEST = File.join(ASSET_DIR, 'compact-manifest.json')

# 一覧表の症例行と列境界。 / Source rows and column boundaries in the summary tables.
ROWS = {
  'no185-medical.png' => ['pages/001161432-p31.png', 495, 944, 831, 83, [0, 248, 417, 586, 673, 752, 831]],
  'no862-medical.png' => ['pages/001161432-p114.png', 495, 966, 831, 32, [0, 248, 417, 586, 673, 752, 831]],
  'no1260-medical.png' => ['pages/001161432-p172.png', 495, 300, 831, 148, [0, 248, 417, 586, 673, 752, 831]],
  'no1332-medical.png' => ['pages/001161432-p183.png', 495, 889, 831, 96, [0, 248, 417, 586, 673, 752, 831]],
  'no1737-medical.png' => ['pages/001161432-p275.png', 495, 288, 831, 273, [0, 248, 417, 586, 673, 752, 831]],
  'no1762-medical.png' => ['pages/001161432-p280.png', 495, 539, 831, 83, [0, 248, 417, 586, 673, 752, 831]],
  'no1790-row.png' => ['pages/001161432-p285.png', 495, 735, 831, 247, [0, 248, 417, 586, 673, 752, 831]],
  'no101-medical.png' => ['pages/001161432-p329.png', 494, 774, 832, 121, [0, 289, 458, 627, 714, 793, 832]]
}.freeze

EDGE = 4
PADDING = 5
BORDER = 2
MIN_BODY = 8

def run!(*command)
  stdout, stderr, status = Open3.capture3(*command)
  abort "#{command.join(' ')}\n#{stderr}" unless status.success?
  stdout
end

def geometry(path, x, y, width, height)
  inner_width = width - EDGE * 2
  inner_height = height - EDGE * 2
  return nil if inner_width <= 0 || inner_height <= 0

  value = run!('magick', path, '-crop', "#{inner_width}x#{inner_height}+#{x + EDGE}+#{y + EDGE}",
               '+repage', '-colorspace', 'Gray', '-threshold', '95%', '-negate', '-trim',
               '-format', '%@', 'info:').strip
  match = value.match(/\A(\d+)x(\d+)\+(\d+)\+(\d+)\z/)
  return nil unless match && match[1].to_i.positive? && match[2].to_i.positive?

  { x: match[3].to_i + EDGE, width: match[1].to_i }
end

def dark_pixels(path, x, width, height)
  return 0 if width <= 0 || height <= EDGE * 2

  run!('magick', path, '-crop', "#{width}x#{height - EDGE * 2}+#{x}+#{EDGE}", '+repage',
       '-colorspace', 'Gray', '-threshold', '95%', '-negate',
       '-format', '%[fx:round(mean*w*h)]', 'info:').to_i
end

FileUtils.mkdir_p(RAW_DIR)
FileUtils.mkdir_p(AUDIT_DIR)
manifest = {}

ROWS.each do |name, (page, left, top, width, height, boundaries)|
  page_path = File.join(ASSET_DIR, page)
  raw_path = File.join(RAW_DIR, name)
  compact_path = File.join(ASSET_DIR, name)
  audit_path = File.join(AUDIT_DIR, name)
  run!('magick', page_path, '-crop', "#{width}x#{height}+#{left}+#{top}", '+repage', raw_path)

  cells = []
  cell_log = []
  boundaries.each_cons(2).with_index do |(cell_left, cell_right), index|
    cell_width = cell_right - cell_left
    ink = geometry(raw_path, cell_left, 0, cell_width, height)
    if ink
      keep_left = [ink[:x] - PADDING, BORDER].max
      keep_right = [ink[:x] + ink[:width] + PADDING, cell_width - BORDER].min
    else
      keep_left = [(cell_width - MIN_BODY) / 2, BORDER].max
      keep_right = [keep_left + MIN_BODY, cell_width - BORDER].min
    end
    keep_right = [keep_right, keep_left + 1].max

    prefix = File.join(Dir.tmpdir, "vaxxcausal-#{Process.pid}-#{index}")
    left_border = "#{prefix}-left.png"
    body = "#{prefix}-body.png"
    right_border = "#{prefix}-right.png"
    cell = "#{prefix}-cell.png"
    run!('magick', raw_path, '-crop', "#{BORDER}x#{height}+#{cell_left}+0", '+repage', left_border)
    run!('magick', raw_path, '-crop', "#{keep_right - keep_left}x#{height}+#{cell_left + keep_left}+0", '+repage', body)
    run!('magick', raw_path, '-crop', "#{BORDER}x#{height}+#{cell_right - BORDER}+0", '+repage', right_border)
    run!('magick', left_border, body, right_border, '+append', cell)
    cells << cell
    removed = [[cell_left + BORDER, cell_left + keep_left], [cell_left + keep_right, cell_right - BORDER]].reject { |a, b| b <= a }
    removed_ink = removed.sum { |a, b| dark_pixels(raw_path, a, b - a, height) }
    abort "#{name}: cell #{index} removes #{removed_ink} dark pixels" if removed_ink.positive?
    cell_log << {
      source: [cell_left, cell_right],
      kept_body: [cell_left + keep_left, cell_left + keep_right],
      removed_blank: removed,
      removed_dark_pixels: removed_ink
    }
  end

  run!('magick', *cells, '+append', compact_path)
  separator = File.join(Dir.tmpdir, "vaxxcausal-#{Process.pid}-separator.png")
  run!('magick', '-size', "#{width}x8", 'xc:#777777', separator)
  run!('magick', raw_path, separator, compact_path, '-background', 'white', '-gravity', 'center', '-append', audit_path)

  manifest[name] = {
    source_page: page,
    source_box: [left, top, width, height],
    raw_sha256: Digest::SHA256.file(raw_path).hexdigest,
    compact_sha256: Digest::SHA256.file(compact_path).hexdigest,
    raw_width: width,
    compact_width: run!('magick', 'identify', '-format', '%w', compact_path).to_i,
    height: height,
    cells: cell_log
  }
ensure
  (cells || []).each { |path| FileUtils.rm_f(path) }
  Dir.glob(File.join(Dir.tmpdir, "vaxxcausal-#{Process.pid}-*.png")).each { |path| FileUtils.rm_f(path) }
end

File.write(MANIFEST, JSON.pretty_generate(manifest) + "\n")
puts "generated #{manifest.size} raw/compact/audit image sets"

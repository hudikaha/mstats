# coding: utf-8

require 'cgi'
require 'yaml'

mfacts = [
  File.expand_path('../lib/mfacts.rb', __dir__),
  File.expand_path('lib/mfacts.rb', __dir__)
].find { |path| File.file?(path) }
abort 'lib/mfacts.rb not found' unless mfacts
require mfacts

# 旧静的HTML本文を共通ヘッダー付きRubyページとして出力する。
# Render legacy static HTML content inside a Ruby page with the shared header.
def render_content_page(program)
  cgi = CGI.new
  requested = cgi['l']
  $l = if requested.match?(/^(en|english)/i) ||
          (requested.empty? && ENV['HTTP_ACCEPT_LANGUAGE'].to_s !~ /^ja/)
         :en
       else
         :ja
       end
  iframe = %w[1 true].include?(cgi['i'])
  page = "#{File.basename(program, '.rb')}.rb"
  item = site_menu_items.find { |entry| entry['href'].split('?', 2).first == page }
  abort "menu entry not found: #{page}" unless item
  title = item[$l.to_s] || item['ja']
  content = File.join(__dir__, 'content', "#{File.basename(program, '.rb')}.html")
  abort "content not found: #{content}" unless File.file?(content)

  print_header(title: title, iframe: iframe)
  print File.read(content)
  print "</div></div>\n" unless iframe
  print "</body></html>\n"
end

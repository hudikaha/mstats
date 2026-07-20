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
  print <<~HTML
    <form action="#{CGI.escapeHTML(page)}" method="get" class="language-selector">
      <label><input type="radio" name="l" value="ja" #{'checked' if $l == :ja} onchange="this.form.submit()">日本語</label>
      <label><input type="radio" name="l" value="en" #{'checked' if $l == :en} onchange="this.form.submit()">English</label>
      #{'<input type="hidden" name="i" value="true">' if iframe}
    </form>
    <script>window.CONTENT_LANGUAGE = '#{$l}';</script>
  HTML
  print File.read(content)
  print <<~HTML
    <script>
      document.querySelectorAll('[data-ja][data-en]').forEach(function (element) {
        element.textContent = element.getAttribute('data-#{$l}');
      });
      document.querySelectorAll('[data-language]').forEach(function (element) {
        element.hidden = element.getAttribute('data-language') !== '#{$l}';
      });
    </script>
  HTML
  print "</div></div>\n" unless iframe
  print "</body></html>\n"
end

#!/usr/bin/ruby
# coding: utf-8

require 'net/http'
require 'tempfile'
require 'uri'

LOGIN_URI = URI('https://www.mortality.org/Account/Login')
DOWNLOAD_URI = URI('https://www.mortality.org/File/GetDocument/Public/STMF/Outputs/stmf.csv')

abort 'Usage: fetch-stmf.rb OUTPUT.csv' unless ARGV.length == 1
email = ENV['HMD_EMAIL']
password = ENV['HMD_PASSWORD']
credentials_file = File.expand_path(ENV.fetch('HMD_CREDENTIALS_FILE', '~/.config/mstats/hmdpass.txt'))
if email.to_s.empty? || password.to_s.empty?
  abort "HMD credentials file was not found: #{credentials_file}" unless File.file?(credentials_file)
  mode = File.stat(credentials_file).mode & 0o777
  abort "HMD credentials file must not be group/world-readable: #{credentials_file}" unless (mode & 0o077).zero?

  email, password = File.read(credentials_file).strip.split(':', 2)
end
abort 'HMD email or password is missing' if email.to_s.empty? || password.to_s.empty?

cookies = {}

# 応答cookieを次のHMD requestへ引き継ぐ。
# Carry response cookies into the next HMD request.
def remember_cookies(response, cookies)
  response.get_fields('set-cookie').to_a.each do |header|
    pair = header.split(';', 2).first
    name, value = pair.split('=', 2)
    cookies[name] = value if name && value
  end
end

# passwordをcommand lineへ出さずNet::HTTPでrequestする。
# Use Net::HTTP so the password never appears in command-line arguments.
def hmd_request(uri, request, cookies)
  request['Cookie'] = cookies.map { |name, value| "#{name}=#{value}" }.join('; ') unless cookies.empty?
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    http.request(request)
  end
  remember_cookies(response, cookies)
  response
end

login_page = hmd_request(LOGIN_URI, Net::HTTP::Get.new(LOGIN_URI), cookies)
token = login_page.body[/name="__RequestVerificationToken"[^>]*value="([^"]+)"/, 1]
abort 'HMD login token was not found' unless token

login = Net::HTTP::Post.new(LOGIN_URI)
login.set_form_data(
  'Email' => email,
  'Password' => password,
  'ReturnUrl' => DOWNLOAD_URI.path,
  '__RequestVerificationToken' => token
)
login_response = hmd_request(LOGIN_URI, login, cookies)
unless login_response.is_a?(Net::HTTPRedirection)
  message = login_response.body[/<div class="text-danger[^>]*>.*?<li>(.*?)<\/li>/m, 1]
  message = message&.gsub(/<[^>]+>/, '')&.strip
  abort "HMD login failed: HTTP #{login_response.code}#{message.to_s.empty? ? '' : " (#{message})"}"
end

download = hmd_request(DOWNLOAD_URI, Net::HTTP::Get.new(DOWNLOAD_URI), cookies)
if download.is_a?(Net::HTTPRedirection)
  abort 'HMD download redirected to login; credentials or user agreement need attention'
end
abort "HMD download failed: HTTP #{download.code}" unless download.is_a?(Net::HTTPSuccess)

body = download.body.gsub(/\r\n?/, "\n")
header = body.lines.find { |line| !line.start_with?('#') && !line.strip.empty? }
expected = 'CountryCode,Year,Week,Sex,D0_14,D15_64,D65_74,D75_84,D85p,DTotal,'
abort 'HMD response is not an STMF pooled CSV' unless header&.start_with?(expected)

output = File.expand_path(ARGV.first)
directory = File.dirname(output)
abort "output directory does not exist: #{directory}" unless Dir.exist?(directory)
abort "output already exists: #{output}" if File.exist?(output)

temp = Tempfile.new(['.stmf-', '.csv'], directory)
begin
  temp.write(body)
  temp.flush
  temp.fsync
  temp.close
  File.rename(temp.path, output)
ensure
  temp.close! if File.exist?(temp.path)
end

data_lines = body.lines.reject { |line| line.start_with?('#') || line.strip.empty? }.count - 1
warn "downloaded #{output}: #{data_lines} data lines"

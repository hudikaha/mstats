#!/usr/bin/ruby
# coding: utf-8
# frozen_string_literal: true

require 'cgi'
require 'uri'

# 日本語: 旧URLのqueryを保持し、後継の死因別推移pageへ恒久転送する。
# English: Preserve the legacy query and permanently redirect to the successor cause-trend page.
params = CGI.parse(ENV.fetch('QUERY_STRING', ''))
query = URI.encode_www_form(params.flat_map { |key, values| values.map { |value| [key, value] } })
location = 'https://medicalfacts.info/codtr.rb'
location += "?#{query}" unless query.empty?

print "Status: 301 Moved Permanently\r\n"
print "Location: #{location}\r\n"
print "Cache-Control: no-cache\r\n"
print "Content-Type: text/plain; charset=utf-8\r\n\r\n"
print "Moved permanently to #{location}\n"

#!/usr/bin/env ruby
# frozen_string_literal: true
require 'csv'; require 'json'; require 'net/http'; require 'optparse'; require 'uri'
o={index:'indiv20260721',url:'http://localhost:9200',credentials:File.expand_path('~/.config/mstats/espass.txt'),mapping:File.expand_path('../config/elasticsearch/indiv20260721.json',__dir__),batch_size:1000,replace:false}
OptionParser.new{|p| p.on('--index NAME'){|v|o[:index]=v};p.on('--url URL'){|v|o[:url]=v};p.on('--credentials FILE'){|v|o[:credentials]=v};p.on('--mapping FILE'){|v|o[:mapping]=v};p.on('--batch-size N',Integer){|v|o[:batch_size]=v};p.on('--replace'){o[:replace]=true}}.parse!
abort 'CSV file is required' if ARGV.empty?
a,pass=File.read(o[:credentials]).strip.split(':',2); abort 'Invalid credentials file' if a.to_s.empty?||pass.to_s.empty?; base=URI(o[:url])
def req(base,a,p,m,path,body=nil,ct='application/json'); u=base.dup;u.path=path;r=m.new(u);r.basic_auth(a,p);r['Content-Type']=ct;r.body=body if body;h=Net::HTTP.new(u.hostname,u.port);h.use_ssl=u.scheme=='https';x=h.start{|z|z.request(r)};abort "Elasticsearch #{path} failed: HTTP #{x.code} #{x.body}" unless x.is_a?(Net::HTTPSuccess);x end
head=req(base,a,pass,Net::HTTP::Head,"/#{o[:index]}") rescue nil
if o[:replace] && head; req(base,a,pass,Net::HTTP::Delete,"/#{o[:index]}"); head=nil end
req(base,a,pass,Net::HTTP::Put,"/#{o[:index]}",File.read(o[:mapping])) unless head
batch=[];count=0; flush=-> { next if batch.empty?; x=JSON.parse(req(base,a,pass,Net::HTTP::Post,'/_bulk',batch.join("\n")+"\n",'application/x-ndjson').body); abort 'Bulk import failed' if x['errors'];batch.clear }
ARGV.each{|path| CSV.foreach(path,headers:true){|row| s=row.to_h; id=s.fetch('id'); s['dose_final']=s['dose_final'].to_i if s['dose_final']; s.delete_if{|k,v| v.nil?||v.empty?}; batch << JSON.generate(index:{_index:o[:index],_id:id}) << JSON.generate(s); count+=1;flush.call if (count%o[:batch_size]).zero? }};flush.call;puts "Imported #{count} documents into #{o[:index]}"

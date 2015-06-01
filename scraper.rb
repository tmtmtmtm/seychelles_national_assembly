#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'date'
require 'open-uri'
require 'date'
require 'csv'

require 'execjs'
require 'colorize'
require 'pry'
require 'csv'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def noko_for(url)
  Nokogiri::HTML(open(url).read) 
end

def unbracket(str)
  return ['Independent', 'Independent'] if str.empty?
  cap = str.match(/^(.*?)\s*\((.*?)\)\s*$/) or return [str, str]
  return cap.captures 
end

def datefrom(date)
  Date.parse(date).to_s
end

def scrape_list(url)
  noko = noko_for(url)
  count = 0
  noko.css('div#ja-content td a[href*="view=article"]/@href').map(&:text).uniq.each do |link|
    scrape_mp(URI.join(url, link))
    count += 1
  end
  puts "Added #{count}"
end

def scrape_mp(url)
  # warn "Getting #{url}"
  noko = noko_for(url).css('div.article-content')
  (role, name) = noko.css('p').map { |p| p.text.gsub(/[[:space:]]+/, ' ').strip }.reject(&:empty?).take(2)
  data = { 
    id: url.to_s[%r{id=(\d+)}, 1],
    role: role,
    name: name,
    given_name: noko.xpath('.//strong[contains(.,"Given Name")]/following::text()').first.text.strip,
    family_name: noko.xpath('.//strong[contains(.,"Surname")]/following::text()').first.text.strip,
    # Some members have "Date of Birth" some have "Birth" (sometimes with the B in a separate span)
    birth_date: datefrom(noko.xpath('.//strong[contains(.,"irth")]/following::text()').first.parent.text.strip),
    party: noko.xpath('.//strong[contains(.,"Party")]/following::text()').first.text.strip,
    email: noko.xpath('.//strong[contains(.,"Email")]/following::script').first.text.strip,
    term: 2014,
    source: url.to_s,
  }

  if data[:role][/ELECTED MEMBER FOR (.*)/]
    data.delete :role
    data[:constituency] = $1.sub('THE DISTRICT OF ','')
  elsif data[:role].include? 'PROPORTIONALLY ELECTED MEMBER'
    data.delete :role
    data[:constituency] = 'Proportionally Elected'
  end

  unless data[:email].to_s.empty?
    js = "var retval = ''; " + data[:email].split('--')[1] + ";\nreturn retval"
    js.gsub!("document.write","retval += ")
    mailto = ExecJS.exec(js)
    data[:email] = Nokogiri::HTML(mailto).css('a/@href').text.sub('mailto:','')
  end

  puts data
  ScraperWiki.save_sqlite([:id, :term], data)
end

term = {
  id: 2011,
  name: '2011–2016',
  start_date: '2011',
}
ScraperWiki.save_sqlite([:id], term, 'terms')

scrape_list('http://69.36.179.203/index.php?option=com_content&view=section&id=14&Itemid=27')


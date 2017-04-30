#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'date'
require 'nokogiri'
require 'open-uri'
require 'pry'
require 'scraped'
require 'scraperwiki'

# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'
require 'scraped_page_archive/open-uri'

class MembersPage < Scraped::HTML
  field :member_urls do
    noko.css('div#ja-content td a[href*="view=article"]/@href').map(&:text).uniq.map do |link|
      URI.join(url, link).to_s
    end
  end
end

class MemberPage < Scraped::HTML
  require 'execjs'

  field :id do
    url.to_s[/id=(\d+)/, 1]
  end

  field :name do
    role_and_name.last.sub('Hon. ', '')
  end

  field :given_name do
    noko.xpath('.//strong[contains(.,"Given Name")]/following::text()').first.text.strip
  end

  field :family_name do
    noko.xpath('.//strong[contains(.,"Surname")]/following::text()').first.text.strip
  end

  field :birth_date do
    # Some members have "Date of Birth" some have "Birth" (sometimes with the B in a separate span)
    datefrom(noko.xpath('.//strong[contains(.,"irth")]/following::text()').first.parent.text.strip)
  end

  field :party do
    noko.xpath('.//strong[contains(.,"Party")]/following::text()').first.text.strip
  end

  field :email do
    return if raw_email.to_s.empty?
    js = "var retval = ''; " + raw_email.split('--')[1] + ";\nreturn retval"
    js.gsub!('document.write', 'retval += ')
    mailto = ExecJS.exec(js)
    Nokogiri::HTML(mailto).css('a/@href').text.sub('mailto:', '')
  end

  field :term do
    2011
  end

  field :source do
    url.to_s
  end

  field :constituency do
    return 'Proportionally Elected' unless role[/ELECTED MEMBER FOR (.*)/]
    Regexp.last_match(1).sub('THE DISTRICT OF ', '')
  end

  private

  def datefrom(date)
    Date.parse(date).to_s
  end

  def role_and_name
    noko.css('p').map { |p| p.text.gsub(/[[:space:]]+/, ' ').strip }.reject(&:empty?).take(2)
  end

  def role
    role_and_name.first
  end

  def raw_email
    noko.xpath('.//strong[contains(.,"Email")]/following::script').first.text.strip
  end
end

url = 'http://69.36.179.203/index.php?option=com_content&view=section&id=14&Itemid=27'
page = MembersPage.new(response: Scraped::Request.new(url: url).response)
page.member_urls.each do |link|
  data = MemberPage.new(response: Scraped::Request.new(url: link).response).to_h
  ScraperWiki.save_sqlite(%i[id term], data)
  puts data
end

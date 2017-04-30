#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'
require 'scraped_page_archive/open-uri'

class MembersPage < Scraped::HTML
  field :members do
    noko.css('.pf-content table tr').map do |tr|
      fragment(tr => MemberRow).to_h
    end
  end
end

class MemberRow < Scraped::HTML
  field :id do
    File.basename(image, '.*').sub(/-\d+x\d+/,'')
  end

  field :name do
    # nasty hack to cope with broken layout for Terence Mondon (no image)
    return noko.xpath('*[contains(text(), "Hon.")]').text.gsub('Hon.', '').tidy if image.to_s.empty?
    noko.css('.wp-caption-text').text.gsub('Hon. ', '').tidy
  end

  # TODO: extract the constituency for Pillay et al.
  field :constituency do
    noko.css('h4').text.tidy
  end

  field :party do
    noko.css('p').map(&:text).find { |t| t.include? 'Party: ' }.to_s.gsub('Party: ', '').tidy
  end

  field :image do
    noko.css('img/@src').text
  end

  field :source do
    url.to_s
  end
end

url = 'http://nationalassembly.sc/index.php/your-parliamentarians/'
page = MembersPage.new(response: Scraped::Request.new(url: url).response)
data = page.members

data.each { |r| puts r.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']
ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[id], data)

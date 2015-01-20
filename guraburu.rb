require "mechanize"
require 'erb'
require "romaji"
# load "./mobamasu.rb"


module Guraburu
	def to_chara_links(name)
		name = Romaji.romaji2kana Mobamasu.to_fullname(name).sample, :kana_type => :katakana
		name_r = /#{name}/

		url = "http://gbf-wiki.com/index.php?%BF%CD%CA%AA%B5%D5%B0%FA%A4%AD%B0%EC%CD%F7"

		agent = Mechanize.new
		page = agent.get(url)
		page.body = page.body.toutf8
		page.encoding = 'UTF-8'
		
		td = (page/:tbody)[1]/:td
		td.map { |it| it/:a }.flatten.select { |it| it.inner_text =~ name_r }.map { |it| it[:href] }
	end


	def scraping_chara_page_impl(url)
		url = URI(url)
		puts url.fragment

		agent = Mechanize.new
		page = agent.get(url)

		page.body = page.body.toutf8

		page.body = Mechanize::Util.html_unescape(page.body).split(page.at("//*[@id=\"#{url.fragment}\"]").to_s)[1] if url.fragment

		page.encoding = 'UTF-8'

		data = page.at(:tbody)/:td
		images =  (data/:img).map { |it| it[:src] }
		{
			:name  => data[0].inner_text,
			:name2 => data[1].inner_text,
			:images => images,
			:wiki_url => url,
			:kind => :chara,
			:rank  => data[images.size + 7].inner_text,
			:attr  => data[images.size + 8].inner_text,
			:type  => data[images.size + 9].inner_text,
			:cv  => data[images.size + 19].inner_text,
		}
	end

	def clear_cache
		@cache = {}
	end

	def scraping_chara_page(url)
		@cache ||= clear_cache()
		@cache[url] ||= scraping_chara_page_impl(url)
	end


	def search_chara(query)
		link = to_chara_links(query[:search_word]).sample
		if link.nil?
			return []
		end
		result = scraping_chara_page link
		result[:image] = query[:plus] ? result[:images][1] : result[:images][0]
		[result]
	end

	def	search_summon(query)
		url = "http://gbf-wiki.com/?%BE%A4%B4%AD%C0%D0SSR"

		agent = Mechanize.new
		page = agent.get(url)
		page.body = page.body.toutf8
		page.encoding = 'UTF-8'
		summons = (page/:tr)[1..-1].select { |tr|
			(tr/:td)[1].inner_text =~ /#{query[:search_word]}/
		}.map { |chara|
			{
				:image => (chara/:td)[0].at(:a)[:href],
				:name => (chara/:td)[1].inner_text,
				:type => (chara/:td)[2].inner_text,
				:summon => (chara/:td)[5].inner_text,
				:bless => (chara/:td)[7].inner_text,
				:kind => :summon
			}
		}
	end

	def search(query)
		search_chara(query) + search_summon(query)
	end

	def parse_request(request)
		if request !~ /#guraburu[\s　].*/
			return nil
		end
		(op, search_word, *args) = request.split(/[\s　]+/, 4)
		if search_word.nil?
			return nil
		end

		plus = !!(search_word =~ /\+$/)
		search_word = search_word.gsub(/\+$/, "")

# 		search_word = search_word
# 		search_word = Romaji.romaji2kana search_word, :kana_type => :katakana
		{ :search_word => search_word, :plus => plus }
	end


	module_function :to_chara_links
	module_function :scraping_chara_page_impl
	module_function :scraping_chara_page
	module_function :clear_cache
	module_function :search_summon
	module_function :search_chara
	module_function :search
	module_function :parse_request
end


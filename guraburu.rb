require "mechanize"
require 'erb'
require "romaji"

module Guraburu
	def	search_chara(query)
		name = Romaji.romaji2kana query[:name], :kana_type => :katakana

		url = "http://blog.livedoor.jp/lucius300/archives/38508851.html"

		agent = Mechanize.new
		page = agent.get(url)
		table = page/:table

		result = table.search("tr").select { |tr|
			((tr/"td")[1]/:strong).text =~ /#{name}/
		}
		result.map { |tr|
			chara = Hash[(tr/"td")[1].inner_html.gsub(/\<strong\>.*\<\/strong\>/, "").gsub(/\<a.*\>.*\<\/a\>/, "").split("<br>").select{ |it| !it.empty? && it.include?('：') }.map { |it| it.split '：' }]
			chara["ランク"] = chara["ランク"].gsub(/レア/, "R")

			images = (tr/:a)[0,2].map { |a|
				a["href"]
			}
			name = ((tr/"td")[1]/:strong).text
			chara.merge({
				:name => name,
				:image => query[:plus] ? images[1] : images[0],
				:images => images,
				:wiki_url => "http://gbf-wiki.com/index.php?#{ERB::Util.url_encode((name + " (#{chara["ランク"]})").toeuc)}",
				:kind => :chara,
			})
		}
	end

	def	search_summon(query)
		url = "http://gbf-wiki.com/?%BE%A4%B4%AD%C0%D0SSR"

		agent = Mechanize.new
		page = agent.get(url)
		page.body = page.body.toutf8
		page.encoding = 'UTF-8'
		summons = (page/:tr)[1..-1].select { |tr|
			(tr/:td)[1].inner_text =~ /#{query[:name]}/
		}.map { |chara|
			{
				:image => (chara/:td)[0].at(:a)[:href],
				:name => (chara/:td)[1].inner_text,
				:type => (chara/:td)[2].inner_text,
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

		search_word = Romaji.romaji2kana search_word, :kana_type => :katakana
		{ :name => search_word, :plus => plus }
	end


	module_function :search_summon
	module_function :search_chara
	module_function :search
	module_function :parse_request
end


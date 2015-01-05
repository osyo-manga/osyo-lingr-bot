require "mechanize"
require "romaji"

module Guraburu
	def	search(query)
		url = "http://blog.livedoor.jp/lucius300/archives/38508851.html"

		agent = Mechanize.new
		page = agent.get(url)
		table = page/:table

		table.search("tr").each { |tr|
			name = ((tr/"td")[1]/:strong).text
			if name =~ /#{query[:name]}/
				images = (tr/:a)[0,2].map { |a|
					a["href"]
				}
				return { :images => images, :name => name }
			end
		}
	end


	def parse_request(request)
		if request !~ /#guraburu[\s　].*/
			return nil
		end
		(op, search_word, *args) = request.split(/[\s　]+/, 4)
		if search_word.nil?
			return nil
		end

		search_word = Romaji.romaji2kana search_word, :kana_type => :katakana
		{ :name => search_word }
	end

	module_function :search
	module_function :parse_request
end


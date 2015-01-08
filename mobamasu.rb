require "net/http"
require "json"
require "kconv"
require 'erb'
require "romaji"

module Mobamasu

	def rarity_to_n(rarity)
		case rarity
		when 'N'
			1
		when 'N+'
			2
		when 'R'
			3
		when 'R+'
			4
		when 'SR'
			5
		when 'SR+'
			6
		else
			1
		end
	end

	def search(query)
		response = Net::HTTP.get "ppdb.sekai.in", "/api/2/idol.json?full=1&name=#{ERB::Util.url_encode query[:name]}"
		result = JSON.parse(response)
		if result["result"] == false
			return nil
		end

		idols = result["data"]
		if query[:rarity] == nil
			return idols
		end

		rarity = rarity_to_n query[:rarity]
		idols.select! { |idol|
			idol["Rarity"] == rarity
		}
	end


	def to_image_url(id, frame = true)
		if frame
			"http://125.6.169.35/idolmaster/image_sp/card/l/#{ id }.jpg"
		else
			"http://125.6.169.35/idolmaster/image_sp/card/l_noframe/#{ id }.jpg"
		end
	end


	def search_random(query)
		result = search(query)
		if !result
			return nil
		end
		result[rand(result.length)]
	end

	def search_random_img(query)
		idol = search_random query
		if idol.nil?
			return nil
		end
		to_mobamasu_image_url(idol["ID"], query[:frame])
	end

	def parse_request(request)
		if request !~ /#mobamasu!?[\s　].*/
			return nil
		end
		(op, search_word, *args) = request.split(/[\s　]+/, 4)
		if search_word.nil?
			return nil
		end

		rarity = nil
		args.each do |arg|
			if arg =~ /^(N|N\+|R|R\+|SR|SR\+)(,(N|N\+|R|R\+|SR|SR\+))*$/
				rarity = arg
			end
		end
		frame = true
		if op =~ /#mobamasu!/
			frame = false
		end

		search_word = Romaji.romaji2kana search_word, :kana_type => :hiragana if search_word =~ /\w/
		{ :name => search_word, :rarity => rarity, :frame => frame }
	end


	def search_loading(query)
		name = /#{query[:name]}/

		url = "http://imcgcollector.blog.fc2.com/blog-entry-994.html"

		agent = Mechanize.new
		page = agent.get(url)
		tables = (page/:table)[5, 16]

		chars = tables.search(:tr).select { |tr|
			td = tr/:td
			td[0] && td[0].inner_text =~ name && td[2][:bgcolor] != "#cccccc"
		}

		chars.map { |it|
			{
				:name => (it/:td)[0].inner_text.gsub(/.?[\(（]\d*[\)）].?/, ""),
				:katagaki  => (it/:a)[1][:href],
				:loading_icon  => (it/:a)[2][:href]
			}
		}
	end


	module_function :parse_request
	module_function :rarity_to_n
	module_function :search
	module_function :search_random
	module_function :to_image_url
	module_function :search_loading
end



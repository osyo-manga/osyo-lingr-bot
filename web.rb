# -*- encoding: UTF-8 -*-
# https://github.com/raa0121/raa0121-lingrbot/blob/master/dice.rb
require 'sinatra'
require 'json'
require "mechanize"
require 'set'
require 'digest/sha1'
require 'erb'
require 'open-uri'
require 'nkf'
require "net/http"
require 'dalli'
require 'memcachier'

load "gyazo.rb"
load "codic.rb"
load "mobamasu.rb"
load "guraburu.rb"

$stdout.sync = true


get '/' do
	"Hello, world"
end

def post_to_lingr(room, bot, text, key)
		param = {
		room: room,
		bot: bot,
		text: text,
		bot_verifier: key
	}.tap {|p| p[:bot_verifier] = Digest::SHA1.hexdigest(p[:bot] + p[:bot_verifier]) }

	query_string = param.map {|e|
		e.map {|s| ERB::Util.url_encode s.to_s }.join '='
	}.join '&'
	open "http://lingr.com/api/room/say?#{query_string}"
end


# -------------------- MTG --------------------
module MTG
	def image(name)
		agent = Mechanize.new
		agent.get("http://magiccards.info/query?q=#{name}")
		agent.page.images_with(:src => /scans\/jp/)
	end

	module_function:image
end


get '/mtg' do
	"MTG"
end


get '/mtg/:name' do
	return MTG.image(params[:name]).map {|image| "<img src=#{image} />" }
end

post '/mtg' do
	content_type :text
	json = JSON.parse(request.body.string)
	json["events"].select {|e| e['message'] }.map {|e|
		text = e["message"]["text"]
		if /^#MTG/ =~ text
			result = MTG.image(text[/^#MTG[\s　]*(.+)/, 1]).join("\n")
			if result.empty?
				return "Not found."
			else
				return result
			end
		end
	}
	return ""
end


# -------------------- mobamasu --------------------
def to_mobamasu_image_url(url)
	"http://125.6.169.35/idolmaster/image_sp/card/l/#{ url[/%2F(\w+\.jpg)$/, 1]}"
end


def mobamasu_image_rand(search_word, rarity, regexp)
	if rarity.nil?
		url = "http://mobile-trade.jp/mobamasu/card?t=#{ERB::Util.url_encode search_word}"
		puts url
	else
		rarities = rarity.split(/,/)
		rarity_param = rarities.map do |r|
			'r%5B%5D=' + case r
			when 'N'
				"1"
			when 'N+'
				"2"
			when 'R'
				"3"
			when 'R+'
				"4"
			when 'SR'
				"5"
			when 'SR+'
				"6"
			else
				"1"
			end
		end.join('&')
		url = "http://mobile-trade.jp/mobamasu/card?t=#{ERB::Util.url_encode search_word}&#{rarity_param}"
	end
	agent = Mechanize.new
	agent.get(url)
# 	cards = agent.page.at('div#card').search('h1').to_a
	cards = agent.page.search("section.card").to_a
	if cards.empty?
		return nil
	end
# 	if not regexp.nil?
# 		cards = cards.select { |card|
# 			name = NKF::nkf('-WwXm0', card.at("tbody tr:first-child td:first-child div a").text)
# 			statuses = card.at("tbody tr:nth-of-type(3) td:first-child").text
# 			if statuses =~ /ｽｷﾙ:(.*)[\s　]*ｽｷﾙ効果:(.*?)[\s　]*$/
# 				skill = NKF::nkf('-WwXm0', $1)
# 				regexp.match(name) or regexp.match(skill) or regexp.match(skill[1..-2])
# 			else
# 				regexp.match(name)
# 			end
# 		}
# 	end
	result = cards[rand(cards.length)]
	if result.nil?
		nil
	else
		name = result.search("a").to_a[1].text.strip
		rarity_str = result.search("a").to_a[2].text.strip
		status = result.search("div.one_column_structure")
		image_url = to_mobamasu_image_url status.at("div.image").at("a").attributes["href"].to_s
		cost = status.search("span.value").to_a[1].at("a").text
		skills = status.at("div.skill")
		skill = skills && skills.search("span.field").text
		effect = skills && skills.search("span.value").text

# 		statuses = result.at("tbody tr:nth-of-type(3) td:first-child").text
# 		if statuses =~ /攻:(\d+\/\d+)/
# 			str = $1
# 		end
# 		if statuses =~ /守:(\d+\/\d+)/ or statuses =~ /防:(\d+\/\d+)/
# 			con = $1
# 		end
# 		if statuses =~ /ｺｽﾄ:(\d+)/
# 			cost = $1
# 		end
# 		if statuses =~ /ｽｷﾙ:(.*)[\s　]*ｽｷﾙ効果:(.*?)[\s　]*$/
# 			skill = $1
# 			effect = $2
		"#{name}\n#{image_url}\n#{rarity_str} ｺｽﾄ:#{cost} " + (skills.nil? ? "" : " ｽｷﾙ:#{skill} 効果:#{effect}")
	end
end

def mobamasu_image_rand_from_api(search_word, rarity, regexp)
	# Get data
	cachier = Dalli::Client.new
	idols = cachier.get 'idols'
	unless idols
		res = Net::HTTP.get_response URI.parse('http://sckdb.com/api/idols.json')
		if res.code == '200'
			idols = JSON.parse(res.body).map{|idol|
				# to zenkaku
				idol.name = NKF::nkf('-WwXm0', idol.name)
			}
			cachier.set('idols', idols)
		end
	end
	return nil unless idols
	# apply condition
	unless rarity.nil?
		idols.reject!{|idol|
			idol.rarity != rarity
		}
	end
	unless regexp.nil?
		idols.select!{|idol|
			# TODO: match also with skill
			regexp.match idol.name
		}
	end
	idol = idols.sample
	return nil unless idol
	idol.tap{|i|
		image = "http://125.6.169.35/idolmaster/image_sp/card/l/#{i.image_hash}.jpg"
		break "#{i.name}\n#{image}\n#{i.idol_type} #{i.rarity} ｺｽﾄ:#{i.cost}\n初期 攻/守: #{i.initial_attack}/#{i.initial_defense}\n最大 攻/守:#{i.max_attack}/#{i.max_defense}"
	}
end

def get_mobamasu_image(text, frame = false)
	(op, search_word, *args) = text.split(/[\s　]+/, 4)
	if search_word.nil?
		return ""
	end
	rarity = nil
	regexp = nil
	args.each do |arg|
		if arg =~ /^(N|N\+|R|R\+|SR|SR\+)(,(N|N\+|R|R\+|SR|SR\+))*$/
			rarity = arg
		end
		if arg =~ /^\/.*\/$/
			regexp = Regexp.new(NKF::nkf('-WwXm0', arg[1..-2]))
		end
	end
	result = mobamasu_image_rand(search_word, rarity, regexp)
# 	result = mobamasu_image_rand(search_word, rarity, regexp)
	if result.nil?
		return "#{search_word} is not found."
	else
		return frame ? result : result.sub(/\/l\//, "/l_noframe/")
	end
end


def post_mobamasu(text)
	query = Mobamasu.parse_request(text)
	idol = Mobamasu.search_random query
	if idol.nil?
		return "Not found."
	end
	"#{idol["Name"]}\n#{Mobamasu.to_image_url(idol["ID"], query[:frame])}"
end


post '/mobamasu' do
	content_type :text
	json = JSON.parse(request.body.string)
	json["events"].select {|e| e['message'] }.map {|e|
		text = e["message"]["text"]
		if /^#mobamasu!?[\s　]+(.+)/i =~ text
			return post_mobamasu(text)
		end
# 		if /^#mobamasu[\s　]+(.+)/i =~ text
# 			return get_mobamasu_image(text, true)
# 		elsif /^(#mobamasu_no_frame|#mobamasu!)[\s　]+(.+)/i =~ text
# 			return get_mobamasu_image(text)
# 		end
	}
	return ""
end


# test
get '/test' do
	"test"
end

post '/test' do
	content_type :text
	json = JSON.parse(request.body.string)
	json["events"].select {|e| e['message'] }.map {|e|
		m = e["message"]["text"]

		if /^http:\/\/www.pixiv.net\/member_illust.php\?mode=medium&illust_id=\d+/ =~ m
		agent = Mechanize.new
		agent.get(m)
			pixiv = agent.page.at('a.medium-image').children[0].attributes["src"].value
			file = Time.now.to_i
			agent.get(pixiv, nil,
					  "http://www.pixiv.net",
					  nil).save("./pixiv_#{file}.png")
			gyazo = Gyazo.new ""
			result = gyazo.upload "pixiv_#{file}.png"
# 			File.delete("pixiv_#{file}.png")
			return result
# 			return "pixiv_#{file}.png"
		end
	}
	return ""
end


# -------------------- gyazo --------------------
def post_lingr_gyazo(room, url, width, height, top=0, left=0)
	Thread.start do
		cmd = "http://trickstar.herokuapp.com/api/gyazo/?url=#{url.gsub(/&/, "%26")}&bottom=#{height}&right=#{width}&top=#{top}&left=#{left}"

		result = ""
		open(cmd){ |f|
			result += f.read
		}

		param = {
			room: room,
			bot: 'gyazo',
			text: url + "\n" + result,
			bot_verifier: ENV['GYAZO_BOT_KEY']
		}.tap {|p| p[:bot_verifier] = Digest::SHA1.hexdigest(p[:bot] + p[:bot_verifier]) }

		query_string = param.map {|e|
			e.map {|s| ERB::Util.url_encode s.to_s }.join '='
		}.join '&'
		open "http://lingr.com/api/room/say?#{query_string}"
	end
end


post '/gyazo' do
	content_type :text
	json = JSON.parse(request.body.string)
	json["events"].select {|e| e['message'] }.map {|e|
		text = e["message"]["text"]
		room = e["message"]["room"]

		if /^(http:\/\/www\.amazon.+)/ =~ text
			post_lingr_gyazo(room, text[/^(http:\/\/www\.amazon.+)/, 1], 800, 500)
# 			post_lingr_gyazo(room, "http://www.amazon.co.jp/" + text[/http:\/\/www\.amazon\.co\.jp\/.*(dp\/[A-Z0-9]+).*/, 1], 800, 500)
		end
		if /^#gyazo[\s　]*(http.+)/i =~ text
			post_lingr_gyazo(room, $1, 800, 800)
		end
		if /^#image[\s　]*(.+)/i =~ text
			word = $1.split(/[\s　]/).map {|s| ERB::Util.url_encode s }.join("+")
			url = "http://www.google.co.jp/search?&q=#{word}&tbm=isch"
			post_lingr_gyazo(room, url, 0, 800, 140, 110)
		end
	}
	return ""
end


# -------------------- vimhelpjp --------------------
post '/vimhelpjp' do
	content_type :text
	json = JSON.parse(request.body.string)
	json["events"].select {|e| e['message'] }.map {|e|
		text = e["message"]["text"]
		room = e["message"]["room"]

		if /^:help[\s　]*(.+)/ =~ text
			query = text[/^:help[\s　]*(.+)/, 1]
			url = "http://vim-help-jp.herokuapp.com/api/?query=#{ERB::Util.url_encode query}"
			result = open(url).read
			return result.empty? ? "Not found" : result
		end
	}
	return ""
end


# -------------------- wandbox --------------------
load "./wandbox.rb"

def post_lingr_wandbox(room, code)
	Thread.start do
		result = Wandbox.compile(code).gsub("  ", "　").slice(0, 1000)
		post_to_lingr(room, "wandbox", result, ENV['WANDBOX_BOT_KEY'])
	end
end

def post_lingr_wandbox_run(room, lang, code)
	Thread.start do
		result = Wandbox.run(lang, code).gsub("  ", "　").slice(0, 1000)
		post_to_lingr(room, "wandbox", result, ENV['WANDBOX_BOT_KEY'])
	end
end

def post_lingr_wandbox_code(room, permlink)
	Thread.start do
		result = Wandbox.get_from_permlink(permlink)
		result = <<"EOS"
[code]
#{result.fetch("parameter", {})["code"].chomp}
[compiler message]
#{result.fetch("result", {})["compiler_message"]}
[output]
#{result.fetch("result", {})["program_message"]}
EOS
		result = result.chomp.gsub(/^$/, "　").gsub("	", "　　").gsub("  ", "　").slice(0, 1000)
		post_to_lingr(room, "wandbox", result, ENV['WANDBOX_BOT_KEY'])
	end
end


post '/wandbox' do
	content_type :text
	json = JSON.parse(request.body.string)
	json["events"].select {|e| e['message'] }.map {|e|
		text = e["message"]["text"]
		room = e["message"]["room"]

		if /^!wandbox-cpp[\s　]*help/i =~ text
			return "!wandbox-cpp {expr} で {expr} の結果を返します。\n{expr} には結果が標準出力可能な式、もしくはラムダ式が設定できます\nラムダ式の場合はラムダ式が評価された結果が出力されます"
		elsif /^!wandbox-cpp[\s　]*(.+)/i =~ text
			post_lingr_wandbox(room, $1)
		elsif /^!wandbox-(\S+)[\s　]*(.+)/i =~ text
			post_lingr_wandbox_run(room, $1, $2)
		elsif text =~ /^!wandbox[\s　]+http:\/\/melpon.org\/wandbox\/permlink\/(\w+)$/
			post_lingr_wandbox_code(room, $1)
		end
	}
	return ""
end

get '/wandbox' do
	return "wandbox"
end




# -------------------- codic --------------------
# codic   : http://codic.jp/license.html
# license : http://creativecommons.org/licenses/by-sa/3.0/deed.ja
NAMING = Naming.new("codic")


def post_lingr_codic(room, query)
	Thread.start do
		text = NAMING.find_to_string(query)
		if text.empty?
			text = "Not found."
		end
		post_to_lingr(room, "codic", text, ENV['CODIC_BOT_KEY'])
	end
end


get '/codic/api/text' do
	query  = params[:query]
	if !query
		return ""
	end
	text = NAMING.find_to_string(query)
	CGI.escapeHTML(text).gsub(/\n/, "<br>")
end


post '/codic/lingr' do
	content_type :text
	json = JSON.parse(request.body.string)
	json["events"].select {|e| e['message'] }.map {|e|
		text = e["message"]["text"]
		room = e["message"]["room"]
		
		if /#codic\s+(.+)/i =~ text
			post_lingr_codic(room, $1)
		end
	}
	return ""
end



post '/guraburu' do
	content_type :text
	json = JSON.parse(request.body.string)
	json["events"].select {|e| e['message'] }.map {|e|
		text = e["message"]["text"]
		if /^#guraburu[\s　]+(.+)/i =~ text
			result = Guraburu.search_images Guraburu.parse_request(text)
			puts result
			images = result
			return "#{name}\n#{images[rand(images.length)]}"
		end
	}
	return ""
end




# -*- encoding: UTF-8 -*-
# https://github.com/raa0121/raa0121-lingrbot/blob/master/dice.rb
require 'sinatra'
require 'json'
require "mechanize"
require 'set'
require 'digest/sha1'
require 'erb'
require 'open-uri'

load "gyazo.rb"


get '/' do
	"Hello, world"
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
def mobamasu_image_rand(name, rarity)
	if rarity.nil?
		url = "http://mobile-trade.jp/fun/idolmaster/card.php?_name=#{ERB::Util.url_encode name}"
	else
		rarities = rarity.split(/,/)
		rarity_param = rarities.map do |r|
			'rarity%5B%5D=' + case r
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
		url = "http://mobile-trade.jp/fun/idolmaster/card.php?_name=#{ERB::Util.url_encode name}&#{rarity_param}"
	end
	agent = Mechanize.new
	agent.get(url)
	result = agent.page.links_with(:href => /Fidolmaster/)
	if result.empty?
		return ""
	end
	result[rand(result.length)].href
end

def get_mobamasu_image(text, frame = false)
	(op, name, rarity) = text.split(/[\s　]+/, 3)
	if name.nil?
		return ""
	end
	result = mobamasu_image_rand(name, rarity)
	if result.empty?
		return "Not found."
	else
		return frame ? result : result.sub(/%2Fl%2F/, "%2Fl_noframe%2F")
	end
end


post '/mobamasu' do
	content_type :text
	json = JSON.parse(request.body.string)
	json["events"].select {|e| e['message'] }.map {|e|
		text = e["message"]["text"]
		if /^#mobamasu[\s　]+(.+)/ =~ text
			return get_mobamasu_image(text)
		end
		if /^#mobamasu_frame[\s　]+(.+)/ =~ text
			return get_mobamasu_image(text, true)
		end
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
			result += f.read + "\n"
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
		if /^#gyazo[\s　]*(http.+)/ =~ text
			post_lingr_gyazo(room, text[/^#gyazo[\s　]*(http.+)/, 1], 0, 800)
		end
		if /^#image[\s　]*(.+)/ =~ text
			word = text[/^#image[\s　]*(.+)/, 1].split(/[\s　]/).map {|s| ERB::Util.url_encode s }.join("+")
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





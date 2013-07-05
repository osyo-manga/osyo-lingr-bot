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
def mobamasu_image_rand(name)
	url = "http://mobile-trade.jp/fun/idolmaster/card.php?_name=#{name}"
	agent = Mechanize.new
	agent.get(url)
	result = agent.page.links_with(:href => /Fidolmaster/)
	if result.empty?
		return ""
	end
	result[rand(result.length)].href
end

post '/mobamasu' do
	content_type :text
	json = JSON.parse(request.body.string)
	json["events"].select {|e| e['message'] }.map {|e|
		text = e["message"]["text"]
		if /^#mobamasu/ =~ text
			result = mobamasu_image_rand(text[/^#mobamasu[\s　]*(.+)/, 1])
			if result.empty?
				return "Not found."
			else
				return result
			end
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
def post_lingr_gyazo(room, url, width, height)
	Thread.start do
		url = "http://trickstar.herokuapp.com/api/gyazo/?url=#{url}&bottom=#{height}&right=#{width}"

		result = ""
		open(url){ |f|
			result += f.read + "\n"
		}

		param = {
			room: room,
			bot: 'gyazo',
			text: result,
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

		if /^(http:\/\/www.amazon.+)/ =~ text
			post_lingr_gyazo(text[/^(http:\/\/www.amazon.+)/, 1], 800, 500)
		end
		if /^#gyazo[\s　]*(http.+)/ =~ text
			post_lingr_gyazo(text[/^#gyazo[\s　]*(http.+)/, 1], 800, 500)
		end
	}
	return ""
end


# -*- encoding: UTF-8 -*-
# https://github.com/raa0121/raa0121-lingrbot/blob/master/dice.rb
require 'sinatra'
require 'json'
require "mechanize"

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
		text = e["message"]["text"]

		if /^http:\/\/www.pixiv.net\/member_illust.php\?mode=medium&illust_id=\d+/ =~ m
			agent.get(m)
			pixiv = agent.page.at('a.medium-image').children[0].attributes["src"].value
			file = Time.now.to_i
			agent.get(pixiv, nil,
					  "http://www.pixiv.net",
					  nil).save("./pixiv_#{file}.png") 
			url = `./gyazo pixiv_#{file}.png`.gsub("\n","")
			File.delete("pixiv_#{file}.png")
			"#{url.sub("//","//cache.")}.png"
		end
	}
	return ""
end



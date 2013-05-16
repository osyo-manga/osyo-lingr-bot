# https://github.com/raa0121/raa0121-lingrbot/blob/master/dice.rb
require 'rubygems'
require 'sinatra'
require 'json'
require "mechanize"


# -------------------- MTG --------------------
module MTG
	def image(name)
		agent = Mechanize.new
		agent.get("http://magiccards.info/query?q=#{name}")
		agent.page.images_with(:src => /scans\/jp/)
	end

	module_function:image
end

get '/' do
	"Hello, world"
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
			result = MTG.image(text[/^#MTG\s*(.+)/, 1]).join("\n")
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
			result = mobamasu_image_rand(text[/^#mobamasu\s*(.+)/, 1])
			if result.empty?
				return "Not found."
			else
				return result
			end
		end
	}
	return ""
end


# -------------------- kwsm --------------------

module KWSM
	urls = [
		"http://yomigee.blog87.fc2.com/blog-entry-1615.html",
		"http://yomigee.blog87.fc2.com/blog-entry-1614.html"
	]

	agent = Mechanize.new
	@@images = urls.map {|url|
		agent.get(url).images_with(:src => /cg/)
	}.flatten
	
	def image_rand
		@@images[rand(@@images.length)]
	end

	module_function:image_rand
end


get '/kwsm' do
	"<img src=\"#{KWSM.image_rand.src}\">"
end


post '/kwsm' do
	content_type :text
	json = JSON.parse(request.body.string)
	json["events"].select {|e| e['message'] }.map {|e|
		text = e["message"]["text"]
		if /^#kwsm/ =~ text
			return "わかるわ\n" + KWSM.image_rand
		end
	}
	return ""
end



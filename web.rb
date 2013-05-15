# https://github.com/raa0121/raa0121-lingrbot/blob/master/dice.rb
require 'rubygems'
require 'sinatra'
require 'json'
require "mechanize"


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
	result = ""
	json = JSON.parse(request.body.string)
	json["events"].select {|e| e['message'] }.map {|e|
		text = e["message"]["text"]
		if /^#MTG/ =~ text
			result += MTG.image(text[/^#MTG\s*(.+)/, 1]).join("\n") + "\n"
		end
	}
	return result
end



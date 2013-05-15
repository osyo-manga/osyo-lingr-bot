# https://github.com/raa0121/raa0121-lingrbot/blob/master/dice.rb
require 'rubygems'
require 'sinatra'
require 'json'
require "mechanize"


module MTG
	def image(name)
		agent = Mechanize.new
		agent.get("http://magiccards.info/query?q=#{name}")
		agent.page.images_with(:src => /scans\/jp\/pvc/)
	end

	module_function:image
end


get '/mtg' do
	"hoge"
end

post '/mtg' do
	content_type :text
	json = JSON.parse(request.body.string)
	json["events"].select {|e| e['message'] }.map {|e|
		text = e["message"]["text"]
		if /^#MTG/ =~ text
			return MTG.imge(text[/^#MTG\s*(.+)/, 1]).join("\n")
		end
	}
	""
end



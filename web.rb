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
		if /^#kwsm/ =~ text || /わかるわ/u =~ text || /わからないわ/ =~ text
			return "わかるわ\n" + KWSM.image_rand.src
		end
	}
	return ""
end


# --------------------reading_vimrc --------------------

class ReadingVimrc
	def initialize
		@is_running_ = false
		@messages = []
	end

	def is_running?
		@is_running_
	end

	def start
		@is_running_ = true
		@messages = []
	end

	def stop
		@is_running_ = false
	end
	
	def members
		@messages.map {|mes| mes[:name] }.uniq
	end

	def status
		is_running? ? "started" : "stopped"
	end

	def add(message)
		if is_running?
			@messages << message
		end
	end
end

reading_vimrc = ReadingVimrc.new

get '/reading_vimrc' do
	"status: #{reading_vimrc.status}<br>members<br>#{reading_vimrc.members.join('<br>')}"
end


post '/reading_vimrc' do
	content_type :text
	json = JSON.parse(request.body.string)
	json["events"].select {|e| e['message'] }.map {|e|
		text = e["message"]["text"]
		if /^!reading_vimrc[\s　]start$/ =~ text
			reading_vimrc.start
			return "started"
		end
		if /^!reading_vimrc[\s　]stop$/ =~ text
			reading_vimrc.stop
			return "stoped"
		end
		if /^!reading_vimrc[\s　]status$/ =~ text
			return reading_vimrc.status
		end
		if /^!reading_vimrc[\s　]member$/ =~ text
			members = reading_vimrc.members
			return members.empty? ? "だれもいませんでした" : members.join("\n")
		end
		if /^!reading_vimrc[\s　]help$/ =~ text
			str = <<"EOS"
vimrc読書会で発言した人を集計するための bot です

!reading_vimrc {command}

"start"  : 集計の開始
"stop"   : 集計の終了
"status" : ステータスの出力
"member" : "start" ～ "stop" の間に発言した人を列挙
"help"   : 使い方を出力
EOS
			return str
		end
		if /^!reading_vimrc[\s　]*(.+)$/ =~ text
			return "Not found command"
		end
		reading_vimrc.add({:name => e["message"]["speaker_id"], :text => text})
	}
	return ""
end



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
require "csv"

load "gyazo.rb"
load "codic.rb"


get '/' do
	"Hello, world"
end

def post(room, bot, text, key)
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
def mobamasu_image_rand(search_word, rarity, regexp)
	if rarity.nil?
		url = "http://mobile-trade.jp/fun/idolmaster/card.php?_name=#{ERB::Util.url_encode search_word}"
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
		url = "http://mobile-trade.jp/fun/idolmaster/card.php?_name=#{ERB::Util.url_encode search_word}&#{rarity_param}"
	end
	agent = Mechanize.new
	agent.get(url)
	cards = agent.page.search("table.card_search_result_table").to_a
	if cards.empty?
		return nil
	end
	if not regexp.nil?
		cards = cards.select { |card|
			name = NKF::nkf('-WwXm0', card.at("tbody tr:first-child td:first-child div a").text)
			statuses = card.at("tbody tr:nth-of-type(3) td:first-child").text
			if statuses =~ /ｽｷﾙ:(.*)[\s　]*ｽｷﾙ効果:(.*?)[\s　]*$/
				skill = NKF::nkf('-WwXm0', $1)
				regexp.match(name) or regexp.match(skill) or regexp.match(skill[1..-2])
			else
				regexp.match(name)
			end
		}
	end
	result = cards[rand(cards.length)]
	if result.nil?
		nil
	else
		name = result.at("tbody tr:first-child td:first-child div a").text
		image_url = result.at("tbody tr:nth-of-type(2) td:first-child a").attributes["href"].value
		rarity_str = result.at("tbody tr:first-child td:first-child div a:last-child").text
		statuses = result.at("tbody tr:nth-of-type(3) td:first-child").text
		if statuses =~ /攻:(\d+\/\d+)/
			str = $1
		end
		if statuses =~ /守:(\d+\/\d+)/ or statuses =~ /防:(\d+\/\d+)/
			con = $1
		end
		if statuses =~ /ｺｽﾄ:(\d+)/
			cost = $1
		end
		if statuses =~ /ｽｷﾙ:(.*)[\s　]*ｽｷﾙ効果:(.*?)[\s　]*$/
			skill = $1
			effect = $2
		end
		"#{name}\n#{image_url}\n#{rarity_str} ｺｽﾄ:#{cost} " + (skill.nil? ? "" : " ｽｷﾙ:#{skill} 効果:#{effect}")
	end
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
	if result.nil?
		return "#{search_word} is not found."
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
			return get_mobamasu_image(text, true)
		elsif /^(#mobamasu_no_frame|#mobamasu!)[\s　]+(.+)/ =~ text
			return get_mobamasu_image(text)
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


# -------------------- wandbox --------------------
def compile(expr)
	code = <<"EOS"
#include <iostream>
#include <functional>
#include <algorithm>
#include <string>
#include <tuple>
#include <typeinfo>
#include <boost/config.hpp>


template<typename T>
void
print_type(){
	T* value;
}

template<typename T>
void
print_type(T){
	T* value;
}


auto
func(){
	return #{expr};
}

template<typename F>
auto
output_impl(F func, bool&&)
->decltype(std::cout << func()){
	return std::cout << func();
}


template<typename F>
auto
output_impl(F const& func, bool const&&)
->decltype(func()){
	func();
}


template<typename T>
auto
output_impl(T const& value, bool const&)
->decltype(std::cout << value){
	return std::cout << value;
}


template<typename F>
auto
output(F func, bool&&)
->decltype(output_impl(func(), true)){
	return output_impl(func(), true);
}
syo_manga



template<typename F>
void
output(F func, bool const&&){
	func();
}


int
main(){
	output(func, false);
	return 0;
}
EOS

	body = {
		"code" => code,
		"options" => "c++1y,boost-1.55,warning",
		"compiler" => "clang-head",
	}

	uri = URI.parse("http://melpon.org/wandbox/api/compile.json")

	request = Net::HTTP::Post.new(uri.request_uri, initheader = { "Content-type" => "application/json" },)
	request.body = body.to_json

	http = Net::HTTP.new(uri.host, uri.port)
	# http.set_debug_output $stderr

	http.start do |http|
		response = http.request(request)
		result = JSON.parse(response.body)
		return result["program_output"] ? result["program_output"] : result["compiler_error"]
	end
end


def post_lingr_wandbox(room, code)
	Thread.start do
		result = compile(code).gsub("  ", "　")
		post(room, "wandbox", result, ENV['WANDBOX_BOT_KEY'])
	end
end


post '/wandbox' do
	content_type :text
	json = JSON.parse(request.body.string)
	json["events"].select {|e| e['message'] }.map {|e|
		text = e["message"]["text"]
		room = e["message"]["room"]

		if /^!wandbox-cpp[\s　]*help/ =~ text
			return "!wandbox-cpp {expr} で {expr} の結果を返します。\n{expr} には結果が標準出力可能な式、もしくはラムダ式が設定できます\nラムダ式の場合はラムダ式が評価された結果が出力されます"
		elsif /^!wandbox-cpp[\s　]*(.+)/ =~ text
			post_lingr_wandbox(room, $1)
		end
	}
	return ""
end

get '/wandbox' do
	return "wandbox"
end




# -------------------- codic --------------------
NAMING = Naming.new("codic")


get '/codic/api/text' do
	query  = params[:query]
	if !query
		return ""
	end
	NAMING.find_to_string(query)
end


post '/codic/lingr' do
	content_type :text
	json = JSON.parse(request.body.string)
	json["events"].select {|e| e['message'] }.map {|e|
		text = e["message"]["text"]
		room = e["message"]["room"]
		
		if /#codic\s+(.+)/ =~ text
			return NAMING.find_to_string($1)
		end
	}
	return ""
end


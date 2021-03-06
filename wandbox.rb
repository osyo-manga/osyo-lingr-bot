require 'open-uri'
require "net/http"
require 'json'


module Wandbox

	def compile(expr)
		code = <<"EOS"
#include <iostream>
#include <functional>
#include <algorithm>
#include <string>
#include <tuple>
#include <typeinfo>
#include <cstdio>
#include <vector>
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
			"compiler-option-raw" => "-fno-color-diagnostics",
		}

		uri = URI.parse("http://melpon.org/wandbox/api/compile.json")

		request = Net::HTTP::Post.new(uri.request_uri, initheader = { "Content-type" => "application/json" },)
		request.body = body.to_json

		http = Net::HTTP.new(uri.host, uri.port)
		# http.set_debug_output $stderr

		http.start do |http|
			response = http.request(request)
			result = JSON.parse(response.body)
			return (result["program_output"] ? result["program_output"] : result["compiler_error"]).chomp
		end
	end
	
	module_function :compile

	def run(lang, code)
		body = {
			"compiler" => lang,
			"code" => code,
			"options" => "",
			"compiler-option-raw" => "",
		}

		uri = URI.parse("http://melpon.org/wandbox/api/compile.json")

		request = Net::HTTP::Post.new(uri.request_uri, initheader = { "Content-type" => "application/json" },)
		request.body = body.to_json

		http = Net::HTTP.new(uri.host, uri.port)
		# http.set_debug_output $stderr

		http.start do |http|
			response = http.request(request)
			result = JSON.parse(response.body)
			(result.has_key? "program_message") ? result["program_message"].chomp : "Not found compiler."
		end
	end

	module_function :run

	def get_from_permlink(permlink)
		uri = URI.parse "http://melpon.org/wandbox/api/permlink/#{ permlink }"

		request = Net::HTTP::Get.new(uri.path)
		http = Net::HTTP.new(uri.host, uri.port)
		http.start do |http|
			response = http.request(request)
			result = JSON.parse(response.body)
		end
	end

	def get_code(permlink)
		get_from_permlink(permlink).fetch("parameter", {})["code"]
	end
	
	module_function :get_from_permlink
	module_function :get_code
end


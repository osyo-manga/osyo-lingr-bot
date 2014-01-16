# -*- encoding: UTF-8 -*-
require "CSV"


class Entry
	def initialize(csv_file)
		@csv = CSV.read(csv_file, :encoding => 'UTF-8')
	end

	def find_word(word)
		@csv.select { | line | /#{word}/ =~ line[1] }
	end
end


class Translation
	def initialize(csv_file)
		@csv = CSV.read(csv_file, :encoding => 'UTF-8')
	end

	def find_id(id)
		@csv.select { | line | id == line[0] }
	end
end


class NamingNihongo
	def initialize(csv_directory)
		@entry = Entry.new(csv_directory + "/" + "naming-entry.csv")
		@translation = Translation.new(csv_directory + "/" + "naming-translation.csv")
	end

	def find(word)
		@entry.find_word(word).map { | line |
			{
				:name => line[1],
				:children => @translation.find_id(line[0]).map { | line |
					{
						:word => line[3],
						:comment => line[4]
					}
				}
			}
		}
	end

	def find_to_string(word)
		find(word).map{ | entry |
			entry[:name] + "\n" + entry[:children].map { | child |
				"　*" + child[:word] + (child[:comment].empty? ? "" : " : #{child[:comment]}" )
			}.join("\n")
		}.join("\n")
	end
end


class NamingEigo
	def initialize(csv_directory)
		@entry = Entry.new(csv_directory + "/" + "english-entry.csv")
		@translation = Translation.new(csv_directory + "/" + "english-translation.csv")
	end

	def find(word)
		@entry.find_word(word).map { | line |
			{
				:name => line[1],
				:kana => line[3],
				:verb => line[6],
				:children => @translation.find_id(line[0]).map { | line |
					{
						:word => line[2],
						:comment => line[4]
					}
				}
			}
		}
	end

	def find_to_string(word)
		find(word).map{ | entry |
			"[#{entry[:name]}] #{entry[:kana]}" + "\n" + entry[:children].map { | child |
				"　*" + child[:comment]
# 				"　*" + child[:word] + (child[:comment].empty? ? "" : " : #{child[:comment]}" )
			}.join("\n")
		}.join("\n")
	end
end


class Naming
	def initialize(csv_directory)
		@nihongo = NamingNihongo.new(csv_directory)
		@eigo    = NamingEigo.new(csv_directory)
	end

	def find(word)
		
	end
	
	def find_to_string(word)
		if /(?:\p{Hiragana}|\p{Katakana}|[一-龠々])/ =~ word
			@nihongo.find_to_string(word)
		else
			@eigo.find_to_string(word)
		end
	end
end


#!/usr/bin/env ruby
# encoding: utf-8

load 'rb/gallery.rb'

filters = {}
filters['gallery'] = 'lenkun'
gallery = Gallery::Gallery.new("gallery.db", filters)

count = 0
gallery.getYears().each do |y|
	puts y
	gallery.getMonths(y).each do |m|
		puts " - #{m}"
		gallery.getDays(y, m).each do |d|
			print "   - #{d}: #{gallery.getPhotos(y, m, d).length}; "
			count = count + gallery.getPhotos(y, m, d).length
			puts gallery.getPhotos(y, m, d).join(', ')
		end
	end
end

puts "Total count: #{count}"
puts
puts "Countries:"
countries = gallery.getCountries()
countries.keys.each do |c|
	puts " - #{c} = #{countries[c]}"
end
puts
puts "Cameras:"
cameras = gallery.getCameras()
cameras.each do |c|
	puts " - #{c}"
end
puts
puts "Authors:"
authors = gallery.getAuthors()
authors.each do |c|
	puts " - #{c}"
end

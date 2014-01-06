#!/usr/bin/ruby1.8
# encoding: utf-8

load 'rb/test_gallery.rb'

filters = {}
filters['gallery'] = 'lenkun1'
gallery = Gallery::Gallery.new("test_lenkun.db", filters)

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

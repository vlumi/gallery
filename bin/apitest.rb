#!/usr/bin/env ruby
# encoding: utf-8

load 'rb/gallery.rb'

filters = {}
#filters['gallery'] = 'lenkun'
gallery = Gallery::Gallery.new("gallery.sqlite3", filters)

count = 0
gallery.getYears.each do |y|
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
puts "Galleries:"
p gallery.getGalleries
p gallery.gallery_counts
puts
puts "Countries:"
p gallery.getCountries
puts
puts "Cameras:"
p gallery.getCameras
puts
puts "Authors:"
p gallery.getAuthors

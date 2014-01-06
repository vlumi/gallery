#!/usr/bin/ruby
require 'sqlite3'
require 'RMagick'

@files = ARGV
@all_files = false

@camera_map = {
	'DMC-GF1' 			=> 'Panasonic DMC-GF1',
	'FinePix F50fd' => 'Fuji FinePix F50fd',
	'iPhone 4'			=> 'Apple iPhone 4',
}

if @files.length == 0 then
	@all_files = true
	@files = Dir["thumbs/*.jpg"].sort.collect do |f|
		f.split(/\//)[-1];
	end
end

database = SQLite3::Database.new("lenkun.db");
database.transaction do |db|

	if @all_files then
		db.execute("DELETE FROM photos");
	end

	stmt_del = db.prepare("DELETE FROM photos WHERE name = ?")
	stmt_ins = db.prepare("INSERT INTO photos (name, title, taken, country, author, camera, width, height, t_width, t_height) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
	@files.each do |f|
		title = ""

		md = /^(\d\d\d\d)(\d\d)(\d\d)_(\d\d)(\d\d)(\d\d)_(.*)_\d+\.jpg$/.match(f)
		taken = sprintf("%04d-%02d-%02d %02d:%02d:%02d", md[1].to_i, md[2].to_i, md[3].to_i, md[4].to_i, md[5].to_i, md[6].to_i)
		camera = md[7].gsub(/_/, ' ')
		if @camera_map.has_key?(camera) then
			camera = @camera_map[camera]
		end

		country = "nl"
		author = "Ville Misaki"

		width, height, t_width, t_height = 0, 0, 0, 0
		Magick::ImageList.new("#{f}").each do |img|
			width, height = img.columns, img.rows
		end
		Magick::ImageList.new("thumbs/#{f}").each do |img|
			t_width, t_height = img.columns, img.rows
		end

		if not @all_files then
			stmt_del.execute(f);
		end

		puts "Inserting file '#{f}' to DB: '#{title}', '#{taken}', country: #{country}, author: #{author}, camera: #{camera}, full: #{width}x#{height}, thumbnail: #{t_width}x#{t_height}"
		stmt_ins.execute(f, "", taken, country, author, camera, width, height, t_width, t_height)

		ObjectSpace.garbage_collect
	end # files

end # transaction

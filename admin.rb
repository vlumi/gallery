#!/usr/bin/ruby
# encoding: utf-8

# Script for managing the gallery database.
#
# Usage: ./admin.rb [options] [file(s)]
#
# Running without parameters searches for new photos in full/, prompting for the properties of each,
# and inserts them into the database, outside of any galleries.
#
# If no files are included as parameters, operates in "insert" mode, not touching old photos.
# To update old photos' properties (including EXIF), include them in the parameters
#
# Copyright 2014 Ville Misaki

require 'optparse'
require 'exifr'
require 'sqlite3'
require 'RMagick'

# Parse parameters in full scope.
@dbfile = 'gallery.db'
@exifonly = false
@verbose  = false
@simulate = false

OptionParser.new do |o|
  o.on("--exifonly", "Only load and update the exif to the database, not touching user-specific fields.") do |v|
    @exifonly = true
  end
  o.on("--verbose", "Verbose output.") do |v|
    @verbose = true
  end
  o.on("--simulate", "Don't actually do any changes, just show what would be done.") do |v|
    @simulate = true
  end
  o.on("-h", "--help") do |v|
    puts o
    exit
  end
  o.parse!
end

def main
  files = ARGV
  all_files = false

  if files.length == 0 then
    all_files = true
    files = Dir["full/*.jpg"].sort
  end
  files = files.collect { |f| File.basename(f) }

  # Collect information about the photos on the disk.
  photos_disk = {}
  files.each do |f|
    photos_disk[f] = EXIFR::JPEG.new('full/' + f).to_hash
  end

  exif_models = photos_disk.keys.collect do |f|
    if photos_disk[f][:model].start_with?(photos_disk[f][:make]) then
      photos_disk[f][:model]
    else
      [ photos_disk[f][:make], photos_disk[f][:model] ].join(' ')
    end
  end.uniq.sort

  database = init_db @dbfile
  database.transaction do |db|
    fields = {
      photos: {
        user: %w{ title description country place author },
        db: %w{
          name taken
          title description country place author
          camera fstop shutter iso
          width height t_width t_height
        },
      },
    }

    photos_db = {}
    db.execute("SELECT #{fields[:photos][:db].join(',')} FROM photos") do |row|
      photos_db[ row['name'] ] = row
    end

    missing_files = files & (photos_db.keys - photos_disk.keys)
    new_files = files & (photos_disk.keys - photos_db.keys)

    if missing_files.length > 0 then
      puts "The following files found in the database were not found on disk:"
      puts missing_files.collect { |f| " - #{f}\n"  }
    end

    if new_files.length > 0 then
      insert_new_photos files: new_files, db: db, fields: fields, exif: photos_disk
    end

    unless all_files then
      old_files = files & (photos_disk.keys - new_files)
      update_photo_meta files: old_files, db: db, fields: fields, exif: photos_disk, old_data: photos_db
    end

  end # transaction

end # main

def init_db(dbfile)
  create_db = true unless File.exist? dbfile
  schema_version = nil

  database = SQLite3::Database.new(dbfile)
  begin
    database.transaction do |db|
      db.results_as_hash = true
      db.type_translation = true
      db.execute('SELECT version FROM schema_info') do |row|
        schema_version = row['version']
      end
    end
  rescue SQLite3::SQLException => e
    if e.to_s == 'no such table: schema_info' then
      # FIXME: just exit, remove support for really old stuff later.
      schema_version = 0
    else
      puts "Could not determine schema version of the database dbfile, exiting:"
      p e
      exit
    end
  end

  if create_db then
    puts "Initializing database #{dbfile}"

    database.transaction do |db|
      ddl = IO.read('schema.ddl')
      db.execute_batch(ddl)
    end
  else
    schema_ddls = Dir["schema_to_*.ddl"]
    schema_versions = schema_ddls.collect { |f| f.scan(/\d+/).first.to_i }.find_all { |v| v > schema_version }.sort

    begin
      database.transaction do |db|
        schema_versions.each do |v|
          puts "Running migration to schema version #{v}"
          ddl = IO.read("schema_to_#{v}.ddl")
          db.execute_batch(ddl)
        end
      end
    rescue SQLite3::SQLException => e
      puts "Error in migration, exiting:"
      p e
      exit
    end
  end

  database
end # init_db

def insert_new_photos(opts)
  files  = opts[:files]
  db     = opts[:db]
  fields = opts[:fields]
  exif   = opts[:exif]

  sql_ins_photos  = "INSERT INTO photos (" + fields[:photos][:db].join(',') + ") VALUES (" + fields[:photos][:db].collect { |f| '?'}.join(',') + ")"
  stmt_ins_photos = db.prepare(sql_ins_photos)

  # TODO: from the last photo in the database, or the previous session..?
  prev = {
    title:       '',
    description: '',
    country:     '',
    place:       '',
    location:    '',
    author:      '',
  }

  files.each do |file|
    data = {
      name:  file,
      taken: exif[file][:date_time_original].to_s,

      title:       '',
      description: '',
      country:     '',
      place:       '',
      location:    '',
      author:      '',

      camera:  exif[file][:model],
      focal:   exif[file][:focal_length].round,
      fstop:   exif[file][:aperture_value],
      shutter: exif[file][:exposure_time].to_s,
      iso:     exif[file][:iso_speed_ratings],

      width:    0,
      height:   0,
      t_width:  0,
      t_height: 0,
      f_width:  exif[file][:width],
      f_height: exif[file][:height],
    }

    puts "Processing #{file}"

    unless @exifonly
      begin
        fields[:photos][:user].each do |field|
          prev[field.to_sym] = data[field.to_sym] = prompt_field field: field, data: data, prev: prev[field.to_sym]
        end

      rescue Exception => e
        puts e
        exit
      end
      puts
    end

    puts data if @verbose

    # FIXME: check/create thumbnails
    #      Magick::ImageList.new("i/#{file}").each do |img|
    #        data[:width], data[:height] = img.columns, img.rows
    #      end
    #      Magick::ImageList.new("thumbs/#{file}").each do |img|
    #        data[:t_width], data[:t_height] = img.columns, img.rows
    #      end

    data_ins_photos = fields[:photos][:db].collect { |f| data[f.to_sym] }

    stmt_ins_photos.execute(*data_ins_photos) unless @simulate

    ObjectSpace.garbage_collect
  end
end # insert_new_photos

def update_photo_meta(opts)
  files    = opts[:files]
  db       = opts[:db]
  fields   = opts[:fields]
  exif     = opts[:exif]
  old_data = opts[:old_data]

  sql_upd_photos  = "UPDATE photos SET " + fields[:photos][:db].collect { |field| field + '=?'  }.join(',') + " WHERE name=?"
  stmt_upd_photos = db.prepare(sql_upd_photos)

  files.each do |file|
    data = {
      name:  file,
      taken: exif[file][:date_time_original].to_s,

      #      title:       old_data[file]['title'],
      #      description: old_data[file]['description'],
      #      country:     old_data[file]['country'],
      #      place:       old_data[file]['place'],
      #      location:    old_data[file]['location'],
      #      author:      old_data[file]['author'],

      title:       '',
      description: '',
      country:     '',
      place:       '',
      location:    '',
      author:      '',

      camera:  exif[file][:model],
      focal:   exif[file][:focal_length].round,
      fstop:   exif[file][:aperture_value],
      shutter: exif[file][:exposure_time].to_s,
      iso:     exif[file][:iso_speed_ratings],

      width:    0,
      height:   0,
      t_width:  0,
      t_height: 0,
      f_width:  exif[file][:width],
      f_height: exif[file][:height],
    }

    puts "Processing #{file}"

    unless @exifonly
      begin
        fields[:photos][:user].each do |field|
          foo = prompt_field field: field, data: data, prev: old_data[file][field]
          data[field.to_sym] = foo
        end

      rescue Exception => e
        puts e
        exit
      end
      puts
    end

    puts data if @verbose

    Magick::ImageList.new("i/#{file}").each do |img|
      data[:width], data[:height] = img.columns, img.rows
    end
    Magick::ImageList.new("thumbs/#{file}").each do |img|
      data[:t_width], data[:t_height] = img.columns, img.rows
    end

    data_upd_photos = fields[:photos][:db].collect { |field| data[field.to_sym] }

    stmt_upd_photos.execute(*data_upd_photos, file) unless @simulate

    ObjectSpace.garbage_collect
  end
end # update_photo_meta

def prompt_field(opts)
  f    = opts[:field]
  data = opts[:data]
  prev = opts[:prev]

  print "  Enter #{f} [default: \"#{prev}\"; \"-\" for empty]: "
  val = $stdin.gets

  case val
  when '-' then ''
  when ''  then prev
  else val.chomp
  end
end # prompt_field

main

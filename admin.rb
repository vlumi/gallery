#!/usr/bin/ruby
# encoding: utf-8

# Script for managing the gallery database.
#
# Usage: ./admin.rb [command] [options] [photo(s)]
#
#
#
# Copyright 2014 Ville Misaki <ville@misaki.fi>

require 'optparse'
require 'exifr'
require 'sqlite3'
require 'RMagick'

@conf = {
  # Static configuration.
  dbfile: 'gallery.sqlite3',
  thumbnails: {
    i:      { width: 1500, height: 1500 },
    thumbs: { width:  600, height:  200 },
  },

  # From data and arguments.
  cmd: '',

  galleries:  [],
  photos:     [],
  all_photos: false,

  exifonly:  false,
  force:     false,
  verbose:   false,
  debug:     false,
  simulate:  false,
  help:      false,

  opts: nil,

  fields: {
    galleries: %w{ name title description epoch },
    photos: {
      user: %w{ title description country place author },
      db: %w{
        name taken
        title description country place author
        camera fstop shutter iso
        width height t_width t_height f_width f_height
      },
    },
    photo_galleries: %w{ photo_name gallery_name },
  },

}

def main

  parse_params(@conf)

  unless %w{ add update rm show g-add g-update g-rm g-show g-ls to-g from-g }.include? @conf[:cmd] then
    puts @conf[:opts]
    exit
  end

  if @conf[:photos].length == 0 then
    @conf[:all_photos] = true
    @conf[:photos] = Dir["full/*.jpg"].sort
  end
  @conf[:photos] = @conf[:photos].collect{ |f| File.basename(f) }

  database = init_db @conf[:dbfile]
  database.transaction do |db|
    db.results_as_hash = true
    db.type_translation = true

    if %w{add update rm show to-g from-g}.include? @conf[:cmd] then
      # Photo commands.

      photos_db = {}
      db.execute("SELECT " + @conf[:fields][:photos][:db].join(',') + " FROM photos") do |row|
        photos_db[ row['name'] ] = row
      end

      # Photos that were explicitly selected and are in the db.
      curr_photos = @conf[:photos] & photos_db.keys

      photos_disk = {}
      if %w{ add update }.include? @conf[:cmd] then
        # Collect information about the photos on the disk.
        @conf[:photos].each do |f|
          photos_disk[f] = EXIFR::JPEG.new('full/' + f).to_hash
        end
        missing_photos = @conf[:photos] & (photos_db.keys - photos_disk.keys)

        if missing_photos.length > 0 then
          puts "The following photos found in the database were not found on disk:"
          puts missing_photos.collect{ |f| " - #{f}\n" }
        end
      end

      case @conf[:cmd]
        
      when "add" then
        new_photos = @conf[:photos] & (photos_disk.keys - photos_db.keys)

        insert_new_photos db: db, photos: new_photos, fields: @conf[:fields][:photos], exif: photos_disk

      when "update" then
        update_photo_meta db: db, photos: curr_photos, fields: @conf[:fields][:photos], exif: photos_disk, old_data: photos_db

      when "rm" then
        if @conf[:all_photos] && ! @conf[:force] then
          puts "Deleting all photos requires --force."
          exit
        end
        remove_photo db: db, photos: curr_photos

      when "show" then
        show_photos db: db, photos: curr_photos, galleries: @conf[:galleries], data: photos_db

      when "to-g" then
        add_photos_to_galleries db: db, photos: curr_photos, galleries: @conf[:galleries], fields: @conf[:fields][:photo_galleries]

      when "from-g" then
        if @conf[:all_photos] && ! @conf[:force] then
          puts "Removing all photos from galleries requires --force."
          exit
        end
        remove_photos_from_galleries db: db, photos: curr_photos, galleries: @conf[:galleries], fields: @conf[:fields][:photo_galleries]
      end
    else
      # Gallery commands.
      case @conf[:cmd]

      when "g-add" then
        create_gallery db: db, fields: @conf[:fields][:galleries]

      when "g-update" then
        update_galleries db: db, galleries: @conf[:galleries], fields: @conf[:fields][:galleries]

      when "g-show" then
        show_galleries db: db, galleries: @conf[:galleries]

      when "g-ls" then
        list_gallery_photos db: db, galleries: @conf[:galleries]

      when "g-rm" then
        if ! @conf[:force] then
          puts "Deleting galleries requires --force."
          exit
        end
        delete_galleries db: db, galleries: @conf[:galleries]
      end
    end

  end # transaction

end # main

def parse_params(conf)
  conf[:opts] = OptionParser.new do |o|
    o.banner = "Usage: ./admin.rb [command] [options] [photo(s)]"
    o.separator ""
    o.separator "Commands:"
    o.separator "    add           Add new photos from full/ to the database."
    o.separator "                  Defaults to all new photos if no photo given."
    o.separator "                  Creates thumbnails if not already present."
    o.separator "    update        Update the properties of the given photos."
    o.separator "    rm            Remove the given photos from the database."
    o.separator "    show          Show the properties of the photos."
    o.separator "    g-add         Create a new gallery, prompting for properties."
    o.separator "    g-update      Update the properties of the given galleries."
    o.separator "    g-rm          Delete a gallery."
    o.separator "    g-show        List galleries' properties. Defaults to all galleries."
    o.separator "    g-ls          List the photos in the galleries, grouped by gallery."
    o.separator "                  Defaults to all galleries if none specified."
    o.separator "    to-g          Add the selected photos to the given galleries."
    o.separator "    from-g        Remove the selected photos from the given galleries."
    o.separator ""
    o.separator "Options:"
    o.on("-g", "--gallery [x,y,z]", "The gallery to use with add-gal and rm-gal commands.") do |v|
      (conf[:galleries] << v.split(',')).flatten!
    end
    o.on("--exifonly", "Only load and update the exif to the database, not prompting or touching user-specific fields.") do |v|
      conf[:exifonly] = true
    end
    o.on("--force", "Some operations need to be forced to try to avoid accidents, e.g. deleting all photos.") do |v|
      conf[:force] = true
    end
    o.on("--verbose", "Verbose output.") do |v|
      conf[:verbose] = true
    end
    o.on("--debug", "Even more Verbose output.") do |v|
      conf[:debug]   = true
      conf[:verbose] = true
    end
    o.on("--simulate", "Don't actually do any changes, just show what would be done.") do |v|
      conf[:simulate] = true
    end
    o.on("-h", "--help") do |v|
      conf[:help] = true
    end
    o.parse!
  end

  conf[:cmd] = ARGV.shift
  conf[:photos] = ARGV
  conf[:all_photos] = false
end

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
    schema_versions = schema_ddls.collect{ |f| f.scan(/\d+/).first.to_i }.find_all{ |v| v > schema_version }.sort

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
  photos = opts[:photos]
  db     = opts[:db]
  fields = opts[:fields]
  exif   = opts[:exif]

  return if photos.length == 0

  sql_ins_photos  = "INSERT INTO photos (" + fields[:db].join(',') + ") VALUES (" + fields[:db].collect{ |f| '?'}.join(',') + ")"
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

  photos.each do |photo|
    data = {
      name:  photo,
      taken: '',

      title:       '',
      description: '',
      country:     '',
      place:       '',
      location:    '',
      author:      '',

      camera:  '',
      focal:   '',
      fstop:   '',
      shutter: '',
      iso:     '',

      width:    0,
      height:   0,
      t_width:  0,
      t_height: 0,
      f_width:  0,
      f_height: 0,
    }
    parse_exif(data, exif[photo])

    puts "Processing #{photo}" if @conf[:debug]

    unless @conf[:exifonly]
      begin
        puts "#{photo}"
        fields[:user].each do |field|
          prev[field.to_sym] = data[field.to_sym] = prompt_field field: field, default: prev[field.to_sym]
        end

      rescue Exception => e
        puts e
        exit
      end
      puts
    end

    puts data if @conf[:debug]

    create_thumbs(photo: photo)
    
    Magick::ImageList.new("i/#{photo}").each do |img|
      data[:width], data[:height] = img.columns, img.rows
    end
    Magick::ImageList.new("thumbs/#{photo}").each do |img|
      data[:t_width], data[:t_height] = img.columns, img.rows
    end

    data_ins_photos = fields[:db].collect{ |f| data[f.to_sym] }

    puts "Inserting photo #{photo} into the database." if @conf[:verbose]
    stmt_ins_photos.execute(*data_ins_photos) unless @conf[:simulate]

    ObjectSpace.garbage_collect
  end
end # insert_new_photos

def update_photo_meta(opts)
  photos   = opts[:photos]
  db       = opts[:db]
  fields   = opts[:fields]
  exif     = opts[:exif]
  old_data = opts[:old_data]

  sql_upd_photos  = "UPDATE photos SET " + fields[:db].collect{ |field| field + '=?'  }.join(',') + " WHERE name=?"
  stmt_upd_photos = db.prepare(sql_upd_photos)

  photos.each do |photo|
    data = {
      name:  photo,
      taken: '',

      #      title:       old_data[photo]['title'],
      #      description: old_data[photo]['description'],
      #      country:     old_data[photo]['country'],
      #      place:       old_data[photo]['place'],
      #      location:    old_data[photo]['location'],
      #      author:      old_data[photo]['author'],

      title:       '',
      description: '',
      country:     '',
      place:       '',
      location:    '',
      author:      '',

      camera:  '',
      focal:   '',
      fstop:   '',
      shutter: '',
      iso:     '',

      width:    0,
      height:   0,
      t_width:  0,
      t_height: 0,
      f_width:  0,
      f_height: 0,
    }
    parse_exif(data, exif[photo])

    puts "Processing #{photo}" if @conf[:debug]

    unless @conf[:exifonly]
      begin
        fields[:user].each do |field|
          data[field.to_sym] = prompt_field field: field, default: old_data[photo][field]
        end

      rescue Exception => e
        puts e
        exit
      end
      puts
    end

    puts data if @conf[:debug]

    create_thumbs(photo: photo)
    
    Magick::ImageList.new("i/#{photo}").each do |img|
      data[:width], data[:height] = img.columns, img.rows
    end
    Magick::ImageList.new("thumbs/#{photo}").each do |img|
      data[:t_width], data[:t_height] = img.columns, img.rows
    end

    data_upd_photos = fields[:db].collect{ |field| data[field.to_sym].to_s }

    puts "Updating properties for photo #{photo} in the database." if @conf[:verbose]
    stmt_upd_photos.execute(*data_upd_photos, photo) unless @conf[:simulate]

    ObjectSpace.garbage_collect
  end
end # update_photo_meta

def remove_photo(opts)
  photos = opts[:photos]
  db    = opts[:db]

  puts "Processing #{photo}" if @conf[:debug]

  sql_del_photos  = "DELETE FROM photos WHERE name=?"
  stmt_del_photos = db.prepare(sql_del_photos)

  photos.each do |photo|
    puts "Deleting photo #{photo} from the database." if @conf[:verbose]
    stmt_del_photos.execute(photo) unless @conf[:simulate]
    puts "Photo #{photo} deleted."
  end
end

def show_photos(opts)
  db        = opts[:db]
  photos    = opts[:photos]
  galleries = opts[:galleries]
  data      = opts[:data]

  if galleries.length > 0 then
    gphotos = []

    sql_sel_gphotos = "SELECT DISTINCT photo_name FROM photo_galleries WHERE gallery_name IN (" + galleries.collect{ |g| '?' }.join(',') + ")"
    db.execute(sql_sel_gphotos, *galleries) do |row|
      gphotos << row['photo_name']
    end

    photos &= gphotos
  end

  photos.sort_by { |f| f.downcase }.each do |photo|
    puts "#{photo}"
    puts "  Title:       #{data[photo]['title']}"
    puts "  Description: #{data[photo]['description']}"
    puts "  Taken:       #{data[photo]['taken']}"
    puts "  Place:       #{data[photo]['place']}"
    puts "  Country:     #{data[photo]['country']}"
    puts "  Author:      #{data[photo]['author']}"
    puts "  Camera:      #{data[photo]['camera']}"
    puts "               F/#{data[photo]['fstop']}, #{data[photo]['shutter']}s, ISO #{data[photo]['iso']}, #{data[photo]['f_width']}x#{data[photo]['f_height']}"
    puts
  end

end

def create_gallery(opts)
  db     = opts[:db]
  fields = opts[:fields]

  sql_ins_gallery  = "INSERT INTO galleries (" + fields.join(',') + ") VALUES (" + fields.collect{ |f| '?' }.join(',')  + ")"
  stmt_ins_gallery = db.prepare(sql_ins_gallery)

  data = {}
  puts "Creating a new gallery:"
  fields.each do |field|
    data[field.to_sym] = prompt_field field: field
  end

  puts "Creating a new gallery #{data[:name]} into the database." if @verbose
  values = fields.collect{ |f| data[f.to_sym] }
  stmt_ins_gallery.execute(*values) unless @conf[:simulate]

  puts "Gallery #{data[:name]} created."
end

def update_galleries(opts)
  db        = opts[:db]
  galleries = opts[:galleries]
  fields = opts[:fields]

  # Load previous values to use as default on the prompt.
  gallery_data = {}
  sql_sel_galleries = "SELECT " + fields.join(',') + " FROM galleries WHERE name IN (" + galleries.collect{ |g| '?' }.join(',') + ")"
  db.execute(sql_sel_galleries, *galleries) do |row|
    name = row['name']
    gallery_data[name] = {}
    fields.each do |field|
      gallery_data[name][field.to_sym] = row[field]
    end
  end

  sql_upd_gallery  = "UPDATE galleries SET " + fields.collect{ |f| "#{f}=?" }.join(',') + " WHERE name=?"
  stmt_upd_gallery = db.prepare(sql_upd_gallery)

  galleries.each do |gallery|
    data = {}
    puts "Updating gallery #{gallery}:"
    fields.each do |field|
      data[field.to_sym] = prompt_field field: field, default: gallery_data[gallery][field.to_sym]
    end

    puts "Updating gallery #{gallery} in the database." if @verbose
    values = fields.collect{ |f| data[f.to_sym] }
    stmt_upd_gallery.execute(*values, gallery) unless @conf[:simulate]

    if gallery == data[:name] then
      puts "Gallery #{data[:name]} updated."
    else
      puts "Gallery #{gallery} => #{data[:name]} updated."
    end
  end

end

def show_galleries(opts)
  db        = opts[:db]
  galleries = opts[:galleries]

  sql_sel_galleries = "SELECT name, title, description, epoch FROM galleries"
  if galleries.length > 0 then
    sql_sel_galleries += " WHERE name IN (" + galleries.collect{ |g| '?' }.join(',') + ")"
  end
  sql_sel_galleries += " ORDER BY LOWER(name)"
  db.execute(sql_sel_galleries, *galleries) do |row|
    puts "#{row['name']}"
    puts "  Title:       #{row['title']}"
    puts "  Description: #{row['description']}"
    puts "  Epoch:       #{row['epoch']}"
    puts
  end
end

def list_gallery_photos(opts)
  db        = opts[:db]
  galleries = opts[:galleries]

  if galleries.length == 0 then
    sql_sel_galleries = "SELECT name FROM galleries"
    db.execute(sql_sel_galleries) do |row|
      galleries << row['name']
    end
  end

  sql_sel_gphotos  = "SELECT photo_name FROM photo_galleries WHERE gallery_name=? ORDER BY photo_name"
  galleries.sort_by { |gallery| gallery.downcase }.each do |gallery|
    puts "#{gallery}"
    db.execute(sql_sel_gphotos, gallery) do |row|
      puts "  #{row['photo_name']}"
    end
  end
end

def delete_galleries(opts)
  db        = opts[:db]
  galleries = opts[:galleries]

  sql_del_gphotos  = "DELETE FROM photo_galleries WHERE gallery_name=?"
  stmt_del_gphotos = db.prepare(sql_del_gphotos)

  sql_del_gallery  = "DELETE FROM galleries WHERE name=?"
  stmt_del_gallery = db.prepare(sql_del_gallery)

  galleries.each do |gallery|
    stmt_del_gphotos.execute(gallery) unless @conf[:simulate]
    stmt_del_gallery.execute(gallery) unless @conf[:simulate]

    puts "Gallery #{gallery} deleted."
  end
end

def add_photos_to_galleries(opts)
  db        = opts[:db]
  photos    = opts[:photos]
  galleries = opts[:galleries]
  fields    = opts[:fields]

  sql_sel_gphotos  = "SELECT " + fields.join(',') + " FROM photo_galleries WHERE " + fields.collect{ |f| "#{f}=?" }.join(' AND ')
  stmt_sel_gphotos = db.prepare(sql_sel_gphotos)

  sql_ins_gphotos = "INSERT INTO photo_galleries (" + fields.join(',') + ") VALUES (" + fields.collect{ |f| '?' }.join(',') + ")"
  stmt_ins_gphotos = db.prepare(sql_ins_gphotos)

  galleries.each do |gallery|
    photos.each do |photo|
      data = {
        photo_name:   photo,
        gallery_name: gallery,
      }
      values = fields.collect{ |f| data[f.to_sym] }

      already_added = false
      stmt_sel_gphotos.execute(*values).each do |row|
        already_added = true
        break
      end

      if already_added then
        puts "Photo #{photo} already exists in gallery #{gallery}."
      else
        stmt_ins_gphotos.execute(*values) unless @conf[:simulate]
        puts "Photo #{photo} added to gallery #{gallery}."
      end
    end
  end
end

def remove_photos_from_galleries(opts)
  db        = opts[:db]
  photos    = opts[:photos]
  galleries = opts[:galleries]
  fields    = opts[:fields]

  sql_del_gphotos  = "DELETE FROM photo_galleries WHERE " + fields.collect{ |f| "#{f}=?" }.join(' AND ')
  stmt_del_gphotos = db.prepare(sql_del_gphotos)

  galleries.each do |gallery|
    photos.each do |photo|
      data = {
        photo_name:   photo,
        gallery_name: gallery,
      }
      values = fields.collect{ |f| data[f.to_sym] }

      stmt_del_gphotos.execute(*values) unless @conf[:simulate]
      puts "Photo #{photo} removed from gallery #{gallery}."
    end
  end
end

def create_thumbs(opts)
  photo = opts[:photo]

  need_thumbs = false
  @conf[:thumbnails].each do |k,v|
    unless File.exist? "#{k.to_s}/#{photo}" then
      need_thumbs = true
      break
    end
  end

  if need_thumbs then
    img_full = Magick::Image::read("full/#{photo}").first

    @conf[:thumbnails].each do |k,v|
      unless File.exist? "#{k.to_s}/#{photo}" then
        puts "Creating thumbnail #{v[:width]}x#{v[:height]} for photo #{photo}" if @conf[:verbose]

        filename  = "#{k.to_s}/#{photo}"
        img_thumb = img_full.resize_to_fit(v[:width], v[:height])
        img_thumb.write(filename) unless @conf[:simulate]
        File.chmod(0644, filename)
      end
    end
  end
end

def prompt_field(opts)
  field   = opts[:field]
  default = opts[:default] || ''

  print "  Enter #{field} [default: \"#{default}\""
  if default != '' then
    print "; \"-\" for empty]: "
  else
    print "]: "
  end
  val = $stdin.gets.chomp

  case val
  when '-' then ''
  when ''  then default
  else val.chomp
  end
end # prompt_field

def camera_name_from_exif(exif)
  if exif[:model].start_with?(exif[:make]) then
    exif[:model]
  else
    [ exif[:make], exif[:model] ].join(' ')
  end
end

def parse_exif(data, exif)
  {
    taken: exif[:date_time_original].to_s,
    
    camera:  camera_name_from_exif(exif),
    focal:   exif[:focal_length].round,
    fstop:   exif[:aperture_value],
    shutter: exif[:exposure_time].to_s,
    iso:     exif[:iso_speed_ratings],

    f_width:  exif[:width],
    f_height: exif[:height],
  }.each do |key, value|
    data[key] = value
  end
end

main

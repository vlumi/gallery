#!/usr/bin/ruby
# encoding: utf-8

require 'sqlite3'

module Gallery
	COUNTRY_MAP = {
		'at' => 'Austria',
		'be' => 'Belgium',
		'ch' => 'Switzerland',
		'de' => 'Germany',
		'dk' => 'Denmark',
		'ee' => 'Estonia',
		'fi' => 'Finland',
		'fr' => 'France',
		'jp' => 'Japan',
		'li' => 'Liechtenstein',
		'lu' => 'Luxembourg',
		'nl' => 'Netherlands',
		'se' => 'Sweden',
		'unknown' => '-',
	} unless defined? COUNTRY_MAP

	class Photo
		attr_reader :id, :file, :title, :taken, :timestamp, :author, :country, :width, :height, :t_width, :t_height
		
		def initialize(params)
			@id      = params[':id']
			@file    = params[':file']
			@title   = params[':title']
			@taken   = params[':taken']
			@author  = params[':author']
			@country = params[':country']
			
			@width    = params[':width'].to_i
			@height   = params[':height'].to_i
			@t_width  = params[':t_width'].to_i
			@t_height = params[':t_height'].to_i
			
			# All photo timestamps are expected to be in local time.
			# For statistics purposes, treat them all like they were in the same timezone.
  			ts = /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/.match(params[':taken']).to_a.collect { |i| i.to_i  }
  			@timestamp = Time.utc(ts[1], ts[2], ts[3], ts[4], ts[5], ts[6])
		end # def initialize()
		
		def to_s()
			@file
		end
	end # class Photo

	class Gallery
		attr_reader :total_count,
        :year_counts, :max_year_count, :year_avgs, :max_year_avg,
        :month_counts, :max_month_count, :month_avgs, :max_month_avg,
        :moy_counts, :max_moy_count, # Month of year
        :dow_counts, :max_dow_count, # Day of week
        :hod_counts, :max_hod_count, # Hour of day
        :country_counts, :max_country_count,
        :camera_counts, :max_camera_count,
        :author_counts, :max_author_count
		
		def initialize(dbfile, filters = nil)
			@photos = {}
			
			@year_counts   = {}
			@year_avgs     = {}
			@month_counts  = {}
			@month_avgs    = {}
			
			@moy_counts = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
			@dow_counts = [0, 0, 0, 0, 0, 0, 0]
			@hod_counts = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
			
			@country_counts = {}
			@camera_counts  = {}
			@author_counts  = {}
			
			sql_filters = []
			sql_filter_vals = []
			gallery = nil
			if filters != nil and filters.is_a?(Hash) then
                if filters['gallery'] != nil then
                    gallery = filters['gallery']
                    sql_filters.push('photo_galleries.gallery_name=?')
                    sql_filter_vals.push(filters['gallery'])
                end
			    ['country', 'camera', 'author'].each do |type|
					if filters[type] != nil then
			            sql_filters.push(type + '=?')
			            sql_filter_vals.push(filters[type])
					end
			    end
			end
            if gallery != nil then
                sql = 'SELECT * FROM photos JOIN photo_galleries ON photo_galleries.photo_name=photos.name'
            else
                sql = 'SELECT * FROM photos'
            end
            if sql_filters.length > 0 then
                sql = sql + ' WHERE ' + sql_filters.join(' AND ')
            end
            sql = sql + ' ORDER BY name'
			
			database = SQLite3::Database.new(dbfile);
			id = 0
			database.transaction do |db|
  				db.results_as_hash = true
  				db.execute(sql, sql_filter_vals) do |row|
  					id += 1
  					_parse_row(row, id)
  				end
			end
			
			@total_count = id
            return if @total_count == 0
			
			# Get extremes, to calculate proper day counts.
			min_year  = @photos.keys.min
			min_month = @photos[min_year].keys.min
			min_day   = @photos[min_year][min_month].keys.min
			
			max_year  = @photos.keys.max
			max_month = @photos[max_year].keys.max
			max_day   = @photos[max_year][max_month].keys.max
			
			# Calculate averages, using the proper day count for extremes.
  			@year_counts.keys.each do |y|
				if y == max_year
					end_date = Date.new(y, max_month, max_day)
				else
					end_date = Date.new(y, 12, 31)
				end
				if y == min_year then
					start_date = Date.new(y, min_month, min_day)
					days = end_date.yday - start_date.yday + 1
				else
					days = end_date.yday
				end
				@year_avgs[y] = @year_counts[y].to_f / days
				
				@month_avgs[y] = {}
				@month_counts[y].keys.each do |m|
					if y == max_year && m == max_month then
						end_day = max_day
					else
						end_day = _days_in_month(y.to_i, m.to_i)
					end
					if y == min_year && m == min_month then
						days = end_day - min_day + 1
					else
						days = end_day
					end
					@month_avgs[y][m] = @month_counts[y][m].to_f / days
				end
  			end
  			
  			@max_year_count  = @year_counts.values.max
  			@max_year_avg    = @year_avgs.values.max
  			@max_month_count = @month_counts.values.collect{ |y| y.values.max }.max
  			@max_month_avg   = @month_avgs.values.collect{ |y| y.values.max }.max
  			
  			@max_moy_count = @moy_counts.max
  			@max_dow_count = @dow_counts.max
  			@max_hod_count = @hod_counts.max
  			
  			@max_country_count = @country_counts.values.max
  			@max_camera_count  = @camera_counts.values.max
  			@max_author_count  = @author_counts.values.max
		end # def initialize()
		
		def _parse_row(row, id)
  			photo = Photo.new({
                                  ':id'      => id,
                                  ':file'    => row['name'],
                                  ':title'   => row['title'],
                                  ':taken'   => row['taken'],
                                  ':author'  => row['author'],
                                  ':country' => row['country'],
                                  
                                  ':width'    => row['width'].to_i,
                                  ':height'   => row['height'].to_i,
                                  ':t_width'  => row['t_width'].to_i,
                                  ':t_height' => row['t_height'].to_i,
                              })
			ts = photo.timestamp
			y, m, d, h, dow = ts.year, ts.month, ts.day, ts.hour, ts.wday
			
  			if not @photos[y].is_a?(Hash) then
				@photos[y] = { m => { d => [ photo ] } }
  			elsif not @photos[y][m].is_a?(Hash) then
				@photos[y][m] = { d => [ photo ] }
  			elsif not @photos[y][m][d].is_a?(Array) then
				@photos[y][m][d] = [ photo ]
  			elsif @photos[y][m][d].index(photo) == nil then
				@photos[y][m][d].push(photo)
  			end
  			
  			if not @year_counts.has_key?(y) then
  				@year_counts[y] = 1
  			else
  				@year_counts[y] += 1
  			end
  			if not @month_counts.has_key?(y) then
  				@month_counts[y] = { m => 1 }
  			elsif not @month_counts[y].has_key?(m) then
  				@month_counts[y][m] = 1
  			else
  				@month_counts[y][m] += 1
  			end
  			
  			@moy_counts[m - 1]   += 1
  			@dow_counts[dow] += 1
  			@hod_counts[h]   += 1
  			
  			if not @country_counts.has_key?(row['country']) then
  				@country_counts[ row['country'] ] = 1
  			else
  				@country_counts[ row['country'] ] += 1
  			end
  			if not @camera_counts.has_key?(row['camera']) then
  				@camera_counts[ row['camera'] ] = 1
  			else
  				@camera_counts[ row['camera'] ] += 1
  			end
  			if not @author_counts.has_key?(row['author']) then
  				@author_counts[ row['author'] ] = 1
  			else
  				@author_counts[ row['author'] ] += 1
  			end
		end
		
		def _days_in_month(year, month)
			(Date.new(year, 12, 31) << (12-month)).day
		end
		
		private :_parse_row, :_days_in_month
		
		
		def getYears()
			@photos.keys.sort
		end # def getYears()
		
		def getMonths(year)
			if @photos[year].is_a?(Hash) then
				@photos[year].keys.sort
			else
				[]
			end
		end # def getMonths()
		
		def getDays(year, month)
			if @photos[year].is_a?(Hash) and @photos[year][month].is_a?(Hash) then
				@photos[year][month].keys.sort
			else
				[]
			end
		end # def getDays()
		
		def getPhotos(year, month, day)
			if @photos[year].is_a?(Hash) and @photos[year][month].is_a?(Hash) and @photos[year][month][day].is_a?(Array) then
				@photos[year][month][day]
			else
				[]
			end
		end # def getPhotos()
		
		def getCountries()
			countries = {}
			@country_counts.keys.each do |c|
				countries[c] = COUNTRY_MAP[c]
			end
			countries
		end # def getCountries()
		
		def getCameras()
			@camera_counts.keys.sort
		end # def getCameras()
		
		def getAuthors()
			@author_counts.keys.sort
		end # def getAuthors()
		
	end # class Gallery
end # module Gallery

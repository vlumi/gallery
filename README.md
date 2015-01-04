gallery
=======

A calendar-based gallery website, aimed for capturing a child's life and progress.

The basic view is a set of photos on a calendar month, in chronological order and with date changes clearly indicated. Previous months can be browsed, and all the photos inside a gallery can be viewed enlargened on a Colorbox layer, the month view changing behind the scenes as necessary.

The project started as a plain directory of photos with an Apache-generated index page, and has evolved organically to be more user-friendly, and to better support the ever-increasing number of photos and the longer timeframe.

The front-end is based on eruby, running e.g. on Apache httpd. The photos are stored on disk, in a flat directory, with separate directories for original JPEGs (including EXIF), thumbnails, and larger versions. The photo properties are stored in a SQLite database.

For the gallery management, there is a command-line script (bin/admin.rb), which will also create the thumbnails if necessary. The basic workflow for adding photos is as follows:

* Copy the new photos in the `full/` sub-directory
* Run `bin/admin.rb add`, entering the properties (title, etc.) for each photo when prompted

A single instance can support multiple separate galleries, hosted on different virtual hosts. The same photo may be included in multiple galleries, without limitations. The mapping of virtual host to library is done by extending the base back-end class, with the `rb/gallery_config.rb`.


Requirements
------------

* Ruby 2.1.0 (for command-line tools), 1.9.3 (for .rhtml)
* Apache httpd with eruby (Embedded Ruby Language), configured to process .rhtml files, running on Linux
* SQLite 3
* exifr and RMagick gems installed for commend-line tools

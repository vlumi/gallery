#!/bin/sh

if [ ! -d "backup" ]; then
  mkdir backup
fi

backup_name="gallery.sqlite3.$(date +\%Y\%m\%d)"

cp -f gallery.sqlite3 backup/$backup_name
gzip -f backup/$backup_name
#!/bin/sh

for i in full/*.jpg ; do
    fname=$(echo $i |sed s/^full.//)
#    echo "Processing $fname ..."
    if [ ! -e thumbs/$fname ] ; then
        echo "Creating $fname"
        convert full/$fname -thumbnail 1500x1500 $fname
        chmod 644 $fname
        convert full/$fname -thumbnail 600x200 thumbs/$fname
        chmod 644 thumbs/$fname
        ./populate_db.rb $fname
    fi
done

find . -name '*.jpg' -exec chmod 644 '{}' \;

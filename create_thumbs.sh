#!/bin/sh

for i in full/*.jpg ; do
    fname=$(echo $i |sed s/^full.//)
    if [ ! -e thumbs/$fname ] ; then
        echo "Creating $fname"
        convert full/$fname -thumbnail 1500x1500 i/$fname
        chmod 644 $fname
        convert full/$fname -thumbnail 600x200 thumbs/$fname
        chmod 644 thumbs/$fname
    fi
done

./admin.rb

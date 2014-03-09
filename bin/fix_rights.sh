#!/bin/sh

chmod 700 backup/ bin/ bin/*.sh bin/*.rb full/ .git/
chmod 600 .gitignore *.ddl TODO.txt

chmod 755 . css/ i/ images/ js/ rb/ thumbs/
chmod 644 */index.html css/* *.sqlite3 i/* images/* *.rhtml js/* rb/* thumbs/*

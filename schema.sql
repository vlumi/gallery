CREATE TABLE galleries (
  name        TEXT PRIMARY KEY,
  title       TEXT,
  description TEXT,
  epoch       TEXT
);

CREATE TABLE photos (
  name       TEXT PRIMARY KEY,
  title      TEXT,
  desciption TEXT,
  taken      TEXT,
  country    TEXT,
  place      TEXT,
  author     TEXT,
  camera     TEXT,
  fstop      TEXT,
  shutter    TEXT,
  iso        INTEGER,
  width      INTEGER,
  height     INTEGER,
  t_width    INTEGER,
  t_height   INTEGER
);

CREATE TABLE photo_galleries (
  photo_name   TEXT,
  gallery_name TEXT,
  FOREIGN KEY(photo_name) REFERENCES photos(name),
  FOREIGN KEY(gallery_name) REFERENCES galleries(name)
);

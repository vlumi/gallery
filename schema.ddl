CREATE TABLE schema_info (
  version INTEGER
);
INSERT INTO schema_info (version) VALUES (1);

CREATE TABLE galleries (
  name        TEXT PRIMARY KEY,
  title       TEXT,
  description TEXT,
  epoch       TEXT
);

CREATE TABLE photos (
  name        TEXT PRIMARY KEY,
  title       TEXT,
  description TEXT,
  taken       TEXT,
  country     TEXT,
  place       TEXT,
  author      TEXT,
  camera      TEXT,
  focal       INTEGER,
  fstop       TEXT,
  shutter     TEXT,
  iso         INTEGER,
  width       INTEGER,
  height      INTEGER,
  t_width     INTEGER,
  t_height    INTEGER
  f_width     INTEGER,
  f_height    INTEGER
);

CREATE TABLE photo_galleries (
  photo_name   TEXT,
  gallery_name TEXT,
  FOREIGN KEY(photo_name) REFERENCES photos(name),
  FOREIGN KEY(gallery_name) REFERENCES galleries(name)
);

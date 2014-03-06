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

ALTER TABLE photos ADD COLUMN description TEXT;
ALTER TABLE photos ADD COLUMN place       TEXT;
ALTER TABLE photos ADD COLUMN focal       INTEGER;
ALTER TABLE photos ADD COLUMN fstop       TEXT;
ALTER TABLE photos ADD COLUMN shutter     TEXT;
ALTER TABLE photos ADD COLUMN iso         INTEGER;
ALTER TABLE photos ADD COLUMN f_width     INTEGER;
ALTER TABLE photos ADD COLUMN f_height    INTEGER;

CREATE TABLE photo_galleries (
  photo_name   TEXT,
  gallery_name TEXT,
  FOREIGN KEY(photo_name) REFERENCES photos(name),
  FOREIGN KEY(gallery_name) REFERENCES galleries(name)
);

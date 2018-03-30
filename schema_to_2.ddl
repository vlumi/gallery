ALTER TABLE galleries RENAME TO gallery;
ALTER TABLE photos RENAME TO photo;

CREATE TABLE photo_gallery (
  photo_name   TEXT,
  gallery_name TEXT,
  PRIMARY KEY(photo_name, gallery_name),
  FOREIGN KEY(photo_name) REFERENCES photos(name),
  FOREIGN KEY(gallery_name) REFERENCES galleries(name)
);
INSERT INTO photo_gallery SELECT * FROM photo_galleries;
DROP TABLE photo_galleries;


DROP TABLE schema_info;
CREATE TABLE schema_info (
  version INTEGER PRIMARY KEY
);
INSERT INTO schema_info (version) VALUES (2);

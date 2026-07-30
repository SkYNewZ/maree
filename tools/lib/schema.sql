-- maree.db — read-only application database, produced by tools/prepare-db.mjs.
-- Primary keys are DORIS public numbers (fiche.numeroFiche, groupe._id,
-- zoneGeographique._id), never the internal fiche._id.

CREATE TABLE species (
  id               INTEGER PRIMARY KEY,   -- fiche.numeroFiche
  commonName       TEXT NOT NULL,
  scientificName   TEXT NOT NULL,
  groupId          INTEGER NOT NULL REFERENCES taxonGroup(id),
  regulated        INTEGER NOT NULL,      -- 0 | 1
  dangerous        INTEGER NOT NULL,      -- 0 | 1
  photoCount       INTEGER NOT NULL,
  depthMin         INTEGER,
  depthMax         INTEGER,
  tempMin          INTEGER,
  tempMax          INTEGER,
  updatedAt        TEXT,
  sourceUrl        TEXT NOT NULL
);

CREATE TABLE section (
  speciesId  INTEGER NOT NULL REFERENCES species(id),
  kind       TEXT NOT NULL,               -- key from tools/lib/sections.mjs
  text       TEXT NOT NULL,
  PRIMARY KEY (speciesId, kind)
);

CREATE TABLE photo (
  speciesId  INTEGER NOT NULL REFERENCES species(id),
  position   INTEGER NOT NULL,            -- 0-based, matches the bucket path
  caption    TEXT,
  PRIMARY KEY (speciesId, position)
);

CREATE TABLE vernacularName (
  speciesId  INTEGER NOT NULL REFERENCES species(id),
  name       TEXT NOT NULL,
  isFrench   INTEGER NOT NULL,            -- 0 | 1
  PRIMARY KEY (speciesId, name)
);

CREATE TABLE taxonGroup (
  id              INTEGER PRIMARY KEY,    -- groupe._id
  parentId        INTEGER REFERENCES taxonGroup(id),
  name            TEXT NOT NULL,
  scientificHint  TEXT,
  speciesCount    INTEGER NOT NULL        -- recursive count within the EU subset
);

CREATE TABLE zone (
  id        INTEGER PRIMARY KEY,          -- zoneGeographique._id
  parentId  INTEGER REFERENCES zone(id),
  name      TEXT NOT NULL
);

CREATE TABLE speciesZone (
  speciesId  INTEGER NOT NULL REFERENCES species(id),
  zoneId     INTEGER NOT NULL REFERENCES zone(id),
  PRIMARY KEY (speciesId, zoneId)
);

CREATE TABLE taxonRank (
  speciesId  INTEGER NOT NULL REFERENCES species(id),
  position   INTEGER NOT NULL,            -- classificationFiche.numOrdre
  rank       TEXT NOT NULL,               -- 'Genre', 'Espece', 'Famille'…
  name       TEXT NOT NULL,
  PRIMARY KEY (speciesId, position)
);

CREATE TABLE meta (
  key    TEXT PRIMARY KEY,
  value  TEXT NOT NULL                    -- dorisDate, generatedAt, speciesCount
);

CREATE INDEX species_groupId ON species(groupId);
CREATE INDEX species_commonName ON species(commonName);
CREATE INDEX speciesZone_zoneId ON speciesZone(zoneId);
CREATE INDEX taxonGroup_parentId ON taxonGroup(parentId);

-- Standalone (not external-content) FTS5: vernacularNames is aggregated from
-- another table, so it has no matching column to synchronise with.
CREATE VIRTUAL TABLE speciesSearch USING fts5(
  speciesId UNINDEXED,
  commonName,
  scientificName,
  vernacularNames,
  tokenize="unicode61 remove_diacritics 2"
);

import { DatabaseSync } from 'node:sqlite'

const EXPECTED_SPECIES = 2837

export function verifyDatabase(path) {
  const db = new DatabaseSync(path, { readOnly: true })
  const problems = []
  const count = (sql) => db.prepare(sql).get().c

  const stats = {
    species: count('SELECT COUNT(*) AS c FROM species'),
    sections: count('SELECT COUNT(*) AS c FROM section'),
    photos: count('SELECT COUNT(*) AS c FROM photo'),
    groups: count('SELECT COUNT(*) AS c FROM taxonGroup'),
    zones: count('SELECT COUNT(*) AS c FROM zone'),
    searchRows: count('SELECT COUNT(*) AS c FROM speciesSearch'),
    vernacular: count('SELECT COUNT(*) AS c FROM vernacularName'),
    ranks: count('SELECT COUNT(*) AS c FROM taxonRank'),
  }

  if (stats.species !== EXPECTED_SPECIES) {
    problems.push(`species: ${stats.species} rows, expected ${EXPECTED_SPECIES}`)
  }
  if (stats.searchRows !== stats.species) {
    problems.push(`speciesSearch: ${stats.searchRows} rows, expected ${stats.species}`)
  }
  for (const table of ['sections', 'photos', 'groups', 'zones', 'vernacular', 'ranks']) {
    if (stats[table] === 0) problems.push(`${table}: empty`)
  }

  // No residual DORIS markup or HTML tags anywhere in user-visible text.
  const dirty = db.prepare(`
    SELECT COUNT(*) AS c FROM (
      SELECT text AS t FROM section
      UNION ALL SELECT commonName FROM species
      UNION ALL SELECT scientificName FROM species
      UNION ALL SELECT name FROM vernacularName
      UNION ALL SELECT COALESCE(caption, '') FROM photo
      UNION ALL SELECT name FROM taxonRank
      UNION ALL SELECT name FROM taxonGroup
    ) WHERE t LIKE '%{{%' OR t LIKE '%&nbsp;%' OR t GLOB '*<[a-zA-Z/]*>*'
  `).get().c
  if (dirty > 0) problems.push(`${dirty} text values still contain markup or HTML`)

  // Referential integrity — SQLite does not enforce the declared foreign keys.
  const orphans = {
    'section.speciesId': count('SELECT COUNT(*) AS c FROM section WHERE speciesId NOT IN (SELECT id FROM species)'),
    'photo.speciesId': count('SELECT COUNT(*) AS c FROM photo WHERE speciesId NOT IN (SELECT id FROM species)'),
    'species.groupId': count('SELECT COUNT(*) AS c FROM species WHERE groupId NOT IN (SELECT id FROM taxonGroup)'),
    'speciesZone.zoneId': count('SELECT COUNT(*) AS c FROM speciesZone WHERE zoneId NOT IN (SELECT id FROM zone)'),
    // Self-references: the pruning steps of prepare-db.mjs can cut a parent loose.
    'taxonGroup.parentId': count('SELECT COUNT(*) AS c FROM taxonGroup WHERE parentId IS NOT NULL AND parentId NOT IN (SELECT id FROM taxonGroup)'),
    'zone.parentId': count('SELECT COUNT(*) AS c FROM zone WHERE parentId IS NOT NULL AND parentId NOT IN (SELECT id FROM zone)'),
  }
  for (const [label, n] of Object.entries(orphans)) {
    if (n > 0) problems.push(`${label}: ${n} orphan rows`)
  }

  // Photo positions must be a contiguous 0-based range so bucket paths resolve.
  const badPhotos = count(`
    SELECT COUNT(*) AS c FROM (
      SELECT s.id FROM species s
      JOIN photo p ON p.speciesId = s.id
      GROUP BY s.id
      HAVING COUNT(*) != s.photoCount
          OR MIN(p.position) != 0
          OR MAX(p.position) != s.photoCount - 1
    )
  `)
  if (badPhotos > 0) problems.push(`${badPhotos} species have non-contiguous photo positions`)

  // Search must be diacritics-insensitive and prefix-capable.
  const hit = db.prepare(`
    SELECT COUNT(*) AS c FROM speciesSearch WHERE speciesSearch MATCH 'elephant*'
  `).get().c
  if (hit === 0) problems.push("search: 'elephant*' matched nothing (diacritics folding broken)")

  if (!db.prepare(`SELECT value FROM meta WHERE key = 'dorisDate'`).get()) {
    problems.push('meta: dorisDate missing')
  }

  db.close()
  return { ok: problems.length === 0, problems, stats }
}

if (import.meta.filename === process.argv[1]) {
  const path = process.argv[2] ?? 'Maree/Resources/maree.db'
  const { ok, problems, stats } = verifyDatabase(path)
  console.log(stats)
  if (!ok) {
    console.error('VERIFICATION FAILED:')
    for (const p of problems) console.error(`  - ${p}`)
    process.exit(1)
  }
  console.log('OK')
}

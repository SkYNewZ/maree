#!/usr/bin/env node
// Transforms the DORIS Android database into maree.db: European subset,
// cleaned text, typed sections, precomputed FTS5 index.
//
// Usage: node tools/prepare-db.mjs [--source=<path>] [--out=<path>] [--zones=1,2,3,5]

import { DatabaseSync } from 'node:sqlite'
import { readFileSync, mkdirSync, rmSync, renameSync, existsSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { verifyDatabase } from './verify-db.mjs'
import { clean, parseRange } from './lib/text.mjs'
import { SECTION_KEYS } from './lib/sections.mjs'
import { PHOTO_HAS_IMAGE } from './lib/photos.mjs'

const args = new Map(
  process.argv.slice(2)
    .filter((a) => a.startsWith('--'))
    .map((a) => { const [k, ...v] = a.slice(2).split('='); return [k, v.join('=')] })
)

const SOURCE = resolve(args.get('source') ?? `${process.env.HOME}/src/skynewz/doris-pwa/DorisAndroid.db`)
const OUT = resolve(args.get('out') ?? 'Maree/Resources/maree.db')
const ZONES = (args.get('zones') ?? '1,2,3,5').split(',').map(Number)

if (!existsSync(SOURCE)) {
  console.error(`Source database not found: ${SOURCE}`)
  console.error('Pass --source=<path> to DorisAndroid.db.')
  process.exit(1)
}

const STATUS_BY_ETAT = { 4: 'published', 5: 'proposed' }
const PICTO_REGULATED = '0'
const PICTO_DANGEROUS = '1'

function slug(text) {
  return text.normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-zA-Z0-9]+/g, '-').replace(/^-|-$/g, '').toLowerCase()
}

// Empty segments are dropped: 4 species (all diatoms) carry no common name, and
// joining blind gave them a double dash — ".../melosira-moniliformis--6053".
function sourceUrl(scientificName, commonName, id) {
  const sci = slug(scientificName.split(/\s+/).slice(0, 2).join(' '))
  return `https://doris.ffessm.fr/Especes/${[sci, slug(commonName), id].filter(Boolean).join('-')}`
}

console.log(`source: ${SOURCE}`)
console.log(`zones:  ${ZONES.join(', ')}`)

// Built beside the target and moved in only once verified. Written in place, a
// throw mid-transaction would leave a truncated maree.db exactly where xcodebuild
// embeds it, and nothing at runtime would notice.
const TMP = `${OUT}.tmp`
rmSync(TMP, { force: true })
mkdirSync(dirname(OUT), { recursive: true })

// node:sqlite enables foreign keys by default; the app opens maree.db without
// them, and sections/photos are inserted before their species row. verify-db.mjs
// checks referential integrity explicitly instead.
const db = new DatabaseSync(TMP, { enableForeignKeyConstraints: false })
db.exec(readFileSync(new URL('./lib/schema.sql', import.meta.url), 'utf8'))
db.exec(`ATTACH '${SOURCE.replace(/'/g, "''")}' AS src`)
db.exec('BEGIN')

// ── Selected fiches: internal _id → public numeroFiche ────────────────────────
const fiches = db.prepare(`
  SELECT f._id, f.numeroFiche, f.nomScientifique, f.nomCommun, f.etatFiche,
         f.pictogrammes, f.groupe_id, f.dateModification
  FROM src.fiche f
  WHERE f._id IN (
    SELECT Fiche_id FROM src.fiches_ZonesGeographiques
    WHERE ZoneGeographique_id IN (${ZONES.join(',')})
  )
  ORDER BY f.numeroFiche
`).all()

console.log(`selected ${fiches.length} fiches`)

// ── Zones and groups (kept whole: small, and needed for tree navigation) ──────
const insertZone = db.prepare('INSERT INTO zone (id, parentId, name) VALUES (?, ?, ?)')
for (const z of db.prepare('SELECT _id, parentZoneGeographique_id, nom FROM src.zoneGeographique').all()) {
  insertZone.run(z._id, z.parentZoneGeographique_id ?? null, clean(z.nom))
}

// groupe._id 1 is the synthetic "racine" node; it is dropped and its children
// become the roots (parentId NULL).
const groups = db.prepare(`
  SELECT _id, groupePere_id, nomGroupe, descriptionGroupe FROM src.groupe WHERE _id != 1
`).all()

// The scientific hint is the first parenthetical fragment of the group
// description, e.g. "Algues rouges (Rhodophycées)" → "Rhodophycées".
function scientificHint(description) {
  const match = clean(description).match(/\(([^)]+)\)/)
  return match ? match[1].trim() : null
}

const insertGroup = db.prepare(
  'INSERT INTO taxonGroup (id, parentId, name, scientificHint, speciesCount) VALUES (?, ?, ?, ?, 0)'
)
for (const g of groups) {
  const parentId = g.groupePere_id === 1 ? null : g.groupePere_id
  insertGroup.run(g._id, parentId, clean(g.nomGroupe), scientificHint(g.descriptionGroupe))
}

// ── Per-fiche content ────────────────────────────────────────────────────────
const sectionsOf = db.prepare('SELECT titre, texte FROM src.sectionFiche WHERE fiche_id = ? ORDER BY numOrdre')
const photosOf = db.prepare(
  `SELECT titre, description FROM src.photoFiche WHERE fiche_id = ? AND ${PHOTO_HAS_IMAGE} ORDER BY _id`
)
const namesOf = db.prepare('SELECT denomination, langue FROM src.autreDenomination WHERE fiche_id = ?')
const ranksOf = db.prepare(`
  SELECT c.niveau, c.termeScientifique, c.termeFrancais, cf.numOrdre
  FROM src.classificationFiche cf
  JOIN src.classification c ON c._id = cf.classification_id
  WHERE cf.fiche_id = ? ORDER BY cf.numOrdre
`)
const zonesOf = db.prepare('SELECT ZoneGeographique_id FROM src.fiches_ZonesGeographiques WHERE Fiche_id = ?')

const insertSpecies = db.prepare(`
  INSERT INTO species (id, commonName, scientificName, groupId, status, regulated, dangerous,
                       photoCount, depthMin, depthMax, tempMin, tempMax, updatedAt, sourceUrl)
  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
`)
const insertSection = db.prepare('INSERT OR REPLACE INTO section (speciesId, kind, text) VALUES (?, ?, ?)')
const insertPhoto = db.prepare('INSERT INTO photo (speciesId, position, caption) VALUES (?, ?, ?)')
const insertName = db.prepare('INSERT OR IGNORE INTO vernacularName (speciesId, name, isFrench) VALUES (?, ?, ?)')
const insertRank = db.prepare('INSERT OR REPLACE INTO taxonRank (speciesId, position, rank, name) VALUES (?, ?, ?, ?)')
const insertSpeciesZone = db.prepare('INSERT OR IGNORE INTO speciesZone (speciesId, zoneId) VALUES (?, ?)')
const insertSearch = db.prepare(
  'INSERT INTO speciesSearch (speciesId, commonName, scientificName, vernacularNames) VALUES (?, ?, ?, ?)'
)

for (const f of fiches) {
  const id = f.numeroFiche
  const commonName = clean(f.nomCommun)
  const scientificName = clean(f.nomScientifique)

  // Sections: duplicate titles are joined; unknown titles are ignored.
  const byKind = new Map()
  for (const s of sectionsOf.all(f._id)) {
    const kind = SECTION_KEYS[s.titre]
    if (!kind) continue
    const text = clean(s.texte)
    if (!text) continue
    byKind.set(kind, byKind.has(kind) ? `${byKind.get(kind)}\n\n${text}` : text)
  }
  for (const [kind, text] of byKind) insertSection.run(id, kind, text)

  const biotope = byKind.get('biotope') ?? ''
  const depth = parseRange(biotope, 'm')
  const temp = parseRange(biotope, '°C')

  const pictos = new Set((f.pictogrammes ?? '').split(';').map((p) => p.trim()).filter(Boolean))

  const photos = photosOf.all(f._id)
  photos.forEach((p, position) => {
    const caption = clean(p.titre) || clean(p.description)
    insertPhoto.run(id, position, caption || null)
  })

  insertSpecies.run(
    id, commonName, scientificName, f.groupe_id,
    STATUS_BY_ETAT[f.etatFiche] ?? 'inProgress',
    pictos.has(PICTO_REGULATED) ? 1 : 0,
    pictos.has(PICTO_DANGEROUS) ? 1 : 0,
    photos.length,
    depth?.min ?? null, depth?.max ?? null,
    temp?.min ?? null, temp?.max ?? null,
    // dateModification is dd/mm/yyyy, often empty and sometimes carrying DORIS's
    // internal "_has_warning" marker (alone or appended). NULL when nothing is left.
    f.dateModification?.replace('_has_warning', '').trim() || null,
    sourceUrl(scientificName, commonName, id)
  )

  // langue is 'FR' for French vernacular names and an empty string otherwise.
  const vernacular = []
  for (const n of namesOf.all(f._id)) {
    const name = clean(n.denomination)
    if (!name) continue
    insertName.run(id, name, n.langue === 'FR' ? 1 : 0)
    vernacular.push(name)
  }

  for (const r of ranksOf.all(f._id)) {
    const name = clean(r.termeScientifique) || clean(r.termeFrancais)
    if (!name) continue
    insertRank.run(id, r.numOrdre, clean(r.niveau), name)
  }

  for (const z of zonesOf.all(f._id)) insertSpeciesZone.run(id, z.ZoneGeographique_id)

  insertSearch.run(id, commonName, scientificName, vernacular.join(' '))
}

// ── Recursive species counts, then prune empty branches ──────────────────────
db.exec(`
  WITH RECURSIVE descendant(rootId, groupId) AS (
    SELECT id, id FROM taxonGroup
    UNION ALL
    SELECT d.rootId, g.id FROM taxonGroup g JOIN descendant d ON g.parentId = d.groupId
  )
  UPDATE taxonGroup SET speciesCount = (
    SELECT COUNT(*) FROM species s
    WHERE s.groupId IN (SELECT groupId FROM descendant WHERE rootId = taxonGroup.id)
  )
`)
db.exec('DELETE FROM taxonGroup WHERE speciesCount = 0')
// Ancestors of a surviving zone are kept even when no species points at them
// directly, otherwise the navigation tree loses its intermediate nodes.
// (taxonGroup needs no such care: a recursive count is non-zero for every ancestor.)
db.exec(`
  WITH RECURSIVE kept(id) AS (
    SELECT DISTINCT zoneId FROM speciesZone
    UNION
    SELECT z.parentId FROM zone z JOIN kept ON z.id = kept.id WHERE z.parentId IS NOT NULL
  )
  DELETE FROM zone WHERE id NOT IN (SELECT id FROM kept)
`)

const dorisDate = db.prepare('SELECT dateBase FROM src.dorisDB_metadata LIMIT 1').get()?.dateBase ?? 'unknown'
const insertMeta = db.prepare('INSERT INTO meta (key, value) VALUES (?, ?)')
insertMeta.run('dorisDate', dorisDate)
insertMeta.run('generatedAt', new Date().toISOString())
insertMeta.run('speciesCount', String(fiches.length))
insertMeta.run('zones', ZONES.join(','))

db.exec('COMMIT')
db.exec('DETACH src')
db.exec("INSERT INTO speciesSearch(speciesSearch) VALUES ('optimize')")
db.exec('VACUUM')
db.close()

const { ok, problems, stats } = verifyDatabase(TMP)
console.log(stats)
if (!ok) {
  console.error('VERIFICATION FAILED:')
  for (const p of problems) console.error(`  - ${p}`)
  rmSync(TMP, { force: true })
  process.exit(1)
}
renameSync(TMP, OUT)
console.log(`wrote ${OUT} (DORIS base dated ${dorisDate})`)

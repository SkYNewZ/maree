#!/usr/bin/env node
// Publishes one 400 px HEIC thumbnail per species to the Backblaze bucket, at
// images/{id}/0_maree.heic. Idempotent: existing objects are skipped.
//
// Requires the authenticated `b2` CLI (b2 account get) and macOS `sips`.
// Usage: node tools/generate-thumbs.mjs [--db=<path>] [--limit=<n>] [--force]

import { DatabaseSync } from 'node:sqlite'
import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
import { writeFile, mkdtemp, rm, stat } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'

const run = promisify(execFile)

const BUCKET = 'doris-production'
const PUBLIC_BASE = 'https://s3.us-east-005.backblazeb2.com/doris-production'
const MAX_EDGE = 400
const QUALITY = 50
const CONCURRENCY = 6

const args = new Map(
  process.argv.slice(2).filter((a) => a.startsWith('--'))
    .map((a) => { const [k, ...v] = a.slice(2).split('='); return [k, v.join('=') || 'true'] })
)
const DB = resolve(args.get('db') ?? 'Maree/Resources/maree.db')
const LIMIT = args.get('limit') ? Number(args.get('limit')) : null
const FORCE = args.get('force') === 'true'

const db = new DatabaseSync(DB, { readOnly: true })
const ids = db.prepare(
  `SELECT id FROM species WHERE photoCount > 0 ORDER BY id ${LIMIT ? `LIMIT ${LIMIT}` : ''}`
).all().map((r) => r.id)
db.close()

console.log(`${ids.length} thumbnails to consider`)

const workDir = await mkdtemp(join(tmpdir(), 'maree-thumbs-'))
const counters = { skipped: 0, uploaded: 0, missing: 0, failed: 0, bytes: 0 }

async function alreadyPublished(id) {
  const res = await fetch(`${PUBLIC_BASE}/images/${id}/0_maree.heic`, { method: 'HEAD' })
  return res.ok
}

async function processOne(id) {
  try {
    if (!FORCE && await alreadyPublished(id)) { counters.skipped++; return }

    const res = await fetch(`${PUBLIC_BASE}/images/${id}/0.jpg`)
    // 16 species carry a photoCount the bucket has no object for. That is a fact
    // about the origin, not a failure of this run: counting it as one made every
    // successful re-run exit 1, and hid the runs that really did break.
    if (res.status === 404) { counters.missing++; return }
    if (!res.ok) throw new Error(`source image HTTP ${res.status}`)

    const source = join(workDir, `${id}.jpg`)
    const target = join(workDir, `${id}.heic`)
    await writeFile(source, Buffer.from(await res.arrayBuffer()))
    await run('sips', ['-Z', String(MAX_EDGE), source,
                       '-s', 'format', 'heic', '-s', 'formatOptions', String(QUALITY),
                       '--out', target])

    // b2 file upload <bucket> <localPath> <remoteName>
    await run('b2', ['file', 'upload', '--quiet', '--content-type', 'image/heic',
                     BUCKET, target, `images/${id}/0_maree.heic`])

    counters.bytes += (await stat(target)).size
    counters.uploaded++
    await rm(source, { force: true })
    await rm(target, { force: true })
  } catch (error) {
    counters.failed++
    console.error(`  ${id}: ${error.message}`)
  }
}

// Fixed-size worker pool over a shared cursor.
let cursor = 0
async function worker() {
  while (cursor < ids.length) {
    const index = cursor++
    await processOne(ids[index])
    if (index % 100 === 0) {
      console.log(`  ${index}/${ids.length} — ${counters.uploaded} uploaded, ${counters.skipped} skipped, ${counters.missing} missing, ${counters.failed} failed`)
    }
  }
}
await Promise.all(Array.from({ length: CONCURRENCY }, worker))

await rm(workDir, { recursive: true, force: true })

const averageKb = counters.uploaded ? Math.round(counters.bytes / counters.uploaded / 1024) : 0
console.log(`uploaded ${counters.uploaded} (avg ${averageKb} KB), skipped ${counters.skipped}, missing at origin ${counters.missing}, failed ${counters.failed}`)
if (counters.failed > 0) process.exit(1)

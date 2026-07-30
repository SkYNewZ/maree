// Validates a CLI numeric flag's raw string value. A truthy check on the raw
// string (`args.limit ? Number(args.limit) : null`) treats '0' as "absent",
// silently expanding an operator's "process nothing" into "process everything"
// — the bug that let a --limit=0 --force run re-upload ~100 production
// thumbnails before anyone meant it to.
//
// Returns null when raw is undefined (flag omitted — caller decides what
// "no limit" means), otherwise a non-negative integer. Throws on anything
// else (NaN, non-integer, negative) so the caller can fail loudly before
// doing any work.
export function parseLimit(raw) {
  if (raw === undefined) return null
  const n = Number(raw)
  if (!Number.isInteger(n) || n < 0) {
    throw new Error(`--limit must be a non-negative integer, got ${JSON.stringify(raw)}`)
  }
  return n
}

// A photoFiche row with an empty cleURL has no file in the bucket: the reference
// pipeline drops it before numbering (doris-pwa/scripts/fetch-doris.js, imgBase()
// returns null → .filter(Boolean)), so images/{numeroFiche}/{n}.jpg skips it.
// Any tool that numbers photos MUST filter on this predicate, or its positions
// drift from the bucket. Shared by prepare-db.mjs and generate-thumbs.mjs.
export const PHOTO_HAS_IMAGE = "cleURL IS NOT NULL AND TRIM(cleURL) <> ''"

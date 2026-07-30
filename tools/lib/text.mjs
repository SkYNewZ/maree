// DORIS stores a custom {{…}} markup, sometimes mixed with raw HTML.
// Unlike the PWA's version, this cleaner preserves paragraph breaks:
// it normalises horizontal whitespace only, then collapses runs of blank lines.
function stripMarkup(text) {
  return text
    .replace(/\{\{\/?[ibg]\}\}/gi, '')
    .replace(/\{\{n\/\}\}/gi, '\n')
    .replace(/\{\{A:[^}]*\}\}([\s\S]*?)\{\{\/A\}\}/gi, '$1')
    .replace(/\{\{[^}]*\}\}/g, '')
}

function stripHtml(text) {
  return text
    // A few texts double-escape their inline tags ("&lt;em&gt;"). Only a bare tag
    // name is markup: "&lt; 4 mm" and the French "&lt;&lt;citation&gt;&gt;" stay literal.
    .replace(/(?<!&lt;)&lt;(\/?[a-zA-Z][a-zA-Z0-9]*)&gt;(?!&gt;)/g, '<$1>')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(?:p|div|li)>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, '&')
}

export function clean(text) {
  if (!text) return ''
  return stripHtml(stripMarkup(text))
    .replace(/[^\S\n]+/g, ' ')   // horizontal whitespace only — keeps \n
    .replace(/ *\n */g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
}

const RANGE_UNITS = { m: 'm\\b', '°C': '°\\s*C' }

// Matches "5 à 30 m", "12–18 m", "de 8 et 24 °C". Returns null unless both bounds
// are present and ordered — a single "30 m maximum" is not a range.
export function parseRange(text, unit) {
  if (!text) return null
  const pattern = new RegExp(`(\\d+)\\s*(?:–|-|à|et)\\s*(\\d+)\\s*${RANGE_UNITS[unit]}`, 'i')
  const match = text.match(pattern)
  if (!match) return null
  const min = Number(match[1])
  const max = Number(match[2])
  return min <= max ? { min, max } : null
}

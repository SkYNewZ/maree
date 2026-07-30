import { test } from 'node:test'
import assert from 'node:assert/strict'
import { clean, parseRange } from './text.mjs'
import { SECTION_KEYS, SECTION_ORDER } from './sections.mjs'

test('retire le markup italique/gras/glossaire', () => {
  assert.equal(clean('{{i}}Paracentrotus lividus{{/i}} (Lamarck, 1816)'), 'Paracentrotus lividus (Lamarck, 1816)')
  assert.equal(clean('{{b}}gras{{/b}} et {{g}}Genre{{/g}}'), 'gras et Genre')
})

test('preserve les sauts de paragraphe', () => {
  assert.equal(clean('Premier.{{n/}}{{n/}}Second.'), 'Premier.\n\nSecond.')
  assert.equal(clean('Ligne A<br>Ligne B'), 'Ligne A\nLigne B')
})

test('deroule les liens et supprime le markup inconnu', () => {
  assert.equal(clean('voir {{A:https://x.fr}}la fiche{{/A}} ici'), 'voir la fiche ici')
  assert.equal(clean('avant {{XYZ:42}} apres'), 'avant apres')
})

test('retire les balises HTML et decode les entites', () => {
  assert.equal(clean('<p>Texte&nbsp;&amp;&nbsp;suite</p>'), 'Texte & suite')
  assert.equal(clean('a &lt;b&gt; c &quot;d&quot; &#39;e&#39;'), 'a <b> c "d" \'e\'')
})

test('normalise les espaces horizontaux sans ecraser les retours', () => {
  assert.equal(clean('  trop   d\'espaces  \n\n  suite '), 'trop d\'espaces\n\nsuite')
  assert.equal(clean('a\n\n\n\n\nb'), 'a\n\nb')
})

test('tolere null et undefined', () => {
  assert.equal(clean(null), '')
  assert.equal(clean(undefined), '')
})

test('extrait les plages de profondeur et de temperature', () => {
  assert.deepEqual(parseRange('entre 5 et 30 m de fond', 'm'), { min: 5, max: 30 })
  assert.deepEqual(parseRange('de 10 à 25 m', 'm'), { min: 10, max: 25 })
  assert.deepEqual(parseRange('12–18 m', 'm'), { min: 12, max: 18 })
  assert.deepEqual(parseRange('de 8 à 24 °C', '°C'), { min: 8, max: 24 })
  assert.equal(parseRange('aucune plage ici', 'm'), null)
  assert.equal(parseRange('30 m maximum', 'm'), null)
})

test('les cles de sections sont completes et ordonnees', () => {
  assert.equal(Object.keys(SECTION_KEYS).length, 14)
  assert.equal(SECTION_KEYS['Critères de reconnaissance'], 'identification')
  assert.equal(SECTION_KEYS['Reproduction - Multiplication'], 'reproduction')
  // toute cle presente dans la table doit avoir une place dans l'ordre d'affichage
  for (const key of Object.values(SECTION_KEYS)) {
    assert.ok(SECTION_ORDER.includes(key), `cle absente de SECTION_ORDER: ${key}`)
  }
  assert.equal(SECTION_ORDER[0], 'identification')
})

// Exact DORIS section titles → stable ASCII keys.
// The set is closed: the source database contains exactly 15 distinct titles,
// and we deliberately drop "Références bibliographiques" (out of v1 scope).
export const SECTION_KEYS = {
  'Critères de reconnaissance': 'identification',
  'Distribution': 'distribution',
  'Biotope': 'biotope',
  'Description': 'description',
  'Alimentation': 'feeding',
  'Reproduction - Multiplication': 'reproduction',
  'Divers biologie': 'biologyMisc',
  'Vie associée': 'associatedLife',
  'Informations complémentaires': 'additionalInfo',
  'Réglementation': 'regulation',
  'Origine du nom français': 'frenchNameOrigin',
  'Origine du nom scientifique': 'scientificNameOrigin',
  'Autres noms scientifiques parfois utilisés, mais non valides': 'invalidSynonyms',
  'Espèces Ressemblantes': 'similarSpecies',
}

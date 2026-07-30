import { test } from 'node:test'
import assert from 'node:assert/strict'
import { parseLimit } from './args.mjs'

test('--limit absent means no limit', () => {
  assert.equal(parseLimit(undefined), null)
})

test('--limit=0 is a real value, not "absent"', () => {
  assert.equal(parseLimit('0'), 0)
})

test('a positive integer passes through', () => {
  assert.equal(parseLimit('5'), 5)
})

test('a non-integer or negative value throws before any work happens', () => {
  assert.throws(() => parseLimit('abc'), /non-negative integer/)
  assert.throws(() => parseLimit('1.5'), /non-negative integer/)
  assert.throws(() => parseLimit('-1'), /non-negative integer/)
})

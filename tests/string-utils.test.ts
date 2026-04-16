import { describe, it, expect } from 'vitest'

function capitalize(str: string): string {
  return str.charAt(0).toUpperCase() + str.slice(1)
}

function reverse(str: string): string {
  return str.split('').reverse().join('')
}

function truncate(str: string, maxLength: number): string {
  if (str.length <= maxLength) return str
  return str.slice(0, maxLength) + '...'
}

describe('capitalize', () => {
  it('capitalizes first letter', () => {
    expect(capitalize('hello')).toBe('Hello')
  })
  it('handles empty string', () => {
    expect(capitalize('')).toBe('')
  })
  it('handles already capitalized', () => {
    expect(capitalize('Hello')).toBe('Hello')
  })
})

describe('reverse', () => {
  it('reverses a string', () => {
    expect(reverse('hello')).toBe('olleh')
  })
  it('handles palindrome', () => {
    expect(reverse('racecar')).toBe('racecar')
  })
})

describe('truncate', () => {
  it('truncates long string', () => {
    expect(truncate('Hello World', 5)).toBe('Hello...')
  })
  it('keeps short string', () => {
    expect(truncate('Hi', 5)).toBe('Hi')
  })
  it('handles exact length', () => {
    expect(truncate('Hello', 5)).toBe('Hello')
  })
})

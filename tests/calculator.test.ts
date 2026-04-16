import { describe, it, expect } from 'vitest'
import { add, subtract, multiply, divide, power, modulo } from '../src/calculator'

describe('add', () => {
  it('adds positive numbers', () => {
    expect(add(2, 3)).toBe(5)
  })
  it('adds negative numbers', () => {
    expect(add(-1, -1)).toBe(-2)
  })
  it('adds mixed numbers', () => {
    expect(add(-1, 1)).toBe(0)
  })
})

describe('subtract', () => {
  it('subtracts numbers', () => {
    expect(subtract(5, 3)).toBe(2)
  })
  it('returns negative', () => {
    expect(subtract(3, 5)).toBe(-2)
  })
})

describe('multiply', () => {
  it('multiplies numbers', () => {
    expect(multiply(3, 4)).toBe(12)
  })
  it('multiplies by zero', () => {
    expect(multiply(5, 0)).toBe(0)
  })
})

describe('divide', () => {
  it('divides numbers', () => {
    expect(divide(10, 2)).toBe(5)
  })
  it('returns float', () => {
    expect(divide(7, 2)).toBe(3.5)
  })
  it('throws on zero', () => {
    expect(() => divide(1, 0)).toThrow('Cannot divide by zero')
  })
})

describe('power', () => {
  it('calculates power', () => {
    expect(power(2, 3)).toBe(8)
  })
  it('zero exponent', () => {
    expect(power(5, 0)).toBe(1)
  })
})

describe('modulo', () => {
  it('calculates remainder', () => {
    expect(modulo(10, 3)).toBe(1)
  })
  it('throws on zero', () => {
    expect(() => modulo(10, 0)).toThrow('Cannot modulo by zero')
  })
})

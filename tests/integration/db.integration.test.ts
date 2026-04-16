import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

beforeAll(async () => {
  await prisma.$connect()
})

afterAll(async () => {
  await prisma.post.deleteMany()
  await prisma.user.deleteMany()
  await prisma.$disconnect()
})

describe('User CRUD', () => {
  it('creates a user', async () => {
    const user = await prisma.user.create({
      data: { email: 'test@example.com', name: 'Test User' },
    })
    expect(user.email).toBe('test@example.com')
    expect(user.name).toBe('Test User')
  })

  it('finds user by email', async () => {
    const user = await prisma.user.findUnique({
      where: { email: 'test@example.com' },
    })
    expect(user).not.toBeNull()
    expect(user!.name).toBe('Test User')
  })
})

describe('Post CRUD', () => {
  it('creates a post with author', async () => {
    const user = await prisma.user.findUnique({
      where: { email: 'test@example.com' },
    })
    const post = await prisma.post.create({
      data: {
        title: 'Hello World',
        content: 'First post',
        authorId: user!.id,
      },
    })
    expect(post.title).toBe('Hello World')
    expect(post.published).toBe(false)
  })

  it('queries posts with author relation', async () => {
    const posts = await prisma.post.findMany({
      include: { author: true },
    })
    expect(posts).toHaveLength(1)
    expect(posts[0].author.email).toBe('test@example.com')
  })
})

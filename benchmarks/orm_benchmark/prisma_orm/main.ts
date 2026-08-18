import { PrismaClient } from '@prisma/client';
import * as fs from 'fs';

const dbPath = '/tmp/prisma_orm_bench.db';
if (fs.existsSync(dbPath)) fs.unlinkSync(dbPath);

const prisma = new PrismaClient();

async function run() {
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "auth_users" (
      "id" INTEGER PRIMARY KEY AUTOINCREMENT,
      "name" TEXT NOT NULL,
      "email" TEXT NOT NULL,
      "age" INTEGER NOT NULL,
      "is_active" BOOLEAN NOT NULL
    );
  `);

  const insertCount = 5000;
  const lookupCount = 5000;
  const queryCount = 1000;

  console.log('=== Prisma ORM (SQLite) Benchmark ===');

  // 1. Batch / Iterative Inserts in Transaction
  const swInsert = Date.now();
  const data = [];
  for (let i = 1; i <= insertCount; i++) {
    data.push({
      name: `User ${i}`,
      email: `user${i}@example.com`,
      age: 18 + (i % 60),
      isActive: i % 2 === 0,
    });
  }
  await prisma.user.createMany({ data });
  const insertMs = Date.now() - swInsert;
  const insertRps = (insertCount / (insertMs / 1000)).toFixed(1);
  console.log(`1. Inserts (${insertCount} records): ${insertMs}ms (${insertRps} ops/sec)`);

  // 2. Point Lookups (findById)
  const swLookup = Date.now();
  for (let i = 1; i <= lookupCount; i++) {
    const id = 1 + (i % insertCount);
    const result = await prisma.user.findUnique({ where: { id } });
    if (!result) throw new Error('Not found');
  }
  const lookupMs = Date.now() - swLookup;
  const lookupRps = (lookupCount / (lookupMs / 1000)).toFixed(1);
  console.log(`2. Point Lookups (${lookupCount} ops): ${lookupMs}ms (${lookupRps} ops/sec)`);

  // 3. Filtered QuerySet + OrderBy + Limit
  const swQuery = Date.now();
  for (let i = 0; i < queryCount; i++) {
    const minAge = 20 + (i % 30);
    const results = await prisma.user.findMany({
      where: {
        isActive: true,
        age: { gte: minAge },
      },
      orderBy: { age: 'desc' },
      take: 20,
    });
    if (results.length === 0) throw new Error('Empty query result');
  }
  const queryMs = Date.now() - swQuery;
  const queryRps = (queryCount / (queryMs / 1000)).toFixed(1);
  console.log(`3. Filtered QuerySet + Pagination (${queryCount} queries): ${queryMs}ms (${queryRps} ops/sec)`);

  // 4. Bulk Update
  const swUpdate = Date.now();
  const updated = await prisma.user.updateMany({
    where: { age: { gte: 50 } },
    data: { isActive: false },
  });
  const updateMs = Date.now() - swUpdate;
  console.log(`4. Bulk Update (${updated.count} rows updated): ${updateMs}ms`);

  await prisma.$disconnect();
}

run();

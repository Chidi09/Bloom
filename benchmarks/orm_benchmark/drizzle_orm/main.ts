import { Database } from 'bun:sqlite';
import { drizzle } from 'drizzle-orm/bun-sqlite';
import { sqliteTable, integer, text } from 'drizzle-orm/sqlite-core';
import { eq, gte, and, desc } from 'drizzle-orm';
import * as fs from 'fs';

const dbPath = '/tmp/drizzle_orm_bench.db';
if (fs.existsSync(dbPath)) fs.unlinkSync(dbPath);

const sqlite = new Database(dbPath);
sqlite.run('PRAGMA synchronous = NORMAL;');
sqlite.run('PRAGMA journal_mode = WAL;');

const users = sqliteTable('auth_users', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  name: text('name').notNull(),
  email: text('email').notNull(),
  age: integer('age').notNull(),
  isActive: integer('is_active', { mode: 'boolean' }).notNull(),
});

sqlite.run(`
  CREATE TABLE "auth_users" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "age" INTEGER NOT NULL,
    "is_active" INTEGER NOT NULL
  );
`);

const db = drizzle(sqlite);

async function run() {
  const insertCount = 5000;
  const lookupCount = 5000;
  const queryCount = 1000;

  console.log('=== Drizzle ORM (bun:sqlite) Benchmark ===');

  // 1. Batch / Iterative Inserts in Transaction
  const swInsert = Date.now();
  const insertTx = sqlite.transaction(() => {
    for (let i = 1; i <= insertCount; i++) {
      db.insert(users).values({
        name: `User ${i}`,
        email: `user${i}@example.com`,
        age: 18 + (i % 60),
        isActive: i % 2 === 0,
      }).run();
    }
  });
  insertTx();
  const insertMs = Date.now() - swInsert;
  const insertRps = (insertCount / (insertMs / 1000)).toFixed(1);
  console.log(`1. Inserts (${insertCount} records): ${insertMs}ms (${insertRps} ops/sec)`);

  // 2. Point Lookups (findById)
  const swLookup = Date.now();
  for (let i = 1; i <= lookupCount; i++) {
    const id = 1 + (i % insertCount);
    const result = db.select().from(users).where(eq(users.id, id)).get();
    if (!result) throw new Error('Not found');
  }
  const lookupMs = Date.now() - swLookup;
  const lookupRps = (lookupCount / (lookupMs / 1000)).toFixed(1);
  console.log(`2. Point Lookups (${lookupCount} ops): ${lookupMs}ms (${lookupRps} ops/sec)`);

  // 3. Filtered QuerySet + OrderBy + Limit
  const swQuery = Date.now();
  for (let i = 0; i < queryCount; i++) {
    const minAge = 20 + (i % 30);
    const results = db.select().from(users)
      .where(and(eq(users.isActive, true), gte(users.age, minAge)))
      .orderBy(desc(users.age))
      .limit(20)
      .all();
    if (results.length === 0) throw new Error('Empty query result');
  }
  const queryMs = Date.now() - swQuery;
  const queryRps = (queryCount / (queryMs / 1000)).toFixed(1);
  console.log(`3. Filtered QuerySet + Pagination (${queryCount} queries): ${queryMs}ms (${queryRps} ops/sec)`);

  // 4. Bulk Update
  const swUpdate = Date.now();
  const updated = db.update(users)
    .set({ isActive: false })
    .where(gte(users.age, 50))
    .run();
  const updateMs = Date.now() - swUpdate;
  console.log(`4. Bulk Update (${updated.changes} rows updated): ${updateMs}ms`);

  sqlite.close();
}

run();

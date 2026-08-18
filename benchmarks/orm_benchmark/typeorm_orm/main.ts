import 'reflect-metadata';
import { DataSource, EntitySchema } from 'typeorm';

interface IUser {
  id: number;
  name: string;
  email: string;
  age: number;
  isActive: boolean;
}

const UserSchema = new EntitySchema<IUser>({
  name: 'User',
  tableName: 'auth_users',
  columns: {
    id: {
      primary: true,
      type: Number,
      generated: true,
    },
    name: {
      type: String,
    },
    email: {
      type: String,
    },
    age: {
      type: Number,
    },
    isActive: {
      type: Boolean,
      name: 'is_active',
    },
  },
});

const AppDataSource = new DataSource({
  type: 'sqljs',
  synchronize: true,
  logging: false,
  entities: [UserSchema],
});

async function run() {
  await AppDataSource.initialize();
  const repo = AppDataSource.getRepository<IUser>('User');

  const insertCount = 5000;
  const lookupCount = 5000;
  const queryCount = 1000;

  console.log('=== TypeORM (sqljs) Benchmark ===');

  // 1. Batch / Iterative Inserts in Transaction
  const swInsert = Date.now();
  await AppDataSource.transaction(async (manager) => {
    const list: Partial<IUser>[] = [];
    for (let i = 1; i <= insertCount; i++) {
      list.push({
        name: `User ${i}`,
        email: `user${i}@example.com`,
        age: 18 + (i % 60),
        isActive: i % 2 === 0,
      });
    }
    await manager.save('User', list, { chunk: 1000 });
  });
  const insertMs = Date.now() - swInsert;
  const insertRps = (insertCount / (insertMs / 1000)).toFixed(1);
  console.log(`1. Inserts (${insertCount} records): ${insertMs}ms (${insertRps} ops/sec)`);

  // 2. Point Lookups (findById)
  const swLookup = Date.now();
  for (let i = 1; i <= lookupCount; i++) {
    const id = 1 + (i % insertCount);
    const result = await repo.findOneBy({ id } as any);
    if (!result) throw new Error('Not found');
  }
  const lookupMs = Date.now() - swLookup;
  const lookupRps = (lookupCount / (lookupMs / 1000)).toFixed(1);
  console.log(`2. Point Lookups (${lookupCount} ops): ${lookupMs}ms (${lookupRps} ops/sec)`);

  // 3. Filtered QuerySet + OrderBy + Limit
  const swQuery = Date.now();
  for (let i = 0; i < queryCount; i++) {
    const minAge = 20 + (i % 30);
    const results = await repo.createQueryBuilder('user')
      .where('user.is_active = :isActive', { isActive: 1 })
      .andWhere('user.age >= :minAge', { minAge })
      .orderBy('user.age', 'DESC')
      .limit(20)
      .getMany();
    if (results.length === 0) throw new Error('Empty query result');
  }
  const queryMs = Date.now() - swQuery;
  const queryRps = (queryCount / (queryMs / 1000)).toFixed(1);
  console.log(`3. Filtered QuerySet + Pagination (${queryCount} queries): ${queryMs}ms (${queryRps} ops/sec)`);

  // 4. Bulk Update
  const swUpdate = Date.now();
  const updateRes = await repo.createQueryBuilder()
    .update('User')
    .set({ isActive: false })
    .where('age >= :age', { age: 50 })
    .execute();
  const updateMs = Date.now() - swUpdate;
  console.log(`4. Bulk Update (${updateRes.affected ?? 0} rows updated): ${updateMs}ms`);

  await AppDataSource.destroy();
}

run();

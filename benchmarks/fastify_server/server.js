const fastify = require('fastify')({ logger: false });

fastify.get('/ping', async (request, reply) => {
  return { message: 'hello world' };
});

fastify.get('/users/:id', async (request, reply) => {
  return {
    id: request.params.id,
    name: 'Alice',
    role: 'admin'
  };
});

fastify.post('/echo', async (request, reply) => {
  return {
    received: true,
    data: request.body
  };
});

const port = process.argv[2] ? parseInt(process.argv[2], 10) : 4002;
fastify.listen({ port, host: '127.0.0.1' }, (err, address) => {
  if (err) {
    console.error(err);
    process.exit(1);
  }
  console.log(`Fastify server running on ${address}`);
});

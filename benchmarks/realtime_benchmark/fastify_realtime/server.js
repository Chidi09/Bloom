const fastify = require('fastify')({ logger: false });
fastify.register(require('@fastify/websocket'));

const connections = new Map();
const channelSubscribers = new Map();
let connIdCounter = 0;

fastify.register(async function (fastify) {
  fastify.get('/ws', { websocket: true }, (connection, req) => {
    const socket = connection.socket || connection;
    const id = `conn_${++connIdCounter}`;
    const subbedChannels = new Set();
    connections.set(id, { socket, subbedChannels });

    socket.on('message', (message) => {
      try {
        const text = typeof message === 'string' ? message : message.toString('utf8');
        const data = JSON.parse(text);
        if (data.type === 'subscribe' && data.channel) {
          subbedChannels.add(data.channel);
          if (!channelSubscribers.has(data.channel)) {
            channelSubscribers.set(data.channel, new Set());
          }
          channelSubscribers.get(data.channel).add(id);
          socket.send(JSON.stringify({ type: 'subscribed', channel: data.channel }));
        } else if (data.type === 'broadcast' && data.channel) {
          const subs = channelSubscribers.get(data.channel);
          if (subs) {
            const wire = JSON.stringify({
              type: 'broadcast',
              channel: data.channel,
              payload: data.payload || {},
            });
            for (const subId of subs) {
              const c = connections.get(subId);
              if (c && c.socket.readyState === 1) {
                c.socket.send(wire);
              }
            }
          }
        }
      } catch (e) {}
    });

    socket.on('close', () => {
      for (const ch of subbedChannels) {
        const set = channelSubscribers.get(ch);
        if (set) {
          set.delete(id);
          if (set.size === 0) channelSubscribers.delete(ch);
        }
      }
      connections.delete(id);
    });
  });
});

fastify.get('/stats', async () => ({
  activeConnections: connections.size,
  activeChannels: channelSubscribers.size,
}));

const port = process.argv[2] ? parseInt(process.argv[2], 10) : 5002;
fastify.listen({ port, host: '127.0.0.1' }, (err, address) => {
  if (err) {
    console.error(err);
    process.exit(1);
  }
  console.log(`Fastify Realtime server running on ws://127.0.0.1:${port}/ws`);
});

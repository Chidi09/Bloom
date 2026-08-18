import WebSocket from 'ws';

const targetPort = process.argv[2] ? parseInt(process.argv[2], 10) : 5001;
const clientCount = process.argv[3] ? parseInt(process.argv[3], 10) : 1000;
const broadcastCount = process.argv[4] ? parseInt(process.argv[4], 10) : 50;
const targetWsUrl = `ws://127.0.0.1:${targetPort}/ws`;
const channel = 'room:bench';

async function run() {
  console.log(`Connecting ${clientCount} WebSocket clients to ${targetWsUrl}...`);

  const sockets: WebSocket[] = [];
  let connectedCount = 0;
  let subscribedCount = 0;
  let totalMessagesReceived = 0;

  const swConnect = Date.now();

  const connectPromise = new Promise<void>((resolve, reject) => {
    let settled = false;

    for (let i = 0; i < clientCount; i++) {
      const ws = new WebSocket(targetWsUrl);
      sockets.push(ws);

      ws.on('open', () => {
        connectedCount++;
        ws.send(JSON.stringify({ type: 'subscribe', channel }));
        if (connectedCount === clientCount && !settled) {
          settled = true;
          resolve();
        }
      });

      ws.on('message', (data) => {
        totalMessagesReceived++;
      });

      ws.on('error', (err) => {
        // ignore connection errors during heavy load
      });
    }

    setTimeout(() => {
      if (!settled) {
        settled = true;
        resolve();
      }
    }, 10000);
  });

  await connectPromise;
  const connectMs = Date.now() - swConnect;
  console.log(`✓ ${connectedCount}/${clientCount} clients connected & subscribed in ${connectMs}ms`);

  // Wait 1s for all subscription handshakes to settle
  await new Promise((r) => setTimeout(r, 1000));

  console.log(`Broadcasting ${broadcastCount} messages to channel '${channel}' (${clientCount * broadcastCount} fan-out deliveries)...`);

  const expectedDeliveries = connectedCount * broadcastCount;
  totalMessagesReceived = 0;
  const swBroadcast = Date.now();

  // Send broadcasts via HTTP endpoint or publisher socket
  const pubSocket = new WebSocket(targetWsUrl);
  await new Promise<void>((res) => pubSocket.on('open', () => res()));

  for (let b = 1; b <= broadcastCount; b++) {
    pubSocket.send(JSON.stringify({
      type: 'broadcast',
      channel,
      payload: { index: b, timestamp: Date.now(), data: 'Realtime payload' },
    }));
  }

  // Wait for all messages to arrive
  const timeoutLimit = 10000;
  const startTime = Date.now();
  while (totalMessagesReceived < expectedDeliveries && Date.now() - startTime < timeoutLimit) {
    await new Promise((r) => setTimeout(r, 50));
  }

  const broadcastDurationMs = Date.now() - swBroadcast;
  const deliveryThroughput = ((totalMessagesReceived / (broadcastDurationMs / 1000))).toFixed(0);

  console.log(`✓ Delivered ${totalMessagesReceived}/${expectedDeliveries} fan-out messages in ${broadcastDurationMs}ms (${deliveryThroughput} msgs/sec throughput)`);

  pubSocket.close();
  for (const s of sockets) {
    try { s.close(); } catch (e) {}
  }
  process.exit(0);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});

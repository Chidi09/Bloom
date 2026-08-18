import 'reflect-metadata';
import { Controller, Get, Module } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { WebSocketServer, WebSocket } from 'ws';
import * as http from 'http';

const connections = new Map<string, { socket: WebSocket; channels: Set<string> }>();
const channelSubscribers = new Map<string, Set<string>>();
let connCounter = 0;

@Controller()
class AppController {
  @Get('stats')
  getStats() {
    return {
      activeConnections: connections.size,
      activeChannels: channelSubscribers.size,
    };
  }
}

@Module({
  controllers: [AppController],
})
class AppModule {}

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { logger: false });
  const server = app.getHttpServer() as http.Server;
  const wss = new WebSocketServer({ noServer: true });

  server.on('upgrade', (request, socket, head) => {
    if (request.url?.startsWith('/ws')) {
      wss.handleUpgrade(request, socket, head, (ws) => {
        wss.emit('connection', ws, request);
      });
    } else {
      socket.destroy();
    }
  });

  wss.on('connection', (socket: WebSocket) => {
    const id = `conn_${++connCounter}`;
    const channels = new Set<string>();
    connections.set(id, { socket, channels });

    socket.on('message', (raw) => {
      try {
        const text = typeof raw === 'string' ? raw : raw.toString('utf8');
        const data = JSON.parse(text);

        if (data.type === 'subscribe' && data.channel) {
          channels.add(data.channel);
          if (!channelSubscribers.has(data.channel)) {
            channelSubscribers.set(data.channel, new Set());
          }
          channelSubscribers.get(data.channel)!.add(id);
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
              if (c && c.socket.readyState === WebSocket.OPEN) {
                c.socket.send(wire);
              }
            }
          }
        }
      } catch (e) {}
    });

    socket.on('close', () => {
      for (const ch of channels) {
        const set = channelSubscribers.get(ch);
        if (set) {
          set.delete(id);
          if (set.size === 0) channelSubscribers.delete(ch);
        }
      }
      connections.delete(id);
    });
  });

  const port = process.argv[2] ? parseInt(process.argv[2], 10) : 5003;
  await app.listen(port, '127.0.0.1');
  console.log(`NestJS Realtime server running on ws://127.0.0.1:${port}/ws`);
}

bootstrap();

import 'reflect-metadata';
import { Controller, Get, Post, Param, Body, Module } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';

@Controller()
class AppController {
  @Get('ping')
  getPing() {
    return { message: 'hello world' };
  }

  @Get('users/:id')
  getUser(@Param('id') id: string) {
    return {
      id,
      name: 'Alice',
      role: 'admin',
    };
  }

  @Post('echo')
  postEcho(@Body() body: any) {
    return {
      received: true,
      data: body,
    };
  }
}

@Module({
  controllers: [AppController],
})
class AppModule {}

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { logger: false });
  const port = process.argv[2] ? parseInt(process.argv[2], 10) : 4003;
  await app.listen(port, '127.0.0.1');
  console.log(`NestJS server running on http://127.0.0.1:${port}`);
}

bootstrap();

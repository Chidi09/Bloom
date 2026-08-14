// lib/src/utils/ansi.dart

class Ansi {
  static const String reset = '\x1B[0m';
  static const String bold = '\x1B[1m';
  static const String dim = '\x1B[2m';

  static const String black = '\x1B[30m';
  static const String red = '\x1B[31m';
  static const String green = '\x1B[32m';
  static const String yellow = '\x1B[33m';
  static const String blue = '\x1B[34m';
  static const String magenta = '\x1B[35m';
  static const String cyan = '\x1B[36m';
  static const String white = '\x1B[37m';
  static const String gray = '\x1B[90m';

  static String colorize(String text, String color) => '$color$text$reset';
  static String boldText(String text) => '$bold$text$reset';
  static String dimText(String text) => '$dim$text$reset';

  static String success(String text) => '$green✔ $text$reset';
  static String error(String text) => '$red✖ $text$reset';
  static String warn(String text) => '$yellow⚠ $text$reset';
  static String info(String text) => '$cyanℹ $text$reset';
  static String step(String text) => '$magenta› $text$reset';
}

void printBloomBanner({String version = '0.1.0'}) {
  print('''
${Ansi.cyan}${Ansi.bold}
   ____  __    ____  ____  __  ___
  / __ )/ /   / __ \\/ __ \\/  |/  /
 / __  / /   / / / / / / / /|_/ / 
/ /_/ / /___/ /_/ / /_/ / /  / /  
/_____/_____/\\____/\\____/_/  /_/   ${Ansi.dim}v$version${Ansi.reset}

${Ansi.dim}The Opinionated Application Framework for Flutter${Ansi.reset}
''');
}

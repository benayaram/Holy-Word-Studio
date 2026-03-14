import 'dart:io';

void main() {
  final res = Process.runSync('keytool', [
    '-list',
    '-v',
    '-keystore',
    'C:\\Users\\dell\\.android\\debug.keystore',
    '-alias',
    'androiddebugkey',
    '-storepass',
    'android',
    '-keypass',
    'android',
  ]);
  File('sha.txt').writeAsStringSync(res.stdout);
}

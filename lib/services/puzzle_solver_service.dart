import 'dart:async';
import 'dart:isolate';

import 'package:btcaddress/btc_tool.dart';

class PuzzleSolveProgress {
  final int tested;
  final String currentPrivKeyHex;
  final double keysPerSecond;

  const PuzzleSolveProgress({
    required this.tested,
    required this.currentPrivKeyHex,
    required this.keysPerSecond,
  });
}

class PuzzleSolveFound {
  final int tested;
  final String privateKeyHex;
  final String addressLegacy;
  final String addressCompressed;

  const PuzzleSolveFound({
    required this.tested,
    required this.privateKeyHex,
    required this.addressLegacy,
    required this.addressCompressed,
  });
}

class PuzzleSolverController {
  Isolate? _isolate;
  ReceivePort? _receivePort;
  StreamSubscription? _sub;

  bool get isRunning => _isolate != null;

  Future<void> start({
    required String targetAddress,
    required int bitLength,
    required bool checkLegacy,
    required bool checkCompressed,
    required void Function(PuzzleSolveProgress progress) onProgress,
    required void Function(PuzzleSolveFound found) onFound,
    required void Function() onNotFound,
    required void Function(Object error) onError,
  }) async {
    await stop();

    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn<_PuzzleSolveRequest>(
      _puzzleSolveIsolateEntry,
      _PuzzleSolveRequest(
        sendPort: _receivePort!.sendPort,
        targetAddress: targetAddress.trim(),
        bitLength: bitLength,
        checkLegacy: checkLegacy,
        checkCompressed: checkCompressed,
      ),
      debugName: 'puzzle-solver',
    );

    _sub = _receivePort!.listen((message) {
      if (message is Map) {
        final type = message['type'];
        switch (type) {
          case 'progress':
            onProgress(
              PuzzleSolveProgress(
                tested: message['tested'] as int,
                currentPrivKeyHex: message['currentPrivKeyHex'] as String,
                keysPerSecond: (message['keysPerSecond'] as num).toDouble(),
              ),
            );
            return;
          case 'found':
            onFound(
              PuzzleSolveFound(
                tested: message['tested'] as int,
                privateKeyHex: message['privateKeyHex'] as String,
                addressLegacy: message['addressLegacy'] as String,
                addressCompressed: message['addressCompressed'] as String,
              ),
            );
            return;
          case 'not_found':
            onNotFound();
            return;
          case 'error':
            onError(message['error'] ?? 'Erro desconhecido');
            return;
        }
      }
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;

    _receivePort?.close();
    _receivePort = null;

    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }
}

class _PuzzleSolveRequest {
  final SendPort sendPort;
  final String targetAddress;
  final int bitLength;
  final bool checkLegacy;
  final bool checkCompressed;

  const _PuzzleSolveRequest({
    required this.sendPort,
    required this.targetAddress,
    required this.bitLength,
    required this.checkLegacy,
    required this.checkCompressed,
  });
}

void _puzzleSolveIsolateEntry(_PuzzleSolveRequest req) {
  final send = req.sendPort;

  if (req.bitLength < 8 || req.bitLength > 32) {
    send.send({
      'type': 'error',
      'error': 'bitLength inválido (use 8..32 para puzzles educativos).',
    });
    return;
  }

  final target = req.targetAddress;
  if (target.isEmpty) {
    send.send({'type': 'error', 'error': 'Informe um endereço alvo.'});
    return;
  }

  final btc = BitcoinTOOL();

  final BigInt start = BigInt.one;
  final BigInt end = (BigInt.one << req.bitLength) - BigInt.one;

  int tested = 0;
  final stopwatch = Stopwatch()..start();
  int lastProgressAtTested = 0;
  int lastProgressAtMs = 0;

  try {
    for (BigInt k = start; k <= end; k += BigInt.one) {
      tested++;
      final privHex = k.toRadixString(16).padLeft(64, '0');

      btc.setPrivateKeyHex(privHex);

      if (req.checkLegacy) {
        final addr = btc.getAddress(false);
        if (addr == target) {
          send.send({
            'type': 'found',
            'tested': tested,
            'privateKeyHex': privHex,
            'addressLegacy': addr,
            'addressCompressed': btc.getAddress(true),
          });
          return;
        }
      }

      if (req.checkCompressed) {
        final addrC = btc.getAddress(true);
        if (addrC == target) {
          send.send({
            'type': 'found',
            'tested': tested,
            'privateKeyHex': privHex,
            'addressLegacy': btc.getAddress(false),
            'addressCompressed': addrC,
          });
          return;
        }
      }

      if (tested - lastProgressAtTested >= 5000) {
        final ms = stopwatch.elapsedMilliseconds;
        final deltaMs = ms - lastProgressAtMs;
        final deltaKeys = tested - lastProgressAtTested;
        final kps = deltaMs <= 0 ? 0.0 : (deltaKeys * 1000.0) / deltaMs;

        send.send({
          'type': 'progress',
          'tested': tested,
          'currentPrivKeyHex': privHex,
          'keysPerSecond': kps,
        });

        lastProgressAtTested = tested;
        lastProgressAtMs = ms;
      }
    }

    send.send({'type': 'not_found'});
  } catch (e) {
    send.send({'type': 'error', 'error': e.toString()});
  }
}

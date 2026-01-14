import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:btcaddress/btc_tool.dart';

enum PuzzleSearchStrategy {
  sequential,
  random,
}

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
    PuzzleSearchStrategy strategy = PuzzleSearchStrategy.sequential,
    int? randomSeed,
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
        strategy: strategy,
        randomSeed: randomSeed,
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
  final PuzzleSearchStrategy strategy;
  final int? randomSeed;

  const _PuzzleSolveRequest({
    required this.sendPort,
    required this.targetAddress,
    required this.bitLength,
    required this.checkLegacy,
    required this.checkCompressed,
    required this.strategy,
    required this.randomSeed,
  });
}

BigInt _randomKey(math.Random random, int bitLength) {
  if (bitLength <= 0) return BigInt.one;

  int candidate;
  if (bitLength <= 30) {
    candidate = random.nextInt(1 << bitLength);
  } else if (bitLength == 31) {
    final hi = random.nextInt(1 << 16);
    final lo = random.nextInt(1 << 15);
    candidate = (hi << 15) | lo;
  } else {
    final hi = random.nextInt(1 << 16);
    final lo = random.nextInt(1 << 16);
    candidate = (hi << 16) | lo;
  }

  if (candidate == 0) candidate = 1;
  return BigInt.from(candidate);
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
    bool checkKey(BigInt k) {
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
          return true;
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
          return true;
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

      return false;
    }

    if (req.strategy == PuzzleSearchStrategy.random) {
      final random = math.Random(req.randomSeed ?? DateTime.now().microsecondsSinceEpoch);
      final int maxTries = end.toInt();

      for (int i = 0; i < maxTries; i++) {
        final k = _randomKey(random, req.bitLength);
        tested++;
        if (checkKey(k)) return;
      }
    } else {
      for (BigInt k = start; k <= end; k += BigInt.one) {
        tested++;
        if (checkKey(k)) return;
      }
    }

    send.send({'type': 'not_found'});
  } catch (e) {
    send.send({'type': 'error', 'error': e.toString()});
  }
}

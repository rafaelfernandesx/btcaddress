import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';
import 'package:pointycastle/digests/ripemd160.dart';

class ECDSA {
  BigInt? k;
  final BigInt a;
  final BigInt b;
  final BigInt p;
  final BigInt n;
  final Map<String, BigInt> G;

  ECDSA()
      : a = BigInt.zero,
        b = BigInt.from(7),
        p = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F', radix: 16),
        n = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141', radix: 16),
        G = {
          'x': BigInt.parse('55066263022277343669578718895168534326250603453777594175500187360389116729240'),
          'y': BigInt.parse('32670510020758816978083085130507043184471273380659243275938904335757337482424'),
        };

  Map<String, BigInt> doublePoint(Map<String, BigInt> pt) {
    // Garantir que o ponto seja válido
    BigInt gcd = (BigInt.two * pt['y']!) % p;
    if (gcd.gcd(p) != BigInt.one) {
      throw Exception("Esta biblioteca ainda não suporta ponto no infinito. Veja: https://github.com/BitcoinPHP/BitcoinECDSA.php/issues/9");
    }

    // Calcular a inclinação
    BigInt slope = ((BigInt.from(3) * pt['x']! * pt['x']!) + a) * ((BigInt.two * pt['y']!).modInverse(p)) % p;

    // Calcular as novas coordenadas do ponto
    BigInt newX = (slope * slope - pt['x']! - pt['x']!) % p;
    BigInt newY = (slope * (pt['x']! - newX) - pt['y']!) % p;

    // Retornar o novo ponto
    return {'x': newX, 'y': newY};
  }

  Map<String, BigInt> addPoints(Map<String, BigInt> pt1, Map<String, BigInt> pt2) {
    // Verificar se os pontos são idênticos
    if (pt1['x'] == pt2['x'] && pt1['y'] == pt2['y']) {
      return doublePoint(pt1); // Ajuste para sua implementação de `doublePoint`
    }

    // Garantir que o divisor não seja inválido
    BigInt gcd = (pt1['x']! - pt2['x']!).abs().gcd(p);
    if (gcd != BigInt.one) {
      throw Exception("Esta biblioteca ainda não suporta ponto no infinito. Veja: https://github.com/BitcoinPHP/BitcoinECDSA.php/issues/9");
    }

    // Calcular a inclinação
    BigInt slope = ((pt1['y']! - pt2['y']!) * (pt1['x']! - pt2['x']!).modInverse(p)) % p;

    // Calcular as novas coordenadas do ponto
    BigInt newX = (slope * slope - pt1['x']! - pt2['x']!) % p;
    BigInt newY = (slope * (pt1['x']! - newX) - pt1['y']!) % p;

    // Ajustar valores negativos para o módulo
    if (newX < BigInt.zero) newX += p;
    if (newY < BigInt.zero) newY += p;

    return {'x': newX, 'y': newY};
  }

  Map<String, BigInt> mulPoint(BigInt k, Map<String, BigInt> pG, {int base = 16}) {
    // Obter representação binária de `k`
    String kBin = k.toRadixString(2);

    // Iniciar a iteração para calcular `k * G`
    Map<String, BigInt> lastPoint = pG;
    for (int i = 1; i < kBin.length; i++) {
      if (kBin[i] == '1') {
        lastPoint = addPoints(doublePoint(lastPoint), pG);
      } else {
        lastPoint = doublePoint(lastPoint);
      }
    }

    // Validar o ponto resultante
    if (!validatePoint(
      lastPoint['x']!.toRadixString(16),
      lastPoint['y']!.toRadixString(16),
    )) {
      throw Exception('The resulting point is not on the curve.');
    }

    return lastPoint;
  }

  bool validatePoint(String x, String y) {
    final BigInt a = this.a; // Supondo que `a` é um atributo da classe
    final BigInt b = this.b; // Supondo que `b` é um atributo da classe
    final BigInt p = this.p; // Supondo que `p` é um atributo da classe

    // Converter os valores hexadecimais para BigInt
    BigInt xBigInt = BigInt.parse(x, radix: 16);
    BigInt yBigInt = BigInt.parse(y, radix: 16);

    // Calcular y² (lado direito da equação)
    BigInt y2 = (xBigInt.modPow(BigInt.from(3), p) + (a * xBigInt) + b) % p;

    // Calcular o lado esquerdo da equação
    BigInt yLeft = yBigInt.modPow(BigInt.from(2), p);

    // Comparar os dois lados
    return y2 == yLeft;
  }

  Map<String, String> getPubKeyPoints() {
    if (k == null) {
      throw Exception('No Private Key was defined');
    }

    var pubKey = mulPoint(k!, G);

    var xHex = pubKey['x']!.toRadixString(16).padLeft(64, '0');
    var yHex = pubKey['y']!.toRadixString(16).padLeft(64, '0');

    return {'x': xHex, 'y': yHex};
  }
}

class BitcoinTOOL {
  late String networkPrefix;
  late ECDSA ecdsa;

  BitcoinTOOL() {
    networkPrefix = '00';
    ecdsa = ECDSA();
  }

  setNetworkPrefix(prefix) {
    networkPrefix = prefix;
  }

  getNetworkPrefix() {
    return networkPrefix;
  }

  getPrivatePrefix() {
    if (networkPrefix == '6f') {
      return 'ef';
    }
    return '80';
  }

  String hash256d(String data) {
    var hash1 = sha256.convert(HEX.decode(data)).bytes;
    var hash2 = sha256.convert(hash1).toString();
    return hash2;
  }

  String hash160(String data) {
    var hash256 = sha256.convert(HEX.decode(data)).bytes;
    var hash160 = RIPEMD160Digest().process(hash256 as Uint8List);
    String result = HEX.encode(hash160);
    return result;
  }

  String generateRandom256BitsHexaString([String extra = 'FkejkzqesrfeifH3ioio9hb55sdssdsdfOO:ss']) {
    final ecdsaN = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141', radix: 16); // Substituir pelo valor correto de n
    String generateRandom() {
      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256)); // 256 bits = 32 bytes
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      return hex + timestamp + extra;
    }

    while (true) {
      final random = generateRandom();
      final hash = hash256d(HEX.encode(random.codeUnits));
      final res = BigInt.parse(hash, radix: 16);

      if (res < ecdsaN - BigInt.one) {
        return hash;
      }
    }
  }

  String getPubKey({bool compressed = false, Map<String, String> pubKeyPts = const {}}) {
    if (pubKeyPts.isEmpty) {
      pubKeyPts = ecdsa.getPubKeyPoints(); // Substitua por sua lógica para obter os pontos da chave pública
    }

    if (!compressed) {
      // Chave pública não comprimida
      String uncompressedPubKey = '04${pubKeyPts['x']}${pubKeyPts['y']}';
      return uncompressedPubKey;
    }

    // Verificar se a coordenada 'y' é par
    BigInt y = BigInt.parse(pubKeyPts['y']!, radix: 16);
    BigInt two = BigInt.from(2);
    String compressedPubKey;

    if (y % two == BigInt.zero) {
      // Se 'y' for par
      compressedPubKey = '02${pubKeyPts['x']}';
    } else {
      // Se 'y' for ímpar
      compressedPubKey = '03${pubKeyPts['x']}';
    }

    return compressedPubKey;
  }

  String getAddressFromPublicHex(String publicKeyHex, {String networkPrefix = '00'}) {
    // Obter o endereço com o prefixo da rede
    String address = networkPrefix + hash160(publicKeyHex);

    // Adicionar checksum
    String checksum = hash256d(address).substring(0, 8);
    address += checksum;

    // Codificar em Base58
    String base58Address = Base58().encode(HEX.decode(address) as Uint8List);

    // Validar o endereço
    if (validateAddress(base58Address)) {
      return base58Address;
    } else {
      throw Exception('O endereço gerado parece não ser válido.');
    }
  }

  getAddressh160([bool compressed = false]) {
    String address = getPubKey(compressed: compressed);

    address = hash160(address);
    return address;
  }

  getAddress([bool compressed = false, bool verify = false]) {
    String address = getPubKey(compressed: compressed);

    address = getNetworkPrefix() + hash160(address);

    //checksum
    address = address + hash256d(address).toString().substring(0, 8);
    address = Base58().encode(HEX.decode(address) as Uint8List);
    if (verify == false) {
      return address;
    }
    if (validateAddress(address)) {
      return address;
    }
    throw Exception('the generated address seems not to be valid.');
  }

  getRipeMd160Address([bool compressed = false, bool verify = false]) {
    String address = getPubKey(compressed: compressed);

    final addressRipemd = hash160(address);
    address = getNetworkPrefix() + addressRipemd;

    //checksum
    address = address + hash256d(address).toString().substring(0, 8);
    address = Base58().encode(HEX.decode(address) as Uint8List);
    if (verify == false) {
      return addressRipemd;
    }
    if (validateAddress(address)) {
      return addressRipemd;
    }
    throw Exception('the generated address seems not to be valid.');
  }

  // getP2SHAddress(bool compressed = false)
  // {

  // 	pubkey = getPubKey(compressed);

  // 	keyhash = '00' . '14' . this.hash160(hex2bin(pubkey));
  // 	address = '05' . this.hash160(hex2bin(keyhash));

  // 	checksum = hash256d(hex2bin(address));
  // 	address = address . substr(checksum, 0, 8);

  // 	address = Base58::encode(address);

  // 	if (this.validateAddress(address))
  // 		return address;
  // 	else
  // 		throw \Exception('the generated address seems not to be valid.');
  // }

  void setPrivateKeyHex(String k) {
    final key = BigInt.parse(k, radix: 16);
    final maxKey = ecdsa.n - BigInt.one;

    if (key > maxKey) {
      throw Exception('Private Key is not in the 1,n-1 range');
    }

    ecdsa.k = key;
  }

  setPrivateKeyFromSeed(String seed) {
    var hash = HEX.encode(sha256.convert(seed.codeUnits).bytes);
    var k = BigInt.parse(hash, radix: 16);
    final maxKey = ecdsa.n - BigInt.one;

    if (k > maxKey) {
      throw Exception('Private Key is not in the 1,n-1 range');
    }
    ecdsa.k = k;
  }

  String getPrivateKey() {
    return ecdsa.k?.toRadixString(16) ?? '';
  }

  BigInt getPrivateKeyDecimal() {
    if (ecdsa.k == null) {
      throw Exception('No Private Key was defined');
    }
    return ecdsa.k!;
  }

  void generateRandomPrivateKey([String extra = 'FSQF5356dsdsqdfEFEQ3fq4q6dq4s5d']) {
    ecdsa.k = BigInt.parse(generateRandom256BitsHexaString(extra), radix: 16);
  }

  bool validateAddress(String addr) {
    var address = Base58().decode(addr);
    if (address.length != 25) return false;
    final checksum = HEX.encode(address.sublist(21, 25));
    final rawAddress = address.sublist(0, 21);
    final rawSum = hash256d(HEX.encode(rawAddress)).substring(0, 8);
    if (rawSum == checksum) {
      return true;
    }
    return false;
  }

  getWif([bool compressed = false]) {
    if (ecdsa.k == null) {
      throw Exception('No Private Key was defined');
    }

    BigInt k = ecdsa.k!;

    String secretKey = getPrivatePrefix() + k.toRadixString(16).padLeft(64, '0');

    if (compressed) {
      secretKey += '01';
    }

    secretKey += hash256d(secretKey).substring(0, 8);
    final wif = Base58().encode(HEX.decode(secretKey) as Uint8List);
    return wif;
  }

  // getBalance(?string address, bool compressed = false)
  // {
  // 	addr = address ?? getAddress(compressed);
  // 	try {
  // 		balance = file_get_contents('https://blockchain.info/q/addressbalance/' . addr);
  // 		return balance;
  // 	} catch (\Throwable th) {
  // 		return 'Error';
  // 	}
  // }

  bool validateWifKey(String wif) {
    // Decodificar a chave WIF usando Base58
    Uint8List decodedKey = Base58().decode(wif);

    // Converter para hexadecimal
    String keyHex = HEX.encode(decodedKey);

    // Calcular o comprimento e verificar o checksum
    int length = keyHex.length;
    List<int> checksum = HEX.decode(hash256d(keyHex.substring(0, length - 8)));

    return keyHex.substring(length - 8) == HEX.encode(checksum).substring(0, 8);
  }

  void setPrivateKeyWithWif(String wif) {
    if (!validateWifKey(wif)) {
      throw Exception('Invalid WIF');
    }

    Uint8List decodedKey = Base58().decode(wif);
    String keyHex = HEX.encode(decodedKey);

    // Obter a chave privada do WIF
    String privateKeyHex = keyHex.substring(2, 66);

    // Chamar a função para definir a chave privada em hexadecimal
    setPrivateKeyHex(privateKeyHex);
  }
}

class Base58 {
  String alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  Map<String, int> alphabetMap = {};
  int? base58;

  String? leader;

  Base58([String alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz']) {
    alphabet = alphabet;
    base58 = alphabet.length;
    leader = (alphabet)[0];
    for (var i = 0; i < (alphabet).length; i++) {
      alphabetMap[(alphabet)[i]] = i;
    }
  }
  String encode(Uint8List source) {
    if (source.isEmpty) {
      return "";
    }
    List<int> digits = [0];

    for (var i = 0; i < source.length; ++i) {
      var carry = source[i];
      for (var j = 0; j < digits.length; ++j) {
        carry += digits[j] << 8;
        digits[j] = carry % base58!;
        carry = carry ~/ base58!;
      }
      while (carry > 0) {
        digits.add(carry % base58!);
        carry = carry ~/ base58!;
      }
    }
    var string = "";

    // deal with leading zeros
    for (var k = 0; source[k] == 0 && k < source.length - 1; ++k) {
      string += leader!;
    }
    // convert digits to a string
    for (var q = digits.length - 1; q >= 0; --q) {
      string += alphabet[digits[q]];
    }
    return string;
  }

  Uint8List decode(String string) {
    if (string.isEmpty) {
      throw ArgumentError('Non-base$base58 character');
    }
    List<int> bytes = [0];
    for (var i = 0; i < string.length; i++) {
      var value = alphabetMap[string[i]];
      if (value == null) {
        throw ArgumentError('Non-base$base58 character');
      }
      var carry = value;
      for (var j = 0; j < bytes.length; ++j) {
        carry += bytes[j] * base58!;
        bytes[j] = carry & 0xff;
        carry >>= 8;
      }
      while (carry > 0) {
        bytes.add(carry & 0xff);
        carry >>= 8;
      }
    }
    // deal with leading zeros
    for (var k = 0; string[k] == leader && k < string.length - 1; ++k) {
      bytes.add(0);
    }
    return Uint8List.fromList(bytes.reversed.toList());
  }
}

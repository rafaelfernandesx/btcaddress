class AddressModel {
  final String seed;
  final String addressCompressed;
  final String addressUncompressed;
  final String addressBech32;
  final String addressTaproot;
  final String privateKeyHex;
  final String privateKeyWif;
  final String privateKeyWifCompressed;
  final String publicKeyHex;
  final String publicKeyHexCompressed;
  final DateTime timestamp;

  AddressModel({
    required this.seed,
    required this.addressCompressed,
    required this.addressUncompressed,
    this.addressBech32 = '',
    this.addressTaproot = '',
    required this.privateKeyHex,
    required this.privateKeyWif,
    required this.privateKeyWifCompressed,
    required this.publicKeyHex,
    required this.publicKeyHexCompressed,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'seed': seed,
      'addressCompressed': addressCompressed,
      'addressUncompressed': addressUncompressed,
      'addressBech32': addressBech32,
      'addressTaproot': addressTaproot,
      'privateKeyHex': privateKeyHex,
      'privateKeyWif': privateKeyWif,
      'privateKeyWifCompressed': privateKeyWifCompressed,
      'publicKeyHex': publicKeyHex,
      'publicKeyHexCompressed': publicKeyHexCompressed,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    final tsRaw = json['timestamp'];
    final ts = DateTime.tryParse(tsRaw?.toString() ?? '');
    return AddressModel(
      seed: json['seed'] ?? '',
      addressCompressed: json['addressCompressed'] ?? '',
      addressUncompressed: json['addressUncompressed'] ?? '',
      addressBech32: json['addressBech32'] ?? '',
      addressTaproot: json['addressTaproot'] ?? '',
      privateKeyHex: json['privateKeyHex'] ?? '',
      privateKeyWif: json['privateKeyWif'] ?? '',
      privateKeyWifCompressed: json['privateKeyWifCompressed'] ?? '',
      publicKeyHex: json['publicKeyHex'] ?? '',
      publicKeyHexCompressed: json['publicKeyHexCompressed'] ?? '',
      timestamp: ts ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

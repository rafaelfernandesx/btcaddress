class AddressModel {
  final String seed;
  final String addressCompressed;
  final String addressUncompressed;
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
      'privateKeyHex': privateKeyHex,
      'privateKeyWif': privateKeyWif,
      'privateKeyWifCompressed': privateKeyWifCompressed,
      'publicKeyHex': publicKeyHex,
      'publicKeyHexCompressed': publicKeyHexCompressed,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      seed: json['seed'] ?? '',
      addressCompressed: json['addressCompressed'] ?? '',
      addressUncompressed: json['addressUncompressed'] ?? '',
      privateKeyHex: json['privateKeyHex'] ?? '',
      privateKeyWif: json['privateKeyWif'] ?? '',
      privateKeyWifCompressed: json['privateKeyWifCompressed'] ?? '',
      publicKeyHex: json['publicKeyHex'] ?? '',
      publicKeyHexCompressed: json['publicKeyHexCompressed'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

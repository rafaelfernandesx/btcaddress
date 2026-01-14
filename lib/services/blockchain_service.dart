import 'package:dio/dio.dart';

class BlockchainService {
  final Dio _dio;

  BlockchainService({Dio? dio}) : _dio = dio ?? Dio();

  /// Returns a formatted string like "0.00000000 BTC" or throws.
  Future<String> getBalanceBtc(String address) async {
    final url = 'https://blockchain.info/q/addressbalance/$address';
    final response = await _dio.get(url);

    // blockchain.info/q/addressbalance returns satoshis as a plain number
    final dynamic raw = response.data;
    final int satoshis = raw is int ? raw : int.parse(raw.toString());

    final double btc = satoshis / 100000000;
    return '${btc.toStringAsFixed(8)} BTC';
  }
}

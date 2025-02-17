import 'package:btcaddress/btc_tool.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Btc Address generator'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final btc = BitcoinTOOL();
  final seedController = TextEditingController();
  final hexController = TextEditingController();
  final wifController = TextEditingController();
  final p2pkhController = TextEditingController();
  final p2pkhcController = TextEditingController();
  final ripemdcController = TextEditingController();
  final ripemdController = TextEditingController();
  final pubKeyHexController = TextEditingController();
  final pubKeyHexcController = TextEditingController();
  final privKeyHexController = TextEditingController();
  final privKeyWifController = TextEditingController();
  final privKeyWifcController = TextEditingController();

  void update() {
    setState(() {
      p2pkhController.text = btc.getAddress();
      p2pkhcController.text = btc.getAddress(true);
      ripemdController.text = btc.getRipeMd160Address();
      ripemdcController.text = btc.getRipeMd160Address(true);
      pubKeyHexController.text = btc.getPubKey();
      pubKeyHexcController.text = btc.getPubKey(compressed: true);
      privKeyHexController.text = btc.getPrivateKey();
      privKeyWifController.text = btc.getWif();
      privKeyWifcController.text = btc.getWif(true);
    });
  }

  Future<String> getBalance(String address) async {
    try {
      final url = 'https://blockchain.info/q/addressbalance/$address';
      final response = await Dio().get(url);

      final balance = await response.data;
      return balance;
    } catch (e) {
      return 'Error';
    }
  }

  bool more = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                SizedBox(height: 16),
                TextField(
                  controller: seedController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Seed',
                  ),
                  onChanged: (value) {
                    btc.setPrivateKeyFromSeed(value);
                    update();
                  },
                ),
                SizedBox(height: 8),
                TextField(
                  controller: hexController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Hex',
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      btc.setPrivateKeyHex(value);
                      update();
                    }
                  },
                ),
                SizedBox(height: 8),
                TextField(
                  controller: wifController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Wif',
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      btc.setPrivateKeyWithWif(value);
                      update();
                    }
                  },
                ),
                SizedBox(height: 8),
                Text('Results:'),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: p2pkhcController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Address Compressed',
                        ),
                        readOnly: true,
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      onPressed: () async {
                        final balance = await getBalance(p2pkhcController.text);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Balance: $balance'),
                          duration: Duration(milliseconds: 250),
                        ));
                      },
                      icon: Icon(Icons.search),
                    )
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: p2pkhController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Address UnCompressed',
                        ),
                        readOnly: true,
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      onPressed: () async {
                        final balance = await getBalance(p2pkhController.text);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Balance: $balance'),
                          duration: Duration(milliseconds: 250),
                        ));
                      },
                      icon: Icon(Icons.search),
                    )
                  ],
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      more = !more;
                    });
                  },
                  child: Icon(more ? Icons.expand_less : Icons.expand_more),
                ),
                SizedBox(height: 8),
                Visibility(
                  visible: more,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                      controller: privKeyHexController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Private Key Hex',
                      ),
                      readOnly: true,
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: privKeyWifController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Private Key Wif',
                      ),
                      readOnly: true,
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: privKeyWifcController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Private Key Wif compressed',
                      ),
                      readOnly: true,
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: ripemdController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'ripemd160 uncompressed',
                      ),
                      readOnly: true,
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: ripemdcController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'ripemd160 compressed',
                      ),
                      readOnly: true,
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: pubKeyHexController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'PubKey hex uncompressed',
                      ),
                      readOnly: true,
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: pubKeyHexcController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'PubKey hex compressed',
                      ),
                      readOnly: true,
                    ),
                  ]),
                ),
                SizedBox(height: 64),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

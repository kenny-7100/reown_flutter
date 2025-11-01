import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:reown_appkit_dapp/pages/connect_page.dart';
import 'package:reown_appkit_dapp/utils/deep_link_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DeepLinkHandler.initListener();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ReownAppKit? _appKit;
  ReownAppKitModal? _appKitModal;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  PairingMetadata get _pairingMetadata {
    const universalLink = 'https://appkit-lab.reown.com/flutter_appkit';
    return PairingMetadata(
      name: 'name',
      description: 'description',
      url: universalLink,
      redirect: Redirect(
        native: 'wcflutterdapp://',
        universal: universalLink,
        linkMode: false,
      ),
    );
  }

  Future<void> _initializeService() async {
    _appKit = ReownAppKit(
      core: ReownCore(
        projectId: '986837d557c1c7a14641d330a1135226',
        logLevel: LogLevel.nothing,
      ),
      metadata: _pairingMetadata,
    );

    _appKitModal = ReownAppKitModal(
      context: context,
      appKit: _appKit,
      disconnectOnDispose: true,
    );

    await _appKitModal!.init();

    DeepLinkHandler.init(_appKitModal!);
    DeepLinkHandler.checkInitialLink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ConnectPage(appKitModal: _appKitModal!),
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:reown_appkit_dapp/pages/connect_page.dart';
import 'package:reown_appkit_dapp/utils/crypto/helpers.dart';
import 'package:reown_appkit_dapp/utils/deep_link_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DeepLinkHandler.initListener();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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

  String get _flavor {
    String flavor = '-${const String.fromEnvironment('FLUTTER_APP_FLAVOR')}';
    return flavor.replaceAll('-production', '');
  }

  String _universalLink() {
    Uri link = Uri.parse('https://appkit-lab.reown.com/flutter_appkit');
    if (_flavor.isNotEmpty || kDebugMode) {
      return link.replace(path: '${link.path}_internal').toString();
    }
    return link.toString();
  }

  Redirect _constructRedirect(bool linkModeEnabled) {
    return Redirect(
      native: 'wcflutterdapp$_flavor://',
      universal: _universalLink(),
      linkMode: linkModeEnabled,
    );
  }

  PairingMetadata _pairingMetadata(bool linkModeEnabled) {
    return PairingMetadata(
      name: 'Reown\'s AppKit ${_flavor.replaceFirst('-', '')}',
      description: 'Reown\'s sample dApp with Flutter SDK',
      url: _universalLink(),
      icons: [
        'https://raw.githubusercontent.com/reown-com/reown_flutter/refs/heads/develop/assets/appkit-icon$_flavor.png',
      ],
      redirect: _constructRedirect(linkModeEnabled),
    );
  }

  Future<void> _initializeService() async {
    _appKit = ReownAppKit(
      core: ReownCore(
          projectId: '986837d557c1c7a14641d330a1135226',
          logLevel: LogLevel.all),
      metadata: _pairingMetadata(false),
    );

    _appKit!.core.relayClient.onRelayClientError.subscribe(_relayClientError);
    _appKit!.core.relayClient.onRelayClientConnect.subscribe(_setState);
    _appKit!.core.relayClient.onRelayClientDisconnect.subscribe(_setState);
    _appKit!.core.relayClient.onRelayClientMessage.subscribe(_onRelayMessage);

    _appKitModal = ReownAppKitModal(
      context: context,
      appKit: _appKit,
      optionalNamespaces: _namespacesBasedOnChains(),
      getBalanceFallback: () async {
        return 0.0;
      },
      disconnectOnDispose: true,
    );

    _appKitModal!.onModalConnect.subscribe(_onModalConnect);
    _appKitModal!.onModalError.subscribe(_onModalError);
    _appKitModal!.onSessionEventEvent.subscribe(_onSessionEvent);
    _appKitModal!.onSessionUpdateEvent.subscribe(_onSessionUpdate);

    await _appKitModal!.init();
    await _registerEventHandlers();

    DeepLinkHandler.init(_appKitModal!);
    DeepLinkHandler.checkInitialLink();

    final allChains = ReownAppKitModalNetworks.getAllSupportedNetworks();
    for (final chain in allChains) {
      final namespace = NamespaceUtils.getNamespaceFromChain(chain.chainId);
      for (final event in getChainEvents(namespace)) {
        _appKit!.registerEventHandler(chainId: chain.chainId, event: event);
      }
    }
  }

  Map<String, RequiredNamespace>? _namespacesBasedOnChains() {
    Map<String, RequiredNamespace> namespaces = {};

    final supportedNS = ReownAppKitModalNetworks.getAllSupportedNamespaces();
    for (var ns in supportedNS) {
      final chains = ReownAppKitModalNetworks.getAllSupportedNetworks(
        namespace: ns,
      );
      if (chains.isNotEmpty) {
        namespaces[ns] = RequiredNamespace(
          chains: chains.map((c) => c.chainId).toList(),
          methods: getChainMethods(ns),
          events: getChainEvents(ns),
        );
      }
    }

    return namespaces;
  }

  Future<void> _registerEventHandlers() async {
    final onLine = _appKit!.core.connectivity.isOnline.value;
    if (!onLine) {
      await Future.delayed(const Duration(milliseconds: 500));
      _registerEventHandlers();
      return;
    }

    final allChains = ReownAppKitModalNetworks.getAllSupportedNetworks();
    for (final chain in allChains) {
      final namespace = NamespaceUtils.getNamespaceFromChain(chain.chainId);
      for (final event in getChainEvents(namespace)) {
        _appKit!.registerEventHandler(chainId: chain.chainId, event: event);
      }
    }
  }

  void _relayClientError(ErrorEvent? event) {
    debugPrint('[SampleDapp] _relayClientError ${event?.error}');
    _setState('');
  }

  void _setState(_) => setState(() {});

  @override
  void dispose() {
    _appKit!.core.relayClient.onRelayClientError.unsubscribe(_relayClientError);
    _appKit!.core.relayClient.onRelayClientConnect.unsubscribe(_setState);
    _appKit!.core.relayClient.onRelayClientDisconnect.unsubscribe(_setState);
    _appKit!.core.relayClient.onRelayClientMessage.unsubscribe(_onRelayMessage);

    _appKitModal!.onModalConnect.unsubscribe(_onModalConnect);
    _appKitModal!.onModalError.unsubscribe(_onModalError);
    _appKitModal!.onSessionEventEvent.unsubscribe(_onSessionEvent);
    _appKitModal!.onSessionUpdateEvent.unsubscribe(_onSessionUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ConnectPage(appKitModal: _appKitModal!),
    );
  }

  void _onSessionEvent(SessionEvent? args) {
    debugPrint('[SampleDapp] _onSessionEvent $args');
  }

  void _onSessionUpdate(SessionUpdate? args) {
    debugPrint('[SampleDapp] _onSessionUpdate $args');
  }

  void _onRelayMessage(MessageEvent? args) async {
    if (args != null) {
      try {
        final payloadString = await _appKit!.core.crypto.decode(
          args.topic,
          args.message,
        );
        final data = jsonDecode(payloadString ?? '{}') as Map<String, dynamic>;
        debugPrint('[SampleDapp] _onRelayMessage data $data');
      } catch (e) {
        debugPrint('[SampleDapp] _onRelayMessage error $e');
      }
    }
  }

  void _onModalConnect(ModalConnect? event) async {
    debugPrint('[ExampleApp] _onModalConnect ${event?.session.toJson()}');
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('AppKit is connected'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onModalError(ModalError? event) {
    debugPrint('[ExampleApp] _onModalError ${event?.toString()}');
    if ((event?.message ?? '').contains('Coinbase Wallet Error')) {
      _appKitModal!.disconnect();
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          event?.message ?? event?.description ?? 'An error occurred',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:reown_appkit_dapp/pages/connect_page.dart';
import 'package:reown_appkit_dapp/utils/crypto/helpers.dart';
import 'package:reown_appkit_dapp/utils/dart_defines.dart';
import 'package:reown_appkit_dapp/utils/deep_link_handler.dart';
import 'package:reown_appkit_dapp/utils/string_constants.dart';
import 'package:reown_appkit_dapp/widgets/event_widget.dart';
import 'package:reown_appkit_dapp/widgets/log_overlay.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      DeepLinkHandler.initListener();
      runApp(MyApp());
    },
    (error, stackTrace) async {},
  );
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
      title: StringConstants.appTitle,
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

  final LogManager _logManager = LogManager();

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

  void _logListener(String event) => _logManager.addLog(event);

  Future<void> _initializeService() async {
    _appKit = ReownAppKit(
      core: ReownCore(projectId: DartDefines.projectId, logLevel: LogLevel.all),
      metadata: _pairingMetadata(false),
    );

    _appKit!.core.relayClient.onRelayClientError.subscribe(_relayClientError);
    _appKit!.core.relayClient.onRelayClientConnect.subscribe(_setState);
    _appKit!.core.relayClient.onRelayClientDisconnect.subscribe(_setState);
    _appKit!.core.relayClient.onRelayClientMessage.subscribe(_onRelayMessage);

    _appKitModal = ReownAppKitModal(
      context: context,
      appKit: _appKit,
      siweConfig: _siweConfig(false),
      optionalNamespaces: _namespacesBasedOnChains(),
      getBalanceFallback: () async {
        return 0.0;
      },
      disconnectOnDispose: true,
    );

    _appKitModal!.appKit!.core.addLogListener(_logListener);

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
    _appKitModal!.appKit!.core.removeLogListener(_logListener);

    _appKit!.core.relayClient.onRelayClientError.unsubscribe(_relayClientError);
    _appKit!.core.relayClient.onRelayClientConnect.unsubscribe(_setState);
    _appKit!.core.relayClient.onRelayClientDisconnect.unsubscribe(_setState);
    _appKit!.core.relayClient.onRelayClientMessage.unsubscribe(_onRelayMessage);

    _appKitModal!.onModalConnect.unsubscribe(_onModalConnect);
    _appKitModal!.onModalError.unsubscribe(_onModalError);
    _appKitModal!.onSessionEventEvent.unsubscribe(_onSessionEvent);
    _appKitModal!.onSessionUpdateEvent.unsubscribe(_onSessionUpdate);

    _logManager.dispose();
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EventWidget(
          title: StringConstants.receivedEvent,
          content:
              'Topic: ${args!.topic}\nEvent Name: ${args.name}\nEvent Data: ${args.data}',
        );
      },
    );
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

  SIWEConfig _siweConfig(bool enabled) => SIWEConfig(
        getNonce: () async {
          return SIWEUtils.generateNonce();
        },
        getMessageParams: () async {
          debugPrint('[SIWEConfig] getMessageParams()');
          final url = _appKitModal!.appKit!.metadata.url;
          final uri = Uri.parse(url);
          return SIWEMessageArgs(
            domain: uri.authority,
            uri: 'https://${uri.authority}/login',
            statement: 'Welcome to AppKit $packageVersion for Flutter.',
            methods: MethodsConstants.allMethods,
          );
        },
        createMessage: (SIWECreateMessageArgs args) {
          debugPrint('[SIWEConfig] createMessage()');
          return SIWEUtils.formatMessage(args);
        },
        verifyMessage: (SIWEVerifyMessageArgs args) async {
          debugPrint('[SIWEConfig] verifyMessage()');
          final chainId = SIWEUtils.getChainIdFromMessage(args.message);
          final address = SIWEUtils.getAddressFromMessage(args.message);
          final cacaoSignature = args.cacao != null
              ? args.cacao!.s
              : CacaoSignature(t: CacaoSignature.EIP191, s: args.signature);
          return await SIWEUtils.verifySignature(
            address,
            args.message,
            cacaoSignature,
            chainId,
            DartDefines.projectId,
          );
        },
        getSession: () async {
          final chainId = _appKitModal!.selectedChain!.chainId;
          final namespace = NamespaceUtils.getNamespaceFromChain(chainId);
          final address = _appKitModal!.session!.getAddress(namespace)!;
          return SIWESession(address: address, chains: [chainId]);
        },
        onSignIn: (SIWESession session) {
          debugPrint('[SIWEConfig] onSignIn()');
        },
        signOut: () async {
          return true;
        },
        onSignOut: () {
          debugPrint('[SIWEConfig] onSignOut()');
        },
        enabled: enabled,
        signOutOnDisconnect: true,
        signOutOnAccountChange: false,
        signOutOnNetworkChange: false,
      );

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

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:reown_appkit_dapp/models/page_data.dart';
import 'package:reown_appkit_dapp/pages/connect_page.dart';
import 'package:reown_appkit_dapp/utils/constants.dart';
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

      if (kDebugMode) {
        runApp(MyApp());
      } else {
        FlutterError.onError = (FlutterErrorDetails details) {
          FlutterError.presentError(details);
          Sentry.captureException(details.exception, stackTrace: details.stack);
        };

        await SentryFlutter.init((options) {
          options.dsn = DartDefines.sentryDSN;
          options.environment = kDebugMode ? 'debug_app' : 'deployed_app';
          options.attachScreenshot = true;
          options.sendDefaultPii = true;
          options.tracesSampleRate = 1.0;
          options.profilesSampleRate = 1.0;
        }, appRunner: () => runApp(SentryWidget(child: const MyApp())));
      }
    },
    (error, stackTrace) async {
      if (!kDebugMode) {
        await Sentry.captureException(error, stackTrace: stackTrace);
      }
      debugPrint('Uncaught error: $error');
      debugPrint('Stack trace: $stackTrace');
    },
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
      navigatorObservers: [SentryNavigatorObserver()],
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

  List<PageData> _pageDatas = [];
  int _selectedIndex = 0;
  bool _showLogOverlay = false;
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

  FeaturesConfig? _featuresConfig() {
    return FeaturesConfig(
      socials: [
        AppKitSocialOption.Email,
        AppKitSocialOption.X,
        AppKitSocialOption.Google,
        AppKitSocialOption.Apple,
        AppKitSocialOption.Discord,
        AppKitSocialOption.GitHub,
        AppKitSocialOption.Facebook,
        AppKitSocialOption.Twitch,
        AppKitSocialOption.Telegram,
      ],
      showMainWallets: true,
    );
  }

  void _logListener(String event) => _logManager.addLog(event);

  Future<void> _initializeService() async {
    final prefs = await SharedPreferences.getInstance();
    final linkModeEnabled = false;
    final analyticsEnabled = prefs.getBool('appkit_sample_analytics') ?? true;
    final socialsEnabled = prefs.getBool('appkit_sample_socials') ?? true;

    _appKit = ReownAppKit(
      core: ReownCore(projectId: DartDefines.projectId, logLevel: LogLevel.all),
      metadata: _pairingMetadata(linkModeEnabled),
    );

    _appKit!.core.relayClient.onRelayClientError.subscribe(_relayClientError);
    _appKit!.core.relayClient.onRelayClientConnect.subscribe(_setState);
    _appKit!.core.relayClient.onRelayClientDisconnect.subscribe(_setState);
    _appKit!.core.relayClient.onRelayClientMessage.subscribe(_onRelayMessage);

    _appKitModal = ReownAppKitModal(
      context: context,
      appKit: _appKit,
      logLevel: LogLevel.all,
      enableAnalytics: analyticsEnabled,
      siweConfig: _siweConfig(linkModeEnabled),
      featuresConfig: socialsEnabled ? _featuresConfig() : null,
      optionalNamespaces: _namespacesBasedOnChains(),
      getBalanceFallback: () async {
        return 0.0;
      },
      disconnectOnDispose: true,
      customWallets: [
        ReownAppKitModalWalletInfo(
          listing: AppKitModalWalletListing(
            id: '00001',
            name: 'Reown Web Sample',
            homepage: 'https://react-wallet.walletconnect.com',
            imageId:
                'https://avatars.githubusercontent.com/u/179229932?s=200&v=4',
            order: 1,
            webappLink: 'https://react-wallet.walletconnect.com',
          ),
        ),
      ],
    );

    _appKitModal!.appKit!.core.addLogListener(_logListener);

    _appKitModal!.onModalConnect.subscribe(_onModalConnect);
    _appKitModal!.onModalUpdate.subscribe(_onModalUpdate);
    _appKitModal!.onModalNetworkChange.subscribe(_onModalNetworkChange);
    _appKitModal!.onModalDisconnect.subscribe(_onModalDisconnect);
    _appKitModal!.onModalError.subscribe(_onModalError);
    _appKitModal!.onSessionEventEvent.subscribe(_onSessionEvent);
    _appKitModal!.onSessionUpdateEvent.subscribe(_onSessionUpdate);

    _pageDatas = [
      PageData(
        page: ConnectPage(appKitModal: _appKitModal!),
        title: StringConstants.connectPageTitle,
        icon: Icons.home,
      ),
    ];

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
    _appKitModal!.onModalUpdate.unsubscribe(_onModalUpdate);
    _appKitModal!.onModalNetworkChange.unsubscribe(_onModalNetworkChange);
    _appKitModal!.onModalDisconnect.unsubscribe(_onModalDisconnect);
    _appKitModal!.onModalError.unsubscribe(_onModalError);
    _appKitModal!.onSessionEventEvent.unsubscribe(_onSessionEvent);
    _appKitModal!.onSessionUpdateEvent.unsubscribe(_onSessionUpdate);

    _logManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pageDatas.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }
    final List<Widget> navRail = [];
    if (MediaQuery.of(context).size.width >= Constants.smallScreen) {
      navRail.add(_buildNavigationRail());
    }
    navRail.add(Expanded(child: _pageDatas[_selectedIndex].page));

    return Scaffold(
      appBar: AppBar(
        title: Text(_pageDatas[_selectedIndex].title),
        actions: [
          const Text('Relay '),
          CircleAvatar(
            radius: 6.0,
            backgroundColor: _appKit!.core.relayClient.isConnected
                ? Colors.green
                : Colors.red,
          ),
          const SizedBox(width: 16.0),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: Constants.smallScreen.toDouble(),
              ),
              child: Row(children: navRail),
            ),
          ),
          if (_showLogOverlay)
            StreamBuilder<List<String>>(
              stream: _logManager.logsStream,
              initialData: _logManager.logs,
              builder: (context, snapshot) {
                return LogOverlay(
                  logs: snapshot.data ?? [],
                  onClear: () => _logManager.clearLogs(),
                  onToggle: () => setState(() => _showLogOverlay = false),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationRail() {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      labelType: NavigationRailLabelType.selected,
      destinations: _pageDatas
          .map(
            (e) => NavigationRailDestination(
              icon: Icon(e.icon),
              label: Text(e.title),
            ),
          )
          .toList(),
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

  void _onModalUpdate(ModalConnect? event) {
    debugPrint('[ExampleApp] _onModalUpdate ${event?.session.toJson()}');
    setState(() {});
  }

  void _onModalNetworkChange(ModalNetworkChange? event) {
    debugPrint('[ExampleApp] _onModalNetworkChange ${event?.toString()}');
    setState(() {});
  }

  void _onModalDisconnect(ModalDisconnect? event) {
    debugPrint('[ExampleApp] _onModalDisconnect ${event?.toString()}');
    setState(() {});
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

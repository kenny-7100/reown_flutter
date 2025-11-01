import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:reown_appkit/reown_appkit.dart';
import 'package:reown_appkit_dapp/utils/constants.dart';
import 'package:reown_appkit_dapp/utils/crypto/helpers.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key, required this.appKitModal});

  final ReownAppKitModal appKitModal;

  @override
  ConnectPageState createState() => ConnectPageState();
}

class ConnectPageState extends State<ConnectPage> {
  final List<ReownAppKitModalNetworkInfo> _selectedChains = [];

  @override
  void initState() {
    super.initState();
    widget.appKitModal.onModalConnect.subscribe(_onModalConnect);
    widget.appKitModal.onModalUpdate.subscribe(_onModalUpdate);
    widget.appKitModal.onModalNetworkChange.subscribe(_onModalNetworkChange);
    widget.appKitModal.onModalDisconnect.subscribe(_onModalDisconnect);
    widget.appKitModal.onModalError.subscribe(_onModalError);
    widget.appKitModal.appKit!.onSessionConnect.subscribe(_onSessionConnect);
    widget.appKitModal.appKit!.onSessionAuthResponse.subscribe(
      _onSessionAuthResponse,
    );
    widget.appKitModal.onModalDisconnect.subscribe(_onModalDisconnect);
  }

  @override
  void dispose() {
    widget.appKitModal.onModalConnect.unsubscribe(_onModalConnect);
    widget.appKitModal.onModalUpdate.unsubscribe(_onModalUpdate);
    widget.appKitModal.onModalNetworkChange.unsubscribe(_onModalNetworkChange);
    widget.appKitModal.onModalDisconnect.unsubscribe(_onModalDisconnect);
    widget.appKitModal.onModalError.unsubscribe(_onModalError);
    widget.appKitModal.onModalDisconnect.unsubscribe(_onModalDisconnect);
    widget.appKitModal.appKit!.onSessionAuthResponse.unsubscribe(
      _onSessionAuthResponse,
    );
    widget.appKitModal.appKit!.onSessionConnect.unsubscribe(_onSessionConnect);
    super.dispose();
  }

  Future<void> _refreshData() async {
    try {
      await widget.appKitModal.reconnectRelay();
      final topic = widget.appKitModal.session!.topic ?? '';
      if (topic.isNotEmpty) {
        await widget.appKitModal.loadAccountData();
        widget.appKitModal.appKit!.ping(topic: topic);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    setState(() {});
    return;
  }

  @override
  Widget build(BuildContext context) {
    final modalTheme = ReownAppKitModalTheme.maybeOf(context);
    final isDarkMode = modalTheme?.isDarkMode ?? false;
    final themeColors = ReownAppKitModalTheme.colorsOf(context);
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Stack(
        children: [
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  color: isDarkMode
                      ? Colors.black.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
          ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: StyleConstants.linear16,
            ),
            children: <Widget>[
              const SizedBox(height: StyleConstants.linear16),
              const SizedBox(height: StyleConstants.linear8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppKitModalNetworkSelectButton(
                    appKit: widget.appKitModal,
                    size: BaseButtonSize.small,
                    closeAfterPick: true,
                  ),
                  const SizedBox.square(dimension: 8.0),
                  AppKitModalConnectButton(
                    appKit: widget.appKitModal,
                    size: BaseButtonSize.small,
                  ),
                ],
              ),
              Divider(color: themeColors.grayGlass010),
              const SizedBox(height: StyleConstants.linear8),
              Visibility(
                visible: widget.appKitModal.isConnected,
                child: Column(
                  children: [
                    AppKitModalAccountButton(appKitModal: widget.appKitModal),
                    const SizedBox.square(dimension: 8.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppKitModalBalanceButton(
                          appKitModal: widget.appKitModal,
                          onTap: widget.appKitModal.openModalView,
                        ),
                        const SizedBox.square(dimension: 8.0),
                        AppKitModalAddressButton(
                          appKitModal: widget.appKitModal,
                          onTap: widget.appKitModal.openModalView,
                        ),
                      ],
                    ),
                    const SizedBox.square(dimension: 8.0),
                    Text(
                      'Connected with ${widget.appKitModal.session?.connectedWalletName ?? 'Unknown wallet'}',
                    ),
                    const SizedBox.square(dimension: 8.0),
                    _SmartAccountButtons(appKitModal: widget.appKitModal),
                    const SizedBox.square(dimension: 8.0),
                    Text(
                      const JsonEncoder.withIndent(
                        '    ',
                      ).convert(widget.appKitModal.session?.toJson()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: StyleConstants.linear8),
            ],
          ),
        ],
      ),
    );
  }

  void _onSessionConnect(SessionConnect? event) async {
    if (event == null) return;
    setState(() => _selectedChains.clear());
  }

  void _onSessionAuthResponse(SessionAuthResponse? response) {
    if (response?.session != null) {
      setState(() => _selectedChains.clear());
    }
  }

  void _onModalConnect(ModalConnect? event) async {
    setState(() {});
  }

  void _onModalUpdate(ModalConnect? event) {
    setState(() {});
  }

  void _onModalNetworkChange(ModalNetworkChange? event) {
    setState(() {});
  }

  void _onModalDisconnect(ModalDisconnect? event) async {
    setState(() {});
  }

  void _onModalError(ModalError? event) {
    setState(() {});
  }
}

class _SmartAccountButtons extends StatefulWidget {
  final ReownAppKitModal appKitModal;
  const _SmartAccountButtons({required this.appKitModal});

  @override
  State<_SmartAccountButtons> createState() => __SmartAccountButtonsState();
}

class __SmartAccountButtonsState extends State<_SmartAccountButtons> {
  @override
  Widget build(BuildContext context) {
    final chainId = widget.appKitModal.selectedChain?.chainId ?? '';
    if (chainId.isEmpty) {
      return SizedBox.shrink();
    }
    final namespace = NamespaceUtils.getNamespaceFromChain(chainId);
    if (namespace != 'eip155') {
      return SizedBox.shrink();
    }

    return FutureBuilder<Widget>(
      future: contractCallsButton(widget.appKitModal, context),
      builder: (context, snapshot) {
        return snapshot.data ?? SizedBox.shrink();
      },
    );
  }
}

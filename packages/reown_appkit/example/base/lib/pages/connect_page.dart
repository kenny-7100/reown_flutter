import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';

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
    widget.appKitModal.appKit!.onSessionConnect.subscribe(_onSessionConnect);
    widget.appKitModal.appKit!.onSessionAuthResponse.subscribe(
      _onSessionAuthResponse,
    );
  }

  @override
  void dispose() {
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
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Column(
        children: [
          AppKitModalConnectButton(appKit: widget.appKitModal),
          Visibility(
            visible: widget.appKitModal.isConnected,
            child: AppKitModalAccountButton(appKitModal: widget.appKitModal),
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
}

import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key, required this.appKitModal});

  final ReownAppKitModal appKitModal;

  @override
  ConnectPageState createState() => ConnectPageState();
}

class ConnectPageState extends State<ConnectPage> {
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
}

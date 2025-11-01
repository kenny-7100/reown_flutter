import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key, required this.appKitModal});

  final ReownAppKitModal appKitModal;

  @override
  ConnectPageState createState() => ConnectPageState();
}

class ConnectPageState extends State<ConnectPage> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppKitModalConnectButton(appKit: widget.appKitModal),
        Visibility(
          visible: widget.appKitModal.isConnected,
          child: AppKitModalAccountButton(appKitModal: widget.appKitModal),
        ),
      ],
    );
  }
}

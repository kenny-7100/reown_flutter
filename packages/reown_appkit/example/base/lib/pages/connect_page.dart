import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';

class ConnectPage extends StatelessWidget {
  const ConnectPage({super.key, required this.appKitModal});

  final ReownAppKitModal appKitModal;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppKitModalConnectButton(appKit: appKitModal),
        AppKitModalAccountButton(appKitModal: appKitModal),
      ],
    );
  }
}

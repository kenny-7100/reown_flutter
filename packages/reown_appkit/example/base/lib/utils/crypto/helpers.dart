import 'package:reown_appkit_dapp/utils/crypto/solana.dart';

List<String> getChainMethods(String namespace) {
  switch (namespace) {
    case 'solana':
      return Solana.methods.values.toList();
    default:
      return [];
  }
}

List<String> getChainEvents(String namespace) {
  switch (namespace) {
    case 'solana':
      return Solana.events;
    default:
      return [];
  }
}

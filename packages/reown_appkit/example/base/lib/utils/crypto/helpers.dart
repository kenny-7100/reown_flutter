import 'package:reown_appkit/reown_appkit.dart';
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

Future<SessionRequestParams?> getParams(
  String method,
  String address,
  ReownAppKitModalNetworkInfo chainData, {
  String? callback,
}) async {
  switch (method) {
    case 'solana_signMessage':
      final message = Solana.personalSignMessage();
      return SessionRequestParams(
        method: method,
        params: {'pubkey': address, 'message': message},
      );
    case 'solana_signTransaction':
    case 'solana_signAndSendTransaction':
      final transactionV0_2 = await Solana.constructSolanaTX2(
        address,
        chainData,
      );
      final encodedV0Trx = Solana.serializeTransaction(transactionV0_2);

      return SessionRequestParams(
        method: method,
        params: {
          'transaction': encodedV0Trx,
          'pubkey': address,
          'feePayer': address,
          ...transactionV0_2.message.toJson(),
        },
      );
    case 'solana_signAllTransactions':
      final transactionV0_1 = await Solana.constructSolanaTX(
        address,
        chainData,
      );
      final transactionV0_2 = await Solana.constructSolanaTX2(
        address,
        chainData,
      );
      final encodedV0Trx_1 = Solana.serializeTransaction(transactionV0_1);
      final encodedV0Trx_2 = Solana.serializeTransaction(transactionV0_2);

      return SessionRequestParams(
        method: method,
        params: {
          'transactions': [encodedV0Trx_1, encodedV0Trx_2],
        },
      );
    default:
      return SessionRequestParams(method: method, params: null);
  }
}

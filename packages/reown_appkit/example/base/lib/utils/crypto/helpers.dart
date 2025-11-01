import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:reown_appkit_dapp/utils/crypto/solana.dart';
import 'package:reown_appkit_dapp/utils/smart_contracts.dart';
import 'package:reown_appkit_dapp/widgets/method_dialog.dart';

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

Future<Widget> contractCallsButton(
  ReownAppKitModal appKitModal,
  BuildContext context,
) async {
  late final SmartContract contract;
  late final dynamic Function() future;
  late final String title;
  //
  final chainId = appKitModal.selectedChain!.chainId;
  if (chainId == 'eip155:11155111') {
    title = 'Transfer 0.01 AAVE to Yourself';
    contract = SepoliaAAVEContract();
    future = _transferSmallValue(appKitModal, contract, 0.01);
  } else if (chainId == 'eip155:42161') {
    title = 'Transfer 2.0 USDC to Yourself';
    contract = ARBUSDCContract();
    // will trigger chain abstraction if needed
    future = _transferSmallValue(appKitModal, contract, 2.0);
  } else if (chainId == 'eip155:8453') {
    title = 'Transfer 2.0 USDC to Yourself';
    contract = BASEUSDCContract();
    // will trigger chain abstraction if needed
    future = _transferSmallValue(appKitModal, contract, 2.0);
  } else if (chainId == 'eip155:10') {
    title = 'Transfer 1 WCT to Yourself';
    contract = WCTOPETHContract();
    future = _transferSmallValue(appKitModal, contract, 1.0);
  } else if (chainId == 'eip155:1') {
    title = 'Transfer 0.01 USDT to Yourself';
    contract = ERC20USDTContract();
    future = _transferSmallValue(appKitModal, contract, 0.01);
  } else if (chainId == 'eip155:57054') {
    title = 'Transfer 0.01 wSONIC to Yourself';
    contract = WrappedSonicContract();
    future = _transferSmallValue(appKitModal, contract, 0.01);
  } else if (chainId == 'eip155:137') {
    title = 'Approve send BONSAI';
    contract = PolygonBONSAIContract();
    future = _approveSend(appKitModal, contract);
  } else {
    return SizedBox.shrink();
  }

  return Column(
    children: [
      Text(
        'Smart Contract interaction',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      FutureBuilder(
        future: _readSmartContract(
          appKitModal: appKitModal,
          contract: DeployedContract(
            ContractAbi.fromJson(
              jsonEncode(contract.contractABI),
              contract.name,
            ),
            EthereumAddress.fromHex(contract.contractAddress),
          ),
        ),
        builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
          return Text(jsonEncode(snapshot.data));
        },
      ),
      PrimaryButton(
        title: title,
        borderRadius: BorderRadius.all(Radius.circular(30.0)),
        buttonSize: BaseButtonSize.regular,
        onTap: () {
          MethodDialog.show(context, title, future.call());
        },
      ),
    ],
  );
}

dynamic Function() _transferSmallValue(
  ReownAppKitModal appKitModal,
  SmartContract smartContract,
  double transferValue,
) {
  return () async {
    //
    final deployedContract = DeployedContract(
      ContractAbi.fromJson(
        jsonEncode(smartContract.contractABI),
        smartContract.name,
      ),
      EthereumAddress.fromHex(smartContract.contractAddress),
    );

    // final transferValue = 0.01; //EtherAmount.fromInt(EtherUnit.finney, 11)
    // we first call `decimals` function, which is a read function,
    // to check how much decimal we need to use to parse the amount value
    final decimals = await appKitModal.requestReadContract(
      topic: appKitModal.session!.topic,
      chainId: appKitModal.selectedChain!.chainId,
      deployedContract: deployedContract,
      functionName: 'decimals',
    );

    final requestValue = _formatValue(
      transferValue,
      decimals: (decimals.first as BigInt),
    );
    // now we call `transfer` write function with the parsed value.
    final namespace = NamespaceUtils.getNamespaceFromChain(
      appKitModal.selectedChain!.chainId,
    );
    final senderAddress = appKitModal.session!.getAddress(namespace)!;
    return await appKitModal.requestWriteContract(
      topic: appKitModal.session!.topic,
      chainId: appKitModal.selectedChain!.chainId,
      deployedContract: deployedContract,
      functionName: 'transfer',
      transaction: Transaction(from: EthereumAddress.fromHex(senderAddress)),
      parameters: [
        // should be the recipient address
        EthereumAddress.fromHex(senderAddress),
        requestValue,
      ],
    );
  };
}

dynamic Function() _approveSend(
  ReownAppKitModal appKitModal,
  SmartContract smartContract,
) {
  //
  return () async {
    final deployedContract = DeployedContract(
      ContractAbi.fromJson(
        jsonEncode(smartContract.contractABI),
        smartContract.name,
      ),
      EthereumAddress.fromHex(smartContract.contractAddress),
    );

    final valueToApprove = 1;
    // we first call `decimals` function, which is a read function,
    // to check how much decimal we need to use to parse the amount value
    final decimals = await appKitModal.requestReadContract(
      topic: appKitModal.session!.topic,
      chainId: appKitModal.selectedChain!.chainId,
      deployedContract: deployedContract,
      functionName: 'decimals',
    );

    final requestValue = _formatValue(
      valueToApprove,
      decimals: (decimals.first as BigInt),
    );

    final namespace = NamespaceUtils.getNamespaceFromChain(
      appKitModal.selectedChain!.chainId,
    );
    final senderAddress = appKitModal.session!.getAddress(namespace)!;
    return await appKitModal.requestWriteContract(
      topic: appKitModal.session!.topic,
      chainId: appKitModal.selectedChain!.chainId,
      deployedContract: deployedContract,
      functionName: 'approve',
      transaction: Transaction(from: EthereumAddress.fromHex(senderAddress)),
      parameters: [
        // spender
        EthereumAddress.fromHex(senderAddress),
        // Amount to approve
        requestValue,
      ],
    );
  };
}

// --------
// payable function with no parameters such as:
// {
//   "inputs": [],
//   "name": "functionName",
//   "outputs": [],
//   "stateMutability": "payable",
//   "type": "function"
// },
// return appKitModal.requestWriteContract(
//   topic: appKitModal.session?.topic ?? '',
//   chainId: 'eip155:11155111',
//   rpcUrl: 'https://ethereum-sepolia.publicnode.com',
//   deployedContract: deployedContract,
//   functionName: 'functionName',
//   transaction: Transaction(
//     from: EthereumAddress.fromHex(appKitModal.session!.address!),
//     value: EtherAmount.fromInt(EtherUnit.finney, 1),
//   ),
//   parameters: [],
// );
// ------
// return await appKitModal.requestWriteContract(
//   topic: appKitModal.session?.topic ?? '',
//   chainId: 'eip155:11155111',
//   deployedContract: deployedContract,
//   functionName: 'subscribe',
//   parameters: [],
//   transaction: Transaction(
//     from: EthereumAddress.fromHex(appKitModal.session!.address!),
//     value: EtherAmount.fromInt(EtherUnit.finney, 1),
//   ),
// );
// ------

Future<dynamic> _readSmartContract({
  required ReownAppKitModal appKitModal,
  required DeployedContract contract,
}) async {
  final namespace = NamespaceUtils.getNamespaceFromChain(
    appKitModal.selectedChain!.chainId,
  );
  final results = await Future.wait([
    // results[0]
    appKitModal.requestReadContract(
      topic: appKitModal.session!.topic,
      chainId: appKitModal.selectedChain!.chainId,
      deployedContract: contract,
      functionName: 'name',
    ),
    // results[1]
    appKitModal.requestReadContract(
      topic: appKitModal.session!.topic,
      chainId: appKitModal.selectedChain!.chainId,
      deployedContract: contract,
      functionName: 'symbol',
    ),
    // results[2]
    appKitModal.requestReadContract(
      topic: appKitModal.session!.topic,
      chainId: appKitModal.selectedChain!.chainId,
      deployedContract: contract,
      functionName: 'balanceOf',
      parameters: [
        EthereumAddress.fromHex(appKitModal.session!.getAddress(namespace)!),
      ],
    ),
    // results[3]
    appKitModal.requestReadContract(
      topic: appKitModal.session!.topic,
      chainId: appKitModal.selectedChain!.chainId,
      deployedContract: contract,
      functionName: 'decimals',
    ),
  ]);

  //
  final name = (results[0].first as String);
  final symbol = (results[1].first as String);
  final decimals = results[3].first;
  final multiplier = _multiplier(decimals);
  final balance = (results[2].first as BigInt) / BigInt.from(multiplier);
  final formatter = NumberFormat('#,##0.00000', 'en_US');

  return {
    'name': name,
    'symbol': symbol,
    'decimals': '$decimals',
    'balanceOf': formatter.format(balance),
  };
}

BigInt _formatValue(num value, {required BigInt decimals}) {
  final multiplier = _multiplier(decimals);
  final result = EtherAmount.fromInt(
    EtherUnit.ether,
    (value * multiplier).toInt(),
  );
  return result.getInEther;
}

int _multiplier(BigInt decimals) {
  final d = decimals.toInt();
  final pad = '1'.padRight(d + 1, '0');
  return int.parse(pad);
}

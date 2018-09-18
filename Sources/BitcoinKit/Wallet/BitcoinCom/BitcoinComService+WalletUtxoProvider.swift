//
//  BitcoinComService+UtxoProvider.swift
//  BitcoinKit
//
//  Created by Shun Usami on 2018/09/18.
//  Copyright © 2018 BitcoinKit developers. All rights reserved.
//

import Foundation

extension BitcoinComService: UtxoProvider {
    // GET API: reload utxos
    public func reload(addresses: [Address], completion: (([UnspentTransaction]) -> Void)?) {
        let parameter: String = "[" + addresses.map { "\"\($0.cashaddr)\"" }.joined(separator: ",") + "]"
        let urlString = baseUrl + "address/utxo/\(parameter)"
        let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data else {
                print("data is nil.")
                completion?([])
                return
            }
            guard let response = try? JSONDecoder().decode([[BitcoinComUtxoModel]].self, from: data) else {
                print("decode failed.")
                completion?([])
                return
            }
            self?.userDefaults.set(data, forKey: UserDefaultsKey.utxos.rawValue)
            self?.userDefaults.synchronize()
            completion?(response.joined().asUtxos())
        }
        task.resume()
    }

    // List utxos
    public func list() -> [UnspentTransaction] {
        guard let data = userDefaults.data(forKey: UserDefaultsKey.utxos.rawValue) else {
            print("data is  nil")
            return []
        }

        guard let response = try? JSONDecoder().decode([[BitcoinComUtxoModel]].self, from: data) else {
            print("data cannot be decoded to response")
            return []
        }
        return response.joined().asUtxos()
    }
}

private extension Sequence where Element == BitcoinComUtxoModel {
    func asUtxos() -> [UnspentTransaction] {
        return compactMap { $0.asUtxo() }
    }
}

// MARK: - GET Unspent Transaction Outputs
private struct BitcoinComUtxoModel: Codable {
    let txid: String
    let vout: UInt32
    let scriptPubKey: String
    let amount: Decimal
    let satoshis: UInt64
    let height: Int?
    let confirmations: Int
    let legacyAddress: String
    let cashAddress: String

    func asUtxo() -> UnspentTransaction? {
        guard let lockingScript = Data(hex: scriptPubKey), let txidData = Data(hex: String(txid)) else { return nil }
        let txHash: Data = Data(txidData.reversed())
        let output = TransactionOutput(value: satoshis, lockingScript: lockingScript)
        let outpoint = TransactionOutPoint(hash: txHash, index: vout)
        return UnspentTransaction(output: output, outpoint: outpoint)
    }
}

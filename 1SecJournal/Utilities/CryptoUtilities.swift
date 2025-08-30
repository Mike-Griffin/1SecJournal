//
//  CryptoUtilities.swift
//  1SecJournal
//
//  Created by Mike Griffin on 8/23/25.
//

import CryptoKit
import Foundation

func randomNonce(_ length: Int = 32) -> String {
  precondition(length > 0)
  let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
  var result = ""
  var remaining = length
  while remaining > 0 {
    var random: UInt8 = 0
    let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
    guard status == errSecSuccess else { fatalError("Unable to generate nonce.") }
    if random < charset.count {
      result.append(charset[Int(random)])
      remaining -= 1
    }
  }
  return result
}

func sha256(_ input: String) -> String {
  let hash = SHA256.hash(data: Data(input.utf8))
  return hash.map { String(format: "%02x", $0) }.joined()
}

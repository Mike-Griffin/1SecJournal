//
//  SignInWithAppView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 8/23/25.
//

import SwiftUI
import AuthenticationServices

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userId: String?
    
    fileprivate var currentNonce: String?
    
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        guard
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8),
            let rawNonce = currentNonce
        else {
            self.errorMessage = "Missing Apple identity token."
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        // TODO: Supabase integration
        
        //    do {
        //      let session = try await Supa.client.auth.signInWithIdToken(
        //        credentials: .init(provider: .apple, idToken: idToken, nonce: rawNonce)
        //      )
        //      self.userId = session.user.id
        //      self.errorMessage = nil
        //    } catch {
        //      self.errorMessage = "Sign-in failed: \(error.localizedDescription)"
        //    }
        //  }
    }
    
    struct SignInWithAppleButtonView: View {
        @StateObject private var vm = AuthViewModel()
        
        var body: some View {
            VStack(spacing: 16) {
                SignInWithAppleButton(.signIn) { request in
                    // Ask for what you need (email/fullName only available the first time)
                    request.requestedScopes = [.fullName, .email]
                    
                    // Nonce: send **hashed** to Apple, keep **raw** to send to Supabase
                    let raw = randomNonce()
                    vm.currentNonce = raw
                    request.nonce = sha256(raw)
                } onCompletion: { result in
                    switch result {
                    case .success(let auth):
                        if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                            Task { await vm.signInWithApple(credential: credential) }
                        } else {
                            vm.errorMessage = "Unexpected credential type."
                        }
                    case .failure(let error):
                        vm.errorMessage = "Apple sign-in canceled or failed: \(error.localizedDescription)"
                    }
                }
                .signInWithAppleButtonStyle(.black) // or .white / .whiteOutline
                .frame(height: 48)
                .disabled(vm.isLoading)
                
                if vm.isLoading { ProgressView() }
                
                if let userId = vm.userId {
                    Text("Signed in • \(userId)").font(.footnote).foregroundStyle(.secondary)
                }
                
                if let err = vm.errorMessage {
                    Text(err).font(.footnote).foregroundStyle(.red)
                }
            }
            .padding()
        }
    }
}

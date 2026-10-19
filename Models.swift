


import SwiftUI
import SwiftData
import LocalAuthentication

@main
struct NSNFarmsApp: App {
    let container: ModelContainer
    @State private var backupManager = BackupManager()
    @State private var isUnlocked = false
    
    init() {
        do {
            self.container = try NSNDatabase.createOfflineContainer()
        } catch {
            fatalError("Failed to initialize offline container: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isUnlocked {
                    MainTabView()
                        .environment(backupManager)
                        .modelContainer(container)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "tree.fill").font(.system(size: 64)).foregroundColor(NSNTheme.forestGreen)
                        Text("NSN Farms").font(.largeTitle).fontWeight(.bold)
                        Button("Unlock with Biometrics") {
                            authenticate()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .onAppear { authenticate() }
                }
            }
        }
    }
    
    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock NSN Farms") { success, _ in
                DispatchQueue.main.async { if success { isUnlocked = true } }
            }
        } else {
            isUnlocked = true
        }
    }
}
NSN_Farms_App_Entry_Point.swift
Displaying NSN_Farms_App_Entry_Point.swift.

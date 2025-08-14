import SwiftUI
import WebKit
import CoreBluetooth

struct ContentView: View {
    @StateObject private var bt = BluetoothManager()
    @StateObject private var appState = AppState()
    var body: some View {
        HStack(spacing: 0) {
            if appState.showingMenu {
            VStack(alignment: .leading, spacing: 12) {
                // Google menu
                VStack(alignment: .leading, spacing: 10) {
                    Text("Google")
                        .font(.headline)
                        .padding(.horizontal, 8)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 12) {
                        ForEach(GoogleService.allCases) { service in
                            Button(action: { appState.selectedService = service }) {
                                VStack(spacing: 6) {
                                    Image(systemName: service.symbolName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 28, height: 28)
                                        .foregroundColor(service.tintColor)
                                    Text(service.displayName)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(appState.selectedService == service ? service.tintColor.opacity(0.12) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(appState.selectedService == service ? service.tintColor : Color.secondary.opacity(0.2), lineWidth: appState.selectedService == service ? 1.2 : 0.8)
                                )
                            }
                            .buttonStyle(.plain)
                            .help(service.displayName)
                        }
                    }
                    Divider()
                    if !appState.isLoggedIn {
                        Button("Sign in") { appState.selectedService = .gmail }
                    } else {
                        Text("Signed in").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Divider()
                HStack {
                    Text("Bluetooth")
                        .font(.headline)
                    Spacer()
                    if bt.isPoweredOn {
                        Button(bt.isScanning ? "Stop" : "Scan") {
                            bt.isScanning ? bt.stopScanning() : bt.startScanning()
                        }
                    } else {
                        Text("Bluetooth off").foregroundStyle(.secondary)
                    }
                }
                List(bt.devices) { device in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.name)
                            Text(device.id.uuidString).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("RSSI \(device.rssi)").foregroundStyle(.secondary)
                        Button("Connect") { bt.connect(to: device) }
                    }
                }
                .frame(minWidth: 280)
            }
            Divider()
            }
            VStack(spacing: 0) {
                HStack {
                    if !appState.showingMenu {
                        Button {
                            withAnimation { appState.showingMenu = true }
                        } label: {
                            Label("Menu", systemImage: "chevron.left")
                        }
                        .buttonStyle(.borderless)
                    }
                    Button {
                        NSApp.keyWindow?.toggleFullScreen(nil)
                    } label: {
                        Label("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                }
                .padding(8)
                GmailWebView(url: appState.selectedService.url)
                    .ignoresSafeArea()
                    .onAppear { withAnimation { appState.showingMenu = false } }
            }
        }
        .onAppear { appState.refreshLoginStatus() }
    }
}

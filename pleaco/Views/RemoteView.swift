//
//  RemoteView.swift
//  pleaco
//

import SwiftUI

struct RemoteView: View {
    @StateObject private var remote = RemoteManager.shared
    @State private var joinCode: String = ""
    @State private var showServerConfig = false

    private let cardHeight: CGFloat = 72

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 1. Remote Session
                remoteSection

                // 2. Manual Control (only when connected)
                if remote.state == .connected {
                    TouchControlView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 24)
            .padding(.bottom, 60)
        }
        .background(Color.surfacePrimary)
    }

    // MARK: - Remote Section

    private var remoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Remote", icon: "antenna.radiowaves.left.and.right")

            switch remote.state {
            case .disconnected:
                disconnectedCard
            case .hosting:
                hostingCard
            case .joining:
                joiningCard
            case .connected:
                connectedCards
            }

            serverConfigToggle
        }
    }

    // MARK: - Disconnected

    private var disconnectedCard: some View {
        VStack(spacing: 12) {
            Button {
                remote.hostSession()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Session")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(ProminentButtonStyle())

            Text("or")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("Enter Code", text: $joinCode)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(12)
                .appCardStyle()
                .onChange(of: joinCode) { newValue in
                    joinCode = String(newValue.uppercased().prefix(6))
                }

            Button {
                remote.joinSession(code: joinCode)
            } label: {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Join Session")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(ProminentButtonStyle())
            .disabled(joinCode.count != 6)
        }
    }

    // MARK: - Hosting

    private var hostingCard: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                Text("Your Code")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(remote.roomCode.isEmpty ? "..." : remote.roomCode)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.appAccent)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .appCardStyle()

            HStack(spacing: 8) {
                ProgressView()
                Text("Waiting for partner...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            cancelButton
        }
    }

    // MARK: - Joining

    private var joiningCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ProgressView()
                Text("Connecting...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .appCardStyle()

            cancelButton
        }
    }

    // MARK: - Connected

    private var connectedCards: some View {
        VStack(spacing: 12) {
            // Status
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Partner connected")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: cardHeight)
            .appCardStyle()

            // Incoming
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.subheadline)
                        .foregroundColor(Color.appAccent)
                    Text("Incoming")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(Int(remote.incomingLevel))%")
                    .font(.system(size: 20, weight: .bold).monospacedDigit())
                    .foregroundColor(Color.appAccent)
            }
            .frame(maxWidth: .infinity, minHeight: cardHeight)
            .padding(.horizontal, 16)
            .appCardStyle()

            // Disconnect
            Button {
                remote.disconnect()
            } label: {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("Disconnect")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, minHeight: cardHeight)
            }
            .buttonStyle(SecondaryButtonStyle(isDestructive: true))
        }
    }

    // MARK: - Shared Components

    private var cancelButton: some View {
        Button {
            remote.disconnect()
        } label: {
            Text("Cancel")
        }
        .buttonStyle(SecondaryButtonStyle(isDestructive: true))
    }

    private var serverConfigToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { showServerConfig.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "server.rack")
                        .font(.caption)
                    Text("Server")
                        .font(.caption)
                    Image(systemName: showServerConfig ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            if showServerConfig {
                TextField("wss://pleaco.shelf.am", text: $remote.serverAddress)
                    .font(.system(size: 14, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .appCardStyle()
            }
        }
    }
}

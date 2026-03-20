//
//  RemoteView.swift
//  pleaco
//

import SwiftUI

struct RemoteView: View {
    @ObservedObject private var remote = RemoteManager.shared
    @State private var joinCode: String = ""
    @State private var showServerConfig = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 1. Remote Session
                remoteSection

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
            SectionHeader(title: "Remote Session", icon: "antenna.radiowaves.left.and.right")

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
            // Join Input Field (Premium Style)
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .foregroundColor(Color.appAccent)
                        .font(.system(size: 18))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.appAccent.opacity(0.1)))

                    TextField("6-DIGIT CODE", text: $joinCode)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: joinCode) { old, newValue in
                            joinCode = String(newValue.uppercased().prefix(6))
                        }
                }
                .padding(12)
                .appCardStyle()
            }
            
            // Action Buttons Row
            HStack(spacing: 12) {
                // Create Button
                Button {
                    remote.hostSession()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create")
                    }
                    .foregroundColor(.appAccent)
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    remote.joinSession(code: joinCode)
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Join")
                    }
                }
                .buttonStyle(ProminentButtonStyle())
                .disabled(joinCode.count != 6)
                .opacity(joinCode.count == 6 ? 1.0 : 0.5)
            }
        }
    }

    // MARK: - Hosting

    private var hostingCard: some View {
        VStack(spacing: 12) {
            VStack(spacing: 16) {
                Text("YOUR CODE")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(Color.appAccent.opacity(0.8))

                Text(remote.roomCode.isEmpty ? "..." : remote.roomCode)
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .foregroundColor(Color.appAccent)
                    .textSelection(.enabled)
                    .shadow(color: Color.appAccent.opacity(0.15), radius: 8)
                
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Color.appAccent.opacity(0.8))
                        .scaleEffect(0.8)
                    Text("WAITING FOR PARTNER...")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .appCardStyle()

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
            // Status Indicator (Active Branding)
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 24, height: 24)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.white.opacity(0.5), radius: 4)
                }
                
                Text("Partner connected")
                    .font(.subheadline.bold())
                
                if !remote.partnerDevice.isEmpty && remote.partnerDevice != "No Device" {
                    Text("(\(remote.partnerDevice))")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .appCardStyle(isSelected: true)
            .foregroundColor(.white)

            // Role Selection (Premium Picker) - Now only visible when connected
            HStack(spacing: 8) {
                ForEach(RemoteRole.allCases) { role in
                    Button {
                        remote.role = role
                    } label: {
                        Text(role.rawValue)
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                                    .fill(remote.role == role ? AnyShapeStyle(LinearGradient.accentGradient) : AnyShapeStyle(Color.clear))
                            )
                            .foregroundColor(remote.role == role ? .white : .secondary)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(4)
            .appCardStyle()

            // Incoming Activity Card
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "hand.tap.fill")
                        .font(.subheadline)
                        .foregroundColor(Color.appAccent)
                    Text("Incoming Signal")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(Int(remote.incomingLevel))%")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.appAccent)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .appCardStyle(isSelected: false)

            if remote.role == .sender {
                // Info for Sender
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                    Text("You are controlling your partner's device.")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.top, 4)
            } else if remote.role == .receiver {
                // Info for Receiver
                HStack(spacing: 8) {
                    Image(systemName: "hand.raised.fill")
                        .font(.caption)
                    Text("Local control is locked. Waiting for partner signal.")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.top, 4)
            }

            // Disconnect Button
            Button {
                remote.disconnect()
            } label: {
                Text("Disconnect Session")
                    .foregroundColor(.appAccent)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    // MARK: - Shared Components

    private var cancelButton: some View {
        Button {
            remote.disconnect()
        } label: {
            Text("Cancel")
                .foregroundColor(.appAccent)
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    private var serverConfigToggle: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Server", icon: "server.rack")
            
            TextField("wss://pleaco.shelf.am", text: $remote.serverAddress)
                .font(.system(size: 14, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .appCardStyle()
        }
        .padding(.top, 16)
    }
}

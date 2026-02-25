import SwiftUI
import Combine

struct SettingsView: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @State private var showingAddEditor = false
    @State private var deviceToEdit: SavedDevice? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    devicesSection

                    playbackSection
                }
                .padding(.vertical, 8)
                .padding(.bottom, 60)
            }
            .scrollClipDisabled()
            .background(Color.surfacePrimary)
            .navigationTitle("Einstellungen")
            .sheet(isPresented: $showingAddEditor) {
                DeviceEditorSheet(deviceManager: deviceManager, editingDevice: nil)
            }
            .sheet(item: $deviceToEdit) { device in
                DeviceEditorSheet(deviceManager: deviceManager, editingDevice: device)
            }
        }
    }

    // MARK: – Devices Section

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(title: "Geräte", icon: "cable.connector")
                Spacer()
                Button {
                    showingAddEditor = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text("Hinzufügen")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(Color.appAccent)
                }
            }
            .padding(.horizontal)

            DeviceCard(device: deviceManager.internalDevice) { }

            ForEach(deviceManager.devices) { device in
                DeviceCard(device: device) {
                    deviceToEdit = device
                }
            }
        }
    }

    // MARK: – Playback Section

    private var playbackSection: some View {
        SettingsSectionCard(title: "Wiedergabe", icon: "gauge.with.needle") {
            VStack(spacing: 16) {
                HStack {
                    Text("Standard-Intensität")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(deviceManager.defaultIntensity))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }

                Slider(value: $deviceManager.defaultIntensity, in: 1...100, step: 1)
                    .tint(Color.appAccent)
            }
        }
    }
}

// MARK: – Settings Section Card

struct SettingsSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: title, icon: icon)
                .padding(.horizontal)

            VStack(spacing: 0) {
                content
                    .padding(20)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                    )
            )
            .padding(.horizontal)
        }
    }
}

// MARK: – Device Card

struct DeviceCard: View {
    @ObservedObject var device: SavedDevice
    @ObservedObject var deviceManager = DeviceManager.shared
    var onEdit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            deviceManager.activeDeviceId == device.id
                                ? AnyShapeStyle(Color.white.opacity(0.15))
                                : AnyShapeStyle(Color.surfaceSecondary)
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: device.type.icon)
                        .font(.title3)
                        .foregroundColor(deviceManager.activeDeviceId == device.id ? .white : Color.appAccent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundColor(deviceManager.activeDeviceId == device.id ? .white : .primary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(deviceManager.activeDeviceId == device.id ? Color.white : (device.isConnected ? Color.appAccent.opacity(0.85) : Color.gray))
                            .frame(width: 6, height: 6)

                        Text(device.type.rawValue)
                            .font(.caption)
                            .foregroundColor(deviceManager.activeDeviceId == device.id ? .white.opacity(0.8) : .secondary)
                    }
                }

                Spacer()

                if device.type != .internal {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(deviceManager.activeDeviceId == device.id ? .white : Color.appAccent)
                            .padding(8)
                            .background(Circle().fill(deviceManager.activeDeviceId == device.id ? Color.white.opacity(0.2) : Color.surfaceSecondary))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    deviceManager.setActiveDevice(device)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(deviceManager.activeDeviceId == device.id ? AnyShapeStyle(LinearGradient.accentGradient) : AnyShapeStyle(Color.cardBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(deviceManager.activeDeviceId == device.id ? Color.white.opacity(0.12) : Color.subtleBorder, lineWidth: 0.5)
                )
        )
        .padding(.horizontal)
        .shadow(
            color: deviceManager.activeDeviceId == device.id ? Color.glowAccent : .black.opacity(0.05),
            radius: deviceManager.activeDeviceId == device.id ? 10 : 3,
            x: 0,
            y: deviceManager.activeDeviceId == device.id ? 5 : 2
        )
        .animation(.easeInOut(duration: 0.2), value: deviceManager.activeDeviceId)
        .animation(.easeInOut(duration: 0.2), value: device.isConnected)
    }
}

// MARK: – Device Editor Sheet

struct DeviceEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var deviceManager: DeviceManager

    let editingDevice: SavedDevice?

    @State private var deviceName = ""
    @State private var deviceType: DeviceType = .handy
    @State private var connectionKey = ""
    @State private var serverAddress = "ws://127.0.0.1:12345"

    init(deviceManager: DeviceManager, editingDevice: SavedDevice?) {
        self.deviceManager = deviceManager
        self.editingDevice = editingDevice

        _deviceName = State(initialValue: editingDevice?.name ?? "")
        _deviceType = State(initialValue: editingDevice?.type ?? .handy)
        _connectionKey = State(initialValue: editingDevice?.connectionKey ?? "")
        _serverAddress = State(initialValue: editingDevice?.serverAddress ?? "ws://127.0.0.1:12345")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    if editingDevice == nil {
                        Picker("Typ", selection: $deviceType) {
                            ForEach([DeviceType.handy, .oh, .intiface, .lovespouse], id: \.self) { type in
                                HStack {
                                    Image(systemName: type.icon)
                                    Text(type.rawValue)
                                }
                                .tag(type)
                            }
                        }
                    } else {
                        LabeledContent("Typ", value: deviceType.rawValue)
                    }

                    TextField("Gerätename", text: $deviceName)
                }

                if deviceType == .handy || deviceType == .oh {
                    Section("Verbindung") {
                        SecureField("Verbindungsschlüssel", text: $connectionKey)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("So findest du deinen Verbindungsschlüssel:")
                                .font(.caption)
                                .fontWeight(.semibold)

                            Text("1. Öffne die \(deviceType.rawValue) App\n2. Gehe zu Einstellungen › Verbindungsschlüssel\n3. Kopiere den Schlüssel")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } else if deviceType == .intiface {
                    Section("Server") {
                        TextField("WebSocket-Adresse", text: $serverAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()

                        Text("Standard: ws://127.0.0.1:12345")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if deviceType == .lovespouse {
                    Section("Bluetooth") {
                        Label("Direktverbindung via BLE", systemImage: "dot.radiowaves.left.and.right")
                            .foregroundColor(.accentColor)

                        Text("Pleaco sendet BLE-Advertisement-Pakete direkt vom iPhone ans Toy – genau wie die offizielle App. Kein Gateway nötig. Die App muss dafür im Vordergrund laufen.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    }
                }

                if let device = editingDevice {
                    Section {
                        Button(role: .destructive) {
                            deviceManager.removeDevice(device)
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Gerät löschen")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.surfacePrimary)
            .onAppear {
                if let device = editingDevice {
                    deviceName = device.name
                    deviceType = device.type
                    connectionKey = device.connectionKey
                    serverAddress = device.serverAddress
                }
            }
            .navigationTitle(editingDevice == nil ? "Gerät hinzufügen" : "Gerät bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveDevice()
                    }
                    .disabled((deviceType == .handy || deviceType == .oh) && connectionKey.isEmpty)
                    .tint(Color.appAccent)
                }
            }
        }
    }

    private func saveDevice() {
        if let device = editingDevice {
            device.name = deviceName.isEmpty ? device.name : deviceName
            device.connectionKey = connectionKey
            device.serverAddress = serverAddress

            deviceManager.objectWillChange.send()
            deviceManager.saveDevices()

            if deviceManager.activeDeviceId == device.id {
                deviceManager.setActiveDevice(device)
            }
        } else {
            let newDevice = SavedDevice(
                id: UUID(),
                name: deviceName.isEmpty ? "Neues \(deviceType.rawValue)" : deviceName,
                type: deviceType,
                connectionKey: connectionKey,
                serverAddress: serverAddress
            )
            deviceManager.addDevice(newDevice)
        }
        dismiss()
    }
}

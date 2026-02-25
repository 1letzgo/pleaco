import SwiftUI
import Combine

struct SettingsView: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @State private var showingDeviceEditor = false
    @State private var editingDevice: SavedDevice? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    devicesSection
                    
                    audioSection
                    
                    playbackSection
                }
                .padding(.vertical, 8)
                .padding(.bottom, 60)
            }
            .scrollClipDisabled()
            .background(Color.surfacePrimary)
            .navigationTitle("Settings")
            .sheet(isPresented: $showingDeviceEditor) {
                DeviceEditorSheet(deviceManager: deviceManager, editingDevice: editingDevice)
            }
        }
    }
    
    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(title: "Devices", icon: "cable.connector")
                Spacer()
                Button {
                    editingDevice = nil
                    showingDeviceEditor = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text("Add")
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
                    editingDevice = device
                    showingDeviceEditor = true
                }
            }
        }
    }
    
    private var audioSection: some View {
        SettingsSectionCard(title: "Audio", icon: "mic.fill") {
            VStack(spacing: 16) {
                HStack {
                    Text("Microphone Sensitivity")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(deviceManager.audioSensitivity * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }

                Slider(value: $deviceManager.audioSensitivity, in: 0.1...3.0, step: 0.1)
                    .tint(Color.appAccent)
            }
        }
    }
    
    private var playbackSection: some View {
        SettingsSectionCard(title: "Playback", icon: "gauge.with.needle") {
            VStack(spacing: 16) {
                HStack {
                    Text("Default Intensity")
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
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                    )
            )
            .padding(.horizontal)
        }
    }
}

struct DeviceCard: View {
    @ObservedObject var device: SavedDevice
    @ObservedObject var deviceManager = DeviceManager.shared
    var onEdit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            deviceManager.activeDeviceId == device.id
                                ? AnyShapeStyle(LinearGradient.accentGradient)
                                : AnyShapeStyle(Color.cardBackground)
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: device.type.icon)
                        .font(.title3)
                        .foregroundColor(deviceManager.activeDeviceId == device.id ? .white : .primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.headline)

                    HStack(spacing: 4) {
                        Text(device.type.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(device.isConnected ? Color.green : Color.gray)
                                .frame(width: 6, height: 6)
                            
                            Text(device.isConnected ? "Connected" : "Disconnected")
                                .font(.caption)
                                .foregroundColor(device.isConnected ? .green : .secondary)
                        }
                    }
                }

                Spacer()

                if deviceManager.activeDeviceId == device.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    deviceManager.setActiveDevice(device)
                }
            }

            if device.type != .internal {
                Divider()
                    .padding(.leading, 82)

                HStack(spacing: 0) {
                    Button {
                        if device.isConnected {
                            device.isConnected = false
                            deviceManager.objectWillChange.send()
                        } else {
                            deviceManager.setActiveDevice(device)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: device.isConnected ? "xmark.circle" : "link")
                            Text(device.isConnected ? "Disconnect" : "Connect")
                        }
                        .font(.subheadline)
                        .foregroundColor(device.isConnected ? .red : .accentColor)
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.96))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)

                    Divider()
                        .frame(height: 20)

                    Button(action: onEdit) {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.96))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                )
        )
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: device.isConnected)
    }
}

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
                        Picker("Type", selection: $deviceType) {
                            ForEach([DeviceType.handy, .oh, .intiface], id: \.self) { type in
                                HStack {
                                    Image(systemName: type.icon)
                                    Text(type.rawValue)
                                }
                                .tag(type)
                            }
                        }
                    } else {
                        LabeledContent("Type", value: deviceType.rawValue)
                    }

                    TextField("Device Name", text: $deviceName)
                }

                if deviceType == .handy || deviceType == .oh {
                    Section("Connection") {
                        SecureField("Connection Key", text: $connectionKey)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("How to get your connection key:")
                                .font(.caption)
                                .fontWeight(.semibold)

                            Text("1. Open the \(deviceType.rawValue) app\n2. Go to Settings > Connection Key\n3. Copy the key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } else if deviceType == .intiface {
                    Section("Server") {
                        TextField("WebSocket Address", text: $serverAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()

                        Text("Default: ws://127.0.0.1:12345")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                                Text("Delete Device")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.surfacePrimary)
            .navigationTitle(editingDevice == nil ? "Add Device" : "Edit Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveDevice()
                    }
                    .disabled(deviceType != .intiface && connectionKey.isEmpty)
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
                name: deviceName.isEmpty ? "New \(deviceType.rawValue)" : deviceName,
                type: deviceType,
                connectionKey: connectionKey,
                serverAddress: serverAddress
            )
            deviceManager.addDevice(newDevice)
        }
        dismiss()
    }
}

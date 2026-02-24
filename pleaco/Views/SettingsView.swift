import SwiftUI
import Combine

struct SettingsView: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @State private var showingDeviceEditor = false
    @State private var editingDevice: SavedDevice? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Devices Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Devices", systemImage: "cable.connector")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button {
                                editingDevice = nil
                                showingDeviceEditor = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(Color.accentColor)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Internal Haptics
                        DeviceCard(device: deviceManager.internalDevice) {
                            // Internal device cannot be edited
                        }
                        
                        // External Devices
                        ForEach(deviceManager.devices) { device in
                            DeviceCard(device: device) {
                                editingDevice = device
                                showingDeviceEditor = true
                            }
                        }
                    }
                    
                    // Audio Section
                    SettingsSectionCard(title: "Audio", icon: "mic.fill") {
                        HStack {
                            Text("Microphone Sensitivity")
                            Spacer()
                            Text("\(Int(deviceManager.audioSensitivity * 100))%")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        
                        Slider(value: $deviceManager.audioSensitivity, in: 0.1...3.0, step: 0.1)
                            .tint(Color.accentColor)
                    }
                    
                    // Playback Section
                    SettingsSectionCard(title: "Playback", icon: "gauge.with.needle") {
                        HStack {
                            Text("Default Intensity")
                            Spacer()
                            Text("\(Int(deviceManager.defaultIntensity))%")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        
                        Slider(value: $deviceManager.defaultIntensity, in: 1...100, step: 1)
                            .tint(Color.accentColor)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.appBackground)
            .navigationTitle("Settings")
            .sheet(isPresented: $showingDeviceEditor) {
                DeviceEditorSheet(deviceManager: deviceManager, editingDevice: editingDevice)
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
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                content
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.appContrast.opacity(0.05))
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
                Image(systemName: device.type.icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(deviceManager.activeDeviceId == device.id ? Color.accentColor : Color.appContrast.opacity(0.3))
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        Text(device.type.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if device.isConnected {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("Connected")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("Disconnected")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
                
                if deviceManager.activeDeviceId == device.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                }
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture {
                deviceManager.setActiveDevice(device)
            }
            
            if device.type != .internal {
                Divider()
                    .padding(.leading, 76)
                
                HStack {
                    Spacer()
                    
                    Button {
                        if device.isConnected {
                            device.isConnected = false
                            deviceManager.objectWillChange.send()
                        } else {
                            deviceManager.setActiveDevice(device)
                        }
                    } label: {
                        Label(device.isConnected ? "Disconnect" : "Connect", systemImage: device.isConnected ? "xmark.circle" : "link")
                            .font(.subheadline)
                            .foregroundColor(device.isConnected ? .red : .accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    
                    Divider()
                        .frame(height: 20)
                    
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appContrast.opacity(0.05))
        )
        .padding(.horizontal)
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
                                .fontWeight(.medium)
                            
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
            .background(Color.appBackground)
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
            
            // Force manager to update and save
            deviceManager.objectWillChange.send()
            deviceManager.saveDevices()
            
            // If we're editing the active device, re-apply settings
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

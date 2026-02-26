import SwiftUI
import Combine

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
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
                .padding(.top, 32)
                .padding(.bottom, 60)
            }
            .scrollClipDisabled()
            .background(Color.surfacePrimary)
            .sheet(isPresented: $showingAddEditor) {
                DeviceEditorSheet(deviceManager: deviceManager, editingDevice: nil)
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $deviceToEdit) { device in
                DeviceEditorSheet(deviceManager: deviceManager, editingDevice: device)
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: – Devices Section

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Devices", icon: "cable.connector")
                Spacer()
                Button {
                    showingAddEditor = true
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
            .padding(.horizontal, 18)

            DeviceCard(device: deviceManager.internalDevice, onEdit: { }) {
                dismiss()
            }

            ForEach(deviceManager.devices) { device in
                DeviceCard(device: device, onEdit: {
                    deviceToEdit = device
                }) {
                    dismiss()
                }
            }
        }
    }

    // MARK: – Playback Section

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
                .padding(.horizontal, 18)

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
            .padding(.horizontal, 18)
        }
    }
}

// MARK: – Device Card

struct DeviceCard: View {
    @ObservedObject var device: SavedDevice
    @ObservedObject var deviceManager = DeviceManager.shared
    var onEdit: () -> Void
    var onSelect: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            deviceManager.activeDeviceId == device.id
                                ? AnyShapeStyle(Color.white.opacity(0.15))
                                : AnyShapeStyle(Color.surfaceSecondary)
                        )
                        .frame(width: 38, height: 38)

                    Image(systemName: device.type.icon)
                        .font(.system(size: 14))
                        .foregroundColor(deviceManager.activeDeviceId == device.id ? .white : Color.appAccent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(device.name) (\(device.type.rawValue))")
                        .font(.subheadline.bold())
                        .foregroundColor(deviceManager.activeDeviceId == device.id ? .white : .primary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(deviceManager.activeDeviceId == device.id ? Color.white.opacity(0.8) : (device.isConnected ? Color.appAccent.opacity(0.85) : Color.gray))
                            .frame(width: 5, height: 5)

                        Text(device.isConnected ? "Verbunden" : "Nicht verbunden")
                            .font(.system(size: 11))
                            .foregroundColor(deviceManager.activeDeviceId == device.id ? .white.opacity(0.7) : .secondary)
                    }
                }

                Spacer()

                if device.type != .internal {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(deviceManager.activeDeviceId == device.id ? .white : Color.appAccent)
                            .padding(6)
                            .background(Circle().fill(deviceManager.activeDeviceId == device.id ? Color.white.opacity(0.2) : Color.surfaceSecondary))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    deviceManager.setActiveDevice(device)
                    onSelect()
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
        .padding(.horizontal, 18)
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
                        Picker("Type", selection: $deviceType) {
                            ForEach([DeviceType.handy, .oh, .intiface, .lovespouse, .ossm], id: \.self) { type in
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
                            Text("Here's how to find your connection key:")
                                .font(.caption)
                                .fontWeight(.semibold)

                            Text("1. Open the \(deviceType.rawValue) App\n2. Go to Settings › Connection Key\n3. Copy the key")
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
                } else if deviceType == .lovespouse || deviceType == .ossm {
                    Section("Bluetooth") {
                        Label("Direct connection via BLE", systemImage: "dot.radiowaves.left.and.right")
                            .foregroundColor(.accentColor)

                        let helpText = deviceType == .lovespouse 
                            ? "Pleaco sends BLE advertisement packets directly from the iPhone to the toy - just like the official app. No gateway needed. The app must run in the foreground."
                            : "Pleaco connects directly to your OSSM over Bluetooth Low Energy. The device must be in Bluetooth mode."

                        Text(helpText)
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
                                Text("Delete Device")
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

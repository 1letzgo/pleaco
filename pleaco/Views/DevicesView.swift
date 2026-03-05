import SwiftUI
import Combine

struct DevicesView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var deviceManager = DeviceManager.shared
    @State private var showingAddEditor = false
    @State private var deviceToEdit: SavedDevice? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                devicesSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 24)
            .padding(.bottom, 60)
        }
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

    // MARK: – Devices Section

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "Devices", icon: "cable.connector")
                Spacer()
                Button {
                    showingAddEditor = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundColor(Color.appAccent)
                }
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
            LazyVGrid(columns: columns, spacing: 12) {
                if deviceManager.internalDevice.type.isSupported {
                    DeviceCard(device: deviceManager.internalDevice, onEdit: { }) {
                        dismiss()
                    }
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
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, icon: icon)
                .padding(.horizontal, 4)

            content
                .padding(16)
                .appCardStyle()
        }
        .padding(.horizontal, 18)
    }
}

// MARK: – Device Card

struct DeviceCard: View {
    @ObservedObject var device: SavedDevice
    @ObservedObject var deviceManager = DeviceManager.shared
    var onEdit: () -> Void
    var onSelect: () -> Void

    var body: some View {
        BaseCard(
            title: device.type.rawValue,
            isSelected: deviceManager.activeDeviceId == device.id,
            onTap: {
                withAnimation(.spring(response: 0.3)) {
                    deviceManager.setActiveDevice(device)
                    onSelect()
                }
            }
        ) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: device.type.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(deviceManager.activeDeviceId == device.id ? .white : Color.appAccent)
                    
                // Connection Status Dot
                if device.type != .internal {
                    Circle()
                        .fill(device.isConnected ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .offset(x: 10, y: -4)
                }
            }
            .frame(height: 48)
        }
        .contextMenu {
            if device.type != .internal {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
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
                            ForEach([DeviceType.handy, .oh, .intiface, .lovespouse, .ossm, .internal].filter { $0.isSupported }, id: \.self) { type in
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
                name: deviceName.isEmpty ? deviceManager.nextUniqueName(for: deviceType) : deviceName,
                type: deviceType,
                connectionKey: connectionKey,
                serverAddress: serverAddress
            )
            deviceManager.addDevice(newDevice)
        }
        dismiss()
    }
}

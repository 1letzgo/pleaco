//
//  SettingsView.swift
//  pleaco
//

import SwiftUI
import Combine

struct SettingsView: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @State private var showingAddDevice = false
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Taptic Engine (Internal)")) {
                    HStack(spacing: 12) {
                        Button(action: { deviceManager.setActiveDevice(deviceManager.internalDevice) }) {
                            Image(systemName: deviceManager.internalDevice.type.icon)
                                .font(.title2)
                                .foregroundColor(deviceManager.activeDeviceId == deviceManager.internalDevice.id ? Color.appMagenta : .secondary)
                                .frame(width: 32)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(deviceManager.internalDevice.name)
                                .font(.headline)
                            Text("Standard Vibration")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if deviceManager.internalDevice.isConnected {
                                Text("Available")
                                    .font(.caption2)
                                    .foregroundColor(Color.appMagenta)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Saved Devices")) {
                    ForEach(deviceManager.devices) { device in
                        HStack(spacing: 12) {
                            Button(action: { deviceManager.setActiveDevice(device) }) {
                                Image(systemName: device.type.icon)
                                    .font(.title2)
                                    .foregroundColor(deviceManager.activeDeviceId == device.id ? Color.appMagenta : .secondary)
                                    .frame(width: 32)
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: DeviceDetailView(device: device)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(device.name).font(.headline)
                                    Text(device.type.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if device.isConnected {
                                        Text("Connected")
                                            .font(.caption2)
                                            .foregroundColor(Color.appMagenta)
                                    }
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deviceManager.removeDevice(device)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: { showingAddDevice = true }) {
                        Label("Add External Device", systemImage: "plus.circle.fill")
                            .foregroundColor(Color.appMagenta)
                    }
                }
            }
            .navigationTitle("Devices & Settings")
            .listStyle(.insetGrouped)
            .sheet(isPresented: $showingAddDevice) {
                AddDeviceSheet(deviceManager: deviceManager)
            }
        }
    }
}

struct AddDeviceSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var deviceManager: DeviceManager
    
    @State private var deviceName = ""
    @State private var deviceType: DeviceType = .handy
    @State private var connectionKey = ""
    @State private var serverAddress = "ws://127.0.0.1:12345"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Device Name", text: $deviceName)
                    Picker("Type", selection: $deviceType) {
                        ForEach([DeviceType.handy, .oh, .intiface], id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
                
                if deviceType == .handy || deviceType == .oh {
                    Section("Connection Key") {
                        TextField("Enter Connection Key", text: $connectionKey)
                    }
                } else if deviceType == .intiface {
                    Section("Server Address") {
                        TextField("ws://...", text: $serverAddress)
                    }
                }
            }
            .navigationTitle("Add Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newDevice = SavedDevice(
                            id: UUID(),
                            name: deviceName.isEmpty ? "New Device" : deviceName,
                            type: deviceType,
                            connectionKey: connectionKey,
                            serverAddress: serverAddress
                        )
                        deviceManager.addDevice(newDevice)
                        dismiss()
                    }
                    .disabled(deviceType != .intiface && connectionKey.isEmpty)
                }
            }
        }
    }
}

struct DeviceDetailView: View {
    @ObservedObject var device: SavedDevice
    @ObservedObject var deviceManager = DeviceManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Form {
            Section("Info") {
                TextField("Name", text: $device.name)
                Text("Type: \(device.type.rawValue)").foregroundColor(.secondary)
            }
            
            if device.type == .handy || device.type == .oh {
                Section("API Key") {
                    TextField("Connection Key", text: $device.connectionKey)
                }
            } else if device.type == .intiface {
                Section("Server") {
                    TextField("Server Address", text: $device.serverAddress)
                }
            }
            
            Section {
                Button(device.isConnected ? "Disconnect" : "Connect") {
                    if device.isConnected {
                        device.isConnected = false
                        deviceManager.objectWillChange.send()
                    } else {
                        deviceManager.setActiveDevice(device)
                    }
                }
                .foregroundColor(device.isConnected ? .red : Color.appMagenta)
                
                if deviceManager.activeDeviceId != device.id {
                    Button("Set as Active Device") {
                        deviceManager.setActiveDevice(device)
                        dismiss()
                    }
                    .foregroundColor(Color.appMagenta)
                } else {
                    Text("Currently Active Device")
                        .foregroundColor(.green)
                }
            }
            
            Section {
                Button(role: .destructive) {
                    deviceManager.removeDevice(device)
                    dismiss()
                } label: {
                    Text("Delete Device")
                }
            }
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

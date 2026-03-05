//
//  CustomTopBar.swift
//  pleaco
//

import SwiftUI

struct CustomTopBar: View {
    @Binding var selectedTab: Int
    let tabs = ["Library", "Audio", "Remote", "Devices"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Gap for status bar / notch
            Spacer(minLength: 0)
                .frame(height: 12) // Minimum base padding

            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = index
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(tabs[index])
                                .font(.system(size: 15, weight: selectedTab == index ? .bold : .medium))
                                .foregroundColor(selectedTab == index ? Color.appAccent : .secondary)
                            
                            // Active indicator dot
                            Circle()
                                .fill(selectedTab == index ? Color.appAccent : Color.clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .background(Color.surfacePrimary.ignoresSafeArea(edges: .top))
        // Add a subtle bottom separator
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.subtleBorder)
                .opacity(0.5),
            alignment: .bottom
        )
    }
}

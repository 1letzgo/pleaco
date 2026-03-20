//
//  CustomTopBar.swift
//  pleaco
//

import SwiftUI

struct CustomTopBar: View {
    @Binding var selectedTab: Int
    let tabs = ["Library", "Media", "Remote", "Devices"]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = index
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text(tabs[index])
                                .font(.system(size: 14, weight: selectedTab == index ? .bold : .medium))
                                .foregroundColor(selectedTab == index ? Color.appAccent : .secondary)

                            Circle()
                                .fill(selectedTab == index ? Color.appAccent : Color.clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
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

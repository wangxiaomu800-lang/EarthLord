//
//  TerritoryToolbarView.swift
//  EarthLord
//
//  Created on 2026-01-22.
//

import SwiftUI

/// 领地详情页悬浮工具栏
struct TerritoryToolbarView: View {
    let onDismiss: () -> Void
    let onBuildingBrowser: () -> Void

    @Binding var showInfoPanel: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 关闭按钮
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }

            Spacer()

            // 信息面板切换按钮
            Button {
                withAnimation(.spring()) {
                    showInfoPanel.toggle()
                }
            } label: {
                Image(systemName: showInfoPanel ? "info.circle.fill" : "info.circle")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }

            // 建造按钮
            Button {
                onBuildingBrowser()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                        .font(.body)
                    Text("建造")
                        .font(.body)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.primary)
                .clipShape(Capsule())
            }
        }
        .padding()
    }
}

#Preview {
    VStack {
        TerritoryToolbarView(
            onDismiss: { print("关闭") },
            onBuildingBrowser: { print("建造") },
            showInfoPanel: .constant(true)
        )

        Spacer()
    }
    .background(Color.gray)
}

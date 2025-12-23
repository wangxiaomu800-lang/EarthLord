//
//  TestView.swift
//  EarthLord
//
//  Created by Sherry Wang on 2025/12/23.
//

import SwiftUI

struct TestView: View {
    var body: some View {
        ZStack {
            // 淡蓝绿色背景
            Color(red: 0.7, green: 0.9, blue: 0.85)
                .ignoresSafeArea()

            // 大标题
            Text("这里是分支宇宙的测试页")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
    }
}

#Preview {
    TestView()
}

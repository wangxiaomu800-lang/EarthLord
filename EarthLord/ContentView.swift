//
//  ContentView.swift
//  EarthLord
//
//  Created by 王璇 on 2025/12/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")

            Text("Developed by Sherry Wang")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .padding(.top, 20)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

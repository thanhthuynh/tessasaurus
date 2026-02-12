//
//  ContentView.swift
//  Tessasaurus
//
//  Created by Thanh Huynh on 1/28/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1
    @State private var showTabBar = true

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                HomeView()
                    .opacity(selectedTab == 0 ? 1 : 0)
                    .zIndex(selectedTab == 0 ? 1 : 0)

                PhotoWallView(showTabBar: $showTabBar)
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .zIndex(selectedTab == 1 ? 1 : 0)
            }

            if showTabBar {
                FloatingTabBar(selectedTab: $selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showTabBar)
    }
}

#Preview {
    ContentView()
}

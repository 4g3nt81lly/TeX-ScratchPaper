//
//  PreferencesView.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2022/7/11.
//

// TODO: Preferences pane.

import SwiftUI

struct PreferencesView: View {
    @State var selectedTab = 1
    
    var body: some View {
        TabView {
            GeneralPreferences()
                .tabItem {
                    Image(systemName: "gearshape")
                }
            EditorPreferences()
                .tabItem {
                    Image(systemName: "highlighter")
                }
            BehaviorsPreferences()
                .tabItem {
                    Image(systemName: "flowchart")
                }
        }
        .focusable(false)
    }
}

struct GeneralPreferences: View {
    var body: some View {
        Text("General Pane")
    }
}

struct EditorPreferences: View {
    var body: some View {
        Text("Editor Pane")
    }
}

struct BehaviorsPreferences: View {
    var body: some View {
        Text("Behaviors Pane")
    }
}

struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView()
    }
}

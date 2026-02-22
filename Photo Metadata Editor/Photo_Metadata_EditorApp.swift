//
//  Photo_Metadata_EditorApp.swift
//  Photo Metadata Editor
//
//  Created by Takahiko Inayama on 2026/2/22.
//

import SwiftUI
import SwiftData

@main
struct Photo_Metadata_EditorApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

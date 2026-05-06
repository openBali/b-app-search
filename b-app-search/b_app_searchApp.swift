//
//  b_app_searchApp.swift
//  b-app-search
//
//  Created by Danis on 2026/5/6.
//

import SwiftUI

@main
struct b_app_searchApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

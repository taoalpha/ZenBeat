//
//  MenuBarLabelView.swift
//  ZenBeat
//
//  Created by Tao Zhou on 03.01.2026.
//

import SwiftUI
import SwiftData

struct MenuBarLabelView: View {
    @EnvironmentObject private var manager: ReminderManager
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        HStack(spacing: 4) {
            if manager.isSnoozing {
                Image(systemName: "bell.slash.fill")
            }
            Text(manager.nextEventTitle)
                .font(.system(.body, design: .monospaced))
        }
        .onAppear {
            manager.setModelContext(modelContext)
        }
    }
}

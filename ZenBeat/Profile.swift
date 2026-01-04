//
//  Profile.swift
//  ZenBeat
//
//  Created by Tao Zhou on 04.01.2026.
//

import Foundation
import SwiftData

@Model
final class Profile: Identifiable {
    var id: UUID
    var name: String
    var icon: String // SF Symbol name
    var createdAt: Date
    
    // DND Settings
    var dndEnabled: Bool = false
    var dndStartTime: TimeInterval = 20 * 3600 // 20:00 default
    var dndEndTime: TimeInterval = 8 * 3600    // 08:00 default
    
    @Relationship(deleteRule: .cascade, inverse: \Reminder.profile)
    var reminders: [Reminder]?
    
    init(name: String, icon: String = "person.fill") {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.createdAt = Date()
        self.reminders = []
        self.dndEnabled = false
        self.dndStartTime = 20 * 3600
        self.dndEndTime = 8 * 3600
    }
}

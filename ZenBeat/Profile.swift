//
//  Profile.swift
//  ZenBeat
//
//  Created by Tao Zhou on 04.01.2026.
//

import Foundation
import SwiftData

@Model
final class Profile {
    var id: UUID
    var name: String
    var icon: String // SF Symbol name
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Reminder.profile)
    var reminders: [Reminder]?
    
    init(name: String, icon: String = "person.fill") {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.createdAt = Date()
        self.reminders = []
    }
}

//
//  ReminderEntry.swift
//  ZenBeat
//
//  Created by Tao Zhou on 03.01.2026.
//

import Foundation
import SwiftData

/// Represents a single completion/check-in for a reminder.
@Model
final class ReminderEntry {
    var timestamp: Date
    var count: Int
    /// Legacy field, kept for compatibility.
    var reminderNameRaw: String
    var duration: TimeInterval? // Duration in seconds from overlay show to completion
    var isSkipped: Bool = false
    
    var reminder: Reminder?
    
    init(count: Int, timestamp: Date = Date(), reminder: Reminder? = nil, duration: TimeInterval? = nil, isSkipped: Bool = false) {
        self.count = count
        self.timestamp = timestamp
        self.reminder = reminder
        self.reminderNameRaw = reminder?.name ?? "Unknown"
        self.duration = duration
        self.isSkipped = isSkipped
    }
}

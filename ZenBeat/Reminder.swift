//
//  Reminder.swift
//  ZenBeat
//
//  Created by Tao Zhou on 03.01.2026.
//

import Foundation
import SwiftData

@Model
final class Reminder {
    var id: UUID
    var name: String
    var intervalMinutes: Int
    var dailyGoal: Int?
    var createdAt: Date
    var isArchived: Bool
    
    var typeRaw: Int = 0
    var fixedTimes: [TimeInterval]? // Seconds from midnight
    var alignToClock: Bool = false
    var alignmentMinute: Int = 0
    
    var type: ReminderType {
        get { ReminderType(rawValue: typeRaw) ?? .interval }
        set { typeRaw = newValue.rawValue }
    }
    
    var effectiveDailyGoal: Int {
        if type == .fixed {
            return fixedTimes?.count ?? 0
        } else {
            return dailyGoal ?? 0
        }
    }
    
    @Relationship(deleteRule: .cascade, inverse: \ReminderEntry.reminder)
    var entries: [ReminderEntry]?
    
    var profile: Profile?
    
    init(name: String, intervalMinutes: Int, dailyGoal: Int?, type: ReminderType = .interval, fixedTimes: [TimeInterval]? = nil, alignToClock: Bool = false, alignmentMinute: Int = 0) {
        self.id = UUID()
        self.name = name
        self.intervalMinutes = intervalMinutes
        self.dailyGoal = dailyGoal
        self.typeRaw = type.rawValue
        self.fixedTimes = fixedTimes
        self.alignToClock = alignToClock
        self.alignmentMinute = alignmentMinute
        self.createdAt = Date()
        self.isArchived = false
        self.entries = []
    }
    
    // MARK: - Business Logic
    
    var todayCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayEntries = (entries ?? []).filter { $0.timestamp >= today }
        return todayEntries.reduce(0) { $0 + $1.count }
    }
    
    var dailyProgress: Double {
        let goal = effectiveDailyGoal
        guard goal > 0 else { return 0 }
        return Double(todayCount) / Double(goal)
    }
    
    func isDailyGoalReached(lastEntry: Date? = nil) -> Bool {
        if type == .interval {
            guard let goal = dailyGoal, goal > 0 else { return false }
            return todayCount >= goal
        } else {
            // Fixed logic: Goal is reached if no more future or missed events match "due" criteria
            let now = Date()
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: now)
            let times = (fixedTimes ?? []).sorted()
            
            // Use provided lastEntry or compute it
            let actualLastEntry = lastEntry ?? entries?.max(by: { $0.timestamp < $1.timestamp })?.timestamp
            
            for seconds in times {
                let slotTime = startOfToday.addingTimeInterval(seconds)
                
                if slotTime > now {
                    // There is a future event today -> Not done
                    return false
                }
                
                // For past slots, check if they are "covered"
                if (actualLastEntry ?? Date.distantPast) < slotTime {
                    // We missed this slot and haven't logged it -> It is Due -> Not done
                    return false
                }
            }
            
            // If we are here, no future events and all past slots are covered
            return true
        }
    }
    
    func nextDueDate(from date: Date = Date(), dndEnd: Date? = nil, lastEntryOverride: Date? = nil) -> Date {
        let now = date
        let actualLastEntry = lastEntryOverride ?? entries?.max(by: { $0.timestamp < $1.timestamp })?.timestamp
        
        if type == .fixed {
            // FIXED TIME LOGIC
            let times = (fixedTimes ?? []).sorted()
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: now)
            
            // Helper to get Date for seconds from midnight
            func date(for seconds: TimeInterval, on day: Date) -> Date {
                day.addingTimeInterval(seconds)
            }
            
            var nextSlot: Date?
            var missedSlot: Date?
            
            for seconds in times {
                let slotTime = date(for: seconds, on: startOfToday)
                
                if slotTime > now {
                    // Future slot
                    if nextSlot == nil { nextSlot = slotTime }
                } else {
                    // Past slot
                    // Check if we did it
                    if (actualLastEntry ?? Date.distantPast) < slotTime {
                        missedSlot = slotTime
                    }
                }
            }
            
            if let missed = missedSlot {
                return missed
            } else if let next = nextSlot {
                return next
            } else {
                // No more slots today, pick first slot tomorrow
                if let firstSeconds = times.first {
                    let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
                    return date(for: firstSeconds, on: tomorrow)
                } else {
                    return Date.distantFuture
                }
            }
        } else {
            // INTERVAL LOGIC
            var baseDate = actualLastEntry ?? createdAt
            
            if let dndEnd = dndEnd, dndEnd > baseDate {
                baseDate = dndEnd
            }
            
            if alignToClock {
                let calendar = Calendar.current
                let startOfBase = calendar.startOfDay(for: baseDate)
                let baseMinutes = Int(baseDate.timeIntervalSince(startOfBase) / 60)
                
                // Find next aligned minute after baseMinutes
                let k = Int(ceil(Double(baseMinutes - alignmentMinute) / Double(intervalMinutes)))
                var nextMinutes = alignmentMinute + k * intervalMinutes
                
                if nextMinutes <= baseMinutes {
                    nextMinutes += intervalMinutes
                }
                
                return startOfBase.addingTimeInterval(TimeInterval(nextMinutes * 60))
            } else {
                let intervalSeconds = TimeInterval(intervalMinutes * 60)
                return baseDate.addingTimeInterval(intervalSeconds)
            }
        }
    }
    
    func isDue(at date: Date = Date(), dndEnd: Date? = nil, lastEntryOverride: Date? = nil) -> Bool {
        if isDailyGoalReached(lastEntry: lastEntryOverride) { return false }
        
        if type == .interval {
            let actualLastEntry = lastEntryOverride ?? entries?.max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? createdAt
            if alignToClock {
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: date)
                let currentMinutes = Int(date.timeIntervalSince(startOfDay) / 60)
                
                let k = Int(floor(Double(currentMinutes - alignmentMinute) / Double(intervalMinutes)))
                let lastAlignedMinutes = alignmentMinute + k * intervalMinutes
                let lastAlignedDate = startOfDay.addingTimeInterval(TimeInterval(lastAlignedMinutes * 60))
                
                return lastAlignedDate > actualLastEntry && lastAlignedDate >= createdAt && lastAlignedDate <= date
            } else {
                let due = actualLastEntry.addingTimeInterval(TimeInterval(intervalMinutes * 60))
                return date >= due
            }
        } else {
            // Fixed logic
            let times = (fixedTimes ?? []).sorted()
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: date)
            let actualLastEntry = lastEntryOverride ?? entries?.max(by: { $0.timestamp < $1.timestamp })?.timestamp
            
            for seconds in times {
                let slotTime = startOfToday.addingTimeInterval(seconds)
                if slotTime <= date {
                    // Past slot. If not covered, then DUE.
                    if (actualLastEntry ?? Date.distantPast) < slotTime {
                        return true
                    }
                }
            }
            return false
        }
    }
}

enum ReminderType: Int, Codable {
    case interval = 0
    case fixed = 1
}

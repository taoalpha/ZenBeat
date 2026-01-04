
import Testing
@testable import ZenBeat
import SwiftData
import Foundation

struct ReminderTests {
    
    // No ModelContext needed for pure logic tests on @Model classes if we manage relationships manually.
    
    @Test func intervalReminderNextDueDate() async throws {
        let reminder = Reminder(name: "Test", intervalMinutes: 60, dailyGoal: 5)
        // No context needed
        
        let now = Date()
        let dueDate = reminder.nextDueDate(from: now)
        
        let diff = abs(dueDate.timeIntervalSince(reminder.createdAt) - 3600)
        #expect(diff < 1.0)
    }
    
    @Test func fixedTimeReminderNextDue() async throws {
        // 10:00 AM fixed time
        let fixedTime: TimeInterval = 10 * 3600
        let reminder = Reminder(name: "Fixed", intervalMinutes: 0, dailyGoal: nil, type: .fixed, fixedTimes: [fixedTime])
        
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        // Case 1: Before 10 AM (e.g. 9 AM)
        let nineAM = startOfToday.addingTimeInterval(9 * 3600)
        let dueAtNine = reminder.nextDueDate(from: nineAM)
        #expect(dueAtNine == startOfToday.addingTimeInterval(fixedTime))
        
        // Case 2: After 10 AM (e.g. 11 AM) - WITHOUT logging it
        // Should be Today 10 AM (Overdue)
        let elevenAM = startOfToday.addingTimeInterval(11 * 3600)
        let dueAtElevenOverdue = reminder.nextDueDate(from: elevenAM)
        #expect(dueAtElevenOverdue == startOfToday.addingTimeInterval(fixedTime))
        
        // Case 3: After 10 AM - WITH logging it
        // Log the 10 AM entry
        let entryTime = startOfToday.addingTimeInterval(10 * 3600 + 60) // 10:01
        let entry = ReminderEntry(count: 1, timestamp: entryTime, reminder: reminder)
        reminder.entries = [entry]
        
        let dueAtElevenCompleted = reminder.nextDueDate(from: elevenAM)
        // Should be tomorrow 10 AM
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        #expect(dueAtElevenCompleted == tomorrow.addingTimeInterval(fixedTime))
    }
    
    @Test func fixedTimeGoalReached() async throws {
        let fixedTime: TimeInterval = 10 * 3600
        let reminder = Reminder(name: "Fixed", intervalMinutes: 0, dailyGoal: nil, type: .fixed, fixedTimes: [fixedTime])
        
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        // At 9 AM, not reached
        #expect(!reminder.isDailyGoalReached(lastEntry: nil))
        
        // Log entry at 10:01
        let entryTime = startOfToday.addingTimeInterval(10 * 3600 + 60)
        let entry = ReminderEntry(count: 1, timestamp: entryTime, reminder: reminder)
        // Manually link relationship since we aren't using a context to auto-update inverses
        reminder.entries = [entry] 
        
        // Now it should be reached
        #expect(reminder.isDailyGoalReached())
    }
}

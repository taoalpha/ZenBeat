//
//  ReminderManager.swift
//  ZenBeat
//
//  Created by Tao Zhou on 03.01.2026.
//

import SwiftUI
import SwiftData
import UserNotifications
import Combine

@MainActor
class ReminderManager: ObservableObject {
    // MARK: - Published State
    @Published var reminders: [Reminder] = []
    @Published var nextDueReminder: Reminder?
    @Published var nextEventTitle: String = "Ready"
    @Published var timeRemaining: TimeInterval = 0
    @Published var isTimerRunning = false
    
    // Overlay States
    @Published var showTimeUpOverlay: Bool = false

    @Published var activeOverlayReminder: Reminder?
    @Published var reminderToEdit: Reminder?
    
    // Profile State
    @Published var currentProfile: Profile?
    @Published var allProfiles: [Profile] = []
    
    // Snooze State
    @Published var snoozeEndTime: Date? = nil
    
    var isSnoozing: Bool {
        guard let endTime = snoozeEndTime else { return false }
        return Date() < endTime
    }
    
    var snoozeTimeRemaining: TimeInterval {
        guard let endTime = snoozeEndTime else { return 0 }
        return max(0, endTime.timeIntervalSinceNow)
    }
    // MARK: - Filtered Properties
    
    var upcomingReminders: [Reminder] {
        let dndEnd = getLatestEffectiveDNDEndTime()
        let now = Date()
        return reminders.filter { !($0.isDailyGoalReached(lastEntry: getLastEntryTime(for: $0))) }
            .sorted { r1, r2 in
                let d1 = r1.nextDueDate(from: now, dndEnd: dndEnd, lastEntryOverride: getLastEntryTime(for: r1))
                let d2 = r2.nextDueDate(from: now, dndEnd: dndEnd, lastEntryOverride: getLastEntryTime(for: r2))
                return d1 < d2
            }
    }
    
    var completedReminders: [Reminder] {
        reminders.filter { $0.isDailyGoalReached(lastEntry: getLastEntryTime(for: $0)) }
            .sorted { $0.name < $1.name }
    }
    
    // MARK: - Internal/Private
    var modelContext: ModelContext?
    private var timerCancellable: AnyCancellable?
    
    // Cache for last entry times to avoid expensive DB queries every second
    var lastEntryTimes: [UUID: Date] = [:]
    
    // Track which reminders we've already shown the overlay for (reset when they're no longer due)
    var notifiedReminderIds: Set<UUID> = []
    
    // Track when the overlay was shown to calculate duration
    private var overlayShowTime: Date?
    
    init() {
        requestNotificationPermission()
        startTimer()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        refreshReminders()
        
        if reminders.isEmpty {
            // Check if profiles exist, if not create default
            // This is handled in ensureDefaultProfile() which we call now
        }
        
        ensureDefaultProfile()
        refreshProfiles()
        refreshReminders()
        
        startTimer()
    }
    
    // MARK: - Profile Logic
    
    func refreshProfiles() {
        guard let context = modelContext else { return }
        do {
            let descriptor = FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.createdAt)])
            allProfiles = try context.fetch(descriptor)
            
            // Set current profile if not set (first launch or after load)
            if currentProfile == nil {
                if let savedIdString = UserDefaults.standard.string(forKey: "selectedProfileId"),
                   let savedId = UUID(uuidString: savedIdString),
                   let savedProfile = allProfiles.first(where: { $0.id == savedId }) {
                    currentProfile = savedProfile
                } else {
                    currentProfile = allProfiles.first
                }
            }
        } catch {
            print("Failed to fetch profiles: \(error)")
        }
    }
    
    // MARK: - Snooze
    
    func snooze(for minutes: Int) {
        snoozeEndTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
    }
    
    func cancelSnooze() {
        snoozeEndTime = nil
    }
    
    func ensureDefaultProfile() {
        guard let context = modelContext else { return }
        
        // Fetch all profiles first
        let profileDesc = FetchDescriptor<Profile>()
        let profileCount = (try? context.fetchCount(profileDesc)) ?? 0
        
        if profileCount == 0 {
            let defaultProfile = Profile(name: "Default", icon: "person.circle")
            context.insert(defaultProfile)
            try? context.save()
            currentProfile = defaultProfile
        }
    }
    
    func switchProfile(to profile: Profile) {
        currentProfile = profile
        UserDefaults.standard.set(profile.id.uuidString, forKey: "selectedProfileId")
        notifiedReminderIds.removeAll() // Clear state when switching profiles
        refreshReminders()
    }
    
    func createProfile(name: String, icon: String) {
        guard let context = modelContext else { return }
        let newProfile = Profile(name: name, icon: icon)
        context.insert(newProfile)
        try? context.save()
        refreshProfiles()
        switchProfile(to: newProfile)
    }
    
    func refreshReminders() {
        guard let context = modelContext, let profile = currentProfile else {
            reminders = []
            return
        }
        
        // Filter by current profile AND not archived
        // Note: Relationship filtering in Predicate can be tricky in SwiftData versions.
        // Easiest is to fetch reminders that belong to the profile.
        // But since we want to observe changes, sorting etc...
        // Let's rely on relationship traversing if possible, OR explicit predicate.
        
        let profileId = profile.id
        
        do {
            let descriptor = FetchDescriptor<Reminder>(
                predicate: #Predicate { $0.profile?.id == profileId && !$0.isArchived },
                sortBy: [SortDescriptor(\.createdAt)]
            )
            let newReminders = try context.fetch(descriptor)
            
            // If the current reminders list changed significantly, we might want to clear notified set
            // but usually refreshReminders is called for UI updates too.
            // Let's just update the list.
            reminders = newReminders
            updateNextEvent()
        } catch {
            print("Failed to fetch reminders for profile: \(error)")
        }
    }
    
    // MARK: - Timer Logic
    
    func startTimer() {
        guard timerCancellable == nil else { return }
        isTimerRunning = true
        
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
        isTimerRunning = false
    }
    
    private func tick() {
        updateNextEvent()
    }
    
    // MARK: - Event Calculation
    
    private func updateNextEvent() {
        guard !reminders.isEmpty, modelContext != nil else {
            nextEventTitle = L10n.noRemindersMenu
            return
        }
        
        // DND Override - Check first before any calculation
        if isInDNDMode() {
            nextEventTitle = "🌙 \(L10n.doNotDisturb)"
            return
        }
        
        var minTimeRemaining: TimeInterval = .infinity
        var nextRem: Reminder? = nil
        
        let now = Date()
        
        for reminder in reminders {
            var lastEntryDate: Date? = nil
            if let lastCached = lastEntryTimes[reminder.id] {
                lastEntryDate = lastCached
            } else {
                let entries = reminder.entries ?? []
                lastEntryDate = entries.max(by: { $0.timestamp < $1.timestamp })?.timestamp
                if let date = lastEntryDate {
                    lastEntryTimes[reminder.id] = date
                }
            }

            if reminder.isDailyGoalReached(lastEntry: lastEntryDate) {
                continue
            }
            
            let dndEnd = getLatestEffectiveDNDEndTime()
            let dueDate = reminder.nextDueDate(from: now, dndEnd: dndEnd, lastEntryOverride: lastEntryDate)
            
            let secondsUntilDue = dueDate.timeIntervalSince(now)
            
            if secondsUntilDue < minTimeRemaining {
                minTimeRemaining = secondsUntilDue
                nextRem = reminder
            }
        }
        
        self.nextDueReminder = nextRem
        self.timeRemaining = minTimeRemaining
        

        
        if let next = nextRem {
            if minTimeRemaining <= 0 {
                nextEventTitle = L10n.readyLabel(next.name)
                
                // Trigger overlay if not already notified for this reminder
                if !notifiedReminderIds.contains(next.id) && !showTimeUpOverlay && !isSnoozing {
                    activeOverlayReminder = next
                    notifiedReminderIds.insert(next.id)
                    showTimeUpOverlay = true
                    overlayShowTime = Date()
                } else if showTimeUpOverlay {
                    // If overlay is already up, only update activeOverlayReminder if it's nil or no longer due
                    if activeOverlayReminder == nil {
                        activeOverlayReminder = next
                    }
                }
            } else {
                nextEventTitle = "\(formatShortTime(minTimeRemaining)) \(L10n.until) \(next.name)"
                // If this reminder is no longer due, remove from notified set so it can notify again next time
                notifiedReminderIds.remove(next.id)
            }
        } else {
             // All reminders completed or none exist
             if !reminders.isEmpty {
                 nextEventTitle = L10n.goalReached
             }
        }
    }
    
    // MARK: - Actions
    
    func logReminder(reminder: Reminder, count: Int, isSkipped: Bool = false) {
        guard let context = modelContext else { return }
        
        var duration: TimeInterval?
        if let start = overlayShowTime {
            duration = Date().timeIntervalSince(start)
            // Reset for next time
            overlayShowTime = nil
        }
        
        let entry = ReminderEntry(count: count, timestamp: Date(), reminder: reminder, duration: duration, isSkipped: isSkipped)
        context.insert(entry)
        
        // Update cache
        lastEntryTimes[reminder.id] = entry.timestamp
        
        do {
            try context.save()
            
            // Remove from notified set so next cycle can re-check
            notifiedReminderIds.remove(reminder.id)
            
            refreshReminders()
            
            // Check if there are more due reminders (this will close overlay if none)
            checkForMoreDueReminders()
        } catch {
            print("Failed to save entry: \(error)")
        }
    }
    
    func checkForMoreDueReminders() {
        let now = Date()
        
        // If in DND, don't show overlay
        if isInDNDMode() {
            showTimeUpOverlay = false
            overlayShowTime = nil
            return
        }
        
        for reminder in reminders {
            // Skip if daily goal reached
            if reminder.isDailyGoalReached(lastEntry: getLastEntryTime(for: reminder)) {
                continue
            }
            
            let lastEntry = lastEntryTimes[reminder.id] ?? (reminder.entries?.max(by: { $0.timestamp < $1.timestamp })?.timestamp)
            let dndEnd = getLatestEffectiveDNDEndTime()
            
            if reminder.isDue(at: now, dndEnd: dndEnd, lastEntryOverride: lastEntry) && !notifiedReminderIds.contains(reminder.id) {
                // Found another due reminder
                activeOverlayReminder = reminder
                notifiedReminderIds.insert(reminder.id)
                overlayShowTime = Date() // Reset start time for the next reminder in sequence
                return
            }
        }
        
        // No more due reminders - close the overlay
        showTimeUpOverlay = false
        activeOverlayReminder = nil
        overlayShowTime = nil
        notifiedReminderIds.removeAll() // Clear notifications when the entire due sequence is finished or closed
    }
    
    private func isInDNDMode() -> Bool {
        guard let profile = currentProfile else { return false }
        if !profile.dndEnabled { return false }
        
        let start = profile.dndStartTime
        let end = profile.dndEndTime
        
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour, .minute, .second], from: now)
        
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)
        
        let currentSeconds = (hour * 3600) + (minute * 60) + second
        
        if start < end {
            // Same day (e.g. 9:00 - 17:00)
            return currentSeconds >= start && currentSeconds < end
        } else {
            // Spans midnight (e.g. 22:00 - 08:00)
            return currentSeconds >= start || currentSeconds < end
        }
    }
    
    func getLatestEffectiveDNDEndTime() -> Date? {
        guard let profile = currentProfile else { return nil }
        if !profile.dndEnabled { return nil }
        
        let start = profile.dndStartTime
        let end = profile.dndEndTime
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        let components = calendar.dateComponents([.hour, .minute, .second], from: now)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)
        let currentSeconds = (hour * 3600) + (minute * 60) + second
        
        if start < end {
            // Intra-day (e.g. 08:00 to 20:00)
            if currentSeconds >= end {
                // Passed DND today
                return startOfDay.addingTimeInterval(end)
            } else {
                // Before DND or in DND today -> Last valid end was yesterday
                guard let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfDay) else { return nil }
                return yesterday.addingTimeInterval(end)
            }
        } else {
            // Overnight (e.g. 22:00 to 08:00)
            // End time (08:00) is always relative to the "following" day of the start.
            // If currentSeconds >= end (e.g. 09:00). The specific DND period that ended was "last night's", which ended today at 08:00.
            if currentSeconds >= end {
                return startOfDay.addingTimeInterval(end)
            } else {
                // If currentSeconds < end (e.g. 06:00). We are IN DND (or before it if gap is weird?).
                // But wait, if we are IN DND (at 06:00), the *previous* DND ended yesterday at 08:00.
                // The current one ends TODAY at 08:00 (in the future).
                // Requirement: "start countdown again when DND ends".
                // If we are currently IN DND, logic handles it by pausing.
                // WE only care about this return value when we are OUT of DND.
                // So if currentSeconds < start (e.g. 15:00) but end was 08:00.
                // 15:00 >= 08:00. enters first block. Returns today 08:00. Correct.
                
                // What if we are at 06:00 (In DND)?
                // 06:00 < 08:00. Enters else.
                // Last end was yesterday 08:00.
                guard let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfDay) else { return nil }
                return yesterday.addingTimeInterval(end)
            }
        }
    }
    
    // MARK: - Notifications
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    

    
    // MARK: - Helpers
    func getLastEntryTime(for reminder: Reminder) -> Date? {
        if let cached = lastEntryTimes[reminder.id] {
            return cached
        }
        // Fallback fetch
        let entries = reminder.entries ?? []
        if let last = entries.max(by: { $0.timestamp < $1.timestamp })?.timestamp {
            lastEntryTimes[reminder.id] = last
            return last
        }
        return nil
    }
    
    // Formatter
    private func formatShortTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(secs)s"
        }
    }
}
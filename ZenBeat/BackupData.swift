//
//  BackupData.swift
//  ZenBeat
//
//  Data structures and functions for backup and restore.
//

import Foundation
import SwiftData

// MARK: - Codable Export Structures

struct BackupData: Codable {
    let version: Int
    let exportDate: Date
    let profiles: [ProfileExport]
}

struct ProfileExport: Codable {
    let id: UUID
    let name: String
    let icon: String
    let createdAt: Date
    let reminders: [ReminderExport]
}

struct ReminderExport: Codable {
    let id: UUID
    let name: String
    let intervalMinutes: Int
    let dailyGoal: Int?
    let createdAt: Date
    let isArchived: Bool
    let typeRaw: Int
    let fixedTimes: [TimeInterval]?
    let entries: [ReminderEntryExport]
}

struct ReminderEntryExport: Codable {
    let timestamp: Date
    let count: Int
    let duration: TimeInterval?
    let isSkipped: Bool
}

// MARK: - Export Function

extension ReminderManager {
    
    func exportBackup() -> Data? {
        guard let context = modelContext else { return nil }
        
        do {
            // Fetch all profiles
            let profileDescriptor = FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.createdAt)])
            let profiles = try context.fetch(profileDescriptor)
            
            var profileExports: [ProfileExport] = []
            
            for profile in profiles {
                var reminderExports: [ReminderExport] = []
                
                for reminder in profile.reminders ?? [] {
                    var entryExports: [ReminderEntryExport] = []
                    
                    for entry in reminder.entries ?? [] {
                        entryExports.append(ReminderEntryExport(
                            timestamp: entry.timestamp,
                            count: entry.count,
                            duration: entry.duration,
                            isSkipped: entry.isSkipped
                        ))
                    }
                    
                    reminderExports.append(ReminderExport(
                        id: reminder.id,
                        name: reminder.name,
                        intervalMinutes: reminder.intervalMinutes,
                        dailyGoal: reminder.dailyGoal,
                        createdAt: reminder.createdAt,
                        isArchived: reminder.isArchived,
                        typeRaw: reminder.typeRaw,
                        fixedTimes: reminder.fixedTimes,
                        entries: entryExports
                    ))
                }
                
                profileExports.append(ProfileExport(
                    id: profile.id,
                    name: profile.name,
                    icon: profile.icon,
                    createdAt: profile.createdAt,
                    reminders: reminderExports
                ))
            }
            
            let backup = BackupData(
                version: 1,
                exportDate: Date(),
                profiles: profileExports
            )
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            return try encoder.encode(backup)
        } catch {
            print("Export error: \(error)")
            return nil
        }
    }
    
    func importBackup(from data: Data) throws {
        guard let context = modelContext else {
            throw BackupError.noContext
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let backup = try decoder.decode(BackupData.self, from: data)
        
        // 1. Safe clear
        try performCleanSlate()
        
        // 2. Import data from backup
        var importedProfiles: [Profile] = []
        
        for profileExport in backup.profiles {
            let profile = Profile(name: profileExport.name, icon: profileExport.icon)
            profile.createdAt = profileExport.createdAt
            context.insert(profile)
            importedProfiles.append(profile)
            
            for reminderExport in profileExport.reminders {
                let reminder = Reminder(
                    name: reminderExport.name,
                    intervalMinutes: reminderExport.intervalMinutes,
                    dailyGoal: reminderExport.dailyGoal,
                    type: ReminderType(rawValue: reminderExport.typeRaw) ?? .interval,
                    fixedTimes: reminderExport.fixedTimes
                )
                reminder.createdAt = reminderExport.createdAt
                reminder.isArchived = reminderExport.isArchived
                reminder.profile = profile
                context.insert(reminder)
                
                for entryExport in reminderExport.entries {
                    let entry = ReminderEntry(
                        count: entryExport.count,
                        timestamp: entryExport.timestamp,
                        reminder: reminder,
                        duration: entryExport.duration,
                        isSkipped: entryExport.isSkipped
                    )
                    context.insert(entry)
                }
            }
        }
        
        try context.save()
        
        // 4. Update current profile to the first imported one (or sensible default)
        if let firstProfile = importedProfiles.first {
            self.currentProfile = firstProfile
            UserDefaults.standard.set(firstProfile.id.uuidString, forKey: "selectedProfileId")
        }
        
        // 5. Refresh and restart
        refreshProfiles()
        refreshReminders()
        startTimer()
    }
    
    func eraseAllData() throws {
        try performCleanSlate()
        
        // 4. Re-initialize state
        ensureDefaultProfile()
        refreshProfiles()
        refreshReminders()
        
        // 5. Restart timer
        startTimer()
    }
    
    private func performCleanSlate() throws {
        guard let context = modelContext else {
            throw BackupError.noContext
        }
        
        // 1. Stop timer and overlays to prevent background access to deleted objects
        stopTimer()
        showTimeUpOverlay = false
        activeOverlayReminder = nil
        nextDueReminder = nil
        reminderToEdit = nil
        
        // 2. Clear local state references
        reminders = []
        allProfiles = []
        currentProfile = nil
        lastEntryTimes = [:]
        notifiedReminderIds = []
        snoozeEndTime = nil
        
        // 3. Delete all entries, reminders, and profiles from DB
        let entries = try context.fetch(FetchDescriptor<ReminderEntry>())
        for entry in entries { context.delete(entry) }
        
        let rems = try context.fetch(FetchDescriptor<Reminder>())
        for reminder in rems { context.delete(reminder) }
        
        let profs = try context.fetch(FetchDescriptor<Profile>())
        for profile in profs { context.delete(profile) }
        
        try context.save()
    }
}

enum BackupError: LocalizedError {
    case noContext
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .noContext: return "Database context not available."
        case .invalidData: return "Invalid backup file."
        }
    }
}

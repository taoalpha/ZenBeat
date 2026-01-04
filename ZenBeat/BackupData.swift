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
        
        // Clear existing data (optional - could merge instead)
        let existingProfiles = try context.fetch(FetchDescriptor<Profile>())
        for profile in existingProfiles {
            context.delete(profile)
        }
        
        let existingEntries = try context.fetch(FetchDescriptor<ReminderEntry>())
        for entry in existingEntries {
            context.delete(entry)
        }
        
        // Import profiles
        for profileExport in backup.profiles {
            let profile = Profile(name: profileExport.name, icon: profileExport.icon)
            profile.createdAt = profileExport.createdAt
            context.insert(profile)
            
            // Import reminders for this profile
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
                
                // Import entries for this reminder
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
        
        // Refresh state
        refreshProfiles()
        refreshReminders()
    }
    
    func eraseAllData() throws {
        guard let context = modelContext else {
            throw BackupError.noContext
        }
        
        // Delete all entries first (due to relationships)
        let entries = try context.fetch(FetchDescriptor<ReminderEntry>())
        for entry in entries {
            context.delete(entry)
        }
        
        // Delete all reminders
        let reminders = try context.fetch(FetchDescriptor<Reminder>())
        for reminder in reminders {
            context.delete(reminder)
        }
        
        // Delete all profiles
        let profiles = try context.fetch(FetchDescriptor<Profile>())
        for profile in profiles {
            context.delete(profile)
        }
        
        try context.save()
        
        // Clear state
        currentProfile = nil
        self.reminders = []
        allProfiles = []
        
        // Recreate default profile
        ensureDefaultProfile()
        refreshProfiles()
        refreshReminders()
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

//
//  Strings.swift
//  ZenBeat
//
//  Localized string constants for the app
//

import Foundation

enum L10n {
    private static var bundle: Bundle {
        LanguageManager.shared.bundle
    }
    
    private static func localized(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }
    
    // MARK: - General
    static var general: String { localized("general") }
    static var settings: String { localized("settings") }
    static var reminders: String { localized("reminders") }
    static var cancel: String { localized("cancel") }
    static var save: String { localized("save") }
    static var edit: String { localized("edit") }
    static var add: String { localized("add") }
    static var done: String { localized("done") }
    static var skip: String { localized("skip") }
    static var close: String { localized("close") }
    static var delete: String { localized("delete") }
    static var log: String { localized("log") }
    
    // MARK: - Settings
    static var launchAtLogin: String { localized("launch_at_login") }

    static var noRemindersTitle: String { localized("no_reminders_title") }
    static var noRemindersSubtitle: String { localized("no_reminders_subtitle") }
    static var language: String { localized("language") }
    static var about: String { localized("about") }
    static var version: String { localized("version") }
    static var profiles: String { localized("profiles") }
    
    // MARK: - Do Not Disturb
    static var doNotDisturb: String { localized("do_not_disturb") }
    static var dndDescription: String { localized("dnd_description") }
    static var startTime: String { localized("start_time") }
    static var endTime: String { localized("end_time") }
    
    // MARK: - Reminder Edit
    static var newReminder: String { localized("new_reminder") }
    static var editReminder: String { localized("edit_reminder") }
    static var type: String { localized("type") }
    static var intervalMode: String { localized("interval_mode") }
    static var fixedTimeMode: String { localized("fixed_time_mode") }
    static var times: String { localized("times") }
    static var addTime: String { localized("add_time") }
    static var name: String { localized("name") }
    static var namePlaceholder: String { localized("name_placeholder") }
    static var interval: String { localized("interval") }
    static var custom: String { localized("custom") }
    static var min: String { localized("min") }
    static var dailyReps: String { localized("daily_reps") }
    
    // MARK: - Dashboard
    static var ready: String { localized("ready") }
    static var upcoming: String { localized("upcoming") }
    static var completed: String { localized("completed") }
    static var seeRecords: String { localized("see_records") }
    static var deleteConfirmTitle: String { localized("delete_confirm_title") }
    static var deleteConfirmMessage: String { localized("delete_confirm_message") }
    static var timesPerDay: String { localized("reps_per_day") }
    
    // MARK: - Time Up Overlay
    static var timesUp: String { localized("times_up") }
    static func timeFor(_ name: String) -> String {
        String(format: localized("time_for"), name)
    }
    static var doneButton: String { localized("done_button") }
    static var noActiveReminder: String { localized("no_active_reminder") }
    
    // MARK: - Today Overlay
    static func todays(_ name: String) -> String {
        String(format: localized("todays"), name)
    }
    static var goalReached: String { localized("goal_reached") }
    static var nextReminderIn: String { localized("next_reminder_in") }
    static var noActiveReminders: String { localized("no_active_reminders") }
    
    // MARK: - Menu Bar
    static var noRemindersMenu: String { localized("no_reminders") }
    static func readyLabel(_ name: String) -> String {
        String(format: localized("ready_label"), name)
    }
    static var until: String { localized("until") }
    
    // MARK: - Formatted Strings
    static func everyXMin(_ minutes: Int) -> String {
        String(format: localized("every_x_min"), minutes)
    }
    
    static func xTimesPerDay(_ count: Int) -> String {
        "\(count) \(timesPerDay)"
    }
    
    static func xOfYTimes(_ current: Int, _ goal: Int) -> String {
        "\(current) / \(goal) \(times)"
    }
}

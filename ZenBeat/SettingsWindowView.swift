//
//  SettingsWindowView.swift
//  ZenBeat
//
//  Created by Tao Zhou on 03.01.2026.
//

import SwiftUI
import SwiftData
import ServiceManagement
import UniformTypeIdentifiers

struct SettingsWindowView: View {
    @EnvironmentObject var manager: ReminderManager
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: SettingsTab = .general
    @State private var editingReminder: Reminder?
    @State private var isAddingNew = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    SidebarButton(title: tab.title, icon: tab.icon, isSelected: selectedTab == tab) {
                        selectedTab = tab
                    }
                }
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(width: 180)
            .background(Color(nsColor: .alternatingContentBackgroundColors[0]))
            
            Divider()
            
            // Content
            VStack {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .profiles:
                    ProfilesSettingsView()
                case .reminders:
                    RemindersSettingsView(editingReminder: $editingReminder, isAddingNew: $isAddingNew)
                case .about:
                    AboutSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
        .frame(width: 650, height: 450)
        .background(WindowAccessor { window in
            if let window = window {
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
            }
        })
        .popover(item: $editingReminder) { reminder in
            ReminderEditSheet(reminder: reminder, isNew: false)
        }
        .popover(isPresented: $isAddingNew) {
            ReminderEditSheet(reminder: Reminder(name: "", intervalMinutes: 60, dailyGoal: 5), isNew: true)
        }
        .onChange(of: manager.reminderToEdit) { _, newValue in
            if let reminder = newValue {
                selectedTab = .reminders
                editingReminder = reminder
                // Reset to avoid re-triggering
                manager.reminderToEdit = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNewReminder)) { _ in
            selectedTab = .reminders
            isAddingNew = true
        }
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case profiles
    case general
    case reminders
    case about
    
    var id: String { rawValue }
    var title: String {
        switch self {
        case .profiles: return L10n.profiles
        case .general: return L10n.general
        case .reminders: return L10n.reminders
        case .about: return L10n.about
        }
    }
    var icon: String {
        switch self {
        case .profiles: return "person.2.fill"
        case .general: return "gear"
        case .reminders: return "bell"
        case .about: return "info.circle"
        }
    }
}

struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .frame(width: 20, alignment: .center)
                        .foregroundStyle(isSelected ? .white : .primary)
                Text(title)
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .pointingCursor()
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var manager: ReminderManager
    @ObservedObject private var languageManager = LanguageManager.shared
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var showEraseConfirmation = false
    @State private var errorMessage: String?
    @State private var showErrorMessage = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        // Launch at Login Switch
                        HStack {
                            Text(L10n.launchAtLogin)
                            Spacer()
                            Toggle("", isOn: $launchAtLogin)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .tint(.green)
                                .controlSize(.mini)
                        }
                        .onChange(of: launchAtLogin) { _, newValue in
                            updateLaunchAtLogin(enabled: newValue)
                        }
                        
                        Divider()
                        
                        // Language Picker
                        HStack {
                            Text(L10n.language)
                            Spacer()
                            Picker("", selection: $languageManager.currentLanguage) {
                                ForEach(AppLanguage.allCases) { language in
                                    Text(language.displayName).tag(language)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                        

                    }
                    .padding(12)
                }
                
                // Backup & Restore Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Backup & Restore")
                            .font(.headline)
                        
                        Text("Export all your profiles, reminders, and history to a file. Import to restore on another device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            Button {
                                exportBackup()
                            } label: {
                                Label("Export Backup", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                            .pointingCursor()
                            
                            Button {
                                importBackup()
                            } label: {
                                Label("Import Backup", systemImage: "square.and.arrow.down")
                            }
                        .buttonStyle(.bordered)
                        .pointingCursor()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                
                // Danger Zone
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Danger Zone")
                            .font(.headline)
                            .foregroundStyle(.red)
                        
                        Text("Permanently delete all profiles, reminders, and history. This cannot be undone.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Button(role: .destructive) {
                            showEraseConfirmation = true
                        } label: {
                            Label("Erase All Data", systemImage: "trash.fill")
                        }
                        .buttonStyle(.bordered)
                        .pointingCursor()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                
                Spacer()
            }
            .padding()
        }
        .confirmationDialog("Erase All Data?", isPresented: $showEraseConfirmation, titleVisibility: .visible) {
            Button("Erase Everything", role: .destructive) {
                eraseAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all your profiles, reminders, and history. This action cannot be undone.")
        }
        .alert("Error", isPresented: $showErrorMessage, presenting: errorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }
    
    private func dndTimeBinding(for storage: Binding<Double>) -> Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                return today.addingTimeInterval(storage.wrappedValue)
            },
            set: { newDate in
                let calendar = Calendar.current
                let components = calendar.dateComponents([.hour, .minute], from: newDate)
                let seconds = (components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60
                storage.wrappedValue = Double(seconds)
            }
        )
    }
    
    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
    

    
    private func exportBackup() {
        guard let data = manager.exportBackup() else {
            errorMessage = "Failed to create backup: Data generation failed."
            showErrorMessage = true
            print("Failed to create backup")
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "zenbeat_backup_\(Date().formatted(.dateTime.year().month().day())).json"
        savePanel.title = "Export Backup"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try data.write(to: url)
                    print("Backup saved to \(url)")
                } catch {
                    errorMessage = "Failed to save backup: \(error.localizedDescription)"
                    showErrorMessage = true
                    print("Failed to save backup: \(error)")
                }
            }
        }
    }
    
    private func importBackup() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Import Backup"
        openPanel.message = "Select a ZenBeat backup file to restore."
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                do {
                    let data = try Data(contentsOf: url)
                    try manager.importBackup(from: data)
                    print("Backup restored successfully")
                } catch {
                    errorMessage = "Failed to restore backup: \(error.localizedDescription)"
                    showErrorMessage = true
                    print("Failed to restore backup: \(error)")
                }
            }
        }
    }
    
    private func eraseAllData() {
        do {
            try manager.eraseAllData()
            print("All data erased successfully")
        } catch {
            errorMessage = "Failed to erase data: \(error.localizedDescription)"
            showErrorMessage = true
            print("Failed to erase data: \(error)")
        }
    }
}

struct RemindersSettingsView: View {
    @Binding var editingReminder: Reminder?
    @Binding var isAddingNew: Bool
    @EnvironmentObject var manager: ReminderManager
    @Environment(\.modelContext) private var modelContext
    
    // Local state for viewing reminders (does NOT change active profile)
    @State private var selectedProfile: Profile?
    
    // Reminders filtered by selectedProfile (for management view only)
    var reminders: [Reminder] {
        guard let profile = selectedProfile else { return [] }
        return (profile.reminders ?? []).filter { !$0.isArchived }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    // Profile Picker (local only - for management)
                    Menu {
                        ForEach(manager.allProfiles, id: \.id) { profile in
                            Button {
                                selectedProfile = profile
                            } label: {
                                HStack {
                                    Image(systemName: profile.icon)
                                    Text(profile.name)
                                    if profile.id == selectedProfile?.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if let profile = selectedProfile {
                                Image(systemName: profile.icon)
                                Text(profile.name)
                                    .font(.headline)
                            } else {
                                Text(L10n.reminders)
                                    .font(.headline)
                            }
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    
                    Spacer()
                    Button {
                        isAddingNew = true
                    } label: {
                        Label(L10n.add, systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if reminders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(L10n.noRemindersTitle)
                            .font(.headline)
                        Text(L10n.noRemindersSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    VStack(spacing: 10) {
                        ForEach(reminders) { reminder in
                            ReminderRowSettings(reminder: reminder) {
                                editingReminder = reminder
                            } onDelete: {
                                deleteReminder(reminder)
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding()
        }
        .onAppear {
            // Initialize with current active profile
            if selectedProfile == nil {
                selectedProfile = manager.currentProfile
            }
        }
    }
    
    private func deleteReminder(_ reminder: Reminder) {
        modelContext.delete(reminder)
        try? modelContext.save()
        manager.refreshReminders()
    }
}

struct ReminderRowSettings: View {
    let reminder: Reminder
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showRecordsSheet = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        GroupBox {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(reminder.name)
                        .font(.headline)
                    Text("\(L10n.everyXMin(reminder.intervalMinutes)) • \(L10n.xTimesPerDay(reminder.effectiveDailyGoal))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Menu {
                    Button {
                        showRecordsSheet = true
                    } label: {
                        Label(L10n.seeRecords, systemImage: "clock.arrow.circlepath")
                    }
                    
                    Button {
                        onEdit()
                    } label: {
                        Label(L10n.edit, systemImage: "pencil")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label(L10n.delete, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .pointingCursor()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
        .pointingCursor()
        .confirmationDialog(L10n.deleteConfirmTitle, isPresented: $showDeleteConfirmation) {
            Button(L10n.delete, role: .destructive) {
                onDelete()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.deleteConfirmMessage)
        }
        .popover(isPresented: $showRecordsSheet) {
            ReminderRecordsView(reminder: reminder)
        }
    }
}

struct ReminderEditSheet: View {
    let reminder: Reminder
    var isNew: Bool
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var manager: ReminderManager
    
    // Local editing state
    @State private var name: String = ""
    @State private var type: ReminderType = .interval
    @State private var intervalMinutes: Int = 60
    @State private var dailyGoal: Int = 5
    @State private var fixedTimes: [TimeInterval] = []
    
    @State private var newTimeSelection = Date()
    
    // Common interval presets
    let intervalPresets = [15, 30, 45, 60, 90, 120]
    // Common goal presets
    let goalPresets = [1, 3, 5, 10, 15, 20]
    
    var body: some View {
        VStack(spacing: 20) {
            Text(isNew ? L10n.newReminder : L10n.editReminder)
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                // Name
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(L10n.namePlaceholder, text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Type Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.type)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $type) {
                        Text(L10n.intervalMode).tag(ReminderType.interval)
                        Text(L10n.fixedTimeMode).tag(ReminderType.fixed)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                
                if type == .interval {
                    // Interval settings
                    intervalSection
                    
                    // Daily Reps (Only shown in Interval mode)
                    dailyRepsSection
                } else {
                    // Fixed Time settings
                    fixedTimeSection
                }
            }
            
            Spacer()
            
            // Buttons
            HStack {
                Button(L10n.cancel) {
                    dismiss()
                }
                
                Spacer()
                
                Button(L10n.save) {
                    saveChanges()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 380, height: 450)
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        name = reminder.name
        type = reminder.type
        intervalMinutes = reminder.intervalMinutes
        dailyGoal = reminder.dailyGoal ?? 5
        fixedTimes = reminder.fixedTimes ?? []
    }
    
    private func saveChanges() {
        reminder.name = name
        reminder.type = type
        reminder.intervalMinutes = intervalMinutes
        reminder.dailyGoal = dailyGoal
        reminder.fixedTimes = fixedTimes
        
        if isNew {
            // Assign to current profile
            reminder.profile = manager.currentProfile
            modelContext.insert(reminder)
        }
        try? modelContext.save()
        manager.refreshReminders()
        dismiss()
    }
    
    var intervalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.interval)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                ForEach(intervalPresets, id: \.self) { mins in
                    Button {
                        intervalMinutes = mins
                    } label: {
                        Text("\(mins)m")
                            .frame(minWidth: 40)
                    }
                    .buttonStyle(.bordered)
                    .tint(intervalMinutes == mins ? .accentColor : .secondary)
                    .controlSize(.small)
                }
            }
            
            HStack {
                Text(L10n.custom)
                    .font(.caption)
                TextField("", value: $intervalMinutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                Text(L10n.min)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    var dailyRepsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.dailyReps)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                ForEach(goalPresets, id: \.self) { goal in
                    Button {
                        dailyGoal = goal
                    } label: {
                        Text("\(goal)")
                            .frame(minWidth: 30)
                    }
                    .buttonStyle(.bordered)
                    .tint(dailyGoal == goal ? .accentColor : .secondary)
                    .controlSize(.small)
                }
            }
            
            HStack {
                Text(L10n.custom)
                    .font(.caption)
                TextField("", value: $dailyGoal, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
            }
        }
    }
    
    var fixedTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.times)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Spacer()
                
                DatePicker("", selection: $newTimeSelection, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(width: 100)
                
                Button {
                    addTime(newTimeSelection)
                } label: {
                    Label(L10n.addTime, systemImage: "plus")
                }
                .buttonStyle(.plain)
                .controlSize(.small)
            }
            
            List {
                let times = fixedTimes.sorted()
                ForEach(times, id: \.self) { time in
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        
                        Text(dateFromSeconds(time), style: .time)
                            .monospacedDigit()
                        
                        Spacer()
                        
                        Button {
                           removeTime(time)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 120)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .alternatingContentBackgroundColors[0]).opacity(0.5))
            .cornerRadius(6)
        }
    }
    
    private func dateFromSeconds(_ seconds: TimeInterval) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return startOfDay.addingTimeInterval(seconds)
    }
    
    private func addTime(_ date: Date) {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let seconds = TimeInterval((comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60)
        
        // Add if not exists (simple duplication check)
        if !fixedTimes.contains(where: { abs($0 - seconds) < 60 }) {
            fixedTimes.append(seconds)
            fixedTimes.sort()
        }
    }
    
    private func removeTime(_ time: TimeInterval) {
        // Remove first matching instance
        if let idx = fixedTimes.firstIndex(of: time) {
            fixedTimes.remove(at: idx)
        }
    }
}

struct AboutSettingsView: View {
    let appVersion: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        return version 
    }()
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // App Icon
            // Use NSImage(named: "AppIcon")
            Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                .resizable()
                .frame(width: 128, height: 128)
            
            VStack(spacing: 8) {
                Text("ZenBeat")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("\(L10n.version) \(appVersion)")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("Copyright © \(Calendar.current.component(.year, from: Date()).formatted(.number.grouping(.never))) Tao Zhou. All rights reserved.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Profiles Settings View
struct ProfilesSettingsView: View {
    @EnvironmentObject var manager: ReminderManager
    @Environment(\.modelContext) private var modelContext
    @State private var newProfileName = ""
    @State private var showAddSheet = false
    @State private var editingProfile: Profile?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(L10n.profiles)
                    .font(.title2.bold())
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Label(L10n.add, systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Profiles List as Cards
            if manager.allProfiles.isEmpty {
                ContentUnavailableView("No Profiles", systemImage: "person.2.slash", description: Text("Create a profile to organize your reminders."))
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(manager.allProfiles, id: \.id) { profile in
                            ProfileCard(
                                profile: profile,
                                isSelected: profile.id == manager.currentProfile?.id,
                                onSelect: {
                                    manager.switchProfile(to: profile)
                                },
                                onEdit: {
                                    editingProfile = profile
                                }
                            )
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            manager.setModelContext(modelContext)
            manager.refreshProfiles()
        }
        .popover(isPresented: $showAddSheet) {
            ProfileAddSheet(manager: manager)
        }
        .popover(item: $editingProfile) { profile in
            ProfileEditSheet(manager: manager, profile: profile)
        }
    }
}

struct ProfileCard: View {
    let profile: Profile
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: profile.icon)
                    .font(.system(size: 18))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            
            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.headline)
                Text("\(profile.reminders?.count ?? 0) reminders")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Checkmark
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            
            // Edit Button
            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .pointingCursor()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .pointingCursor()
    }
}

struct ProfileAddSheet: View {
    @ObservedObject var manager: ReminderManager
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var icon = "person.fill"
    
    let iconOptions = ["person.fill", "briefcase.fill", "house.fill", "figure.walk", "book.fill", "gamecontroller.fill"]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("New Profile")
                .font(.headline)
            
            TextField("Profile Name", text: $name)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Text("Icon:")
                ForEach(iconOptions, id: \.self) { iconName in
                    Button {
                        icon = iconName
                    } label: {
                        Image(systemName: iconName)
                            .font(.title2)
                            .frame(width: 32, height: 32)
                            .background(icon == iconName ? Color.accentColor.opacity(0.2) : Color.clear)
                            .contentShape(Circle())
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .pointingCursor()
                }
            }
            
            HStack {
                Button(L10n.cancel) { dismiss() }
                    .buttonStyle(AppButtonStyle(color: .secondary))
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(L10n.save) {
                    guard !name.isEmpty else { return }
                    manager.createProfile(name: name, icon: icon)
                    dismiss()
                }
                .buttonStyle(AppButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
    }
}

struct ProfileEditSheet: View {
    @ObservedObject var manager: ReminderManager
    @Environment(\.dismiss) private var dismiss
    let profile: Profile
    
    @State private var name: String
    @State private var icon: String
    @State private var dndEnabled: Bool
    @State private var dndStartTime: TimeInterval
    @State private var dndEndTime: TimeInterval
    
    init(manager: ReminderManager, profile: Profile) {
        self.manager = manager
        self.profile = profile
        _name = State(initialValue: profile.name)
        _icon = State(initialValue: profile.icon)
        _dndEnabled = State(initialValue: profile.dndEnabled)
        _dndStartTime = State(initialValue: profile.dndStartTime)
        _dndEndTime = State(initialValue: profile.dndEndTime)
    }
    
    let iconOptions = ["person.fill", "briefcase.fill", "house.fill", "figure.walk", "book.fill", "gamecontroller.fill"]
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Edit Profile")
                .font(.title3.bold())
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Profile Details")
                    .font(.headline)
                
                TextField("Profile Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Text("Icon:")
                    ForEach(iconOptions, id: \.self) { iconName in
                        Button {
                            icon = iconName
                        } label: {
                            Image(systemName: iconName)
                                .font(.title3)
                                .frame(width: 32, height: 32)
                                .background(icon == iconName ? Color.accentColor.opacity(0.2) : Color.clear)
                                .contentShape(Circle())
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .pointingCursor()
                    }
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.doNotDisturb)
                            .font(.headline)
                        Text(L10n.dndDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $dndEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(.green)
                        .controlSize(.mini)
                }
                
                if dndEnabled {
                    HStack {
                        Text(L10n.startTime)
                        Spacer()
                        DatePicker("", selection: dndTimeBinding(for: $dndStartTime), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text(L10n.endTime)
                        Spacer()
                        DatePicker("", selection: dndTimeBinding(for: $dndEndTime), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .frame(width: 100)
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Button(L10n.cancel) { dismiss() }
                    .buttonStyle(AppButtonStyle(color: .secondary))
                    .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(L10n.save) {
                    guard !name.isEmpty else { return }
                    profile.name = name
                    profile.icon = icon
                    profile.dndEnabled = dndEnabled
                    profile.dndStartTime = dndStartTime
                    profile.dndEndTime = dndEndTime
                    manager.refreshReminders()
                    dismiss()
                }
                .buttonStyle(AppButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400, height: 500)
    }
    
    private func dndTimeBinding(for storage: Binding<Double>) -> Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                return today.addingTimeInterval(storage.wrappedValue)
            },
            set: { newDate in
                let calendar = Calendar.current
                let components = calendar.dateComponents([.hour, .minute], from: newDate)
                let seconds = (components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60
                storage.wrappedValue = Double(seconds)
            }
        )
    }
}

struct ReminderRecordsView: View {
    let reminder: Reminder
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.seeRecords)
                    .font(.headline)
                Spacer()
                Button(L10n.close) {
                    dismiss()
                }
                .buttonStyle(.plain)
                .pointingCursor()
            }
            .padding()
            
            Divider()
            
            if let entries = reminder.entries, !entries.isEmpty {
                List {
                    ForEach(entries.sorted(by: { $0.timestamp > $1.timestamp }), id: \.id) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                if let duration = entry.duration {
                                    Text("Duration: \(formatDuration(duration))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .listStyle(.plain)
            } else {
                ContentUnavailableView("No Records", systemImage: "clock")
                    .padding()
            }
        }
        .frame(width: 300, height: 400)
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}


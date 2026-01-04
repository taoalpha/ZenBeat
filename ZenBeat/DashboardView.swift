//
//  DashboardView.swift
//  ZenBeat
//
//  Created by Tao Zhou on 03.01.2026.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject var manager: ReminderManager
    @Environment(\.openWindow) var openWindow
    @ObservedObject private var i18n = LanguageManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                // Profile Picker
                Menu {
                    ForEach(manager.allProfiles, id: \.id) { profile in
                        Button {
                            manager.switchProfile(to: profile)
                        } label: {
                            HStack {
                                Image(systemName: profile.icon)
                                Text(profile.name)
                                if profile.id == manager.currentProfile?.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if let profile = manager.currentProfile {
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
                }
                .menuStyle(.borderlessButton)
                .pointingCursor()
                .fixedSize()
                
                Spacer()
                
                // Snooze Button
                if manager.isSnoozing {
                    Button {
                        manager.cancelSnooze()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.slash.fill")
                                .foregroundStyle(.orange)
                            Text(formatSnoozeTime(manager.snoozeTimeRemaining))
                                .font(.caption)
                                .monospacedDigit()
                        }
                    }
                    .buttonStyle(.plain)
                    .pointingCursor()
                } else {
                    Menu {
                        Button("15 minutes") { manager.snooze(for: 15) }
                        Button("30 minutes") { manager.snooze(for: 30) }
                        Button("1 hour") { manager.snooze(for: 60) }
                        Button("2 hours") { manager.snooze(for: 120) }
                    } label: {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 13))
                    }
                    .menuStyle(.borderlessButton)
                    .pointingCursor()
                    .fixedSize()
                }
                
                Button {
                    // Open settings and trigger add new reminder
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                    // Post notification after a short delay to let Settings window appear
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        NotificationCenter.default.post(name: .addNewReminder, object: nil)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                .pointingCursor()
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Reminder List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(manager.reminders) { reminder in
                        ReminderRow(reminder: reminder)
                    }
                }
                .padding()
            }
            
            if manager.reminders.isEmpty {
                ContentUnavailableView {
                    Label(L10n.noRemindersMenu, systemImage: "bell")
                } description: {
                    Text(L10n.noRemindersSubtitle)
                }
                .padding()
            }
        }
        .frame(width: 300, height: 400)
    }
    
    private func formatSnoozeTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

struct ReminderRow: View {
    let reminder: Reminder
    @EnvironmentObject var manager: ReminderManager
    @State private var isHovering = false
    @ObservedObject private var i18n = LanguageManager.shared
    @Environment(\.openWindow) var openWindow
    
    var body: some View {
        HStack(spacing: 12) {
            // Countdown Circle
            ZStack {
                Circle()
                    .stroke(lineWidth: 4)
                    .opacity(0.2)
                    .foregroundColor(isGoalReached ? .green : (isDue ? .red : .blue))
                
                Circle()
                    .trim(from: 0.0, to: countdownProgress)
                    .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .foregroundColor(isGoalReached ? .green : (isDue ? .red : .blue))
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.easeInOut(duration: 0.3), value: countdownProgress)
                
                if isDue {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Text(shortTimeUntilDue)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(reminder.name)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    // Status badge
                    // Status badge
                    if isGoalReached {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    } else if isDue {
                        Text(L10n.ready)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
                
                // Progress Bar (daily goal)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange)
                            .frame(width: max(0, min(geometry.size.width, geometry.size.width * dailyProgress)))
                    }
                }
                .frame(height: 4)
                
                HStack {
                    let goal = reminder.effectiveDailyGoal
                    if goal > 0 {
                        Text(L10n.xOfYReps(reminder.todayCount, goal))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(reminder.todayCount) reps")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(L10n.log) {
                        manager.logReminder(reminder: reminder, count: 1)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .pointingCursor()
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isDue ? Color.green.opacity(0.6) : Color.clear, lineWidth: 2)
        )
        .onTapGesture(count: 2) {
            manager.reminderToEdit = reminder
            // Open settings window
            if let existingWindow = NSApplication.shared.windows.first(where: { 
                $0.title == L10n.settings
            }), existingWindow.isVisible {
                existingWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                // We need to access openWindow from environment, but we are inside a subview without it passed implicitly?
                // Actually, environment propogates. But we need to use it.
                // Or we can rely on the parent updating manager state?
                // The parent DashboardView has openWindow.
                // Let's use NSApp delegate or just URL scheme if needed?
                // wait, standard openWindow works if environment is available.
                // I'll add @Environment(\.openWindow) to ReminderRow just in case.
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .pointingCursor()
    }
    
    var isGoalReached: Bool {
        return reminder.isDailyGoalReached(lastEntry: manager.getLastEntryTime(for: reminder))
    }
    
    var isDue: Bool {
        return reminder.isDue(
            at: Date(),
            dndEnd: manager.getLatestEffectiveDNDEndTime(),
            lastEntryOverride: manager.getLastEntryTime(for: reminder)
        )
    }
    
    /// Progress from 0 (just started) to 1 (due now)
    var countdownProgress: Double {
        if isGoalReached { return 1.0 }
        let due = reminder.nextDueDate(
            from: Date(),
            dndEnd: manager.getLatestEffectiveDNDEndTime(),
            lastEntryOverride: manager.getLastEntryTime(for: reminder)
        )
        let now = Date()
        
        let totalDuration: TimeInterval
        if reminder.type == .interval {
            totalDuration = TimeInterval(reminder.intervalMinutes * 60)
        } else {
             // For fixed time, duration is time from *last* scheduled (or created) to *next* scheduled.
             // Or maybe just from start of day?
             // Since it's fixed time, "progress" is a bit ambiguous.
             // Let's use time from *previous* slot (or start of day if first) to current slot.
             
             // Simpler approach for visual circular progress:
             // 1. Find the previous slot (or start of day)
             // 2. Linear interpolation between prev and next.
             
             // Hack: let's just make it full circle if due, or time relative to 'now' within last 1 hour?
             // Or better: Let's assume a "window" of relevance?
             // If I have 9am and 5pm. At 1pm, am I 50% done? Technically yes.
             
             // Let's calculate previous anchor point.
             // If no prev slot today, startOfToday.
             let calendar = Calendar.current
             let startOfToday = calendar.startOfDay(for: now)
             
             // effective previous slot
             var prevSlot = startOfToday
             // Find largest slot < nextDue
             // We can infer it from due date.
             
             // If due date is tomorrow, anchor is last slot today.
             // If due date is today slot N, anchor is slot N-1.
             
             // Simplifying: just rely on time remaining.
             // But progress circle needs 0.0 to 1.0.
             // let's use a standard 24h context? No, that's too slow.
             // let's use 60 mins as a standard visual scaler if gap is large?
             
             // Let's try to find the actual span.
             if let lastEntry = manager.getLastEntryTime(for: reminder) {
                 prevSlot = lastEntry
             } else {
                 // No entries? use creation time or start of day
                 prevSlot = reminder.createdAt
             }
             
             // Cap prevSlot to not be too far back if gap is huge?
             // Let's just use the real gap.
             totalDuration = due.timeIntervalSince(prevSlot)
             if totalDuration <= 0 { return 1.0 } // Should not happen if due > prev
        }
        
        // If due is in past, progress is 1.0
        if due <= now { return 1.0 }
        
        // If due is future:
        // Remaining
        let remaining = due.timeIntervalSince(now)
        let elapsed = totalDuration - remaining
        return max(0.0, min(1.0, elapsed / totalDuration))
    }
    
    var shortTimeUntilDue: String {
        if isGoalReached { return "✓" }
        let due = reminder.nextDueDate(
            from: Date(),
            dndEnd: manager.getLatestEffectiveDNDEndTime(),
            lastEntryOverride: manager.getLastEntryTime(for: reminder)
        )
        let remaining = due.timeIntervalSince(Date())
        
        if remaining <= 0 { return "!" }
        
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        
        if minutes >= 60 {
            return "\(minutes / 60)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
    
    var dailyProgress: Double {
        return reminder.dailyProgress
    }
}

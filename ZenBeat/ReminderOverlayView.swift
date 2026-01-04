//
//  ReminderOverlayView.swift
//  ZenBeat
//
//  Created by Tao Zhou on 03.01.2026.
//

import SwiftUI

struct ReminderOverlayView: View {
    @EnvironmentObject private var manager: ReminderManager
    @ObservedObject private var i18n = LanguageManager.shared
    
    var reminder: Reminder? {
        manager.activeOverlayReminder ?? manager.nextDueReminder
    }
    
    var body: some View {
        ZStack {
            // Ambient Zen Gradient Background
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(red: 0.1, green: 0.2, blue: 0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .opacity(0.95)
            
            // Soft atmospheric glow
            Circle()
                .fill(
                    RadialGradient(gradient: Gradient(colors: [Color.teal.opacity(0.15), Color.clear]), center: .center, startRadius: 0, endRadius: 500)
                )
                .frame(width: 1000, height: 1000)
            
            if let reminder = reminder {
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Icon / Motif
                    Image(systemName: "figure.mind.and.body")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan, .teal], startPoint: .top, endPoint: .bottom)
                        )
                        .padding(.bottom, 10)
                        .shadow(color: .teal.opacity(0.5), radius: 20, x: 0, y: 0)
                    
                    // Main message
                    Text(L10n.timeFor(reminder.name))
                        .font(.system(size: 42, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    // Divider
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, .white.opacity(0.3), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 200, height: 1)
                    
                    // Progress
                    VStack(spacing: 12) {
                        let total = reminder.todayCount
                        let goal = reminder.effectiveDailyGoal
                        
                        Text("\(total) / \(goal)")
                            .font(.system(size: 24, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                        
                        // Custom Zen Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                
                                Capsule()
                                    .fill(
                                        LinearGradient(colors: [.cyan, .green], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .frame(width: geo.size.width * min(CGFloat(total) / CGFloat(goal), 1.0))
                                    .shadow(color: .cyan.opacity(0.5), radius: 8)
                            }
                        }
                        .frame(width: 300, height: 8)
                    }
                    
                    Spacer()
                    
                    // Action Buttons
                    VStack(spacing: 20) {
                        Button(action: { recordAndDismiss(reminder: reminder) }) {
                            HStack {
                                Text(L10n.doneButton)
                            }
                            .font(.title2.weight(.medium))
                            .foregroundColor(.black)
                            .frame(width: 200, height: 55)
                            .background(
                                Capsule()
                                    .fill(LinearGradient(colors: [.white, .cyan.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                            )
                            .shadow(color: .cyan.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { dismissOverlay(reminder: reminder) }) {
                            Text(L10n.skip)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 60)
                }
            } else {
                Text(L10n.noActiveReminder)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
    
    private func recordAndDismiss(reminder: Reminder) {
        manager.logReminder(reminder: reminder, count: 1)
    }
    
    private func dismissOverlay(reminder: Reminder) {
        manager.logReminder(reminder: reminder, count: 0, isSkipped: true)
    }
}

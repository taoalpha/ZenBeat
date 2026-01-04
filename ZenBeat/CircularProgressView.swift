//
//  CircularProgressView.swift
//  ZenBeat
//
//  Created by Tao Zhou on 03.01.2026.
//

import SwiftUI

/// Reusable circular progress indicator
struct CircularProgressView: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    var foregroundColor: Color = .blue
    var backgroundColor: Color = .blue
    var backgroundOpacity: Double = 0.3
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: lineWidth)
                .opacity(backgroundOpacity)
                .foregroundColor(backgroundColor)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .foregroundColor(foregroundColor)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: progress)
        }
    }
}

#Preview {
    CircularProgressView(progress: 0.7)
        .frame(width: 100, height: 100)
}

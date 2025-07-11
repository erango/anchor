//
//  MeetingReminderOverlay.swift
//  Anchor
//
//  Created by Eran Goldin on 07/07/2025.
//

import SwiftUI
import AppKit
import AudioToolbox
@preconcurrency import EventKit

// MARK: - Overlay Style Configuration
enum OverlayStyle: String, CaseIterable {
    case modern = "modern"
    case fullScreen = "fullScreen"
    
    var displayName: String {
        switch self {
        case .modern:
            return "Modern Card"
        case .fullScreen:
            return "Full Screen"
        }
    }
    
    var description: String {
        switch self {
        case .modern:
            return "Centered card with native macOS styling"
        case .fullScreen:
            return "Full screen with vibrant red/orange colors"
        }
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Meeting Reminder Overlay (Modern Card Style)
struct MeetingReminderOverlay: View {
    let event: EKEvent
    let calendarManager: CalendarManager
    let onSnooze: () -> Void
    let onDismissForDay: () -> Void
    let colorManager: ColorManager
    
    @State private var timeUntilMeeting: String = ""
    @State private var currentTime: String = ""
    @State private var updateTask: Task<Void, Never>?
    @State private var isVisible = false
    @State private var shakeOffset: CGFloat = 0
    @State private var showingMenu = false
    
    var body: some View {
        ZStack {
            // Modal background with proper darkness for macOS - captures ALL events
            Color.black
                .opacity(0.5) // Darker for proper modal feel
                .ignoresSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    // macOS standard modal feedback - shake and beep
                    performModalFeedback()
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            // Absorb all drag events and provide feedback
                            performModalFeedback()
                        }
                )
                .accessibilityHidden(true) // Background is decorative
            
            // Main reminder card - SINGLE WINDOW ONLY
            VStack(spacing: 0) {
                // Top toolbar
                HStack {
                    Spacer()
                    
                    Menu {
                        Button("Snooze for 5 minutes") {
                            cleanupAndSnooze()
                        }
                        .keyboardShortcut("s")
                        
                        Button("Remind me 10 minutes before") {
                            calendarManager.snoozeEventUntil(for: event, minutesBeforeEvent: 10)
                            cleanupAndSnooze()
                        }
                        .keyboardShortcut("1")
                        
                        Button("Remind me 2 minutes before") {
                            calendarManager.snoozeEventUntil(for: event, minutesBeforeEvent: 2)
                            cleanupAndSnooze()
                        }
                        .keyboardShortcut("2")
                        
                        Divider()
                        
                        Button("Dismiss for today") {
                            onDismissForDay()
                        }
                        .keyboardShortcut("d")
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title)
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .accessibilityLabel("Reminder options")
                    .accessibilityHint("Choose snooze or dismiss options for this reminder")
                    .help("Options for this reminder")
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()
                
                // Main content area - COMPACT DESKTOP LAYOUT
                VStack(spacing: 20) {
                    // Title section - more compact
                    VStack(spacing: 8) {
                        Text("Meeting Reminder")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)
                        
                        Text(event.title ?? "Untitled Meeting")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Meeting reminder for \(event.title ?? "untitled meeting")")
                    .accessibilityAddTraits(.isHeader)
                    
                    // Countdown section - horizontally organized for desktop
                    HStack(spacing: 40) {
                        // Time countdown
                        VStack(spacing: 8) {
                            Text("Starts in")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            
                            Text(timeUntilMeeting)
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                                .accessibilityLabel("Time until meeting")
                                .accessibilityValue(accessibleTimeText)
                        }
                        
                        // Meeting details
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                Text("at \(calendarManager.formatTime(event.startDate))")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Meeting start time: \(calendarManager.formatTime(event.startDate))")
                            
                            // Location info
                            if let location = event.location, !location.isEmpty {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundStyle(.blue)
                                        .font(.caption)
                                    Text(location)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Meeting location: \(location)")
                            }
                            
                            // Attendees info
                            if event.hasAttendees {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                    Text("Has attendees")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Meeting has other attendees")
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Meeting countdown and details")
                    
                    // Prominent dismiss button
                    Button(action: {
                        calendarManager.snoozeEvent(for: event, minutes: 5)
                        cleanupAndSnooze()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.badge.checkmark.fill")
                                .font(.body)
                            Text("Snooze 5 min")
                                .font(.body.weight(.medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.accentColor, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Snooze reminder for 5 minutes")
                    .accessibilityHint("Dismiss this reminder and snooze for 5 minutes. Press Escape or Enter as shortcut.")
                    .help("Snooze for 5 minutes (Esc or Enter)")
                }
                .padding(.top, 16)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .frame(width: 520, height: 200)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 12) // Enhanced shadow for modal prominence
            .scaleEffect(isVisible ? 1.0 : 0.8)
            .opacity(isVisible ? 1.0 : 0.0)
            .offset(x: shakeOffset) // Add shake animation
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isVisible)
            .animation(.easeInOut(duration: 0.08), value: shakeOffset)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Meeting reminder overlay")
            .accessibilityValue(overlayAccessibilityValue)
        }
        .onAppear {
            isVisible = true
            startTimeUpdates()
        }
        .onDisappear {
            cleanup()
        }
        .focusable()
        .onKeyPress(.escape) {
            calendarManager.snoozeEvent(for: event, minutes: 5)
            cleanupAndSnooze()
            return .handled
        }
        .onKeyPress(.return) {
            calendarManager.snoozeEvent(for: event, minutes: 5)
            cleanupAndSnooze()
            return .handled
        }
        .onKeyPress("s") {
            cleanupAndSnooze()
            return .handled
        }
        .onKeyPress("d") {
            onDismissForDay()
            return .handled
        }
        .onKeyPress("1") {
            calendarManager.snoozeEventUntil(for: event, minutesBeforeEvent: 10)
            cleanupAndSnooze()
            return .handled
        }
        .onKeyPress("2") {
            calendarManager.snoozeEventUntil(for: event, minutesBeforeEvent: 2)
            cleanupAndSnooze()
            return .handled
        }
    }
    
    // MARK: - Accessibility Helpers
    
    private var accessibleTimeText: String {
        if timeUntilMeeting == "Started" {
            return "Meeting has started"
        }
        
        let components = timeUntilMeeting.components(separatedBy: ":")
        if components.count == 2, let minutes = Int(components[0]), let seconds = Int(components[1]) {
            if minutes > 0 {
                return "\(minutes) minutes and \(seconds) seconds"
            } else {
                return "\(seconds) seconds"
            }
        }
        
        return timeUntilMeeting
    }
    
    private var overlayAccessibilityValue: String {
        let title = event.title ?? "Untitled meeting"
        let time = calendarManager.formatTime(event.startDate)
        let location = event.location?.isEmpty == false ? " at \(event.location!)" : ""
        
        return "\(title) starts at \(time)\(location). \(accessibleTimeText) remaining."
    }
    
    // MARK: - Action Helpers
    
    private func cleanupAndSnooze() {
        cleanup()
        onSnooze()
    }
    
    private func startTimeUpdates() {
        updateTask?.cancel()
        updateTask = Task { @MainActor in
            while !Task.isCancelled {
                updateTimes()
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    break
                }
            }
        }
    }
    
    private func updateTimes() {
        let now = Date()
        
        // Update time until meeting
        let timeInterval = event.startDate.timeIntervalSince(now)
        
        if timeInterval <= 0 {
            timeUntilMeeting = "Started"
        } else {
            let minutes = Int(timeInterval) / 60
            let seconds = Int(timeInterval) % 60
            timeUntilMeeting = String(format: "%d:%02d", minutes, seconds)
        }
        
        // Update current time
        currentTime = DateFormatter.timeFormatter.string(from: now)
    }
    
    // Safe cleanup methods to prevent crashes
    private func cleanup() {
        updateTask?.cancel()
        updateTask = nil
    }
    
    // macOS-standard modal feedback
    private func performModalFeedback() {
        // Play system alert sound
        AudioServicesPlaySystemSound(kSystemSoundID_UserPreferredAlert)
        
        // Perform window shake animation
        withAnimation(.easeInOut(duration: 0.08)) {
            shakeOffset = 8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeInOut(duration: 0.08)) {
                shakeOffset = -8
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeInOut(duration: 0.08)) {
                    shakeOffset = 4
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.easeInOut(duration: 0.08)) {
                        shakeOffset = 0
                    }
                }
            }
        }
    }
}

// MARK: - Full Screen Reminder Overlay (Original Design)
struct FullScreenReminderOverlay: View {
    let event: EKEvent
    let calendarManager: CalendarManager
    let onSnooze: () -> Void
    let onDismissForDay: () -> Void
    let colorManager: ColorManager
    
    @State private var timeUntilMeeting: String = ""
    @State private var updateTask: Task<Void, Never>?
    @State private var isVisible = false
    @State private var pulseAnimation = false
    @State private var menuButtonHovered = false
    
    var body: some View {
        ZStack {
            // Full-screen invisible background that captures ALL mouse events
            // This prevents any clicks from passing through to underlying apps
            Color.clear
                .ignoresSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Absorb all tap events - do nothing but prevent pass-through
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            // Absorb all drag events
                        }
                )
            
            // Circular gradient background
            RadialGradient(
                gradient: Gradient(colors: [
                    colorManager.activeColor.opacity(0.95),
                    colorManager.activeColor.opacity(0.85),
                    colorManager.secondaryColor.opacity(0.75),
                    colorManager.secondaryColor.opacity(0.65)
                ]),
                center: .center,
                startRadius: 200,
                endRadius: 800
            )
            .ignoresSafeArea(.all)
            
            // Centered breathing circle animation
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 50,
                        endRadius: 400
                    )
                )
                .frame(width: 600, height: 600)
                .scaleEffect(pulseAnimation ? 1.1 : 0.9)
                .animation(
                    .easeInOut(duration: 6.0)
                    .repeatForever(autoreverses: true),
                    value: pulseAnimation
                )
            
            // Main content
            VStack(spacing: 32) {
                // Menu button in top-right corner
                HStack {
                    Spacer()
                    
                    Menu {
                        Button("Snooze for 5 minutes") {
                            calendarManager.snoozeEvent(for: event, minutes: 5)
                            cleanupAndSnooze()
                        }
                        .keyboardShortcut("s")
                        
                        Button("Remind me 10 minutes before") {
                            calendarManager.snoozeEventUntil(for: event, minutesBeforeEvent: 10)
                            cleanupAndSnooze()
                        }
                        .keyboardShortcut("1")
                        
                        Button("Remind me 2 minutes before") {
                            calendarManager.snoozeEventUntil(for: event, minutesBeforeEvent: 2)
                            cleanupAndSnooze()
                        }
                        .keyboardShortcut("2")
                        
                        Divider()
                        
                        Button("Dismiss for today") {
                            cleanup()
                            onDismissForDay()
                        }
                        .keyboardShortcut("d")
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(menuButtonHovered ? .white : .white.opacity(0.9))
                            .scaleEffect(menuButtonHovered ? 1.1 : 1.0)
                    }
                    .menuStyle(.borderlessButton)
                    .animation(.easeInOut(duration: 0.15), value: menuButtonHovered)
                    .onHover { hovering in
                        menuButtonHovered = hovering
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .padding(.top, 40)
                    .padding(.trailing, 40)
                }
                
                // Top section
                VStack(spacing: 32) {
                    // Alert icon with strong animation
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    // Title section with high contrast
                    VStack(spacing: 16) {
                        Text("MEETING REMINDER")
                            .font(.system(size: 42, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 3)
                        
                        Text(event.title ?? "Untitled Meeting")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                    }
                }
                .padding(.top, 80)
                
                Spacer()
                
                // Countdown with dramatic styling - VERTICALLY CENTERED
                VStack(spacing: 16) {
                    Text("STARTS IN")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                    
                    Text(timeUntilMeeting)
                        .font(.system(size: 80, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                    
                    Text("at \(calendarManager.formatTime(event.startDate))")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                }
                
                Spacer()
                
                // Bottom section
                VStack(spacing: 24) {
                    // Location info with high visibility
                    if let location = event.location, !location.isEmpty {
                        VStack(spacing: 8) {
                            HStack(spacing: 12) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white)
                                
                                Text(location)
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                            }
                            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                        }
                    }
                    
                    // Prominent dismiss button
                    Button(action: {
                        calendarManager.snoozeEvent(for: event, minutes: 5)
                        cleanupAndSnooze()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.badge.checkmark.fill")
                                .font(.system(size: 20, weight: .semibold))
                            Text("SNOOZE 5 MINUTES")
                                .font(.system(size: 20, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.black.opacity(0.3))
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Snooze reminder for 5 minutes")
                    .accessibilityHint("Dismiss this reminder and snooze for 5 minutes. Press Escape or Enter as shortcut.")
                    .help("Snooze for 5 minutes (Esc or Enter)")
                    .padding(.bottom, 40)
                }
            }
            .padding(.bottom, 24) // Additional padding to ensure buttons are visible
        }
        .onAppear {
            isVisible = true
            pulseAnimation = true
            startTimeUpdates()
        }
        .onDisappear {
            cleanup()
        }
        .focusable()
        .onKeyPress(.escape) {
            calendarManager.snoozeEvent(for: event, minutes: 5)
            cleanupAndSnooze()
            return .handled
        }
        .onKeyPress(.return) {
            calendarManager.snoozeEvent(for: event, minutes: 5)
            cleanupAndSnooze()
            return .handled
        }
        .onKeyPress("s") {
            calendarManager.snoozeEvent(for: event, minutes: 5)
            cleanupAndSnooze()
            return .handled
        }
        .onKeyPress("d") {
            cleanup()
            onDismissForDay()
            return .handled
        }
        .onKeyPress("1") {
            calendarManager.snoozeEventUntil(for: event, minutesBeforeEvent: 10)
            cleanupAndSnooze()
            return .handled
        }
        .onKeyPress("2") {
            calendarManager.snoozeEventUntil(for: event, minutesBeforeEvent: 2)
            cleanupAndSnooze()
            return .handled
        }
    }
    
    private func startTimeUpdates() {
        updateTask?.cancel()
        updateTask = Task { @MainActor in
            while !Task.isCancelled {
                updateTimes()
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    break
                }
            }
        }
    }
    
    private func updateTimes() {
        let now = Date()
        let timeInterval = event.startDate.timeIntervalSince(now)
        
        if timeInterval <= 0 {
            timeUntilMeeting = "STARTED"
        } else {
            let minutes = Int(timeInterval) / 60
            let seconds = Int(timeInterval) % 60
            timeUntilMeeting = String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    // Safe cleanup methods to prevent crashes
    private func cleanup() {
        updateTask?.cancel()
        updateTask = nil
    }
    
    private func cleanupAndSnooze() {
        cleanup()
        onSnooze()
    }
}

// MARK: - Mini Reminder Overlay (Bottom Right Corner)
struct MiniReminderOverlay: View {
    let event: EKEvent
    let style: OverlayStyle
    let calendarManager: CalendarManager
    let onTap: () -> Void
    let onSnooze: () -> Void
    let onDismissForDay: () -> Void
    let colorManager: ColorManager
    
    @State private var timeUntilMeeting: String = ""
    @State private var updateTask: Task<Void, Never>?
    @State private var isVisible = false
    @State private var pulseAnimation = false
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Content based on style
            if style == .modern {
                modernMiniStyle
            } else {
                fullScreenMiniStyle
            }
        }
        .frame(width: 280, height: 120)
        .background(backgroundForStyle)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(isHovered ? 0.3 : 0.2), radius: isHovered ? 12 : 8, x: 0, y: isHovered ? 6 : 4)
        .scaleEffect(isHovered ? 1.02 : (isVisible ? 1.0 : 0.8))
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isVisible)
        .animation(.easeInOut, value: isHovered)
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            isVisible = true
            pulseAnimation = true
            startTimeUpdates()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    @ViewBuilder
    private var modernMiniStyle: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "bell.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(colorManager.activeColor)
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "Meeting")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if let location = event.location, !location.isEmpty {
                    Text("📍 \(location)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Text("Starts in \(timeUntilMeeting)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(colorManager.activeColor)
                    .monospacedDigit()
            }
            
            Spacer()
            
            // Menu button
            Menu {
                Button("Snooze") {
                    calendarManager.snoozeEvent(for: event, minutes: 5)
                    onSnooze()
                }
                
                Button("Remind me 10 minutes before the event") {
                    calendarManager.snoozeEventUntil(for: event, minutesBeforeEvent: 10)
                    onSnooze()
                }
                
                Button("Remind me 2 minutes before the event") {
                    calendarManager.snoozeEventUntil(for: event, minutesBeforeEvent: 2)
                    onSnooze()
                }
                
                Divider()
                
                Button("Dismiss for the day") {
                    onDismissForDay()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var fullScreenMiniStyle: some View {
        HStack(spacing: 12) {
            // Icon with full screen style
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "Meeting")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                if let location = event.location, !location.isEmpty {
                    Text("📍 \(location)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
                
                Text("STARTS IN \(timeUntilMeeting)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            
            Spacer()
            
            // Menu button
            Menu {
                Button("Snooze") {
                    calendarManager.snoozeEvent(for: event, minutes: 5)
                    onSnooze()
                }
                
                Button("Remind me 10 minutes before the event") {
                    calendarManager.snoozeEventUntil(for: event, minutesBeforeEvent: 10)
                    onSnooze()
                }
                
                Button("Remind me 2 minutes before the event") {
                    calendarManager.snoozeEventUntil(for: event, minutesBeforeEvent: 2)
                    onSnooze()
                }
                
                Divider()
                
                Button("Dismiss for the day") {
                    onDismissForDay()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var backgroundForStyle: some View {
        if style == .modern {
            // Modern style background with proper material clipping
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(NSColor.separatorColor).opacity(0.2), lineWidth: 0.5)
                )
        } else {
            // Full screen style background
            LinearGradient(
                gradient: Gradient(colors: [
                    colorManager.secondaryColor.opacity(0.85),
                    colorManager.activeColor.opacity(0.75)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private func startTimeUpdates() {
        updateTask?.cancel()
        updateTask = Task { @MainActor in
            while !Task.isCancelled {
                updateTimes()
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    break
                }
            }
        }
    }
    
    private func updateTimes() {
        let now = Date()
        let timeInterval = event.startDate.timeIntervalSince(now)
        
        if timeInterval <= 0 {
            timeUntilMeeting = "STARTED"
        } else {
            let minutes = Int(timeInterval) / 60
            let seconds = Int(timeInterval) % 60
            timeUntilMeeting = String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func cleanup() {
        updateTask?.cancel()
        updateTask = nil
    }
}


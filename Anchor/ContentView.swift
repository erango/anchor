//
//  ContentView.swift
//  Anchor
//
//  Created by Eran Goldin on 07/07/2025.
//

import SwiftUI
@preconcurrency import EventKit

struct ContentView: View {
    let appState: AppState
    @State private var calendarManager = CalendarManager()
    
    var body: some View {
        @Bindable var bindableAppState = appState
        
        NavigationSplitView {
            // Sidebar
            SidebarView(calendarManager: calendarManager, appState: appState)
        } detail: {
            // Main content area
            MainContentView(calendarManager: calendarManager)
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $bindableAppState.showingSettings) {
            SettingsView(calendarManager: calendarManager)
        }
        .onAppear {
            calendarManager.requestPermissionAgain()
        }
    }
}

// MARK: - Sidebar View
struct SidebarView: View {
    let calendarManager: CalendarManager
    let appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) { // 24pt for major sections
            // App header with proper spacing
            VStack(alignment: .leading, spacing: 8) { // 8pt for related content
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title)
                        .foregroundStyle(.white, .blue)
                        .symbolRenderingMode(.palette)
                    
                    Text("Anchor")
                        .font(.title.weight(.semibold))
                }
                
                Text("Meeting reminder app")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            .padding(.bottom, 16) // 16pt separation from status
            
            Divider()
            
            // Status section with semantic spacing
            VStack(alignment: .leading, spacing: 16) { // 16pt for grouped content
                VStack(alignment: .leading, spacing: 8) { // 8pt for labels
                    Text("Status")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    // Only show critical calendar access status
                        StatusRow(
                            title: "Calendar Access",
                            status: calendarStatusInfo
                        )
                }
            }
            
            Divider()
            
            // Actions section with proper grouping
            VStack(alignment: .leading, spacing: 16) { // 16pt for action groups
                VStack(alignment: .leading, spacing: 8) { // 8pt for section content
                    Text("Actions")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    // Essential action buttons with consistent spacing
                    VStack(spacing: 8) { // 8pt between action items
                        ActionButton(
                            title: "Refresh Events",
                            systemImage: "arrow.clockwise",
                            action: { calendarManager.refreshEvents() }
                        )
                        
                        ActionButton(
                            title: "Settings",
                            systemImage: "gearshape.fill",
                            action: { appState.openSettings() }
                        )
                    }
                }
            }
            
            Spacer()
        }
        .padding(24) // 24pt standard container padding
        .frame(minWidth: 240) // Proper minimum sidebar width
    }
    
    private var calendarStatusInfo: (icon: String, text: String, color: Color) {
        if calendarManager.hasCalendarAccess {
            return (icon: "checkmark.circle.fill", text: "Authorized", color: .green)
        } else if let error = calendarManager.errorMessage {
            return (icon: "exclamationmark.triangle.fill", text: "Denied", color: .red)
        } else {
            return (icon: "clock.fill", text: "Checking...", color: .orange)
        }
    }
}

// MARK: - Sidebar Action Button
struct ActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .symbolRenderingMode(.hierarchical)
        .accessibilityLabel(title)
        .accessibilityHint("Activate to \(title.lowercased())")
        .help(accessibilityHelpText)
    }
    
    private var accessibilityHelpText: String {
        switch title {
        case "Refresh Events":
            return "Reload your calendar events to check for updates"
        case "Settings":
            return "Open Anchor settings and preferences"
        default:
            return "Activate to \(title.lowercased())"
        }
    }
}

// MARK: - Main Content View
struct MainContentView: View {
    let calendarManager: CalendarManager
    
    var body: some View {
        Group {
            if !calendarManager.hasCalendarAccess {
                if let errorMessage = calendarManager.errorMessage {
                    ErrorStateView(
                        title: "Calendar Access Required",
                        message: errorMessage,
                        actionTitle: "Open System Preferences",
                        action: {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    )
                } else {
                    LoadingStateView(message: "Requesting calendar access...")
                }
            } else {
                if calendarManager.upcomingEvents.isEmpty {
                    EmptyStateView()
                } else {
                    EventsListView(events: calendarManager.upcomingEvents, calendarManager: calendarManager)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color(NSColor.controlBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main content area")
    }
}

// MARK: - Status Components

struct StatusRow: View {
    let title: String
    let status: (icon: String, text: String, color: Color)
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
            
            Spacer()
            
            HStack(spacing: 4) { // 4pt for icon-text in status
                Image(systemName: status.icon)
                    .font(.caption2)
                    .foregroundStyle(status.color)
                    .symbolRenderingMode(.hierarchical)
                
                Text(status.text)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(status.color)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(status.text)")
        .accessibilityValue(statusAccessibilityValue)
    }
    
    private var statusAccessibilityValue: String {
        switch status.text {
        case "Authorized":
            return "Working properly"
        case "Denied":
            return "Action required - calendar access is needed"
        case "Checking...":
            return "Please wait while checking access"
        default:
            return status.text
        }
    }
}

// MARK: - State Views with Improved Accessibility
struct ErrorStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(.orange)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true) // Decorative
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityHint("Opens System Settings to grant calendar access")
                .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error state")
        .accessibilityValue("\(title). \(message)")
    }
}

struct LoadingStateView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 24) { // 24pt spacing for loading content
            ProgressView()
                .controlSize(.large)
                .scaleEffect(1.2)
                .accessibilityLabel("Loading")
            
            Text(message)
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(32) // 32pt container padding
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading: \(message)")
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 48) {
            Image(systemName: "calendar")
                .font(.system(size: 80, weight: .thin))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true) // Decorative
            
            VStack(spacing: 16) { // 16pt for text block spacing
                Text("No Upcoming Events")
                    .font(.title2.weight(.semibold))
                
                Text("When you have meetings scheduled, they'll appear here and Anchor will remind you before they start.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24) // 24pt horizontal breathing room
            }
        }
        .padding(32) // 32pt container padding
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No upcoming events")
        .accessibilityValue("When you have meetings scheduled, they'll appear here and Anchor will remind you before they start.")
    }
}

// MARK: - Events List with Improved Layout
struct EventsListView: View {
    let events: [EKEvent]
    let calendarManager: CalendarManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with semantic spacing
            VStack(alignment: .leading, spacing: 8) { // 8pt for header content
                HStack {
                    Text("Today's agenda")
                        .font(.title2.weight(.semibold))
                    
                    Spacer()
                    
                    Text("\(events.count) \(events.count == 1 ? "event" : "events")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.fill.tertiary, in: Capsule())
                }
                
                Text("Reminders will appear \(calendarManager.reminderMinutesBefore) minutes before each meeting")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24) // 24pt horizontal container padding
            .padding(.top, 24) // 24pt top padding
            .padding(.bottom, 16) // 16pt separation from list
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Today's agenda: \(events.count) \(events.count == 1 ? "event" : "events")")
            .accessibilityValue("Reminders will appear \(calendarManager.reminderMinutesBefore) minutes before each meeting")
            
            // Events list with proper spacing
            ScrollView {
                LazyVStack(spacing: 0) { // No spacing between items - dividers handle separation
                    ForEach(events, id: \.eventIdentifier) { event in
                        EventRowView(event: event, calendarManager: calendarManager)
                        
                        if event.eventIdentifier != events.last?.eventIdentifier {
                            Divider()
                                .padding(.leading, 24) // Inset divider
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Events list")
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct EventRowView: View {
    let event: EKEvent
    let calendarManager: CalendarManager
    @State private var isRowHovered = false
    
    var body: some View {
        HStack(spacing: 16) { // 16pt spacing for clean separation
            // Time column - fixed width for alignment
            VStack(alignment: .trailing, spacing: 4) {
                Text(calendarManager.formatTime(event.startDate))
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                
                Text(formatDuration(event))
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(width: 70, alignment: .trailing)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Meeting time")
            .accessibilityValue("\(calendarManager.formatTime(event.startDate)), duration \(formatDuration(event))")
            
            // Content column - expandable
            VStack(alignment: .leading, spacing: 8) {
                // Title and status
                HStack(alignment: .top, spacing: 8) {
                Text(event.title ?? "Untitled Event")
                        .font(.system(.body, design: .default, weight: .semibold))
                        .foregroundStyle(.primary)
                    .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer(minLength: 0)
                    
                    // Time until meeting badge
                    Text(timeUntilEventText(for: event.startDate))
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(timeUntilColor(for: event.startDate), in: Capsule())
                        .monospacedDigit()
                        .accessibilityLabel("Time until meeting")
                        .accessibilityValue(timeUntilAccessibilityText(for: event.startDate))
                }
                
                // Event details with improved hierarchy
                VStack(alignment: .leading, spacing: 4) {
                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "location")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .frame(width: 12)
                                .accessibilityHidden(true)
                            
                            Text(location)
                                .font(.system(.subheadline, design: .default, weight: .regular))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Location: \(location)")
                    }
                    
                    if event.hasAttendees {
                        HStack(spacing: 8) {
                            Image(systemName: "person.2")
                                .font(.caption)
                        .foregroundStyle(.green)
                                .frame(width: 12)
                                .accessibilityHidden(true)
                            
                            Text("Meeting with others")
                                .font(.system(.subheadline, design: .default, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Meeting with other attendees")
                    }
                }
            }
            
            // Reminder toggle button - fixed position
            Button {
                if calendarManager.isDismissedForDay(for: event) {
                    // If dismissed for day, re-enable it (undismiss)
                    calendarManager.undismissForDay(for: event)
                } else {
                    // Otherwise toggle the normal reminder setting
                    calendarManager.toggleReminder(for: event)
                }
            } label: {
                Image(systemName: reminderIconName(for: event))
                    .font(.body.weight(.medium))
                    .foregroundStyle(reminderIconColor(for: event))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(reminderTooltip(for: event))
            .accessibilityLabel(reminderAccessibilityLabel(for: event))
            .accessibilityHint(reminderAccessibilityHint(for: event))
            .keyboardShortcut("r", modifiers: [.command])
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isRowHovered ? Color(NSColor.controlAccentColor).opacity(0.08) : Color.clear)
        )
        .animation(.easeInOut, value: isRowHovered)
        .onHover { hovering in
            isRowHovered = hovering
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(eventAccessibilityLabel)
        .accessibilityActions {
            Button("Toggle reminder") {
                if calendarManager.isDismissedForDay(for: event) {
                    calendarManager.undismissForDay(for: event)
                } else {
                    calendarManager.toggleReminder(for: event)
                }
            }
            .keyboardShortcut("r")
        }
    }
    
    // MARK: - Accessibility Helpers
    
    private var eventAccessibilityLabel: String {
        let title = event.title ?? "Untitled Event"
        let time = calendarManager.formatTime(event.startDate)
        let duration = formatDuration(event)
        let location = event.location?.isEmpty == false ? ", at \(event.location!)" : ""
        let attendees = event.hasAttendees ? ", with other attendees" : ""
        
        return "\(title), \(time), \(duration)\(location)\(attendees)"
    }
    
    private func reminderAccessibilityLabel(for event: EKEvent) -> String {
        if calendarManager.isDismissedForDay(for: event) {
            return "Reminder disabled for today"
        } else if calendarManager.isReminderEnabled(for: event) {
            return "Reminder enabled"
        } else {
            return "Reminder disabled"
        }
    }
    
    private func reminderAccessibilityHint(for event: EKEvent) -> String {
        if calendarManager.isDismissedForDay(for: event) {
            return "Enable reminder for this meeting"
        } else if calendarManager.isReminderEnabled(for: event) {
            return "Disable reminder for this meeting"
        } else {
            return "Enable reminder for this meeting"
        }
    }
    
    private func timeUntilAccessibilityText(for date: Date) -> String {
        let now = Date()
        let timeInterval = date.timeIntervalSince(now)
        
        if timeInterval <= 0 {
            return "Meeting is happening now"
        }
        
        let totalMinutes = Int(timeInterval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return minutes > 0 ? "\(hours) hours and \(minutes) minutes" : "\(hours) hours"
        } else {
            return "\(minutes) minutes"
        }
    }
    
    private func formatDuration(_ event: EKEvent) -> String {
        let duration = event.endDate.timeIntervalSince(event.startDate) / 60
        let hours = Int(duration) / 60
        let minutes = Int(duration) % 60
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func timeUntilEventText(for date: Date) -> String {
        let now = Date()
        let timeInterval = date.timeIntervalSince(now)
        
        if timeInterval <= 0 {
            return "Now"
        }
        
        let totalMinutes = Int(timeInterval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 30 {
            return "\(minutes)m"
        } else if minutes > 15 {
            return "\(minutes)m"
        } else if minutes > 5 {
            return "\(minutes)m"
        } else {
            return "Soon"
        }
    }
    
    private func timeUntilColor(for date: Date) -> Color {
        let now = Date()
        let timeInterval = date.timeIntervalSince(now)
        let minutes = Int(timeInterval) / 60
        
        if minutes <= 0 {
            return .red
        } else if minutes <= 5 {
            return .orange
        } else if minutes <= 15 {
            return .yellow
        } else {
            return .accentColor
        }
    }
    
    // MARK: - Reminder Icon Helpers
    
    private func reminderIconName(for event: EKEvent) -> String {
        if calendarManager.isDismissedForDay(for: event) {
            return "bell.badge.waveform" // Dismissed for today
        } else if calendarManager.isReminderEnabled(for: event) {
            return "bell.fill" // Active reminder
        } else {
            return "bell.slash" // Disabled reminder
        }
    }
    
    private func reminderIconColor(for event: EKEvent) -> Color {
        if calendarManager.isDismissedForDay(for: event) {
            return .orange // Dismissed for today
        } else if calendarManager.isReminderEnabled(for: event) {
            return .accentColor // Active reminder
        } else {
            return .secondary // Disabled reminder
        }
    }
    
    private func reminderTooltip(for event: EKEvent) -> String {
        if calendarManager.isDismissedForDay(for: event) {
            return "Dismissed for today - click to re-enable"
        } else if calendarManager.isReminderEnabled(for: event) {
            return "Disable reminder"
        } else {
            return "Enable reminder"
        }
    }
}

// MARK: - Reminder Timing Options
enum ReminderTiming: String, CaseIterable, Identifiable {
    case five = "5"
    case ten = "10"
    case fifteen = "15"
    case twenty = "20"
    case twentyFive = "25"
    case thirty = "30"
    case custom = "custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .five: return "5 minutes"
        case .ten: return "10 minutes"
        case .fifteen: return "15 minutes"
        case .twenty: return "20 minutes"
        case .twentyFive: return "25 minutes"
        case .thirty: return "30 minutes"
        case .custom: return "Custom"
        }
    }
    
    var minutes: Int? {
        switch self {
        case .five: return 5
        case .ten: return 10
        case .fifteen: return 15
        case .twenty: return 20
        case .twentyFive: return 25
        case .thirty: return 30
        case .custom: return nil
        }
    }
    
    static func from(minutes: Int) -> ReminderTiming {
        switch minutes {
        case 5: return .five
        case 10: return .ten
        case 15: return .fifteen
        case 20: return .twenty
        case 25: return .twentyFive
        case 30: return .thirty
        default: return .custom
        }
    }
}

// MARK: - Enhanced Settings Sections with User-Focused Organization
enum SettingsSection: String, CaseIterable, Identifiable {
    case quickSetup = "Quick Setup"
    case notifications = "Notifications" 
    case appearance = "Appearance"
    case advanced = "Advanced"
    case about = "About"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .quickSetup: return "wand.and.stars"
        case .notifications: return "bell.fill"
        case .appearance: return "paintbrush.fill"
        case .advanced: return "gear.badge"
        case .about: return "info.circle"
        }
    }
    
    var description: String {
        switch self {
        case .quickSetup: return "Essential settings to get started quickly"
        case .notifications: return "Reminder timing, style, and behavior"
        case .appearance: return "Colors, themes, and visual customization"
        case .advanced: return "System integration and power user options"
        case .about: return "App information, support, and credits"
        }
    }
    
    var badge: String? {
        switch self {
        case .quickSetup: return "New"
        case .notifications: return nil
        case .appearance: return nil
        case .advanced: return nil
        case .about: return nil
        }
    }
}

// MARK: - Enhanced Settings View with Improved Navigation
struct SettingsView: View {
    let calendarManager: CalendarManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: SettingsSection = .quickSetup
    @State private var selectedTiming: ReminderTiming
    @State private var customMinutes: String
    @State private var searchText: String = ""
    
    init(calendarManager: CalendarManager) {
        self.calendarManager = calendarManager
        let currentMinutes = calendarManager.reminderMinutesBefore
        self._selectedTiming = State(initialValue: ReminderTiming.from(minutes: currentMinutes))
        self._customMinutes = State(initialValue: ReminderTiming.from(minutes: currentMinutes) == .custom ? String(currentMinutes) : "")
    }
    
    var body: some View {
        NavigationSplitView {
            // Enhanced Settings Sidebar
            EnhancedSettingsSidebar(
                selectedSection: $selectedSection,
                searchText: $searchText,
                calendarManager: calendarManager
            )
        } detail: {
            // Settings Content
            SettingsContent(
                selectedSection: selectedSection,
                calendarManager: calendarManager,
                selectedTiming: $selectedTiming,
                customMinutes: $customMinutes,
                searchText: searchText
            )
        }
        .navigationSplitViewStyle(.balanced)
        .frame(width: 900, height: 650)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)
                    Text("Anchor Settings")
                    .font(.title2.weight(.semibold))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Anchor Settings")
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary, .quaternary)
                        .symbolRenderingMode(.palette)
                }
                .buttonStyle(.borderless)
                .help("Close Settings")
                .accessibilityLabel("Close settings")
                .accessibilityHint("Close the settings window")
                .keyboardShortcut(.cancelAction)
                .keyboardShortcut("w", modifiers: [.command])
            }
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search settings...")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Settings window")
    }
}

// MARK: - Enhanced Settings Sidebar with Search and Quick Access
struct EnhancedSettingsSidebar: View {
    @Binding var selectedSection: SettingsSection
    @Binding var searchText: String
    let calendarManager: CalendarManager
    
    var filteredSections: [SettingsSection] {
        if searchText.isEmpty {
            return SettingsSection.allCases
        } else {
            return SettingsSection.allCases.filter { section in
                section.rawValue.localizedCaseInsensitiveContains(searchText) ||
                section.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func resetToDefaults() {
        calendarManager.reminderMinutesBefore = 5
        calendarManager.overlayStyle = .modern
        calendarManager.timeFormat = .twelveHour
        calendarManager.colorManager.resetToDefault()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Quick Actions Section (if not searching)
            if searchText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Actions")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .accessibilityAddTraits(.isHeader)
                    
                    VStack(spacing: 4) {
                        QuickActionButton(
                            title: "Test Reminder",
                            icon: "play.circle.fill",
                            action: { 
                                calendarManager.showTestReminder()
                            }
                        )
                        .keyboardShortcut("t", modifiers: [.command])
                        
                        QuickActionButton(
                            title: "Reset to Defaults",
                            icon: "arrow.counterclockwise.circle",
                            action: { 
                                resetToDefaults()
                            }
                        )
                        .keyboardShortcut("r", modifiers: [.command, .shift])
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Quick actions")
                
                Divider()
            }
            
            // Main Navigation
            List(filteredSections, selection: $selectedSection) { section in
                EnhancedSettingsSidebarRow(section: section)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 320)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Settings sections")
        }
    }
}

// MARK: - Quick Action Button Component
struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 16)
                    .accessibilityHidden(true)
                
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(Color(NSColor.quaternaryLabelColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel(title)
        .accessibilityHint(quickActionHint)
        .help(quickActionHelpText)
    }
    
    private var quickActionHint: String {
        switch title {
        case "Test Reminder":
            return "Show a preview of how reminders will appear"
        case "Reset to Defaults":
            return "Reset all settings to their default values"
        default:
            return "Activate to \(title.lowercased())"
        }
    }
    
    private var quickActionHelpText: String {
        switch title {
        case "Test Reminder":
            return "Show a test reminder to preview your current settings"
        case "Reset to Defaults":
            return "Reset all preferences to their original values"
        default:
            return title
        }
    }
}

// MARK: - Enhanced Settings Sidebar Row with Badge Support
struct EnhancedSettingsSidebarRow: View {
    let section: SettingsSection
    
    var body: some View {
        Label {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.rawValue)
                .font(.body.weight(.medium))
                    
                    Text(section.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Badge for special sections
                if let badge = section.badge {
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule())
                        .accessibilityLabel("\(badge) section")
                }
            }
        } icon: {
            Image(systemName: section.icon)
                .font(.body)
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 20)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(section.rawValue)
        .accessibilityValue(section.description)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Select to view \(section.rawValue.lowercased()) settings")
    }
}

// MARK: - Enhanced Settings Content with Search Support
struct SettingsContent: View {
    let selectedSection: SettingsSection
    let calendarManager: CalendarManager
    @Binding var selectedTiming: ReminderTiming
    @Binding var customMinutes: String
    let searchText: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Enhanced Section Header
                EnhancedSectionHeader(section: selectedSection)
                    .padding(.bottom, 32)
                
                // Section Content
                switch selectedSection {
                case .quickSetup:
                    QuickSetupSettings(
                        calendarManager: calendarManager,
                        selectedTiming: $selectedTiming,
                        customMinutes: $customMinutes
                    )
                case .notifications:
                    NotificationSettings(
                        calendarManager: calendarManager,
                        selectedTiming: $selectedTiming,
                        customMinutes: $customMinutes
                    )
                case .appearance:
                    AppearanceSettings(calendarManager: calendarManager)
                case .advanced:
                    AdvancedSettings(calendarManager: calendarManager)
                case .about:
                    AboutSettings()
                }
                
                Spacer(minLength: 40)
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.controlBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(selectedSection.rawValue) settings")
    }
}

// MARK: - Enhanced Section Header Component
struct EnhancedSectionHeader: View {
    let section: SettingsSection
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: section.icon)
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)
                    
                    Text(section.rawValue)
                        .font(.title.weight(.semibold))
                }
                
                Text(section.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Section-specific action button
            if case .notifications = section {
                Button {
                    // This would need calendar manager passed to header component
                    // For now, this is just a visual element
                } label: {
                    Label("Test Reminder", systemImage: "play.circle.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Test reminder")
                .accessibilityHint("Preview how reminders will appear")
                .help("Show a test reminder")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(section.rawValue) section")
        .accessibilityValue(section.description)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Quick Setup Settings Section (New User Focus)
struct QuickSetupSettings: View {
    let calendarManager: CalendarManager
    @Binding var selectedTiming: ReminderTiming
    @Binding var customMinutes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            // Welcome message for new users
            SettingsGroup(title: "Welcome to Anchor") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Get started quickly by configuring these essential settings:")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    // Essential setup checklist
                    VStack(alignment: .leading, spacing: 12) {
                        QuickSetupChecklistItem(
                            title: "Calendar Access",
                            isCompleted: calendarManager.hasCalendarAccess,
                            description: calendarManager.hasCalendarAccess ? "✓ Authorized" : "Grant access to see your meetings",
                            actionTitle: calendarManager.hasCalendarAccess ? nil : "Open System Settings"
                        ) {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        
                        QuickSetupChecklistItem(
                            title: "Reminder Timing",
                            isCompleted: true,
                            description: "Currently set to \(displayedMinutes) minutes before meetings",
                            actionTitle: "Change"
                        ) {
                            // This will be handled by the binding updates below
                        }
                        
                        QuickSetupChecklistItem(
                            title: "Test Your Setup",
                            isCompleted: false,
                            description: "Preview how reminders will look",
                            actionTitle: "Show Test Reminder"
                        ) {
                            calendarManager.showTestReminder()
                        }
                    }
                }
            }
            
            // Quick timing setup
            SettingsGroup(title: "Reminder Timing") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How early should Anchor remind you before meetings?")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    // Simplified timing picker for quick setup
                    Picker("Reminder timing", selection: $selectedTiming) {
                        ForEach(ReminderTiming.allCases.filter { $0 != .custom }) { timing in
                            Text(timing.displayName).tag(timing)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedTiming) { _, newValue in
                        updateReminderMinutes()
                    }
                }
            }
            
            // Quick style preview
            SettingsGroup(title: "Notification Style") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose your preferred reminder style:")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        ForEach(OverlayStyle.allCases, id: \.self) { style in
                            QuickStyleCard(
                                style: style,
                                isSelected: calendarManager.overlayStyle == style,
                                colorManager: calendarManager.colorManager
                            ) {
                                calendarManager.overlayStyle = style
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var displayedMinutes: String {
        if selectedTiming == .custom {
            let minutes = Int(customMinutes) ?? calendarManager.reminderMinutesBefore
            return String(minutes)
        } else {
            return String(selectedTiming.minutes ?? calendarManager.reminderMinutesBefore)
        }
    }
    
    private func updateReminderMinutes() {
        if selectedTiming == .custom {
            if let minutes = Int(customMinutes), minutes > 0 {
                calendarManager.reminderMinutesBefore = minutes
            }
        } else if let presetMinutes = selectedTiming.minutes {
            calendarManager.reminderMinutesBefore = presetMinutes
        }
    }
}

// MARK: - Quick Setup Checklist Item
struct QuickSetupChecklistItem: View {
    let title: String
    let isCompleted: Bool
    let description: String
    let actionTitle: String?
    let action: () -> Void
    
    var body: some View {
                            HStack(spacing: 12) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isCompleted ? .green : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let actionTitle = actionTitle, !isCompleted {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(isCompleted ? Color.green.opacity(0.1) : Color(NSColor.quaternaryLabelColor).opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Quick Style Card
struct QuickStyleCard: View {
    let style: OverlayStyle
    let isSelected: Bool
    let colorManager: ColorManager
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Preview mini card
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [colorManager.activeColor, colorManager.secondaryColor]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 50)
                    .overlay(
                        VStack(spacing: 2) {
                            Image(systemName: style == .modern ? "bell.badge.fill" : "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.white)
                            
                            RoundedRectangle(cornerRadius: 1)
                                .fill(.white.opacity(0.8))
                                .frame(width: 40, height: 2)
                        }
                    )
                
                Text(style.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .padding(12)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.quaternaryLabelColor).opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
    }
}

// MARK: - Notification Settings Section (Enhanced from Reminders)
struct NotificationSettings: View {
    let calendarManager: CalendarManager
    @Binding var selectedTiming: ReminderTiming
    @Binding var customMinutes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            // Timing Configuration
            SettingsGroup(title: "Timing & Schedule") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Show reminder \(displayedMinutes) minutes before meetings")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Reminder timing", selection: $selectedTiming) {
                            ForEach(ReminderTiming.allCases) { timing in
                                Text(timing.displayName).tag(timing)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedTiming) { _, newValue in
                            updateReminderMinutes()
                        }
                        
                        // Show custom input when "Custom" is selected
                        if selectedTiming == .custom {
                            HStack(spacing: 8) {
                                TextField("Minutes", text: $customMinutes)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .onSubmit {
                                        updateReminderMinutes()
                                    }
                                    .onChange(of: customMinutes) { _, _ in
                                        updateReminderMinutes()
                                    }
                                
                                Text("minutes before meeting")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, 16)
                        }
                    }
                }
            }
            
            // Notification Style & Behavior
            SettingsGroup(title: "Notification Style") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose how reminders appear on your screen:")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    ForEach(OverlayStyle.allCases, id: \.self) { style in
                        StyleOptionButtonWithPreview(
                            style: style,
                            isSelected: calendarManager.overlayStyle == style,
                            action: { calendarManager.overlayStyle = style },
                            colorManager: calendarManager.colorManager
                        )
                    }
                }
            }
            
            // Test & Preview
            SettingsGroup(title: "Preview & Testing") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Test your notification settings to see how they'll appear:")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        PreviewReminderButton(calendarManager: calendarManager)
                            .frame(maxWidth: 200)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Pro Tip")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                            Text("Use Cmd+, to quickly open settings")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var displayedMinutes: String {
        if selectedTiming == .custom {
            let minutes = Int(customMinutes) ?? calendarManager.reminderMinutesBefore
            return String(minutes)
        } else {
            return String(selectedTiming.minutes ?? calendarManager.reminderMinutesBefore)
        }
    }
    
    private func updateReminderMinutes() {
        if selectedTiming == .custom {
            if let minutes = Int(customMinutes), minutes > 0 {
                calendarManager.reminderMinutesBefore = minutes
            }
        } else if let presetMinutes = selectedTiming.minutes {
            calendarManager.reminderMinutesBefore = presetMinutes
        }
    }
}

// MARK: - Advanced Settings Section (New)
struct AdvancedSettings: View {
    let calendarManager: CalendarManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            // System Integration
            SettingsGroup(title: "System Integration") {
                VStack(alignment: .leading, spacing: 16) {
                    // Time Format Setting
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Time Format")
                            .font(.subheadline.weight(.medium))
                        
                        Picker("Time Format", selection: Binding(
                            get: { calendarManager.timeFormat },
                            set: { calendarManager.timeFormat = $0 }
                        )) {
                            ForEach(TimeFormat.allCases, id: \.self) { format in
                                Text(format.displayName).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Divider()
                    
                    // Calendar Access Status
                    HStack(spacing: 12) {
                        Image(systemName: calendarStatusInfo.icon)
                            .font(.title3)
                            .foregroundStyle(calendarStatusInfo.color)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Calendar Access")
                                .font(.body.weight(.medium))
                            
                            Text(calendarStatusInfo.text)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if !calendarManager.hasCalendarAccess {
                            Button("Open System Settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.quaternaryLabelColor).opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            
            // Data & Reset
            SettingsGroup(title: "Data Management") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Manage your settings and app data:")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reset All Settings")
                                    .font(.body.weight(.medium))
                                Text("Restore default values for all preferences")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Reset") {
                                // TODO: Implement reset functionality
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Refresh Calendar Data")
                                    .font(.body.weight(.medium))
                                Text("Reload events from your calendar")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Refresh") {
                                calendarManager.refreshEvents()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }
    
    private var calendarStatusInfo: (icon: String, text: String, color: Color) {
        if calendarManager.hasCalendarAccess {
            return (icon: "checkmark.circle.fill", text: "Authorized and working", color: .green)
        } else if let error = calendarManager.errorMessage {
            return (icon: "exclamationmark.triangle.fill", text: "Access denied - needed for reminders", color: .red)
        } else {
            return (icon: "clock.fill", text: "Checking access permissions...", color: .orange)
        }
    }
}

// MARK: - About Settings Section (New)
struct AboutSettings: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            // App Information
            SettingsGroup(title: "About Anchor") {
                VStack(spacing: 20) {
                    // App icon and basic info
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 64))
                            .foregroundStyle(.white, Color.accentColor)
                            .symbolRenderingMode(.palette)
                        
                        VStack(spacing: 4) {
                            Text("Anchor")
                                .font(.title.weight(.semibold))
                            
                            Text("Meeting Reminder App for macOS")
                                .font(.body)
                                .foregroundStyle(.secondary)
                            
                            Text("Version 1.0")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    // Feature highlights
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Features:")
                            .font(.subheadline.weight(.medium))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            FeatureRow(icon: "bell.fill", text: "Smart meeting reminders")
                            FeatureRow(icon: "paintbrush.fill", text: "Customizable notification styles")
                            FeatureRow(icon: "calendar.circle.fill", text: "Native calendar integration")
                            FeatureRow(icon: "gear.badge", text: "Flexible timing options")
                        }
                    }
                }
            }
            
            // Support & Links
            SettingsGroup(title: "Support & Feedback") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Get help or share feedback:")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                            Text("Need help? Check the built-in tips and shortcuts")
                                .font(.body)
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                            Text("Created by Eran Goldin")
                                .font(.body)
                            Spacer()
                        }
                    }
                }
            }
            
            // Legal & Credits
            SettingsGroup(title: "Legal") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Anchor respects your privacy and only accesses calendar data locally on your device. No data is transmitted to external servers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("© 2025 Eran Goldin. All rights reserved.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Feature Row Component
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}




// MARK: - Appearance Settings Section
struct AppearanceSettings: View {
    let calendarManager: CalendarManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            // Color Customization
            SettingsGroup(title: "Reminder Colors") {
                VStack(alignment: .leading, spacing: 16) {
                    ColorCustomizationContentView(colorManager: calendarManager.colorManager)
                    
                    HStack {
                        Spacer()
                        PreviewReminderButton(calendarManager: calendarManager)
                            .frame(maxWidth: 200)
                    }
                }
            }
        }
    }
}



// MARK: - Settings Group Container
struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            
            content
        }
    }
}

// MARK: - Color Customization Content (without the header)
struct ColorCustomizationContentView: View {
    var colorManager: ColorManager
    @State private var hexInput: String = ""
    
    var body: some View {
                    VStack(alignment: .leading, spacing: 16) {
            // Live preview
            HStack {
                Text("Preview")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [colorManager.activeColor, colorManager.secondaryColor]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
            }
            
            VStack(alignment: .leading, spacing: 16) {
                // Preset colors grid
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preset Colors")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(Array(ColorManager.presetColors.enumerated()), id: \.offset) { index, colorData in
                            ColorSwatch(
                                color: colorData.color,
                                name: colorData.name,
                                isSelected: !colorManager.isUsingCustomHex && colorManager.selectedColor == colorData.color,
                                action: {
                                    colorManager.setPresetColor(colorData.color)
                                }
                            )
                        }
                    }
                }
                
                // Custom hex input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Custom Color (Hex)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        HStack {
                            Text("#")
                                .font(.body.monospaced())
                                .foregroundStyle(.secondary)
                            
                            TextField("FF6B35", text: $hexInput)
                                .font(.body.monospaced())
                                .textCase(.uppercase)
                                .onSubmit {
                                    if !hexInput.isEmpty {
                                        colorManager.setCustomHex(hexInput)
                                    }
                                }
                                .onChange(of: hexInput) { _, newValue in
                                    // Limit to 6 characters
                                    if newValue.count > 6 {
                                        hexInput = String(newValue.prefix(6))
                                    }
                                    // Auto-apply if we have a valid 6-character hex
                                    if newValue.count == 6 {
                                        colorManager.setCustomHex(newValue)
                                    }
                                }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colorManager.isUsingCustomHex ? colorManager.activeColor : Color(NSColor.separatorColor), lineWidth: 1)
                        )
                        
                        if colorManager.isUsingCustomHex {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorManager.activeColor)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                                )
                        }
                    }
                    
                    // Reset button
                    HStack {
                        Spacer()
                        
                        Button("Reset to Default") {
                            colorManager.resetToDefault()
                            hexInput = ""
                        }
                        .buttonStyle(.bordered)
                        .font(.caption.weight(.medium))
                    }
                }
            }
        }
        .onAppear {
            if colorManager.isUsingCustomHex {
                hexInput = colorManager.customHexColor
            }
        }
    }
}

// MARK: - Color Swatch Component
struct ColorSwatch: View {
    let color: Color
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? Color.white : Color(NSColor.separatorColor),
                                lineWidth: isSelected ? 2 : 0.5
                            )
                    )
                    .overlay(
                        // Selection indicator
                        isSelected ? 
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .background(Circle().fill(color.opacity(0.8)))
                        : nil
                    )
                    .scaleEffect(isHovered ? 1.05 : 1.0)
                    .shadow(color: .black.opacity(isSelected ? 0.2 : 0.1), radius: isSelected ? 3 : 1)
                
                Text(name)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.borderless)
        .animation(.easeInOut, value: isHovered)
        .animation(.easeInOut, value: isSelected)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview Reminder Button Component
struct PreviewReminderButton: View {
    let calendarManager: CalendarManager
    
    var body: some View {
                                Button {
            calendarManager.showTestReminder()
                                } label: {
            Label("Preview reminder", systemImage: "play.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .symbolRenderingMode(.hierarchical)
    }
}

// MARK: - Style Option Button with Preview
struct StyleOptionButtonWithPreview: View {
    let style: OverlayStyle
    let isSelected: Bool
    let action: () -> Void
    let colorManager: ColorManager
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                // Selection indicator
                Image(systemName: isSelected ? "circle.fill" : "circle")
                                            .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                                        
                // Content
                VStack(alignment: .leading, spacing: 8) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(style.displayName)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(.primary)
                                            
                                            Text(style.description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Preview graphic
                    ReminderStylePreview(style: style, colorManager: colorManager)
                                        }
                                        
                                        Spacer()
                                    }
            .padding(16)
        }
        .buttonStyle(.plain)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                .fill(.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Reminder Style Preview Component
struct ReminderStylePreview: View {
    let style: OverlayStyle
    let colorManager: ColorManager
    
    var body: some View {
        HStack(spacing: 8) {
            // Mini preview card
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [colorManager.activeColor, colorManager.secondaryColor]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 60)
                .overlay(
                    VStack(spacing: 4) {
                        // Icon based on style
                        Image(systemName: style == .modern ? "bell.badge.fill" : "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                        
                        // Sample text lines
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(.white.opacity(0.8))
                                .frame(width: 60, height: 2)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(.white.opacity(0.6))
                                .frame(width: 45, height: 2)
                        }
                        
                        // Mini button
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.9))
                            .frame(width: 35, height: 8)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.3), lineWidth: 0.5)
                )
            
            Text("Preview")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Style Option Button
struct StyleOptionButton: View {
    let style: OverlayStyle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(style.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    Text(style.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
            .padding(12)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Time Format Option Button
struct TimeFormatOptionButton: View {
    let format: TimeFormat
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(format.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    Text(format == .twelveHour ? "2:30 PM, 11:45 AM" : "14:30, 23:45")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(12)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

// Helper extension for cursor support - deprecated in favor of direct hover handling
// extension View {
//     func cursor(_ cursor: NSCursor) -> some View {
//         self.onHover { inside in
//             if inside {
//                 cursor.push()
//             } else {
//                 NSCursor.pop()
//             }
//         }
//     }
// }

// MARK: - Helper Functions
private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter.string(from: date)
}




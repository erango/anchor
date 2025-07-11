//
//  CalendarManager.swift
//  Anchor
//
//  Created by Eran Goldin on 07/07/2025.
//

import Foundation
@preconcurrency import EventKit
import SwiftUI

// MARK: - Time Format Options
enum TimeFormat: String, CaseIterable, Identifiable {
    case twelveHour = "12h"
    case twentyFourHour = "24h"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .twelveHour:
            return "12-hour (AM/PM)"
        case .twentyFourHour:
            return "24-hour (Military)"
        }
    }
}

// MARK: - Unified Preferences Management System
@Observable
class PreferencesManager {
    // MARK: - Core Settings
    var reminderMinutesBefore: Int = 5 {
        didSet { savePreferences() }
    }
    
    var overlayStyle: OverlayStyle = .modern {
        didSet { savePreferences() }
    }
    
    var timeFormat: TimeFormat = .twelveHour {
        didSet { savePreferences() }
    }
    
    // MARK: - Reminder Management
    private(set) var enabledReminders: Set<String> = []
    private(set) var dismissedForDay: Set<String> = []
    private(set) var snoozedEvents: [String: Date] = [:]
    
    // MARK: - State Management
    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Keys for UserDefaults
    private enum Keys: String, CaseIterable {
        case reminderMinutesBefore = "reminderMinutesBefore"
        case overlayStyle = "overlayStyle"
        case timeFormat = "timeFormat"
        case enabledReminders = "enabledReminders"
        case snoozedEvents = "snoozedEvents"
        case lastVersion = "lastAppVersion"
    }
    
    init() {
        loadPreferences()
        performMigrationIfNeeded()
    }
    
    // MARK: - Unified Save/Load System
    
    private func loadPreferences() {
        reminderMinutesBefore = userDefaults.object(forKey: Keys.reminderMinutesBefore.rawValue) as? Int ?? 5
        
        if let savedStyleRaw = userDefaults.string(forKey: Keys.overlayStyle.rawValue),
           let savedStyle = OverlayStyle(rawValue: savedStyleRaw) {
            overlayStyle = savedStyle
        }
        
        if let savedTimeFormatRaw = userDefaults.string(forKey: Keys.timeFormat.rawValue),
           let savedTimeFormat = TimeFormat(rawValue: savedTimeFormatRaw) {
            timeFormat = savedTimeFormat
        }
        
        if let savedReminders = userDefaults.array(forKey: Keys.enabledReminders.rawValue) as? [String] {
            enabledReminders = Set(savedReminders)
        }
        
        loadSnoozedEvents()
    }
    
    private func savePreferences() {
        userDefaults.set(reminderMinutesBefore, forKey: Keys.reminderMinutesBefore.rawValue)
        userDefaults.set(overlayStyle.rawValue, forKey: Keys.overlayStyle.rawValue)
        userDefaults.set(timeFormat.rawValue, forKey: Keys.timeFormat.rawValue)
        userDefaults.set(Array(enabledReminders), forKey: Keys.enabledReminders.rawValue)
        saveSnoozedEvents()
    }
    
    private func loadSnoozedEvents() {
        if let data = userDefaults.data(forKey: Keys.snoozedEvents.rawValue),
           let decoded = try? decoder.decode([String: Date].self, from: data) {
            // Filter out expired snoozes
            let now = Date()
            snoozedEvents = decoded.filter { $0.value > now }
        }
    }
    
    private func saveSnoozedEvents() {
        if let encoded = try? encoder.encode(snoozedEvents) {
            userDefaults.set(encoded, forKey: Keys.snoozedEvents.rawValue)
        }
    }
    
    // MARK: - Migration System
    
    private func performMigrationIfNeeded() {
        let currentVersion = "1.0"
        let lastVersion = userDefaults.string(forKey: Keys.lastVersion.rawValue)
        
        if lastVersion != currentVersion {
            print("🔄 Performing preferences migration from \(lastVersion ?? "none") to \(currentVersion)")
            // Future migration logic would go here
            userDefaults.set(currentVersion, forKey: Keys.lastVersion.rawValue)
        }
    }
    
    // MARK: - Reminder Management
    
    func isReminderEnabled(for eventId: String) -> Bool {
        if enabledReminders.isEmpty {
            return true // Default to enabled when no preferences exist
        }
        return enabledReminders.contains(eventId)
    }
    
    func setReminderEnabled(_ enabled: Bool, for eventId: String) {
        if enabled {
            enabledReminders.insert(eventId)
        } else {
            enabledReminders.remove(eventId)
        }
        savePreferences()
    }
    
    func isDismissedForDay(_ eventId: String) -> Bool {
        return dismissedForDay.contains(eventId)
    }
    
    func setDismissedForDay(_ dismissed: Bool, for eventId: String) {
        if dismissed {
            dismissedForDay.insert(eventId)
        } else {
            dismissedForDay.remove(eventId)
        }
        // Don't save dismissed for day - it resets at midnight
    }
    
    func isEventSnoozed(_ eventId: String) -> Bool {
        guard let snoozeTime = snoozedEvents[eventId] else { return false }
        return snoozeTime > Date()
    }
    
    func snoozeEvent(_ eventId: String, until: Date) {
        snoozedEvents[eventId] = until
        savePreferences()
    }
    
    func removeSnooze(for eventId: String) {
        snoozedEvents.removeValue(forKey: eventId)
        savePreferences()
    }
    
    func clearExpiredSnoozes() {
        let now = Date()
        let originalCount = snoozedEvents.count
        snoozedEvents = snoozedEvents.filter { $0.value > now }
        
        if snoozedEvents.count != originalCount {
            savePreferences()
        }
    }
    
    func clearDismissedForDay() {
        dismissedForDay.removeAll()
    }
    
    // MARK: - Reset Functions
    
    func resetToDefaults() {
        reminderMinutesBefore = 5
        overlayStyle = .modern
        timeFormat = .twelveHour
        enabledReminders.removeAll()
        dismissedForDay.removeAll()
        snoozedEvents.removeAll()
        savePreferences()
    }
    
    func exportPreferences() -> [String: Any] {
        var export: [String: Any] = [:]
        export[Keys.reminderMinutesBefore.rawValue] = reminderMinutesBefore
        export[Keys.overlayStyle.rawValue] = overlayStyle.rawValue
        export[Keys.timeFormat.rawValue] = timeFormat.rawValue
        export[Keys.enabledReminders.rawValue] = Array(enabledReminders)
        return export
    }
    
    func importPreferences(from data: [String: Any]) -> Bool {
        var success = true
        
        if let minutes = data[Keys.reminderMinutesBefore.rawValue] as? Int, minutes > 0 {
            reminderMinutesBefore = minutes
        } else {
            success = false
        }
        
        if let styleRaw = data[Keys.overlayStyle.rawValue] as? String,
           let style = OverlayStyle(rawValue: styleRaw) {
            overlayStyle = style
        } else {
            success = false
        }
        
        if let formatRaw = data[Keys.timeFormat.rawValue] as? String,
           let format = TimeFormat(rawValue: formatRaw) {
            timeFormat = format
        } else {
            success = false
        }
        
        if let reminders = data[Keys.enabledReminders.rawValue] as? [String] {
            enabledReminders = Set(reminders)
        } else {
            success = false
        }
        
        savePreferences()
        return success
    }
}

// MARK: - Enhanced Error Handling System
@Observable
class ErrorManager {
    var currentError: AnchorError?
    var errorHistory: [AnchorError] = []
    private let maxHistoryCount = 10
    
    func reportError(_ error: AnchorError) {
        print("🚨 Error reported: \(error.description)")
        
        currentError = error
        errorHistory.insert(error, at: 0)
        
        // Keep history manageable
        if errorHistory.count > maxHistoryCount {
            errorHistory = Array(errorHistory.prefix(maxHistoryCount))
        }
    }
    
    func clearCurrentError() {
        currentError = nil
    }
    
    func clearAllErrors() {
        currentError = nil
        errorHistory.removeAll()
    }
}

// MARK: - Error Types
enum AnchorError: LocalizedError, Identifiable, Equatable {
    case calendarAccessDenied
    case calendarAccessRestricted
    case calendarAccessUnknown
    case eventFetchFailed(String)
    case reminderScheduleFailed(String)
    case overlayDisplayFailed(String)
    case preferencesLoadFailed(String)
    case preferencesSaveFailed(String)
    
    var id: String {
        switch self {
        case .calendarAccessDenied: return "calendar_access_denied"
        case .calendarAccessRestricted: return "calendar_access_restricted"
        case .calendarAccessUnknown: return "calendar_access_unknown"
        case .eventFetchFailed: return "event_fetch_failed"
        case .reminderScheduleFailed: return "reminder_schedule_failed"
        case .overlayDisplayFailed: return "overlay_display_failed"
        case .preferencesLoadFailed: return "preferences_load_failed"
        case .preferencesSaveFailed: return "preferences_save_failed"
        }
    }
    
    var description: String {
        switch self {
        case .calendarAccessDenied:
            return "Calendar access was denied. Please grant access in System Settings > Privacy & Security > Calendars."
        case .calendarAccessRestricted:
            return "Calendar access is restricted by system policies."
        case .calendarAccessUnknown:
            return "Unknown calendar access status."
        case .eventFetchFailed(let details):
            return "Failed to fetch calendar events: \(details)"
        case .reminderScheduleFailed(let details):
            return "Failed to schedule reminder: \(details)"
        case .overlayDisplayFailed(let details):
            return "Failed to display reminder overlay: \(details)"
        case .preferencesLoadFailed(let details):
            return "Failed to load preferences: \(details)"
        case .preferencesSaveFailed(let details):
            return "Failed to save preferences: \(details)"
        }
    }
    
    var recoveryAction: String? {
        switch self {
        case .calendarAccessDenied:
            return "Open System Settings"
        case .eventFetchFailed, .reminderScheduleFailed:
            return "Try Again"
        case .preferencesLoadFailed, .preferencesSaveFailed:
            return "Reset to Defaults"
        default:
            return nil
        }
    }
}

// MARK: - Updated Color Management (Migrated to @Observable)
@Observable
class ColorManager {
    var selectedColor: Color = .orange
    var customHexColor: String = ""
    var isUsingCustomHex: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let colorKey = "AnchorReminderColor"
    private let customHexKey = "AnchorCustomHexColor"
    private let isUsingCustomKey = "AnchorIsUsingCustomHex"
    
    // Preset rainbow colors
    static let presetColors: [(name: String, color: Color)] = [
        ("Red", .red),
        ("Orange", .orange),
        ("Yellow", .yellow),
        ("Green", .green),
        ("Mint", .mint),
        ("Teal", .teal),
        ("Cyan", .cyan),
        ("Blue", .blue),
        ("Indigo", .indigo),
        ("Purple", .purple),
        ("Pink", .pink),
        ("Brown", .brown)
    ]
    
    init() {
        loadSavedColor()
    }
    
    var activeColor: Color {
        return isUsingCustomHex ? hexToColor(customHexColor) : selectedColor
    }
    
    var secondaryColor: Color {
        return generateSecondaryColor(from: activeColor)
    }
    
    func saveColor() {
        if isUsingCustomHex {
            userDefaults.set(customHexColor, forKey: customHexKey)
            userDefaults.set(true, forKey: isUsingCustomKey)
        } else {
            if let colorName = Self.presetColors.first(where: { $0.color == selectedColor })?.name {
                userDefaults.set(colorName, forKey: colorKey)
            }
            userDefaults.set(false, forKey: isUsingCustomKey)
        }
    }
    
    func loadSavedColor() {
        isUsingCustomHex = userDefaults.bool(forKey: isUsingCustomKey)
        
        if isUsingCustomHex {
            customHexColor = userDefaults.string(forKey: customHexKey) ?? "FF6B35"
        } else {
            let savedColorName = userDefaults.string(forKey: colorKey) ?? "Orange"
            selectedColor = Self.presetColors.first(where: { $0.name == savedColorName })?.color ?? .orange
        }
    }
    
    func resetToDefault() {
        selectedColor = .orange
        customHexColor = ""
        isUsingCustomHex = false
        saveColor()
    }
    
    func setCustomHex(_ hex: String) {
        customHexColor = validateHex(hex)
        isUsingCustomHex = true
        saveColor()
    }
    
    func setPresetColor(_ color: Color) {
        selectedColor = color
        isUsingCustomHex = false
        saveColor()
    }
    
    private func validateHex(_ hex: String) -> String {
        var cleanHex = hex.replacingOccurrences(of: "#", with: "")
        cleanHex = String(cleanHex.prefix(6))
        
        // Ensure it contains only valid hex characters
        let validCharacters = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        if cleanHex.rangeOfCharacter(from: validCharacters.inverted) != nil {
            return "FF6B35" // Default orange fallback
        }
        
        // Pad with zeros if too short
        while cleanHex.count < 6 {
            cleanHex += "0"
        }
        
        return cleanHex.uppercased()
    }
    
    private func hexToColor(_ hex: String) -> Color {
        let validHex = validateHex(hex)
        
        var rgbValue: UInt64 = 0
        Scanner(string: validHex).scanHexInt64(&rgbValue)
        
        let red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgbValue & 0x0000FF) / 255.0
        
        return Color(red: red, green: green, blue: blue)
    }
    
    private func generateSecondaryColor(from color: Color) -> Color {
        // Safe color conversion with fallback
        guard let nsColor = NSColor(color).usingColorSpace(.displayP3) else {
            // Fallback: create a simple darker version
            return color.opacity(0.8)
        }
        
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        // Try to get HSB values
        nsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Validate the values are reasonable
        guard hue >= 0 && hue <= 1 && saturation >= 0 && saturation <= 1 && brightness >= 0 && brightness <= 1 else {
            // Fallback: create a simple darker version
            return color.opacity(0.8)
        }
        
        // Create a slightly shifted hue for gradient effect
        let secondaryHue = fmod(hue + 0.15, 1.0) // Shift 15% around color wheel
        let secondaryBrightness = max(0.3, brightness - 0.2) // Slightly darker
        
        return Color(hue: secondaryHue, saturation: saturation, brightness: secondaryBrightness)
    }
}

// MARK: - Calendar Manager
@MainActor
@Observable final class CalendarManager {
    private let eventStore = EKEventStore()
    
    // Core State
    var hasCalendarAccess = false
    var upcomingEvents: [EKEvent] = []
    
    // Unified Management Systems
    let preferencesManager = PreferencesManager()
    let errorManager = ErrorManager()
    let colorManager = ColorManager()
    
    // Computed properties for easy access
    var reminderMinutesBefore: Int {
        get { preferencesManager.reminderMinutesBefore }
        set { preferencesManager.reminderMinutesBefore = newValue }
    }
    
    var overlayStyle: OverlayStyle {
        get { preferencesManager.overlayStyle }
        set { preferencesManager.overlayStyle = newValue }
    }
    
    var timeFormat: TimeFormat {
        get { preferencesManager.timeFormat }
        set { preferencesManager.timeFormat = newValue }
    }
    
    // Legacy error message for backward compatibility
    var errorMessage: String? {
        return errorManager.currentError?.description
    }
    
    // Overlay management
    private let overlayManager = OverlayWindowManager()
    private var reminderTasks: [String: Task<Void, Never>] = [:]
    
    init() {
        requestPermissionAgain()
        setupMidnightReset()
    }
    
    // MARK: - Midnight Reset Timer
    
    private func setupMidnightReset() {
        Task {
            await scheduleMidnightReset()
        }
    }
    
    private func checkCalendarAuthorizationStatus() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        print("Calendar authorization status: \(status.rawValue)")
        
        switch status {
        case .authorized:
            print("Calendar access authorized")
            hasCalendarAccess = true
            await fetchUpcomingEvents()
        case .denied:
            hasCalendarAccess = false
            errorManager.reportError(.calendarAccessDenied)
            print("Calendar access denied")
        case .restricted:
            hasCalendarAccess = false
            errorManager.reportError(.calendarAccessRestricted)
            print("Calendar access restricted")
        case .notDetermined:
            print("Calendar access not determined, requesting...")
            await requestCalendarAccess()
        case .fullAccess:
            print("Calendar full access granted")
            hasCalendarAccess = true
            await fetchUpcomingEvents()
        case .writeOnly:
            print("Calendar write-only access")
            hasCalendarAccess = false
            errorManager.reportError(.calendarAccessRestricted)
        @unknown default:
            hasCalendarAccess = false
            errorManager.reportError(.calendarAccessUnknown)
            print("Unknown calendar authorization status: \(status.rawValue)")
        }
    }
    
    private func requestCalendarAccess() async {
        print("Requesting calendar access...")
        
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            print("Calendar access request completed. Granted: \(granted)")
            
            if granted {
                print("Calendar access granted, fetching events...")
                hasCalendarAccess = true
                errorManager.clearCurrentError()
                await fetchUpcomingEvents()
            } else {
                hasCalendarAccess = false
                errorManager.reportError(.calendarAccessDenied)
                print("Calendar access denied")
            }
        } catch {
            print("Calendar access error: \(error.localizedDescription)")
            hasCalendarAccess = false
            errorManager.reportError(.eventFetchFailed(error.localizedDescription))
        }
    }
    
    func fetchUpcomingEvents() async {
        guard hasCalendarAccess else { 
            print("No calendar access, skipping event fetch")
            return 
        }
        
        let now = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        
        print("Fetching events from \(now) to \(endDate)")
        
        // Perform calendar operations on a background thread
        let events = await withCheckedContinuation { continuation in
            Task.detached { [eventStore] in
                let predicate = eventStore.predicateForEvents(withStart: now, end: endDate, calendars: nil)
                let events = eventStore.events(matching: predicate)
                continuation.resume(returning: events)
            }
        }
        
        print("Found \(events.count) total events")
        
        // Filter events
        let filteredEvents = events.filter { event in
            let isUpcoming = event.startDate > now
            let isNotAllDay = !event.isAllDay
            
            print("Event: '\(event.title ?? "Untitled")' - Start: \(event.startDate), All-day: \(event.isAllDay), Has attendees: \(event.hasAttendees), Upcoming: \(isUpcoming)")
            
            // More permissive filtering - just check if it's upcoming and not all-day
            return isUpcoming && isNotAllDay
        }
        
        print("Filtered to \(filteredEvents.count) events")
        
        upcomingEvents = filteredEvents.sorted { $0.startDate < $1.startDate }
        print("Updated UI with \(upcomingEvents.count) events")
        
        // Schedule reminders for upcoming events
        await scheduleReminders()
    }
    
    func getNextMeeting(within minutes: Int = 30) -> EKEvent? {
        let now = Date()
        let cutoffTime = Calendar.current.date(byAdding: .minute, value: minutes, to: now) ?? now
        
        return upcomingEvents.first { event in
            event.startDate > now && event.startDate <= cutoffTime
        }
    }
    
    func refreshEvents() {
        Task {
            await fetchUpcomingEvents()
        }
    }
    
    func requestPermissionAgain() {
        print("Manual permission request triggered")
        Task {
            await checkCalendarAuthorizationStatus()
        }
    }
    
    // MARK: - Reminder Management
    
    private func scheduleReminders() async {
        // Cancel existing tasks
        for task in reminderTasks.values {
            task.cancel()
        }
        reminderTasks.removeAll()
        
        let now = Date()
        
        for event in upcomingEvents {
            // Only schedule reminders for events that have reminders enabled, not dismissed for the day, and not snoozed
            guard isReminderEnabled(for: event) && !isDismissedForDay(for: event) && !isSnoozed(for: event) else {
                print("Reminders disabled, dismissed, or snoozed for event: \(event.title ?? "Unknown")")
                continue
            }
            
            // Calculate when to show the reminder
            let reminderTime = event.startDate.addingTimeInterval(-Double(reminderMinutesBefore * 60))
            
            // Only schedule if the reminder time is in the future
            if reminderTime > now {
                let timeInterval = reminderTime.timeIntervalSince(now)
                
                print("Scheduling reminder for '\(event.title ?? "Unknown")' in \(timeInterval/60.0) minutes")
                
                let task = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(timeInterval))
                    
                    if !Task.isCancelled {
                        await self?.showReminderForEvent(event)
                    }
                }
                
                // Store task using event identifier
                if let eventId = event.eventIdentifier {
                    reminderTasks[eventId] = task
                }
            } else {
                print("Event '\(event.title ?? "Unknown")' is too soon for reminder")
            }
        }
        
        print("Scheduled \(reminderTasks.count) reminders")
    }
    
    private func showReminderForEvent(_ event: EKEvent) async {
        // Prevent showing reminder if overlay is already visible
        guard !overlayManager.isOverlayVisible else {
            print("⚠️ Overlay already visible, skipping reminder for: \(event.title ?? "Unknown")")
            if let eventId = event.eventIdentifier {
                reminderTasks.removeValue(forKey: eventId)
            }
            return
        }
        
        print("🔄 Triggering reminder for: \(event.title ?? "Unknown")")
                    overlayManager.showMeetingReminder(for: event, style: overlayStyle, colorManager: colorManager, calendarManager: self)
        
        // Remove the task since it has completed
        if let eventId = event.eventIdentifier {
            reminderTasks.removeValue(forKey: eventId)
        }
    }
    
    func showTestReminder() {
        // Prevent multiple test reminders
        guard !overlayManager.isOverlayVisible else {
            print("⚠️ Test reminder already showing")
            return
        }
        
        // Create a test event for immediate display
        let testEvent = EKEvent(eventStore: eventStore)
        testEvent.title = "Test Meeting - Demo Reminder"
        testEvent.startDate = Date().addingTimeInterval(300) // 5 minutes from now
        testEvent.location = "Demo Conference Room"
        
        print("🔄 Showing test reminder")
        overlayManager.showMeetingReminder(for: testEvent, style: overlayStyle, colorManager: colorManager, calendarManager: self)
    }
    
    func clearAllReminders() {
        for task in reminderTasks.values {
            task.cancel()
        }
        reminderTasks.removeAll()
        overlayManager.hideOverlay()
        print("Cleared all reminders and overlay")
    }
    
    // MARK: - Unified Reset Functions
    
    func resetAllPreferences() {
        preferencesManager.resetToDefaults()
        colorManager.resetToDefault()
        errorManager.clearAllErrors()
        
        // Clear any active reminders and reschedule
        clearAllReminders()
        Task {
            await scheduleReminders()
        }
        
        print("🔄 Reset all preferences to default values")
    }
    
    // MARK: - Reminder Management (Enhanced with Unified Preferences)
    
    func isReminderEnabled(for event: EKEvent) -> Bool {
        guard let eventId = event.eventIdentifier else { return true }
        return preferencesManager.isReminderEnabled(for: eventId)
    }
    
    func toggleReminder(for event: EKEvent) {
        guard let eventId = event.eventIdentifier else { return }
        
        let currentlyEnabled = preferencesManager.isReminderEnabled(for: eventId)
        preferencesManager.setReminderEnabled(!currentlyEnabled, for: eventId)
        
        print("\(currentlyEnabled ? "Disabled" : "Enabled") reminder for event: \(event.title ?? "Unknown")")
        
        // Reschedule reminders to apply the change
        Task {
            await scheduleReminders()
        }
    }
    
    // MARK: - Dismiss for Day Management
    
    func isDismissedForDay(for event: EKEvent) -> Bool {
        guard let eventId = event.eventIdentifier else { return false }
        return preferencesManager.isDismissedForDay(eventId)
    }
    
    func dismissForDay(for event: EKEvent) {
        guard let eventId = event.eventIdentifier else { return }
        
        preferencesManager.setDismissedForDay(true, for: eventId)
        print("Dismissed for day: \(event.title ?? "Unknown")")
        
        // Cancel any existing reminder task for this event
        if let task = reminderTasks[eventId] {
            task.cancel()
            reminderTasks.removeValue(forKey: eventId)
        }
    }
    
    func undismissForDay(for event: EKEvent) {
        guard let eventId = event.eventIdentifier else { return }
        
        preferencesManager.setDismissedForDay(false, for: eventId)
        print("Re-enabled reminder for: \(event.title ?? "Unknown")")
        
        // Reschedule reminders to include this event again
        Task {
            await scheduleReminders()
        }
    }
    
    private func scheduleMidnightReset() {
        // Calculate time until next midnight
        let calendar = Calendar.current
        let now = Date()
        
        guard let nextMidnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) else {
            return
        }
        
        let timeInterval = nextMidnight.timeIntervalSince(now)
        
        Task {
            try? await Task.sleep(for: .seconds(timeInterval))
            await clearDismissedForDay()
        }
    }
    
    @MainActor
    private func clearDismissedForDay() {
        preferencesManager.clearDismissedForDay()
        print("Cleared dismissed for day list at midnight")
        
        // Reschedule reminders for the new day
        Task {
            await scheduleReminders()
        }
    }
    
    // MARK: - Snooze Management
    
    func snoozeEvent(for event: EKEvent, minutes: Int) {
        guard let eventId = event.eventIdentifier else { return }
        
        let snoozeUntil = Date().addingTimeInterval(Double(minutes * 60))
        preferencesManager.snoozeEvent(eventId, until: snoozeUntil)
        
        print("Snoozed event '\(event.title ?? "Unknown")' for \(minutes) minutes until \(snoozeUntil)")
        
        // Cancel any existing reminder task for this event
        if let task = reminderTasks[eventId] {
            task.cancel()
            reminderTasks.removeValue(forKey: eventId)
        }
        
        // Schedule new reminder task for snooze time
        scheduleSnoozeReminder(for: event, until: snoozeUntil)
    }
    
    func snoozeEventUntil(for event: EKEvent, minutesBeforeEvent: Int) {
        guard let eventId = event.eventIdentifier else { return }
        
        let snoozeUntil = event.startDate.addingTimeInterval(-Double(minutesBeforeEvent * 60))
        
        // Only schedule if the snooze time is in the future
        guard snoozeUntil > Date() else {
            print("Cannot snooze - reminder time is in the past")
            return
        }
        
        preferencesManager.snoozeEvent(eventId, until: snoozeUntil)
        
        print("Snoozed event '\(event.title ?? "Unknown")' until \(minutesBeforeEvent) minutes before event at \(snoozeUntil)")
        
        // Cancel any existing reminder task for this event
        if let task = reminderTasks[eventId] {
            task.cancel()
            reminderTasks.removeValue(forKey: eventId)
        }
        
        // Schedule new reminder task for snooze time
        scheduleSnoozeReminder(for: event, until: snoozeUntil)
    }
    
    private func scheduleSnoozeReminder(for event: EKEvent, until snoozeTime: Date) {
        guard let eventId = event.eventIdentifier else { return }
        
        let timeInterval = snoozeTime.timeIntervalSince(Date())
        
        // Only schedule if the snooze time is in the future
        guard timeInterval > 0 else { return }
        
        let task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(timeInterval))
            
            if !Task.isCancelled {
                // Clear the snooze when it expires
                self?.preferencesManager.removeSnooze(for: eventId)
                await self?.showReminderForEvent(event)
            }
        }
        
        reminderTasks[eventId] = task
        print("Scheduled snooze reminder for '\(event.title ?? "Unknown")' in \(timeInterval/60.0) minutes")
    }
    
    func isSnoozed(for event: EKEvent) -> Bool {
        guard let eventId = event.eventIdentifier else { return false }
        return preferencesManager.isEventSnoozed(eventId)
     }
    
    // MARK: - Time Formatting
    
    func formatTime(_ date: Date) -> String {
        switch timeFormat {
        case .twelveHour:
            return date.formatted(date: .omitted, time: .shortened)
        case .twentyFourHour:
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
    }
} 
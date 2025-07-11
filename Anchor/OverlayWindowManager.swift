//
//  OverlayWindowManager.swift
//  Anchor
//
//  Created by Eran Goldin on 07/07/2025.
//

import SwiftUI
import AppKit
@preconcurrency import EventKit

// MARK: - Self-Contained Overlay Window
class DetachedOverlayWindow: NSWindow {
    private var isClosing = false
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        // Configure as modal overlay that captures ALL mouse events
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Make this window modal - captures all events
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = false
    }
    
    func safeClose() {
        guard !isClosing else { return }
        isClosing = true
        
        print("🔄 DetachedOverlayWindow: Safe close initiated")
        
        // Immediate hide
        self.orderOut(nil)
        
        // Completely detached close with no references
        DispatchQueue.main.async {
            self.close()
            print("✅ DetachedOverlayWindow: Closed successfully")
        }
    }
}

// MARK: - Mini Overlay Window (Bottom Right)
class MiniOverlayWindow: NSWindow {
    private var isClosing = false
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        // Configure as mini overlay
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
    }
    
    func safeClose() {
        guard !isClosing else { return }
        isClosing = true
        
        print("🔄 MiniOverlayWindow: Safe close initiated")
        
        // Immediate hide
        self.orderOut(nil)
        
        // Completely detached close with no references
        DispatchQueue.main.async {
            self.close()
            print("✅ MiniOverlayWindow: Closed successfully")
        }
    }
}

@MainActor
@Observable
class OverlayWindowManager {
    private var isShowing = false
    private var miniWindow: MiniOverlayWindow?
    
    func showMeetingReminder(for event: EKEvent, style: OverlayStyle, colorManager: ColorManager, calendarManager: CalendarManager) {
        // Prevent multiple overlays
        guard !isShowing else {
            print("⚠️ Overlay already showing, ignoring request")
            return
        }
        
        print("🔄 Creating detached overlay for: \(event.title ?? "Unknown") with style: \(style.displayName)")
        isShowing = true
        
        // Create completely self-contained overlay window
        let window = DetachedOverlayWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Create SwiftUI view with completely detached callbacks
        let overlayView = createDetachedSwiftUIView(
            for: event, 
            style: style,
            colorManager: colorManager,
            calendarManager: calendarManager,
            onSnooze: { [weak self] in
                calendarManager.snoozeEvent(for: event, minutes: 5)
                self?.isShowing = false
                window.safeClose()
                
                // Show mini reminder instead of full overlay
                self?.showMiniReminder(for: event, style: style, colorManager: colorManager, calendarManager: calendarManager)
            },
            onDismissForDay: { [weak self] in
                calendarManager.dismissForDay(for: event)
                self?.isShowing = false
                window.safeClose()
            }
        )
        
        // Create hosting view
        let hostingView = NSHostingView(rootView: overlayView)
        window.contentView = hostingView
        
        // Position on screen
        if let screen = NSScreen.main {
            window.setFrame(screen.frame, display: true)
        }
        
        // Show window - DON'T store reference to avoid retain cycles
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        print("✅ Detached overlay window displayed")
    }
    
    func showMiniReminder(for event: EKEvent, style: OverlayStyle, colorManager: ColorManager, calendarManager: CalendarManager) {
        // Close any existing mini window
        miniWindow?.safeClose()
        
        print("🔄 Creating mini reminder for: \(event.title ?? "Unknown")")
        
        // Create mini overlay window
        let window = MiniOverlayWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 120),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Create mini SwiftUI view
        let miniView = MiniReminderOverlay(
            event: event,
            style: style,
            calendarManager: calendarManager,
            onTap: { [weak self] in
                // Tapping mini reminder shows full reminder again
                window.safeClose()
                self?.miniWindow = nil
                self?.showMeetingReminder(for: event, style: style, colorManager: colorManager, calendarManager: calendarManager)
            },
            onSnooze: { [weak self] in
                // Snoozing from mini reminder just closes it
                window.safeClose()
                self?.miniWindow = nil
            },
            onDismissForDay: { [weak self] in
                // Dismissing mini reminder for the day
                calendarManager.dismissForDay(for: event)
                window.safeClose()
                self?.miniWindow = nil
            },
            colorManager: colorManager
        )
        
        // Create hosting view
        let hostingView = NSHostingView(rootView: miniView)
        window.contentView = hostingView
        
        // Position in bottom right corner (accounting for dock)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = NSRect(
                x: screenFrame.maxX - 300, // 20pt margin from edge
                y: screenFrame.minY + 20,  // 20pt margin from dock
                width: 280,
                height: 120
            )
            window.setFrame(windowFrame, display: true)
        }
        
        // Store reference to mini window
        self.miniWindow = window
        
        // Show window
        window.makeKeyAndOrderFront(nil)
        
        print("✅ Mini reminder displayed in bottom right")
    }
    
    @ViewBuilder
    private func createDetachedSwiftUIView(
        for event: EKEvent, 
        style: OverlayStyle,
        colorManager: ColorManager,
        calendarManager: CalendarManager,
        onSnooze: @escaping () -> Void,
        onDismissForDay: @escaping () -> Void
    ) -> some View {
        switch style {
        case .modern:
            MeetingReminderOverlay(
                event: event,
                calendarManager: calendarManager,
                onSnooze: onSnooze,
                onDismissForDay: onDismissForDay,
                colorManager: colorManager
            )
        case .fullScreen:
            FullScreenReminderOverlay(
                event: event,
                calendarManager: calendarManager,
                onSnooze: onSnooze,
                onDismissForDay: onDismissForDay,
                colorManager: colorManager
            )
        }
    }
    
    func hideOverlay() {
        // This method is now just for compatibility
        // The actual cleanup is handled by the detached window
        isShowing = false
        miniWindow?.safeClose()
        miniWindow = nil
        print("🔄 Hide overlay called - detached windows handle their own cleanup")
    }
    
    var isOverlayVisible: Bool {
        return isShowing
    }
} 
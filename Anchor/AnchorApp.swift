//
//  AnchorApp.swift
//  Anchor
//
//  Created by Eran Goldin on 07/07/2025.
//

import SwiftUI
import AppKit

@Observable
class AppState {
    var showingSettings = false
    
    func openSettings() {
        showingSettings = true
    }
}

@main
struct AnchorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .onAppear {
                    appDelegate.appState = appState
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Anchor") {
                    appDelegate.showAbout()
                }
                .keyboardShortcut("a", modifiers: [.command])
            }
            
            CommandGroup(after: .appInfo) {
                Button("Preferences...") {
                    appState.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            // Enhanced Window Management Commands
            CommandGroup(after: .windowArrangement) {
                Button("Show Main Window") {
                    appDelegate.showMainWindow()
                }
                .keyboardShortcut("m", modifiers: [.command])
                
                Button("Hide to Menu Bar") {
                    appDelegate.hideToMenuBar()
                }
                .keyboardShortcut("h", modifiers: [.command])
            }
            
            // Quick Actions Commands
            CommandGroup(after: .toolbar) {
                Button("Refresh Events") {
                    // This would need access to calendar manager
                    // For now, this is a placeholder
                }
                .keyboardShortcut("r", modifiers: [.command])
                
                Button("Test Reminder") {
                    // This would need access to calendar manager
                    // For now, this is a placeholder
                }
                .keyboardShortcut("t", modifiers: [.command])
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var mainWindow: NSWindow?
    var appState: AppState?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start with dock icon visible since window opens on launch
        NSApp.setActivationPolicy(.regular)
        setupMenuBar()
        setupMainWindow()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        } else {
            // Ensure dock icon is visible if we have visible windows
            NSApp.setActivationPolicy(.regular)
        }
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't terminate when last window is closed - minimize to menu bar instead
        return false
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Show quit confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Quit Anchor?"
        alert.informativeText = "Quitting Anchor will stop all meeting reminders. You can minimize to the menu bar instead to keep reminders active."
        alert.alertStyle = .warning
        alert.icon = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
        
        // Add buttons in reverse order (rightmost first)
        alert.addButton(withTitle: "Just Minimize")  // Default button (rightmost)
        alert.addButton(withTitle: "Really Quit")    // Secondary button (leftmost)
        
        // Set default button (Just Minimize)
        alert.buttons.first?.keyEquivalent = "\r"  // Enter key
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:  // "Just Minimize"
            hideToMenuBar()
            return .terminateCancel
        case .alertSecondButtonReturn: // "Really Quit"
            return .terminateNow
        default:
            return .terminateCancel
        }
    }
    
    @MainActor private func setupMenuBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "calendar.badge.clock", accessibilityDescription: "Anchor")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
        
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Show Anchor", action: #selector(showMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About Anchor", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Anchor", action: #selector(quitApplication), keyEquivalent: "q"))
        
        statusBarItem?.menu = menu
    }
    
    @MainActor private func setupMainWindow() {
        // Find and store reference to main window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { @MainActor in
            if let window = NSApplication.shared.windows.first(where: { $0.contentViewController != nil }) {
                self.mainWindow = window
                
                // Override window close behavior
                window.delegate = self
            }
        }
    }
    
    @MainActor @objc private func statusBarButtonClicked() {
        showMainWindow()
    }
    
    @MainActor @objc func showMainWindow() {
        // Show dock icon when showing main window
        NSApp.setActivationPolicy(.regular)
        
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // If window doesn't exist, find it again
            setupMainWindow()
        }
    }
    
    @MainActor @objc private func openPreferences() {
        // Show main window first if it's hidden
        showMainWindow()
        // Then open preferences
        appState?.openSettings()
    }
    
    @MainActor @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Anchor"
        alert.informativeText = "Meeting reminder app for macOS\n\nVersion 1.0\nCreated by Eran Goldin"
        alert.alertStyle = .informational
        alert.icon = NSImage(systemSymbolName: "calendar.badge.clock", accessibilityDescription: nil)
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @MainActor @objc private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
    
    @MainActor func hideToMenuBar() {
        mainWindow?.orderOut(nil)
        NSApp.hide(nil)
        // Hide dock icon when running from menu bar only
        NSApp.setActivationPolicy(.accessory)
    }
}

extension AppDelegate: NSWindowDelegate {
    @MainActor func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Instead of closing, minimize to menu bar
        hideToMenuBar()
        return false
    }
    
    @MainActor func windowWillClose(_ notification: Notification) {
        // This shouldn't be called due to windowShouldClose returning false
        // But just in case, hide to menu bar
        hideToMenuBar()
    }
}

# Anchor

A beautiful, native macOS calendar reminder app that helps you never miss important meetings.

## Features

### 🎯 Smart Reminders
- **Multiple notification styles**: Modern compact, Full-screen dramatic, and Mini corner notifications
- **Intelligent timing**: Customizable reminder intervals (2, 5, 10+ minutes before events)
- **Calendar integration**: Seamlessly works with your existing macOS Calendar events

### ⌨️ Keyboard-First Experience
- **Quick dismiss**: Press `Esc` or `Enter` to snooze any reminder
- **Menu shortcuts**: `S` (snooze), `D` (dismiss), `1` (10 min before), `2` (2 min before)
- **Global shortcuts**: `⌘M` (show window), `⌘H` (hide to menu bar)

### 🎨 Beautiful Design
- **Native macOS styling**: Uses system materials, colors, and typography
- **Accessibility first**: Full VoiceOver support and keyboard navigation
- **Customizable appearance**: Choose colors, notification styles, and timing preferences

### ⚡ Quick Setup
- **One-time configuration**: Set your preferences once and forget about it
- **Smart defaults**: Works great out of the box with sensible settings
- **Menu bar presence**: Discrete menu bar icon for quick access

## Requirements

- macOS 15.5 or later
- Xcode 16+ (for building from source)
- Calendar access permissions

## Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd anchor
   ```

2. Open in Xcode:
   ```bash
   open Anchor.xcodeproj
   ```

3. Build and run the project (`⌘R`)

4. Grant Calendar permissions when prompted

## Usage

### First Launch
1. Open Anchor and go through the Quick Setup checklist
2. Grant calendar access permissions
3. Choose your preferred notification style
4. Set your default reminder timing

### Daily Use
- Anchor runs quietly in your menu bar
- Reminders appear automatically before your calendar events
- Use keyboard shortcuts for quick actions
- Access settings anytime via the menu bar icon

## Keyboard Shortcuts

### Global
- `⌘M` - Show main window
- `⌘H` - Hide to menu bar
- `⌘A` - About Anchor

### In Reminders
- `Esc` / `Enter` - Quick snooze (5 minutes)
- `S` - Snooze for 5 minutes
- `D` - Dismiss for today
- `1` - Remind 10 minutes before event
- `2` - Remind 2 minutes before event

### Settings
- `⌘T` - Test reminder
- `⌘⇧R` - Reset to defaults
- `⌘W` - Close window

## Technical Details

- **Built with**: Swift 6, SwiftUI, AppKit
- **Architecture**: Observable pattern with centralized state management
- **Accessibility**: Full VoiceOver and keyboard navigation support
- **Performance**: Optimized for minimal resource usage

## Contributing

This project follows modern macOS development best practices:
- Swift 6 concurrency compliance
- Comprehensive accessibility support
- Native macOS Human Interface Guidelines
- Clean, maintainable code architecture

## License

[License information to be added]

---

**Made with ❤️ for macOS users who value productivity and beautiful design.** 
# Ullam - Project Guidelines

## Overview
Ullam is a privacy-focused diary app for iOS 26+ and macOS 26+ built with SwiftUI and SwiftData.

## Architecture
- **Pattern**: MVVM with Service Layer
- **Persistence**: SwiftData with optional iCloud sync
- **Encryption**: CryptoKit AES-GCM with HKDF key derivation
- **Rich Text**: Platform-specific wrappers (UITextView on iOS, NSTextView on macOS)

## Key Concepts

### Terminology
- **Diary**: A collection of pages (not "journal")
- **Page**: A single entry for a day (not "entry")
- Default diary name: "Me & Me"

### Security Model
- Pincode-protected diaries are encrypted with AES-GCM
- Key derivation: `pincode + salt → HKDF-SHA256 → 256-bit AES key`
- Hidden diary count: No UI reveals how many diaries exist
- Diary switching works by iterating all diaries and checking pincode hash
- Multiple hidden diaries can share the same pincode (each has unique salt)

### Data Flow
- Pages auto-save as user types
- Rich text stored as RTF data
- Encrypted fields: title, subtitle, content, emojis
- Plaintext fields: IDs, dates, pincode hash, salt (needed for lookup)

## Project Structure
```
Ullam/
├── Models/          # SwiftData models (Diary, Page, DayMood, etc.)
├── Services/        # DataController, DiaryManager, EncryptionManager
├── Views/           # SwiftUI views organized by feature
├── Components/      # Reusable UI components (RichTextEditor, NumpadView)
└── Extensions/      # Swift extensions
```

## Platform Considerations
- Use `#if canImport(UIKit)` for iOS-specific code
- Use `#if os(iOS)` / `#if os(macOS)` for platform conditionals
- RichTextEditor has separate implementations for UIKit and AppKit

## Build & Run
- Minimum deployment: iOS 26.0, macOS 26.0
- Build with Xcode 17+
- Test on both iOS Simulator and macOS

//
//  ContentView.swift
//  Focus Timer
//
//  Created by needsomevibe on 28/12/25.
//

import SwiftUI
import Combine
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - App Screen Enum
enum AppScreen: String, CaseIterable, Identifiable {
    case home = "Home"
    case focus = "Focus"
    case ambient = "Ambient"
    case rewards = "Rewards"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .home: "house.fill"
        case .focus: "flame.fill"
        case .ambient: "leaf.fill"
        case .rewards: "gift.fill"
        case .settings: "gearshape.fill"
        }
    }
}

// MARK: - Pomodoro Session
enum PomodoroSession: String, CaseIterable, Identifiable {
    case focus = "Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
    
    var id: String { rawValue }
    
    var defaultDuration: TimeInterval {
        switch self {
        case .focus: 25 * 60
        case .shortBreak: 5 * 60
        case .longBreak: 15 * 60
        }
    }
}

// MARK: - Pomodoro View Model
@MainActor
final class PomodoroViewModel: ObservableObject {
    @Published var session: PomodoroSession = .focus {
        didSet { reset(keepSession: true) }
    }
    @Published var focusMinutes: Int = 25 {
        didSet { if session == .focus { reset(keepSession: true) } }
    }
    @Published var shortBreakMinutes: Int = 5 {
        didSet { if session == .shortBreak { reset(keepSession: true) } }
    }
    @Published var longBreakMinutes: Int = 15 {
        didSet { if session == .longBreak { reset(keepSession: true) } }
    }
    
    @Published var currentTask: String = "Swift"
    @Published var sessionCount: Int = 0
    
    @Published private(set) var remaining: TimeInterval
    @Published private(set) var isRunning: Bool = false
    
    private var timer: Timer?
    
    init() {
        remaining = PomodoroSession.focus.defaultDuration
    }
    
    var totalDuration: TimeInterval {
        switch session {
        case .focus: TimeInterval(focusMinutes) * 60
        case .shortBreak: TimeInterval(shortBreakMinutes) * 60
        case .longBreak: TimeInterval(longBreakMinutes) * 60
        }
    }
    
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        let clamped = max(0, min(remaining, totalDuration))
        return 1 - (clamped / totalDuration)
    }
    
    var timeText: String {
        let seconds = max(0, Int(remaining.rounded()))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
    
    func toggle() {
        isRunning ? pause() : start()
    }
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.tick()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func reset(keepSession: Bool = false) {
        pause()
        if !keepSession { session = .focus }
        remaining = totalDuration
    }
    
    private func tick() {
        guard isRunning else { return }
        if remaining > 0 {
            remaining -= 1
        } else {
            pause()
            // Auto-switch logic
            if session == .focus {
                sessionCount += 1
                session = (sessionCount % 4 == 0) ? .longBreak : .shortBreak
            } else {
                session = .focus
            }
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var pomodoroVM = PomodoroViewModel()
    @State private var currentScreen: AppScreen = .home
    @State private var currentTime = Date()
    @State private var showShareModal = false
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            MainScreenBackground()
            
            VStack(spacing: 0) {
                // Top section with logo
                HStack {
                    // Top-left: Logo
                    VStack(alignment: .leading, spacing: 4) {
                        Text("flocus")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    // Top-right: Quote
                    if currentScreen == .home {
                        Text("\"Be yourself, there's no one better\"")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)
                    } else if currentScreen == .focus {
                        Text("\"Make it happen and shock everyone\"")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)
                
                // Large clock - only for non-content screens (will be shown in HomeScreenContent)
                if currentScreen != .ambient && currentScreen != .focus && currentScreen != .home {
                    VStack(spacing: 12) {
                        Text(timeString)
                            .font(.system(size: 120, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    .frame(height: 140)
                    .padding(.vertical, 20)
                }
                
                // Main content area
                Group {
                    switch currentScreen {
                    case .home:
                        HomeScreenContent(currentTime: $currentTime)
                    case .focus:
                        FocusScreenContent(viewModel: pomodoroVM)
                    case .ambient:
                        AmbientScreenContent()
                    case .rewards:
                        RewardsScreenContent()
                    case .settings:
                        SettingsScreenContent(viewModel: pomodoroVM)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom navigation
                BottomNavigationBar(currentScreen: $currentScreen, showShareModal: $showShareModal)
            }
            .blur(radius: showShareModal ? 20 : 0)
            
            // Share Modal
            if showShareModal {
                ShareModal(isPresented: $showShareModal)
                    .zIndex(1000)
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return formatter.string(from: currentTime)
    }
}

// MARK: - Home Screen
struct HomeScreenContent: View {
    @Binding var currentTime: Date
    
    var body: some View {
        VStack(spacing: 20) {
            // Personalized message
            Text(personalizedMessage)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
            
            // Large clock
            Text(timeString)
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return formatter.string(from: currentTime)
    }
    
    private var personalizedMessage: String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let weekday = calendar.component(.weekday, from: currentTime)
        
        let weekdayName = calendar.weekdaySymbols[weekday - 1]
        
        if hour >= 18 {
            return "That's \(weekdayName) in the bag, Marsel. Time to chill."
        } else if hour >= 12 {
            return "Keep going, Marsel. You've got this."
        } else {
            return "Good morning, Marsel. Let's make today count."
        }
    }
}

// MARK: - Focus Screen
struct FocusScreenContent: View {
    @ObservedObject var viewModel: PomodoroViewModel
    @State private var isEditingTask = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Task name with pencil icon
            HStack(spacing: 8) {
                if isEditingTask {
                    TextField("Task name", text: $viewModel.currentTask)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.sentences)
                        .onSubmit {
                            isEditingTask = false
                        }
                } else {
                    Text(viewModel.currentTask)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Button {
                        isEditingTask = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 20)
            
            // Mode selection buttons (pill-shaped)
            HStack(spacing: 12) {
                ForEach(PomodoroSession.allCases) { session in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.session = session
                        }
                    } label: {
                        Text(session.rawValue)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(viewModel.session == session ? .white : .white.opacity(0.7))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background {
                                if viewModel.session == session {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.purple.opacity(0.8))
                                } else {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 16)
            
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<4) { index in
                    Circle()
                        .fill(index == 0 ? Color.white : Color.white.opacity(0.3))
                        .frame(width: index == 0 ? 8 : 6, height: index == 0 ? 8 : 6)
                }
            }
            .padding(.bottom, 40)
            
            // Large Timer display (centered)
            Text(viewModel.timeText)
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.bottom, 40)
            
            // Control buttons
            HStack(spacing: 16) {
                // Start/Pause button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.toggle()
                    }
                } label: {
                    Text(viewModel.isRunning ? "Pause" : "Start")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.purple.opacity(0.8))
                        }
                }
                .buttonStyle(.plain)
                
                // Skip Break button (only shown during break sessions)
                if viewModel.session == .shortBreak || viewModel.session == .longBreak {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.session = .focus
                            viewModel.reset(keepSession: true)
                        }
                    } label: {
                        Text("Skip Break")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.purple.opacity(0.8))
                            }
                    }
                    .buttonStyle(.plain)
                }
                
                // Reset button (circular)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.reset(keepSession: true)
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Focus Timer Card (for top-right)
struct FocusTimerCard: View {
    @ObservedObject var viewModel: PomodoroViewModel
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("Focus")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            
            Text(viewModel.timeText)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            
            Button {
                viewModel.toggle()
            } label: {
                Text(viewModel.isRunning ? "Pause" : "Start")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.purple.opacity(0.8))
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.3))
        }
    }
}

// MARK: - Ambient Screen
struct AmbientScreenContent: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Ambient Sounds")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("Choose your focus environment")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                
                // Ambient sounds
                VStack(spacing: 16) {
                    AmbientSoundCard(name: "Forest", icon: "leaf.fill")
                    AmbientSoundCard(name: "Rain", icon: "cloud.rain.fill")
                    AmbientSoundCard(name: "Ocean", icon: "water.waves")
                    AmbientSoundCard(name: "Cafe", icon: "cup.and.saucer.fill")
                    AmbientSoundCard(name: "Fireplace", icon: "flame.fill")
                    AmbientSoundCard(name: "White Noise", icon: "waveform")
                }
                .padding(.top, 40)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
        }
    }
}

struct AmbientSoundCard: View {
    let name: String
    let icon: String
    @State private var isPlaying = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 40)
            
            Text(name)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            
            Spacer()
            
            Button {
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.1))
        }
    }
}

// MARK: - Rewards Screen
struct RewardsScreenContent: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Your Rewards")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("Earn rewards for your focus sessions")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                
                // Rewards
                VStack(spacing: 16) {
                    RewardCard(title: "Focus Streak", value: "7 days", icon: "flame.fill")
                    RewardCard(title: "Total Sessions", value: "42", icon: "checkmark.circle.fill")
                    RewardCard(title: "Focus Time", value: "24h 30m", icon: "clock.fill")
                    RewardCard(title: "Tasks Completed", value: "128", icon: "list.bullet.checkmark")
                }
                .padding(.top, 40)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
        }
    }
}

struct RewardCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            
            Spacer()
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.1))
        }
    }
}

// MARK: - Settings Screen
struct SettingsScreenContent: View {
    @ObservedObject var viewModel: PomodoroViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                VStack(spacing: 16) {
                    SettingRow(
                        title: "Focus Duration",
                        value: "\(viewModel.focusMinutes) min",
                        control: AnyView(
                            Stepper("", value: $viewModel.focusMinutes, in: 5...120, step: 5)
                                .labelsHidden()
                        )
                    )
                    
                    SettingRow(
                        title: "Short Break",
                        value: "\(viewModel.shortBreakMinutes) min",
                        control: AnyView(
                            Stepper("", value: $viewModel.shortBreakMinutes, in: 1...30, step: 1)
                                .labelsHidden()
                        )
                    )
                    
                    SettingRow(
                        title: "Long Break",
                        value: "\(viewModel.longBreakMinutes) min",
                        control: AnyView(
                            Stepper("", value: $viewModel.longBreakMinutes, in: 5...60, step: 5)
                                .labelsHidden()
                        )
                    )
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
        }
    }
}

struct SettingRow: View {
    let title: String
    let value: String
    let control: AnyView
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text(value)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            control
                .tint(.white)
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.1))
        }
    }
}

// MARK: - Bottom Navigation Bar
struct BottomNavigationBar: View {
    @Binding var currentScreen: AppScreen
    @Binding var showShareModal: Bool
    
    var body: some View {
        HStack {
            // Bottom-left: Music and Edit icons

            
            Spacer()
            
            // Bottom-right: Navigation icons
            HStack(spacing: 12) {
                // Pill-shaped container with three icons
                HStack(spacing: 0) {
                    // Ambient (Leaf) icon
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            currentScreen = .ambient
                        }
                    } label: {
                        ZStack {
                            if currentScreen == .ambient {
                                Circle()
                                    .fill(Color(red: 0.7, green: 0.4, blue: 0.9)) // Bright purple glow
                                    .frame(width: 44, height: 44)
                            }
                            
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 50, height: 50)
                    }
                    .buttonStyle(.plain)
                    
                    // Home icon
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            currentScreen = .home
                        }
                    } label: {
                        ZStack {
                            if currentScreen == .home {
                                Circle()
                                    .fill(Color(red: 0.7, green: 0.4, blue: 0.9)) // Bright purple glow
                                    .frame(width: 44, height: 44)
                            }
                            
                            Image(systemName: "house.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 50, height: 50)
                    }
                    .buttonStyle(.plain)
                    
                    // Focus (Lightbulb) icon
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            currentScreen = .focus
                        }
                    } label: {
                        ZStack {
                            if currentScreen == .focus {
                                Circle()
                                    .fill(Color(red: 0.7, green: 0.4, blue: 0.9)) // Bright purple glow
                                    .frame(width: 44, height: 44)
                            }
                            
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 50, height: 50)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                
                // Standalone square buttons
                // Gift icon
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showShareModal = true
                    }
                } label: {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                                }
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        }
                }
                .buttonStyle(.plain)
                
                // Settings icon
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        currentScreen = .settings
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                                }
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
    }
}

// MARK: - Share Modal
struct ShareModal: View {
    @Binding var isPresented: Bool
    @State private var linkCopied = false
    
    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }
            
            // Modal content
            VStack(spacing: 24) {
                // Close button
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                
                // Title
                Text("Share Flocus with Friends")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                
                // Description
                Text("Love using Flocus? Share it with a friend and help them get more done!")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                
                // Action buttons
                HStack(spacing: 16) {
                    // Copy Link button
                    Button {
                        copyLink()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            Text(linkCopied ? "Copied!" : "Copy Link")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.purple.opacity(0.8))
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // Share button
                    ShareLink(item: URL(string: "https://flocus.app")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            Text("Share")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.purple.opacity(0.8))
                        }
                    }
                }
            }
            .padding(32)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.95))
            }
            .padding(.horizontal, 40)
        }
    }
    
    private func copyLink() {
        #if os(iOS)
        UIPasteboard.general.string = "https://flocus.app"
        #elseif os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("https://flocus.app", forType: .string)
        #endif
        
        withAnimation {
            linkCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                linkCopied = false
            }
        }
    }
}

// MARK: - Background
private struct MainScreenBackground: View {
    var body: some View {
        ZStack {
            // Main gradient: purple to pink to orange
            LinearGradient(
                colors: [
                    Color(red: 0.3, green: 0.15, blue: 0.4),  // Deep purple
                    Color(red: 0.5, green: 0.3, blue: 0.6),   // Lavender
                    Color(red: 0.8, green: 0.4, blue: 0.7),   // Magenta/Pink
                    Color(red: 0.95, green: 0.6, blue: 0.5),  // Pink/Orange
                    Color(red: 1.0, green: 0.7, blue: 0.4),  // Orange
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .ignoresSafeArea()
            
            // Glowing light effects
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 600, height: 600)
                .blur(radius: 100)
                .offset(x: -200, y: -300)
            
            Circle()
                .fill(Color(red: 1.0, green: 0.8, blue: 0.6).opacity(0.2))
                .frame(width: 500, height: 500)
                .blur(radius: 120)
                .offset(x: 300, y: 200)
        }
    }
}

#Preview {
    ContentView()
}

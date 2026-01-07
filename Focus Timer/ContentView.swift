//
//  ContentView.swift
//  Focus Timer
//
//  Created by needsomevibe on 28/12/25.
//

import SwiftUI

enum PomodoroSession: String, CaseIterable, Identifiable {
    case focus = "Focus"
    case shortBreak = "Break"
    
    var id: String { rawValue }
    
    var defaultDuration: TimeInterval {
        switch self {
        case .focus: 25 * 60
        case .shortBreak: 5 * 60
        }
    }
    
    var icon: String {
        switch self {
        case .focus: "target"
        case .shortBreak: "cup.and.saucer.fill"
        }
    }
}

@MainActor
final class PomodoroViewModel: ObservableObject {
    @Published var session: PomodoroSession = .focus {
        didSet { reset(keepSession: true) }
    }
    @Published var focusMinutes: Int = 25 {
        didSet { if session == .focus { reset(keepSession: true) } }
    }
    @Published var breakMinutes: Int = 5 {
        didSet { if session == .shortBreak { reset(keepSession: true) } }
    }
    
    @Published private(set) var remaining: TimeInterval
    @Published private(set) var isRunning: Bool = false
    
    private var timer: Timer?
    
    init() {
        remaining = PomodoroSession.focus.defaultDuration
    }
    
    var totalDuration: TimeInterval {
        switch session {
        case .focus: TimeInterval(focusMinutes) * 60
        case .shortBreak: TimeInterval(breakMinutes) * 60
        }
    }
    
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        let clamped = max(0, min(remaining, totalDuration))
        return 1 - (clamped / totalDuration)
    }
    
    var timeText: String {
        let seconds = max(0, Int(remaining.rounded()))
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
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
            self.tick()
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
            // auto-switch like flocus-style flow
            session = (session == .focus) ? .shortBreak : .focus
        }
    }
}

struct ContentView: View {
    @StateObject private var vm = PomodoroViewModel()
    
    @State private var tasks: [String] = [
        "Deep work: 1 focused block",
        "Reply to important messages",
        "Quick review & plan tomorrow",
    ]
    @State private var newTask: String = ""
    @State private var selectedTaskIndex: Int? = 0
    
    var body: some View {
        ZStack {
            FlocusBackground()
            
            ViewThatFits {
                wideLayout
                narrowLayout
            }
            .padding(20)
        }
    }
    
    private var wideLayout: some View {
        HStack(alignment: .top, spacing: 16) {
            tasksCard
                .frame(width: 320)
            
            timerCard
                .frame(maxWidth: 560)
            
            settingsCard
                .frame(width: 320)
        }
    }
    
    private var narrowLayout: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerBar
                timerCard
                tasksCard
                settingsCard
            }
            .padding(.bottom, 24)
        }
    }
    
    private var headerBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                Text("Focus Timer")
                    .font(.system(.headline, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.92))
            
            Spacer()
            
            Text(Date.now, style: .date)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(.horizontal, 6)
    }
    
    private var timerCard: some View {
        VStack(spacing: 16) {
            headerBar
                .padding(.bottom, 6)
            
            HStack(spacing: 10) {
                ForEach(PomodoroSession.allCases) { session in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            vm.session = session
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: session.icon)
                            Text(session.rawValue)
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(vm.session == session ? .black : .white.opacity(0.85))
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(vm.session == session ? Color.white.opacity(0.9) : Color.white.opacity(0.08))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 14)
                
                Circle()
                    .trim(from: 0, to: max(0.001, vm.progress))
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(red: 0.84, green: 0.65, blue: 1.0),
                                Color(red: 0.46, green: 0.86, blue: 0.99),
                                Color(red: 0.84, green: 0.65, blue: 1.0),
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.25), value: vm.progress)
                
                VStack(spacing: 6) {
                    Text(vm.timeText)
                        .font(.system(size: 58, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.95))
                    
                    Text(vm.session == .focus ? "Stay in the zone" : "Take a slow breath")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .frame(width: 260, height: 260)
            .padding(.top, 6)
            .padding(.bottom, 8)
            
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        vm.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: vm.isRunning ? "pause.fill" : "play.fill")
                        Text(vm.isRunning ? "Pause" : "Start")
                    }
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.92))
                    }
                }
                .buttonStyle(.plain)
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        vm.reset(keepSession: true)
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: 52, height: 52)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .flocusCard()
    }
    
    private var tasksCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Tasks")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Text("Today")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.white.opacity(0.75))
                    TextField("Add a task…", text: $newTask)
                        .textInputAutocapitalization(.sentences)
                        .foregroundStyle(.white.opacity(0.9))
                        .submitLabel(.done)
                        .onSubmit(addTask)
                    
                    Button("Add") { addTask() }
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        }
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                }
                
                if tasks.isEmpty {
                    Text("No tasks yet. Add one and hit start.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(tasks.enumerated()), id: \.offset) { index, task in
                            Button {
                                selectedTaskIndex = index
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selectedTaskIndex == index ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedTaskIndex == index ? Color(red: 0.46, green: 0.86, blue: 0.99) : .white.opacity(0.35))
                                    
                                    Text(task)
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.88))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .lineLimit(2)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(selectedTaskIndex == index ? Color.white.opacity(0.10) : Color.white.opacity(0.06))
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(.white.opacity(selectedTaskIndex == index ? 0.18 : 0.10), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteTask(at: index)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .flocusCard()
    }
    
    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Session")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Text("Customize")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            VStack(spacing: 10) {
                settingRow(
                    title: "Focus",
                    value: "\(vm.focusMinutes) min",
                    icon: "timer"
                ) {
                    Stepper("", value: $vm.focusMinutes, in: 5...90, step: 5)
                        .labelsHidden()
                }
                
                settingRow(
                    title: "Break",
                    value: "\(vm.breakMinutes) min",
                    icon: "cup.and.saucer"
                ) {
                    Stepper("", value: $vm.breakMinutes, in: 1...30, step: 1)
                        .labelsHidden()
                }
                
                Divider()
                    .overlay(Color.white.opacity(0.10))
                    .padding(.vertical, 4)
                
                HStack(spacing: 10) {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ambience")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("UI placeholder (no audio yet)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    
                    Spacer()
                    
                    Text("Lo-fi")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                }
            }
        }
        .padding(20)
        .flocusCard()
    }
    
    private func settingRow(
        title: String,
        value: String,
        icon: String,
        control: () -> some View
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(value)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
            
            Spacer()
            control()
                .tint(Color(red: 0.46, green: 0.86, blue: 0.99))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        }
    }
    
    private func addTask() {
        let trimmed = newTask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tasks.insert(trimmed, at: 0)
        newTask = ""
        selectedTaskIndex = 0
    }
    
    private func deleteTask(at index: Int) {
        guard tasks.indices.contains(index) else { return }
        tasks.remove(at: index)
        if let selectedTaskIndex, selectedTaskIndex == index {
            self.selectedTaskIndex = tasks.isEmpty ? nil : 0
        }
    }
}

private struct FlocusBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.09),
                    Color(red: 0.05, green: 0.06, blue: 0.12),
                    Color(red: 0.04, green: 0.05, blue: 0.10),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            Circle()
                .fill(Color(red: 0.84, green: 0.65, blue: 1.0).opacity(0.18))
                .frame(width: 520, height: 520)
                .blur(radius: 70)
                .offset(x: -180, y: -240)
            
            Circle()
                .fill(Color(red: 0.46, green: 0.86, blue: 0.99).opacity(0.16))
                .frame(width: 560, height: 560)
                .blur(radius: 80)
                .offset(x: 220, y: -220)
            
            Circle()
                .fill(Color(red: 0.55, green: 0.98, blue: 0.78).opacity(0.10))
                .frame(width: 680, height: 680)
                .blur(radius: 90)
                .offset(x: 40, y: 320)
        }
    }
}

private struct FlocusCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 30, x: 0, y: 16)
    }
}

private extension View {
    func flocusCard() -> some View {
        modifier(FlocusCard())
    }
}

#Preview {
    ContentView()
}

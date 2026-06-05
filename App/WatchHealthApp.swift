import SwiftUI

@main
struct WatchHealthApp: App {
    @StateObject private var healthManager = HealthManager()
    @StateObject private var aiEngine = LocalAIEngine()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthManager)
                .environmentObject(aiEngine)
                .preferredColorScheme(.dark) // Deep rich dark mode aesthetics
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var aiEngine: LocalAIEngine
    
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Tổng Quan", systemImage: "heart.text.square.fill")
                }
            
            LocalAIReportView()
                .tabItem {
                    Label("AI Phân Tích", systemImage: "brain.head.profile")
                }
            
            WorkoutHistoryView()
                .tabItem {
                    Label("Tập Luyện", systemImage: "figure.run")
                }
            
            ExportView()
                .tabItem {
                    Label("Xuất File", systemImage: "doc.text.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Cài Đặt", systemImage: "gearshape.fill")
                }
        }
        .accentColor(.red) // Custom vibrant red for health apps
        .onAppear {
            // Run initial analysis
            aiEngine.analyze(healthManager: healthManager)
        }
        .onChange(of: healthManager.stepsToday.count) { _ in
            aiEngine.analyze(healthManager: healthManager)
        }
        .onChange(of: healthManager.isMockDataUsed) { _ in
            aiEngine.analyze(healthManager: healthManager)
        }
    }
}

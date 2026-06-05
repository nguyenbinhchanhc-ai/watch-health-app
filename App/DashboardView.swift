import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var aiEngine: LocalAIEngine
    @State private var selectedHazard: HealthHazard?
    
    // Quick calculations for display
    private var totalSteps: Int {
        Int(healthManager.stepsToday.reduce(0) { $0 + $1.count })
    }
    
    private var totalCalories: Int {
        Int(healthManager.caloriesToday.reduce(0) { $0 + $1.calories })
    }
    
    private var latestHeartRate: Int {
        Int(healthManager.heartRateRecords.last?.value ?? 0)
    }
    
    private var latestSpO2: Int {
        Int((healthManager.spo2Records.last?.value ?? 0) * 100)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Sleek Gradient Background (Red/Purple aura for Health)
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.15, green: 0.05, blue: 0.1),
                        Color(red: 0.05, green: 0.02, blue: 0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header Bar
                        headerSection
                        
                        // Status Badge
                        dataSourceStatusBadge
                        
                        // --- 1. HAZARD BOARD (CẢNH BÁO MỐI NGUY SỨC KHỎE) ---
                        if !aiEngine.activeHazards.isEmpty {
                            hazardBoardSection
                        }
                        
                        // --- 2. QUICK SCORES (ĐIỂM SỐ AI CỤC BỘ) ---
                        quickScoresGrid
                        
                        // --- 3. METRIC CARDS ---
                        metricsGrid
                        
                        // --- 4. ANALYTIC CHARTS ---
                        chartsSection
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedHazard) { hazard in
                HazardDetailSheet(hazard: hazard)
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sức Khỏe Apple Watch")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Phân Tích AI Cục Bộ")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.gray)
            }
            Spacer()
            
            Button(action: {
                Task {
                    await healthManager.refreshData()
                    aiEngine.analyze(healthManager: healthManager)
                }
            }) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(Color.red)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Data Source Status Badge
    private var dataSourceStatusBadge: some View {
        HStack {
            Image(systemName: healthManager.isMockDataUsed ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                .foregroundColor(healthManager.isMockDataUsed ? Color.amber : Color.green)
            
            Text(healthManager.isMockDataUsed ? "Chế độ mô phỏng (Không có thiết bị thực)" : "Đã đồng bộ từ Apple Watch thực tế")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            if healthManager.isMockDataUsed {
                Button(action: {
                    Task {
                        _ = await healthManager.requestAuthorization()
                    }
                }) {
                    Text("Kết nối HealthKit")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.red))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }
    
    // MARK: - Hazard Board Section
    private var hazardBoardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.octagon.fill")
                    .foregroundColor(Color.red)
                Text("CẢNH BÁO NGUY HIỂM SỨC KHỎE")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(Color.red)
                Spacer()
                Text("\(aiEngine.activeHazards.count) Cảnh báo")
                    .font(.caption2)
                    .foregroundColor(Color.white.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red.opacity(0.2)))
            }
            .padding(.horizontal, 4)
            
            ForEach(aiEngine.activeHazards) { hazard in
                Button(action: { selectedHazard = hazard }) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(hazard.level == .critical ? Color.red : Color.amber)
                            .frame(width: 10, height: 10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hazard.title)
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                            Text(hazard.description)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(hazard.level == .critical ? Color.red.opacity(0.15) : Color.amber.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(hazard.level == .critical ? Color.red.opacity(0.3) : Color.amber.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.red.opacity(0.2), lineWidth: 1))
        )
    }
    
    // MARK: - Quick Scores Grid
    private var quickScoresGrid: some View {
        HStack(spacing: 12) {
            // Recovery Score Card
            VStack(spacing: 8) {
                Text("Hồi Phục")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.7))
                
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 6)
                        .frame(width: 65, height: 65)
                    Circle()
                        .trim(from: 0.0, to: CGFloat(aiEngine.recoveryScore) / 100.0)
                        .stroke(
                            AngularGradient(colors: [.orange, .green], center: .center),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 65, height: 65)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(aiEngine.recoveryScore)%")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Text(aiEngine.recoveryScore >= 80 ? "Sẵn sàng" : (aiEngine.recoveryScore >= 50 ? "Trung bình" : "Kiệt sức"))
                    .font(.caption2)
                    .foregroundColor(aiEngine.recoveryScore >= 80 ? Color.green : (aiEngine.recoveryScore >= 50 ? Color.orange : Color.red))
                    .fontWeight(.semibold)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
            )
            
            // Stress Index Card
            VStack(spacing: 8) {
                Text("Căng Thẳng")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.7))
                
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 6)
                        .frame(width: 65, height: 65)
                    Circle()
                        .trim(from: 0.0, to: CGFloat(aiEngine.stressIndex) / 100.0)
                        .stroke(
                            AngularGradient(colors: [.green, .yellow, .red], center: .center),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 65, height: 65)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(aiEngine.stressIndex)")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Text(aiEngine.stressIndex >= 70 ? "Căng thẳng" : (aiEngine.stressIndex >= 40 ? "Bình thường" : "Thư giãn"))
                    .font(.caption2)
                    .foregroundColor(aiEngine.stressIndex >= 70 ? Color.red : (aiEngine.stressIndex >= 40 ? Color.yellow : Color.green))
                    .fontWeight(.semibold)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
            )
        }
    }
    
    // MARK: - Metrics Grid
    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            // Steps Card
            MetricCard(
                title: "Số Bước Chân",
                value: "\(totalSteps)",
                unit: "bước",
                icon: "figure.walk",
                color: .cyan,
                trend: "Mục tiêu: 10,000"
            )
            
            // Active Energy Card
            MetricCard(
                title: "Năng Lượng",
                value: "\(totalCalories)",
                unit: "kcal",
                icon: "flame.fill",
                color: .orange,
                trend: "Tiêu thụ hôm nay"
            )
            
            // Heart Rate Card
            MetricCard(
                title: "Nhịp Tim Hiện Tại",
                value: latestHeartRate > 0 ? "\(latestHeartRate)" : "--",
                unit: "bpm",
                icon: "heart.fill",
                color: .red,
                trend: "Tĩnh: \(Int(healthManager.rhrRecords.last?.value ?? 0)) bpm"
            )
            
            // Blood Oxygen Card
            MetricCard(
                title: "Nồng Độ Oxy SpO2",
                value: latestSpO2 > 0 ? "\(latestSpO2)%" : "--",
                unit: "",
                icon: "waveform.path.ecg",
                color: .purple,
                trend: latestSpO2 >= 95 ? "Bình thường" : "Suy giảm oxy"
            )
        }
    }
    
    // MARK: - Charts Section
    private var chartsSection: some View {
        VStack(spacing: 16) {
            // Steps Hourly Chart
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.cyan)
                    Text("Số bước theo giờ hôm nay")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                if !healthManager.stepsToday.isEmpty {
                    Chart(healthManager.stepsToday) { item in
                        BarMark(
                            x: .value("Giờ", item.date, unit: .hour),
                            y: .value("Số Bước", item.count)
                        )
                        .foregroundStyle(Color.cyan.gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: 140)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 4)) {
                            AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                        }
                    }
                } else {
                    noDataOverlay
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
            )
            
            // Heart Rate Line Chart
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundColor(.red)
                    Text("Biến động nhịp tim (24h qua)")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                if !healthManager.heartRateRecords.isEmpty {
                    Chart(healthManager.heartRateRecords) { item in
                        LineMark(
                            x: .value("Thời gian", item.date),
                            y: .value("Nhịp tim", item.value)
                        )
                        .foregroundStyle(Color.red.gradient)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Thời gian", item.date),
                            y: .value("Nhịp tim", item.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red.opacity(0.2), .red.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    .frame(height: 140)
                    .chartYScale(domain: 40...160)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 6)) {
                            AxisGridLine(stroke: StrokeStyle(dash: [4]))
                                .foregroundStyle(.white.opacity(0.1))
                            AxisValueLabel(format: .dateTime.hour())
                        }
                    }
                } else {
                    noDataOverlay
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
            )
        }
    }
    
    private var noDataOverlay: some View {
        HStack {
            Spacer()
            Text("Không có dữ liệu. Vui lòng bấm làm mới.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
                .padding(.vertical, 30)
            Spacer()
        }
    }
}

// MARK: - Metric Card Component
struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let trend: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
                Text(trend)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
        )
    }
}

// MARK: - Hazard Detail Sheet
struct HazardDetailSheet: View {
    let hazard: HealthHazard
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.02, blue: 0.05).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Image(systemName: hazard.level == .critical ? "exclamationmark.triangle.fill" : "exclamationmark.shield.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(hazard.level == .critical ? .red : .amber)
                        .padding(.top, 40)
                    
                    VStack(spacing: 8) {
                        Text(hazard.level.rawValue)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(hazard.level == .critical ? .red : .amber)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill((hazard.level == .critical ? Color.red : Color.amber).opacity(0.2)))
                        
                        Text(hazard.title)
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Phát Hiện Chi Tiết:")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(hazard.description)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .lineSpacing(4)
                        
                        Divider().background(.white.opacity(0.1))
                        
                        Text("Khuyến Nghị Xử Lý:")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(hazard.recommendation)
                            .font(.body)
                            .foregroundColor(.green.opacity(0.9))
                            .lineSpacing(4)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}

// Color asset helpers
extension Color {
    static let amber = Color(red: 1.0, green: 0.75, blue: 0.0)
}

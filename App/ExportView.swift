import SwiftUI

// Serialized format wrapper
struct ExportDataPackage: Codable {
    let exportDate: String
    let stepsToday: [StepData]
    let caloriesToday: [CaloriesData]
    let heartRateRecords: [HeartRateData]
    let hrvRecords: [HRVData]
    let rhrRecords: [RHRData]
    let spo2Records: [SpO2Data]
    let sleepRecords: [SleepSegment]
    let noiseRecords: [NoiseData]
    let recentWorkouts: [WorkoutLog]
    let aiScoreRecovery: Int
    let aiScoreStress: Int
    let aiScoreCardio: Int
    let aiScoreSleep: Int
    let aiReportMarkdown: String
}

struct ExportView: View {
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var aiEngine: LocalAIEngine
    
    @State private var exportJsonURL: URL?
    @State private var exportCsvURL: URL?
    @State private var isPreparing = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background dark styling
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.15),
                        Color(red: 0.03, green: 0.03, blue: 0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        exportSummaryCard
                        
                        actionButtonsSection
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Trạng Thái"), message: Text(alertMessage), dismissButton: .default(Text("Đóng")))
            }
            .onAppear {
                prepareFiles()
            }
            .onChange(of: healthManager.stepsToday.count) { _ in
                prepareFiles()
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Xuất Dữ Liệu")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Sao lưu hồ sơ sức khỏe & chẩn đoán AI")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.gray)
            }
            Spacer()
            
            Image(systemName: "doc.text.fill")
                .font(.title2)
                .foregroundColor(.cyan)
        }
    }
    
    // MARK: - Export Summary Card
    private var exportSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("THÔNG TIN HỒ SƠ XUẤT FILE")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.cyan)
            
            VStack(spacing: 12) {
                ExportDetailRow(title: "Chỉ số hoạt động (Số bước/Kcal)", count: "\(healthManager.stepsToday.count + healthManager.caloriesToday.count) bản ghi")
                ExportDetailRow(title: "Dữ liệu Tim mạch (HR & RHR)", count: "\(healthManager.heartRateRecords.count + healthManager.rhrRecords.count) bản ghi")
                ExportDetailRow(title: "Biến thiên nhịp tim (HRV)", count: "\(healthManager.hrvRecords.count) bản ghi")
                ExportDetailRow(title: "Nồng độ oxy hô hấp (SpO2)", count: "\(healthManager.spo2Records.count) bản ghi")
                ExportDetailRow(title: "Chu kỳ giấc ngủ (Staging)", count: "\(healthManager.sleepRecords.count) phân đoạn")
                ExportDetailRow(title: "Bài tập thể thao (Apple Watch)", count: "\(healthManager.recentWorkouts.count) buổi tập")
                ExportDetailRow(title: "Đánh giá an toàn AI", count: "4 chỉ số + bảng cảnh báo")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08), lineWidth: 1))
        )
    }
    
    // MARK: - Action Buttons
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            if isPreparing {
                ProgressView("Đang nén dữ liệu...")
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.cyan))
                    .foregroundColor(Color.white)
            } else {
                // Share JSON Button
                if let jsonURL = exportJsonURL {
                    ShareLink(item: jsonURL) {
                        HStack {
                            Image(systemName: "arrow.down.doc.fill")
                            Text("Xuất File JSON Toàn Diện")
                                .fontWeight(.bold)
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.cyan))
                        .foregroundColor(.black)
                    }
                }
                
                // Share CSV Button
                if let csvURL = exportCsvURL {
                    ShareLink(item: csvURL) {
                        HStack {
                            Image(systemName: "tablecells.fill")
                            Text("Xuất File CSV Biểu Đồ (Excel)")
                                .fontWeight(.bold)
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .foregroundColor(Color.white)
                    }
                }
                
                // Refresh Trigger
                Button(action: {
                    prepareFiles(force: true)
                }) {
                    Text("Làm mới tệp xuất")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                }
            }
        }
    }
    
    // MARK: - File compilation logic
    private func prepareFiles(force: Bool = false) {
        if !force && (exportJsonURL != nil && exportCsvURL != nil) {
            return
        }
        
        // Capture MainActor-isolated variables before dispatching to background thread
        let steps = healthManager.stepsToday
        let calories = healthManager.caloriesToday
        let heartRates = healthManager.heartRateRecords
        let hrvs = healthManager.hrvRecords
        let rhrs = healthManager.rhrRecords
        let spo2s = healthManager.spo2Records
        let sleep = healthManager.sleepRecords
        let noise = healthManager.noiseRecords
        let workouts = healthManager.recentWorkouts
        
        let recoveryScore = aiEngine.recoveryScore
        let stressIndex = aiEngine.stressIndex
        let cardiovascularScore = aiEngine.cardiovascularScore
        let sleepQualityScore = aiEngine.sleepQualityScore
        let localAiReportMarkdown = aiEngine.localAiReportMarkdown
        
        isPreparing = true
        
        // Run in background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm"
            let dateStr = formatter.string(from: Date())
            
            // 1. JSON Packaging
            let package = ExportDataPackage(
                exportDate: dateStr,
                stepsToday: steps,
                caloriesToday: calories,
                heartRateRecords: heartRates,
                hrvRecords: hrvs,
                rhrRecords: rhrs,
                spo2Records: spo2s,
                sleepRecords: sleep,
                noiseRecords: noise,
                recentWorkouts: workouts,
                aiScoreRecovery: recoveryScore,
                aiScoreStress: stressIndex,
                aiScoreCardio: cardiovascularScore,
                aiScoreSleep: sleepQualityScore,
                aiReportMarkdown: localAiReportMarkdown
            )
            
            let tempDir = FileManager.default.temporaryDirectory
            let jsonFileUrl = tempDir.appendingPathComponent("WatchHealth_Export_\(dateStr).json")
            
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = .prettyPrinted
                let jsonData = try encoder.encode(package)
                try jsonData.write(to: jsonFileUrl)
                
                DispatchQueue.main.async {
                    self.exportJsonURL = jsonFileUrl
                }
            } catch {
                print("JSON Export failed: \(error.localizedDescription)")
            }
            
            // 2. CSV Packaging (Daily trends of HRV/RHR/Steps)
            let csvFileUrl = tempDir.appendingPathComponent("WatchHealth_Trends_\(dateStr).csv")
            var csvString = "Time,StepCount,Calories,HeartRate(bpm),HRV(ms),RestingHR(bpm),SpO2(%)\n"
            
            // Compile unified records mapped hourly for today
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            
            for hour in 0..<24 {
                if let hourDate = calendar.date(byAdding: .hour, value: hour, to: startOfToday) {
                    let stepsCount = steps.first(where: { calendar.component(.hour, from: $0.date) == hour })?.count ?? 0
                    let calsCount = calories.first(where: { calendar.component(.hour, from: $0.date) == hour })?.calories ?? 0
                    let hr = heartRates.filter { calendar.component(.hour, from: $0.date) == hour }.map { $0.value }.first ?? 0
                    let hrv = hrvs.filter { calendar.component(.hour, from: $0.date) == hour }.map { $0.value }.first ?? 0
                    let rhrVal = rhrs.first?.value ?? 0
                    let spo2 = (spo2s.filter { calendar.component(.hour, from: $0.date) == hour }.map { $0.value }.first ?? 0) * 100
                    
                    let timeFormatter = DateFormatter()
                    timeFormatter.dateFormat = "HH:00"
                    let timeLabel = timeFormatter.string(from: hourDate)
                    
                    let row = "\(timeLabel),\(stepsCount),\(calsCount),\(hr > 0 ? "\(hr)" : ""),\(hrv > 0 ? "\(hrv)" : ""),\(rhrVal > 0 ? "\(rhrVal)" : ""),\(spo2 > 0 ? "\(spo2)" : "")\n"
                    csvString.append(row)
                }
            }
            
            do {
                try csvString.write(to: csvFileUrl, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    self.exportCsvURL = csvFileUrl
                    self.isPreparing = false
                }
            } catch {
                print("CSV Export failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isPreparing = false
                }
            }
        }
    }
}

// MARK: - Detail Row Component
struct ExportDetailRow: View {
    let title: String
    let count: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text(count)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.cyan)
        }
        .padding(.vertical, 4)
    }
}

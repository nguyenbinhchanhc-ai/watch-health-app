import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var aiEngine: LocalAIEngine
    
    // Baselines saved locally
    @AppStorage("baselineStepGoal") private var baselineStepGoal = 10000
    @AppStorage("baselineSleepGoal") private var baselineSleepGoal = 8.0
    @AppStorage("baselineHrvVal") private var baselineHrvVal = 55.0
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background Gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.12, green: 0.05, blue: 0.08),
                        Color(red: 0.04, green: 0.02, blue: 0.04)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        // HealthKit Connection Status
                        healthKitConnectionSection
                        
                        // Biological Baselines Configuration
                        biologicalBaselinesSection
                        
                        // Mock Simulation Switch
                        simulationControlSection
                        
                        // Medical Disclaimer Card
                        disclaimerSection
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cấu Hình Sức Khỏe")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Quản lý quyền HealthKit & Baselines sinh học")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.gray)
            }
            Spacer()
            
            Image(systemName: "gearshape.fill")
                .font(.title2)
                .foregroundColor(.red)
        }
    }
    
    // MARK: - HealthKit Status Checklist
    private var healthKitConnectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TRẠNG THÁI DỮ LIỆU NHẬP (XML)")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.red)
            
            VStack(spacing: 12) {
                PermissionStatusRow(title: "Nhập tệp export.xml từ Apple Health", status: healthManager.isXmlDataLoaded)
                if healthManager.isXmlDataLoaded {
                    PermissionStatusRow(title: "Dữ liệu bước chân đã đồng bộ", status: !healthManager.stepsToday.isEmpty)
                    PermissionStatusRow(title: "Dữ liệu nhịp tim đã đồng bộ", status: !healthManager.heartRateRecords.isEmpty)
                    PermissionStatusRow(title: "Dữ liệu giấc ngủ đã đồng bộ", status: !healthManager.sleepRecords.isEmpty)
                }
            }
            
            Button(action: {
                healthManager.resetData()
                aiEngine.analyze(healthManager: healthManager)
            }) {
                Text(healthManager.isXmlDataLoaded ? "Xóa Dữ Liệu XML Đã Nhập" : "Chưa Nhập Dữ Liệu Thực Tế")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(healthManager.isXmlDataLoaded ? Color.red : Color.gray))
            }
            .disabled(!healthManager.isXmlDataLoaded)
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }
    
    // MARK: - Biological Baselines
    private var biologicalBaselinesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CẤU HÌNH BASELINE CÁ NHÂN HÓA")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: 16) {
                // Steps
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Mục tiêu số bước hàng ngày:")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text("\(baselineStepGoal) bước")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                    Slider(value: Binding(
                        get: { Double(baselineStepGoal) },
                        set: { baselineStepGoal = Int($0) }
                    ), in: 3000...20000, step: 500)
                    .tint(.red)
                }
                
                // Sleep
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Thời lượng giấc ngủ mong muốn:")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text(String(format: "%.1f giờ", baselineSleepGoal))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                    Slider(value: $baselineSleepGoal, in: 5.0...10.0, step: 0.5)
                    .tint(.red)
                }
                
                // HRV
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("HRV Baseline trung bình (SDNN):")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text("\(Int(baselineHrvVal)) ms")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                    Slider(value: $baselineHrvVal, in: 20...120, step: 5)
                    .tint(.red)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08), lineWidth: 1))
        )
    }
    
    // MARK: - Simulation Controller
    private var simulationControlSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("KIỂM THỬ ỨNG DỤNG (SIMULATION)")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.orange)
            
            Text("Nếu bạn không có Apple Watch hoặc đang chạy ứng dụng trong Xcode Simulator, hãy kích hoạt Chế độ Mô phỏng để tạo dữ liệu sức khỏe giả lập với chất lượng cao giúp kiểm tra đầy đủ các tính năng phân tích của AI.")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .lineSpacing(3)
            
            HStack(spacing: 12) {
                Button(action: {
                    healthManager.forceUseMockData()
                    aiEngine.analyze(healthManager: healthManager)
                }) {
                    Text("Bật Mô Phỏng")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange))
                }
                
                Button(action: {
                    healthManager.resetData()
                    aiEngine.analyze(healthManager: healthManager)
                }) {
                    Text("Xóa Dữ Liệu Mô Phỏng")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.orange.opacity(0.2), lineWidth: 1))
        )
    }
    
    // MARK: - Medical Disclaimer
    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundColor(.red)
                Text("TUYÊN BỐ MIỄN TRỪ TRÁCH NHIỆM Y TẾ")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text("Mọi phân tích sức khỏe, tính toán phục hồi, căng thẳng, chất lượng giấc ngủ và chỉ số tim mạch hô hấp được thực hiện bởi Local AI Engine của WatchHealth chỉ mang tính chất tham khảo giáo dục và lối sống. Thuật toán của chúng tôi được thiết kế theo các thống kê y khoa chung và không thay thế cho các thiết bị y tế chuyên dụng hay chẩn đoán lâm sàng từ bác sĩ chuyên khoa tim mạch/hô hấp. Không tự ý thay đổi liệu trình điều trị hoặc thuốc men dựa trên cảnh báo từ ứng dụng này.")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.red.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.red.opacity(0.15), lineWidth: 1))
        )
    }
}

// MARK: - Permission Status Row
struct PermissionStatusRow: View {
    let title: String
    let status: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(status ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text(status ? "Đã liên kết" : "Chưa kết nối")
                    .font(.system(size: 10))
                    .foregroundColor(status ? Color.green : Color.red)
                    .fontWeight(.bold)
            }
        }
    }
}

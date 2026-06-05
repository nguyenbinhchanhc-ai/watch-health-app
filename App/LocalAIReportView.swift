import SwiftUI

struct LocalAIReportView: View {
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var aiEngine: LocalAIEngine
    @State private var showingCopiedAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background dark theme
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.08, green: 0.08, blue: 0.18),
                        Color(red: 0.02, green: 0.02, blue: 0.06)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Title
                        headerSection
                        
                        // Main Clinical Score Gauges
                        scoresDashboardSection
                        
                        // Diagnostics Summary Cards
                        diagnosticsBreakdown
                        
                        // Markdown Clinical Report View
                        clinicalReportSection
                        
                        // Disclaimer
                        Text("⚠️ Lưu ý: Phân tích được thực hiện cục bộ bằng AI chuyên gia ngoại tuyến (On-Device AI) và chỉ mang tính chất tham khảo, không có giá trị thay thế chỉ định y tế chính thức.")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .alert(isPresented: $showingCopiedAlert) {
                Alert(
                    title: Text("Đã Sao Chép"),
                    message: Text("Báo cáo sức khỏe dạng văn bản đã được lưu vào khay nhớ tạm."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Khám Sức Khỏe")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Phân tích động thái cơ thể tức thời")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.gray)
            }
            Spacer()
            
            Image(systemName: "cpu.fill")
                .font(.title2)
                .foregroundColor(.green)
                .padding(10)
                .background(Circle().fill(.white.opacity(0.06)))
        }
    }
    
    // MARK: - Circular Gauges Section
    private var scoresDashboardSection: some View {
        VStack(spacing: 16) {
            Text("Chỉ Số Sinh Học (Biometrics)")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                ScoreGauge(
                    score: aiEngine.recoveryScore,
                    title: "Hồi Phục",
                    color: Color.green,
                    icon: "sparkles"
                )
                ScoreGauge(
                    score: aiEngine.stressIndex,
                    title: "Căng Thẳng",
                    color: Color.red,
                    icon: "bolt.fill",
                    isStress: true
                )
            }
            
            HStack(spacing: 12) {
                ScoreGauge(
                    score: aiEngine.cardiovascularScore,
                    title: "Tim Mạch",
                    color: Color.blue,
                    icon: "heart.fill"
                )
                ScoreGauge(
                    score: aiEngine.sleepQualityScore,
                    title: "Giấc Ngủ",
                    color: Color.purple,
                    icon: "moon.fill"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08), lineWidth: 1))
        )
    }
    
    // MARK: - Diagnostics Detailed Breakdown
    private var diagnosticsBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nhận Định Chuyên Sâu Cục Bộ")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white.opacity(0.8))
            
            DiagnosticRow(
                title: "Thần Kinh Thực Vật (ANS / HRV)",
                description: aiEngine.recoveryExplanation,
                color: .green,
                icon: "waveform.path.ecg"
            )
            
            DiagnosticRow(
                title: "Trạng Thái Căng Thẳng (Stress Load)",
                description: aiEngine.stressExplanation,
                color: .red,
                icon: "brain.head.profile"
            )
            
            DiagnosticRow(
                title: "Tuần Hoàn & Hô Hấp (Cardio & SpO2)",
                description: aiEngine.cardioExplanation,
                color: .blue,
                icon: "lungs.fill"
            )
            
            DiagnosticRow(
                title: "Cấu Trúc Giấc Ngủ (Sleep Staging)",
                description: aiEngine.sleepExplanation,
                color: .purple,
                icon: "bed.double.fill"
            )
        }
    }
    
    // MARK: - Text-based Clinical Report
    private var clinicalReportSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Bản Tóm Tắt Lâm Sàng (Markdown)")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    UIPasteboard.general.string = aiEngine.localAiReportMarkdown
                    showingCopiedAlert = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc.fill")
                        Text("Copy")
                    }
                    .font(.caption2)
                    .foregroundColor(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.green.opacity(0.15)))
                }
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(aiEngine.localAiReportMarkdown)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(4)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: 350)
            .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.3)))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08), lineWidth: 1))
        )
    }
}

// MARK: - Score Gauge Component
struct ScoreGauge: View {
    let score: Int
    let title: String
    let color: Color
    let icon: String
    var isStress: Bool = false
    
    // Health status label helper
    private var statusLabel: String {
        if isStress {
            if score >= 70 { return "Nguy cơ cao" }
            if score >= 40 { return "Bình thường" }
            return "Thư thái"
        } else {
            if score >= 80 { return "Tối ưu" }
            if score >= 50 { return "Hồi phục vừa" }
            return "Cần nghỉ"
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.06), lineWidth: 5)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(score) / 100.0)
                    .stroke(
                        color.gradient,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(), value: score)
                
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(statusLabel)
                        .font(.system(size: 8))
                        .foregroundColor(color)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.04)))
    }
}

// MARK: - Diagnostic Row Component
struct DiagnosticRow: View {
    let title: String
    let description: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 30)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.75))
                    .lineSpacing(3)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
        )
    }
}

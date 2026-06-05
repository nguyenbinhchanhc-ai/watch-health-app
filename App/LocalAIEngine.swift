import Foundation
import Combine

public enum HealthHazardLevel: String, Codable {
    case info = "Thông tin (Info)"
    case warning = "Cảnh báo (Warning)"
    case critical = "Nguy hiểm (Critical)"
}

public struct HealthHazard: Identifiable, Codable {
    public var id = UUID()
    public var level: HealthHazardLevel
    public var title: String
    public var description: String
    public var recommendation: String
}

@MainActor
public class LocalAIEngine: ObservableObject {
    // Scores
    @Published public var recoveryScore: Int = 0
    @Published public var stressIndex: Int = 0
    @Published public var cardiovascularScore: Int = 0
    @Published public var sleepQualityScore: Int = 0
    
    // Detailed Explanations
    @Published public var recoveryExplanation: String = ""
    @Published public var stressExplanation: String = ""
    @Published public var cardioExplanation: String = ""
    @Published public var sleepExplanation: String = ""
    
    // Detected Hazards
    @Published public var activeHazards: [HealthHazard] = []
    
    // AI Detailed Health Insights Report (Markdown format for presentation)
    @Published public var localAiReportMarkdown: String = ""
    
    public init() {}
    
    public func analyze(healthManager: HealthManager) {
        // Clear old hazards
        var detectedHazards: [HealthHazard] = []
        
        // 1. Calculate Sleep Quality Score & Explanation
        let sleepStats = calculateSleepQuality(sleepRecords: healthManager.sleepRecords)
        self.sleepQualityScore = sleepStats.score
        self.sleepExplanation = sleepStats.explanation
        
        // 2. Calculate Recovery Score & Explanation
        let recoveryStats = calculateRecovery(
            sleepScore: sleepStats.score,
            hrvRecords: healthManager.hrvRecords,
            rhrRecords: healthManager.rhrRecords
        )
        self.recoveryScore = recoveryStats.score
        self.recoveryExplanation = recoveryStats.explanation
        
        // 3. Calculate Stress Index & Explanation
        let stressStats = calculateStress(
            hrvRecords: healthManager.hrvRecords,
            rhrRecords: healthManager.rhrRecords,
            sleepRecords: healthManager.sleepRecords
        )
        self.stressIndex = stressStats.score
        self.stressExplanation = stressStats.explanation
        
        // 4. Calculate Cardiovascular Score & Explanation
        let cardioStats = calculateCardiovascular(
            rhrRecords: healthManager.rhrRecords,
            spo2Records: healthManager.spo2Records
        )
        self.cardiovascularScore = cardioStats.score
        self.cardioExplanation = cardioStats.explanation
        
        // --- Hazard Detection Heuristics ---
        
        // A. Sleep Apnea/Respiratory Distress Indicator
        // Rule: SpO2 drops below 92% during sleep periods
        let sleepPeriods = healthManager.sleepRecords.filter { $0.stage != "Awake" }
        let nightSpO2 = healthManager.spo2Records.filter { record in
            sleepPeriods.contains { period in
                record.date >= period.startDate && record.date <= period.endDate
            }
        }
        let criticalNightSpO2 = nightSpO2.filter { $0.value < 0.92 }
        if !criticalNightSpO2.isEmpty {
            detectedHazards.append(HealthHazard(
                level: .critical,
                title: "Dấu Hiệu Ngưng Thở Khi Ngủ (Sleep Apnea)",
                description: "AI phát hiện nồng độ oxy trong máu (SpO2) giảm xuống mức \(Int((criticalNightSpO2.first?.value ?? 0) * 100))% trong khoảng thời gian ngủ. Đây có thể là dấu hiệu của chứng ngưng thở khi ngủ.",
                recommendation: "Hạn chế nằm ngửa khi ngủ. Bạn nên tham khảo ý kiến bác sĩ chuyên khoa hô hấp hoặc tai mũi họng để tiến hành đo đa ký giấc ngủ nếu tình trạng này lặp lại thường xuyên."
            ))
        }
        
        // B. Hypoxia Risk (General Blood Oxygen Drop)
        // Rule: SpO2 average is below 95%
        if let latestSpO2 = healthManager.spo2Records.last {
            let spo2Percent = latestSpO2.value * 100
            if spo2Percent < 90 {
                detectedHazards.append(HealthHazard(
                    level: .critical,
                    title: "Thiếu Oxy Máu Nguy Kịch (Severe Hypoxia)",
                    description: "Nồng độ oxy trong máu gần nhất đo được là \(Int(spo2Percent))%, dưới ngưỡng an toàn rất nhiều.",
                    recommendation: "Hãy nghỉ ngơi, hít thở sâu. Nếu đi kèm triệu chứng khó thở, chóng mặt, đau ngực, cần tìm kiếm sự trợ giúp y tế ngay lập tức."
                ))
            } else if spo2Percent < 95 {
                detectedHazards.append(HealthHazard(
                    level: .warning,
                    title: "Thiếu Oxy Máu Nhẹ (Mild Hypoxia)",
                    description: "Nồng độ oxy trong máu gần nhất đo được ở mức \(Int(spo2Percent))%, thấp hơn mức chuẩn khỏe mạnh (95-100%).",
                    recommendation: "Cải thiện độ thông thoáng phòng ngủ, duy trì tư thế ngồi thẳng khi thở. Theo dõi sát sao chỉ số này trong vòng 24 giờ tới."
                ))
            }
        }
        
        // C. Overtraining / Autonomic Fatigue Risk
        // Rule: HRV drops >20% and RHR increases >10% compared to baseline
        if healthManager.hrvRecords.count >= 5 && healthManager.rhrRecords.count >= 5 {
            let recentHRVs = healthManager.hrvRecords.suffix(3).map { $0.value }
            let avgRecentHRV = recentHRVs.reduce(0, +) / Double(recentHRVs.count)
            let baseHRVs = healthManager.hrvRecords.prefix(healthManager.hrvRecords.count - 3).map { $0.value }
            let avgBaseHRV = baseHRVs.reduce(0, +) / Double(baseHRVs.count)
            
            let recentRHRs = healthManager.rhrRecords.suffix(3).map { $0.value }
            let avgRecentRHR = recentRHRs.reduce(0, +) / Double(recentRHRs.count)
            let baseRHRs = healthManager.rhrRecords.prefix(healthManager.rhrRecords.count - 3).map { $0.value }
            let avgBaseRHR = baseRHRs.reduce(0, +) / Double(baseRHRs.count)
            
            let hrvDrop = (avgBaseHRV - avgRecentHRV) / avgBaseHRV
            let rhrIncrease = (avgRecentRHR - avgBaseRHR) / avgBaseRHR
            
            if hrvDrop > 0.25 && rhrIncrease > 0.12 {
                detectedHazards.append(HealthHazard(
                    level: .warning,
                    title: "Quá Tải Luyện Tập & Suy Nhược Thần Kinh",
                    description: "Chỉ số HRV giảm mạnh (\(Int(hrvDrop * 100))%) đồng thời nhịp tim tĩnh tăng (\(Int(rhrIncrease * 100))%). Điều này chỉ ra hệ thần kinh đối giao cảm đang bị ức chế mạnh do thiếu hồi phục.",
                    recommendation: "Ngừng ngay các bài tập cường độ cao (HIIT, chạy nặng) trong 48 giờ tới. Tập trung vào các bài tập kéo giãn, Yoga nhẹ nhàng và ngủ thêm ít nhất 1-2 tiếng mỗi đêm."
                ))
            }
        }
        
        // D. Burnout / Extreme Stress Warning
        // Rule: Stress Index > 75 and Recovery < 35
        if self.stressIndex > 75 && self.recoveryScore < 35 {
            detectedHazards.append(HealthHazard(
                level: .critical,
                title: "Nguy Cơ Kiệt Sức Cực Hạn (High Burnout Risk)",
                description: "Chỉ số Căng thẳng đo được ở mức rất cao (\(stressIndex)/100) kết hợp với Khả năng Phục hồi cạn kiệt (\(recoveryScore)%). Hệ thần kinh của bạn đang ở trạng thái báo động đỏ liên tục.",
                recommendation: "Đây là trạng thái nguy hiểm cho sức khỏe tim mạch lâu dài. Bạn cần dành trọn vẹn 1 ngày nghỉ ngơi hoàn toàn, ngắt kết nối công việc, thực hiện thiền định và bổ sung nước đầy đủ."
            ))
        }
        
        // E. Noise Hazard Warning
        // Rule: Average decibel exposure > 80 dB
        let recentNoise = healthManager.noiseRecords.suffix(5).map { $0.value }
        if !recentNoise.isEmpty {
            let avgNoise = recentNoise.reduce(0, +) / Double(recentNoise.count)
            if avgNoise > 85 {
                detectedHazards.append(HealthHazard(
                    level: .critical,
                    title: "Nguy Hiểm Thính Lực (Loud Noise Exposure)",
                    description: "Apple Watch phát hiện bạn thường xuyên tiếp xúc với tiếng ồn trung bình đạt \(Int(avgNoise)) dB, vượt ngưỡng an toàn cho tai (80 dB). Tiếp xúc lâu có thể gây suy giảm thính lực vĩnh viễn.",
                    recommendation: "Di chuyển ra khỏi khu vực ồn ào hoặc sử dụng nút bịt tai chống ồn. Hạn chế nghe tai nghe âm lượng lớn trong thời gian này."
                ))
            } else if avgNoise > 75 {
                detectedHazards.append(HealthHazard(
                    level: .warning,
                    title: "Ô Nhiễm Tiếng Ồn Nhẹ",
                    description: "Mức độ âm thanh môi trường trung bình đo được là \(Int(avgNoise)) dB.",
                    recommendation: "Hãy chú ý bảo vệ tai của bạn. Tránh ở quá lâu trong môi trường có âm thanh lớn liên tục trên 2 tiếng."
                ))
            }
        }
        
        // F. Cardiac Anomaly Warning (Elevated RHR)
        if let latestRHR = healthManager.rhrRecords.last {
            if latestRHR.value > 95 {
                detectedHazards.append(HealthHazard(
                    level: .critical,
                    title: "Nhịp Tim Tĩnh Cao Bất Thường (Tachycardia Risk)",
                    description: "Nhịp tim khi nghỉ ngơi gần nhất đo được là \(Int(latestRHR.value)) bpm. Mức này quá cao đối với trạng thái nghỉ ngơi bình thường.",
                    recommendation: "Ngồi nghỉ tại chỗ thoáng mát, uống một cốc nước ấm nhẹ. Tránh sử dụng caffeine, nicotine hay chất kích thích. Nếu nhịp tim tiếp tục cao và kèm khó thở, hãy đi khám tim mạch."
                ))
            }
        }
        
        self.activeHazards = detectedHazards
        
        // 5. Generate Local AI Detailed Health Insights Report in Markdown
        self.localAiReportMarkdown = generateAILocalReport(
            healthManager: healthManager,
            hazards: detectedHazards
        )
    }
    
    // MARK: - Internal Score Calculations
    
    private func calculateSleepQuality(sleepRecords: [SleepSegment]) -> (score: Int, explanation: String) {
        guard !sleepRecords.isEmpty else {
            return (0, "Không có dữ liệu giấc ngủ. Vui lòng đeo Apple Watch đi ngủ.")
        }
        
        // Group by night (standard night: 6pm to 6pm next day)
        // Here we estimate based on the last night recorded.
        let calendar = Calendar.current
        let latestRecord = sleepRecords.sorted(by: { $0.endDate < $1.endDate }).last!
        let lastNightStart = calendar.date(byAdding: .hour, value: -12, to: latestRecord.endDate)!
        
        let lastNightSegments = sleepRecords.filter { $0.startDate >= lastNightStart }
        let totalSleepDuration = lastNightSegments.reduce(0) { $0 + ($1.stage != "Awake" ? $1.duration : 0) }
        let awakeDuration = lastNightSegments.reduce(0) { $0 + ($1.stage == "Awake" ? $1.duration : 0) }
        
        let deepDuration = lastNightSegments.reduce(0) { $0 + ($1.stage == "Deep" ? $1.duration : 0) }
        let remDuration = lastNightSegments.reduce(0) { $0 + ($1.stage == "REM" ? $1.duration : 0) }
        
        let totalHours = totalSleepDuration / 3600.0
        
        // 1. Duration Score (Max 45 points)
        // Optimal: 7.5 to 8.5 hours.
        var durationScore = 0.0
        if totalHours >= 7.5 && totalHours <= 8.5 {
            durationScore = 45
        } else if totalHours > 8.5 {
            durationScore = max(20, 45 - (totalHours - 8.5) * 10)
        } else {
            durationScore = max(10, (totalHours / 7.5) * 45)
        }
        
        // 2. Sleep Depth (REM + Deep ratio) (Max 35 points)
        // Ideal: > 35% of total sleep is Deep + REM
        var depthScore = 0.0
        if totalSleepDuration > 0 {
            let coreRatio = (deepDuration + remDuration) / totalSleepDuration
            if coreRatio >= 0.38 {
                depthScore = 35
            } else {
                depthScore = (coreRatio / 0.38) * 35
            }
        }
        
        // 3. Sleep Efficiency (Interrupt ratio) (Max 20 points)
        // Ideal: Awake ratio is less than 5% of sleep
        var efficiencyScore = 0.0
        let totalInterval = totalSleepDuration + awakeDuration
        if totalInterval > 0 {
            let awakeRatio = awakeDuration / totalInterval
            if awakeRatio <= 0.05 {
                efficiencyScore = 20
            } else {
                efficiencyScore = max(0, 20 - (awakeRatio - 0.05) * 100)
            }
        }
        
        let finalScore = Int(durationScore + depthScore + efficiencyScore)
        let cappedScore = min(100, max(0, finalScore))
        
        var exp = ""
        if cappedScore >= 85 {
            exp = "Giấc ngủ tuyệt vời! Tổng thời gian đạt \(String(format: "%.1f", totalHours)) giờ với \(Int(deepDuration/60)) phút ngủ sâu (Deep) và \(Int(remDuration/60)) phút ngủ mơ (REM). Nhịp tim và hơi thở điều hòa cực kỳ ổn định."
        } else if cappedScore >= 70 {
            exp = "Giấc ngủ khá ổn (\(String(format: "%.1f", totalHours)) giờ). Tuy nhiên, thời lượng ngủ sâu hoặc REM hơi ít hơn so với tiêu chuẩn mong muốn, hoặc có một vài lần thức giấc nhẹ giữa đêm."
        } else {
            exp = "Giấc ngủ kém chất lượng (\(String(format: "%.1f", totalHours)) giờ). Phát hiện tỷ lệ thức giấc cao (\(Int(awakeDuration/60)) phút) hoặc thiếu ngủ sâu nghiêm trọng. Cần điều chỉnh giờ đi ngủ cố định hơn."
        }
        
        return (cappedScore, exp)
    }
    
    private func calculateRecovery(sleepScore: Int, hrvRecords: [HRVData], rhrRecords: [RHRData]) -> (score: Int, explanation: String) {
        // HRV contribution (40%)
        // Resting HR contribution (30%)
        // Sleep score contribution (30%)
        
        var hrvScoreVal = 50.0
        if let latestHRV = hrvRecords.last {
            // Baseline is around 55ms. Let's scale: HRV > 70 is 100% score, HRV < 25 is 0% score.
            let hrvVal = latestHRV.value
            if hrvVal >= 70 {
                hrvScoreVal = 100
            } else if hrvVal <= 25 {
                hrvScoreVal = 10
            } else {
                hrvScoreVal = 10 + ((hrvVal - 25) / 45.0) * 90
            }
        }
        
        var rhrScoreVal = 60.0
        if let latestRHR = rhrRecords.last {
            // Baseline: RHR around 60bpm is optimal (100% score). RHR > 85 is 0% score, RHR < 50 is also excellent.
            let rhrVal = latestRHR.value
            if rhrVal <= 58 {
                rhrScoreVal = 100
            } else if rhrVal >= 85 {
                rhrScoreVal = 10
            } else {
                rhrScoreVal = 100 - ((rhrVal - 58) / 27.0) * 90
            }
        }
        
        let finalScore = Int((hrvScoreVal * 0.4) + (rhrScoreVal * 0.3) + (Double(sleepScore) * 0.3))
        let cappedScore = min(100, max(0, finalScore))
        
        var exp = ""
        if cappedScore >= 80 {
            exp = "Cơ thể bạn đã hồi phục hoàn toàn! Nhịp tim tĩnh thấp cùng biến thiên nhịp tim (HRV) cao cho thấy hệ thần kinh đối giao cảm hoạt động mạnh mẽ. Sẵn sàng cho mọi hoạt động thể thao cường độ cao."
        } else if cappedScore >= 50 {
            exp = "Khả năng hồi phục ở mức trung bình. Thần kinh có dấu hiệu mệt mỏi nhẹ từ hôm trước. Bạn vẫn có thể tập luyện nhẹ nhàng, nhưng tránh đẩy cơ thể đến mức quá giới hạn."
        } else {
            exp = "Khả năng hồi phục kém! Cơ thể đang chịu tải nặng, hệ tim mạch và thần kinh chưa hồi phục sau các kích thích. Cần ưu tiên ngủ bù, bổ sung nước và không hoạt động thể lực nặng."
        }
        
        return (cappedScore, exp)
    }
    
    private func calculateStress(hrvRecords: [HRVData], rhrRecords: [RHRData], sleepRecords: [SleepSegment]) -> (score: Int, explanation: String) {
        // Stress is high when HRV is low, RHR is high, and sleep is insufficient.
        var stressPoints = 30.0 // Default baseline
        
        // 1. HRV impact (up to 40 points)
        if let latestHRV = hrvRecords.last {
            let hrvVal = latestHRV.value
            if hrvVal < 35 {
                stressPoints += 40 // very low HRV -> high stress
            } else if hrvVal < 50 {
                stressPoints += 25
            } else if hrvVal > 70 {
                stressPoints -= 15 // high HRV -> relaxation
            }
        }
        
        // 2. RHR impact (up to 30 points)
        if let latestRHR = rhrRecords.last {
            let rhrVal = latestRHR.value
            if rhrVal > 75 {
                stressPoints += 30
            } else if rhrVal > 65 {
                stressPoints += 15
            } else if rhrVal < 55 {
                stressPoints -= 10
            }
        }
        
        // 3. Sleep Debt impact (up to 30 points)
        if !sleepRecords.isEmpty {
            let recentSleep = sleepRecords.suffix(15)
            let totalSleepSec = recentSleep.reduce(0) { $0 + ($1.stage != "Awake" ? $1.duration : 0) }
            let avgSleep = (totalSleepSec / 3600.0) / 7.0 // average over last few nights
            if avgSleep < 6.0 {
                stressPoints += 30
            } else if avgSleep < 7.0 {
                stressPoints += 15
            }
        }
        
        let finalScore = Int(stressPoints)
        let cappedScore = min(100, max(0, finalScore))
        
        var exp = ""
        if cappedScore >= 70 {
            exp = "Mức độ căng thẳng (Stress) ở mức CAO. Hệ thần kinh giao cảm (Sympathetic) đang thống trị, nhịp tim biến động ít và cơ thể duy trì trạng thái phòng thủ chống lại stress. Hãy tập hít thở đều (box breathing) ngay."
        } else if cappedScore >= 40 {
            exp = "Mức độ căng thẳng TRUNG BÌNH. Đây là áp lực bình thường của ngày làm việc thông thường, cơ thể vẫn đang kiểm soát tốt các tác nhân căng thẳng."
        } else {
            exp = "Trạng thái thư giãn HOÀN TOÀN (Thư thái). Cơ thể đang tích lũy năng lượng, thần kinh cân bằng và nhịp tim tĩnh được duy trì cực tốt."
        }
        
        return (cappedScore, exp)
    }
    
    private func calculateCardiovascular(rhrRecords: [RHRData], spo2Records: [SpO2Data]) -> (score: Int, explanation: String) {
        // Cardio health is assessed by RHR and SpO2 levels.
        var points = 75.0
        
        // RHR evaluation (optimal 50-60 bpm)
        if let latestRHR = rhrRecords.last {
            let rhrVal = latestRHR.value
            if rhrVal >= 50 && rhrVal <= 60 {
                points += 15
            } else if rhrVal > 60 && rhrVal <= 70 {
                points += 5
            } else if rhrVal > 70 {
                points -= min(30, (rhrVal - 70) * 1.5)
            } else if rhrVal < 50 {
                points += 10 // highly trained athlete
            }
        }
        
        // SpO2 evaluation (optimal 97-100%)
        if let latestSpO2 = spo2Records.last {
            let spo2Percent = latestSpO2.value * 100
            if spo2Percent >= 97 {
                points += 10
            } else if spo2Percent < 95 && spo2Percent >= 90 {
                points -= 25
            } else if spo2Percent < 90 {
                points -= 50
            }
        }
        
        let finalScore = Int(points)
        let cappedScore = min(100, max(0, finalScore))
        
        var exp = ""
        if cappedScore >= 85 {
            exp = "Hệ tuần hoàn vô cùng khỏe mạnh! Nhịp tim tĩnh xuất sắc biểu hiện cơ tim khỏe, bơm máu hiệu quả kết hợp nồng độ bão hòa oxy máu đạt chuẩn tối đa. Khả năng nạp oxy của phổi cực tốt."
        } else if cappedScore >= 70 {
            exp = "Hệ tim mạch bình thường. Không phát hiện dấu hiệu bất thường nghiêm trọng, tuy nhiên nhịp tim tĩnh có phần hơi cao hoặc độ bão hòa oxy giảm nhẹ tạm thời do mệt mỏi."
        } else {
            exp = "Cảnh báo chỉ số tim mạch/hô hấp KÉM! Phát hiện dấu hiệu nhịp tim nhanh khi nghỉ ngơi hoặc nồng độ bão hòa oxy máu thường xuyên giảm dưới ngưỡng chuẩn. Cần kiểm tra sức khỏe tổng quát."
        }
        
        return (cappedScore, exp)
    }
    
    // MARK: - Markdown Report Generator
    
    private func generateAILocalReport(healthManager: HealthManager, hazards: [HealthHazard]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm, dd/MM/yyyy"
        let timestamp = dateFormatter.string(from: Date())
        
        let rhrVal = healthManager.rhrRecords.last?.value ?? 0
        let hrvVal = healthManager.hrvRecords.last?.value ?? 0
        let spo2Val = (healthManager.spo2Records.last?.value ?? 0) * 100
        
        // Total sleep calculations
        let sleepRecs = healthManager.sleepRecords.suffix(10)
        let totalSleepSec = sleepRecs.reduce(0) { $0 + ($1.stage != "Awake" ? $1.duration : 0) }
        let avgSleepVal = sleepRecs.isEmpty ? 0 : (totalSleepSec / 3600.0) / Double(Set(sleepRecs.map { Calendar.current.startOfDay(for: $0.startDate) }).count)
        
        var md = """
        # BÁO CÁO PHÂN TÍCH SỨC KHỎE CHUYÊN SÂU
        *Thời gian phân tích: \(timestamp)*
        *Phương thức: Chạy AI Cục bộ Offline (iPhone CPU)*
        
        ---
        
        ## 📊 CHỈ SỐ TOÀN DIỆN (HEALTH MATRIX)
        
        | Chỉ Số Sức Khỏe | Giá Trị Đo Được | Đánh Giá Cục Bộ | Điểm Số |
        | :--- | :--- | :--- | :--- |
        | **Điểm Phục Hồi (Recovery)** | \(recoveryScore)% | \(recoveryScore >= 80 ? "Xuất sắc" : (recoveryScore >= 50 ? "Khá" : "Yếu")) | **\(recoveryScore)/100** |
        | **Mức Căng Thẳng (Stress)** | \(stressIndex)% | \(stressIndex >= 70 ? "Cao" : (stressIndex >= 40 ? "Bình thường" : "Thư thái")) | **\(stressIndex)/100** |
        | **Tim Mạch & Hô Hấp** | \(cardiovascularScore)% | \(cardiovascularScore >= 85 ? "Khỏe mạnh" : (cardiovascularScore >= 70 ? "Trung bình" : "Suy giảm")) | **\(cardiovascularScore)/100** |
        | **Chất Lượng Giấc Ngủ** | \(sleepQualityScore)% | \(sleepQualityScore >= 85 ? "Tối ưu" : (sleepQualityScore >= 70 ? "Đạt yêu cầu" : "Thấp")) | **\(sleepQualityScore)/100** |
        
        ---
        
        ## 🚨 BẢNG PHÁT HIỆN MỐI NGUY HIỂM (HAZARD RADAR)
        
        """
        
        if hazards.isEmpty {
            md += "> ✅ **Không phát hiện mối nguy hiểm nào.** Hệ thống tim mạch, hô hấp và phục hồi thần kinh của bạn hiện tại hoạt động bình thường trong ngưỡng an toàn của Apple Health.\n\n"
        } else {
            md += "Hệ thống phát hiện **\(hazards.count) mối nguy hiểm tiềm ẩn** cần lưu ý:\n\n"
            for hazard in hazards {
                let colorPrefix = hazard.level == .critical ? "🔴" : "🟡"
                md += "### \(colorPrefix) \(hazard.title) (Mức: \(hazard.level.rawValue))\n"
                md += "- **Chi tiết phát hiện:** \(hazard.description)\n"
                md += "- **Khuyến nghị từ AI:** \(hazard.recommendation)\n\n"
            }
        }
        
        md += """
        ---
        
        ## 🧬 PHÂN TÍCH CHUYÊN SÂU TỪ CƠ THỂ
        
        ### 1. Phân Tích Hệ Thần Kinh Thực Vật (ANS) & HRV
        - **Biến thiên nhịp tim (HRV) hiện tại:** `\(Int(hrvVal)) ms`. 
        - **Đánh giá:** HRV đại diện cho hoạt động của dây thần kinh phế vị và hệ đối giao cảm. HRV ở mức này chỉ ra \(hrvVal < 40 ? "hệ thần kinh đang bị quá tải, khả năng tự điều hòa căng thẳng kém. Cơ thể đang gồng mình chống đỡ stress." : "hệ thần kinh tự chủ linh hoạt, khả năng thích ứng cao với các áp lực sinh lý và tâm lý.").
        
        ### 2. Sức Khỏe Tim Mạch & Hô Hấp (Cardio-Respiratory)
        - **Nhịp tim tĩnh (RHR):** `\(Int(rhrVal)) bpm` | **Nồng độ Oxy máu (SpO2):** `\(Int(spo2Val))%`.
        - **Đánh giá:** Nhịp tim tĩnh là chỉ báo trực tiếp cho thấy sức mạnh cơ tim. Nhịp tim tĩnh `\(Int(rhrVal)) bpm` biểu thị \(rhrVal > 75 ? "tim phải đập nhiều hơn để bơm máu, có thể do thiếu ngủ, chất kích thích hoặc mệt mỏi tích lũy." : "cơ tim khỏe mạnh, lượng máu mỗi nhịp bơm dồi dào, tối ưu hóa mức tiêu hao năng lượng."). Oxy máu \(spo2Val < 95 ? "có dấu hiệu suy giảm nhẹ, hãy chú ý lưu thông khí phòng ngủ." : "duy trì ở mức tuyệt vời, phổi trao đổi khí hiệu quả.").
        
        ### 3. Chất Lượng Giấc Ngủ (Sleep Staging)
        - **Thời gian ngủ trung bình:** `\(String(format: "%.1f", avgSleepVal)) giờ/đêm`.
        - **Đánh giá:** \(sleepQualityScore < 70 ? "Chu kỳ giấc ngủ bị phân mảnh cao. Thiếu hụt thời gian ngủ sâu (Deep Sleep) làm hạn chế quá trình tái tạo tế bào, phục hồi cơ bắp và củng cố trí nhớ." : "Chu kỳ giấc ngủ đồng đều. Các pha ngủ sâu (Deep) và ngủ mơ (REM) diễn ra đầy đủ giúp cơ thể giải độc não bộ và phục hồi thể lực hoàn chỉnh.").
        
        ---
        
        ## 📝 ĐỀ XUẤT HÀNH ĐỘNG HÀNG NGÀY (ACTIONABLE STEPS)
        
        """
        
        // Contextual advice based on scores
        if recoveryScore < 45 {
            md += "1. 🛑 **Nghỉ ngơi bắt buộc:** Không tham gia các buổi tập nặng hôm nay. Đi bộ nhẹ nhàng dưới 30 phút là đủ.\n"
        } else if recoveryScore < 70 {
            md += "1. 🏃‍♂️ **Tập luyện vừa phải:** Bạn có thể tập yoga, cardio nhẹ hoặc chạy bộ cự ly ngắn ở vùng nhịp tim Zone 2.\n"
        } else {
            md += "1. 🔥 **Tăng cường thể lực:** Hôm nay là ngày hoàn hảo để thử thách bản thân với các bài tập nặng hoặc chạy bền.\n"
        }
        
        if stressIndex > 60 {
            md += "2. 🧘‍♂️ **Hạ nhiệt thần kinh:** Thực hiện bài tập thở Box Breathing (Hít vào 4s - Giữ 4s - Thở ra 4s - Giữ 4s) liên tục trong 5 phút. Tránh nạp thêm caffein sau 12h trưa.\n"
        } else {
            md += "2. ⚡ **Duy trì nhịp sinh học:** Đón ánh nắng sáng sớm ít nhất 10 phút để tối ưu hóa lượng cortisol tự nhiên và melatonin vào ban đêm.\n"
        }
        
        if sleepQualityScore < 70 {
            md += "3. 📵 **Vệ sinh giấc ngủ (Sleep Hygiene):** Tắt toàn bộ màn hình điện thoại/máy tính trước khi ngủ 45 phút. Giữ phòng ngủ ở nhiệt độ mát mẻ (khoảng 20-22°C) và tối hoàn toàn.\n"
        } else {
            md += "3. 😴 **Giữ vững phong độ:** Duy trì khung giờ ngủ và thức dậy cố định (chênh lệch không quá 30 phút kể cả ngày cuối tuần).\n"
        }
        
        md += "\n*Tuyên bố miễn trừ trách nhiệm y tế: Các thông số phân tích trên được tính toán hoàn toàn cục bộ dựa trên dữ liệu Apple Health và không thay thế cho các chẩn đoán y tế chuyên nghiệp của bác sĩ.*"
        
        return md
    }
}

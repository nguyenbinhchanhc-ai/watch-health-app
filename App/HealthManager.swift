import Foundation
import HealthKit
import Combine

public struct StepData: Identifiable, Codable {
    public var id = UUID()
    public var date: Date
    public var count: Double
}

public struct CaloriesData: Identifiable, Codable {
    public var id = UUID()
    public var date: Date
    public var calories: Double
}

public struct HeartRateData: Identifiable, Codable {
    public var id = UUID()
    public var date: Date
    public var value: Double
}

public struct HRVData: Identifiable, Codable {
    public var id = UUID()
    public var date: Date
    public var value: Double // in ms
}

public struct RHRData: Identifiable, Codable {
    public var id = UUID()
    public var date: Date
    public var value: Double // bpm
}

public struct SpO2Data: Identifiable, Codable {
    public var id = UUID()
    public var date: Date
    public var value: Double // fraction (e.g. 0.98 for 98%)
}

public struct SleepSegment: Identifiable, Codable {
    public var id = UUID()
    public var startDate: Date
    public var endDate: Date
    public var duration: TimeInterval
    public var stage: String // "Core", "Deep", "REM", "Awake", or "Unknown"
}

public struct NoiseData: Identifiable, Codable {
    public var id = UUID()
    public var date: Date
    public var value: Double // dB
}

public struct WorkoutLog: Identifiable, Codable {
    public var id = UUID()
    public var type: String
    public var duration: TimeInterval
    public var calories: Double
    public var avgHeartRate: Double
    public var date: Date
}

@MainActor
public class HealthManager: ObservableObject {
    @Published public var isXmlDataLoaded = false
    @Published public var isMockDataUsed = false
    @Published public var isParsing = false
    @Published public var importedXmlFileName = ""
    @Published public var parseError = ""
    
    // Core Metrics (Imported or simulated)
    @Published public var stepsToday: [StepData] = []
    @Published public var caloriesToday: [CaloriesData] = []
    @Published public var heartRateRecords: [HeartRateData] = []
    @Published public var hrvRecords: [HRVData] = []
    @Published public var rhrRecords: [RHRData] = []
    @Published public var spo2Records: [SpO2Data] = []
    @Published public var sleepRecords: [SleepSegment] = []
    @Published public var noiseRecords: [NoiseData] = []
    @Published public var recentWorkouts: [WorkoutLog] = []
    
    public init() {
        // App starts empty by default (no mock data) to stick exactly to user's real Apple Watch data.
    }
    
    public func importXML(from url: URL) async {
        isParsing = true
        parseError = ""
        
        // Access security scoped resource for iOS Files App picker
        guard url.startAccessingSecurityScopedResource() else {
            self.parseError = "Không có quyền truy cập tệp tin này."
            self.isParsing = false
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // Execute parser on background thread to keep UI smooth
        let task = Task.detached(priority: .userInitiated) { () -> AppleHealthXMLParser? in
            guard let parser = XMLParser(contentsOf: url) else {
                return nil
            }
            
            let healthXmlParser = AppleHealthXMLParser(daysToKeep: 14) // Limit to last 14 days
            parser.delegate = healthXmlParser
            
            if parser.parse() {
                return healthXmlParser
            } else {
                return nil
            }
        }
        
        let result = await task.value
        
        if let healthParser = result {
            self.importedXmlFileName = url.lastPathComponent
            self.isXmlDataLoaded = true
            self.isMockDataUsed = false
            
            // 1. Process & aggregate hourly steps for today
            aggregateSteps(healthParser.steps)
            
            // 2. Process & aggregate hourly calories for today
            aggregateCalories(healthParser.calories)
            
            // 3. Process heart rates (last 24 hours)
            let calendar = Calendar.current
            let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            self.heartRateRecords = healthParser.heartRates
                .filter { $0.date >= yesterday }
                .sorted(by: { $0.date < $1.date })
            
            // 4. HRV
            self.hrvRecords = healthParser.hrvs.sorted(by: { $0.date < $1.date })
            
            // 5. Resting Heart Rate
            self.rhrRecords = healthParser.rhrs.sorted(by: { $0.date < $1.date })
            
            // 6. Oxygen Saturation
            self.spo2Records = healthParser.spo2s.sorted(by: { $0.date < $1.date })
            
            // 7. Sleep segments
            self.sleepRecords = healthParser.sleepSegments.sorted(by: { $0.startDate < $1.startDate })
            
            // 8. Sound Exposure
            self.noiseRecords = healthParser.noises.sorted(by: { $0.date < $1.date })
            
            // 9. Workouts
            self.recentWorkouts = healthParser.workouts.sorted(by: { $0.date < $1.date })
            
            self.isParsing = false
        } else {
            self.parseError = "Biên dịch tệp XML thất bại. Vui lòng đảm bảo tệp đúng định dạng export.xml từ Apple Health."
            self.isParsing = false
        }
    }
    
    // Group step samples into hourly blocks for today
    private func aggregateSteps(_ rawSteps: [StepData]) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let todaySteps = rawSteps.filter { $0.date >= startOfToday }
        
        var stepsMap: [Date: Double] = [:]
        for hour in 0..<24 {
            if let date = calendar.date(byAdding: .hour, value: hour, to: startOfToday) {
                stepsMap[date] = 0.0
            }
        }
        
        for step in todaySteps {
            let hourComponent = calendar.component(.hour, from: step.date)
            if let hourDate = calendar.date(bySettingHour: hourComponent, minute: 0, second: 0, of: startOfToday) {
                stepsMap[hourDate, default: 0.0] += step.count
            }
        }
        
        self.stepsToday = stepsMap.map { StepData(date: $0.key, count: $0.value) }.sorted(by: { $0.date < $1.date })
    }
    
    // Group active calorie samples into hourly blocks for today
    private func aggregateCalories(_ rawCalories: [CaloriesData]) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let todayCalories = rawCalories.filter { $0.date >= startOfToday }
        
        var calMap: [Date: Double] = [:]
        for hour in 0..<24 {
            if let date = calendar.date(byAdding: .hour, value: hour, to: startOfToday) {
                calMap[date] = 0.0
            }
        }
        
        for cal in todayCalories {
            let hourComponent = calendar.component(.hour, from: cal.date)
            if let hourDate = calendar.date(bySettingHour: hourComponent, minute: 0, second: 0, of: startOfToday) {
                calMap[hourDate, default: 0.0] += cal.calories
            }
        }
        
        self.caloriesToday = calMap.map { CaloriesData(date: $0.key, calories: $0.value.rounded(toPlaces: 1)) }.sorted(by: { $0.date < $1.date })
    }
    
    public func forceUseMockData() {
        self.isMockDataUsed = true
        self.isXmlDataLoaded = true
        loadMockData()
    }
    
    public func resetData() {
        self.isXmlDataLoaded = false
        self.isMockDataUsed = false
        self.importedXmlFileName = ""
        self.stepsToday = []
        self.caloriesToday = []
        self.heartRateRecords = []
        self.hrvRecords = []
        self.rhrRecords = []
        self.spo2Records = []
        self.sleepRecords = []
        self.noiseRecords = []
        self.recentWorkouts = []
    }
    
    // High-fidelity Mock Data Generator (kept in Settings only as option)
    private func loadMockData() {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        // 1. Steps Today (24 hours)
        var mockSteps: [StepData] = []
        let hourlyStepsPattern: [Double] = [
            0, 0, 0, 0, 0, 0,
            150, 400, 1200, 800,
            500, 600, 1100, 900,
            450, 300, 500, 650,
            2500, 1200, 800, 400,
            200, 100, 0, 0
        ]
        for hour in 0..<24 {
            if let date = calendar.date(byAdding: .hour, value: hour, to: startOfToday) {
                if date <= now {
                    let patternSteps = hourlyStepsPattern[hour]
                    let randomOffset = patternSteps > 0 ? Double.random(in: -0.15...0.15) * patternSteps : 0
                    mockSteps.append(StepData(date: date, count: max(0, patternSteps + randomOffset).rounded()))
                }
            }
        }
        self.stepsToday = mockSteps
        
        // 2. Active Calories Today (24 hours)
        var mockCalories: [CaloriesData] = []
        let hourlyCalPattern: [Double] = [
            1.2, 1.2, 1.2, 1.2, 1.2, 1.2,
            10, 15, 45, 30,
            20, 25, 40, 30,
            18, 15, 22, 28,
            220, 90, 40, 20,
            10, 5, 1.2, 1.2
        ]
        for hour in 0..<24 {
            if let date = calendar.date(byAdding: .hour, value: hour, to: startOfToday) {
                if date <= now {
                    let patternCal = hourlyCalPattern[hour]
                    let randomOffset = Double.random(in: -0.1...0.1) * patternCal
                    mockCalories.append(CaloriesData(date: date, calories: max(1.2, patternCal + randomOffset).rounded(toPlaces: 1)))
                }
            }
        }
        self.caloriesToday = mockCalories
        
        // 3. Heart Rate (Recent 24 hours)
        var mockHR: [HeartRateData] = []
        for hour in 0..<24 {
            if let baseDate = calendar.date(byAdding: .hour, value: -hour, to: now) {
                let hourOfDay = calendar.component(.hour, from: baseDate)
                var baseHR = 65.0
                if hourOfDay >= 0 && hourOfDay < 6 {
                    baseHR = 54.0
                } else if hourOfDay == 7 || hourOfDay == 8 {
                    baseHR = 85.0
                } else if hourOfDay == 18 {
                    baseHR = 145.0
                } else if hourOfDay == 19 {
                    baseHR = 110.0
                } else if hourOfDay >= 10 && hourOfDay < 17 {
                    baseHR = 72.0
                }
                for minOffset in [0, 20, 40] {
                    if let date = calendar.date(byAdding: .minute, value: -minOffset, to: baseDate) {
                        let finalHR = baseHR + Double.random(in: -6...8)
                        mockHR.append(HeartRateData(date: date, value: finalHR.rounded()))
                    }
                }
            }
        }
        self.heartRateRecords = mockHR.sorted(by: { $0.date < $1.date })
        
        // 4. HRV (Last 7 days)
        var mockHRV: [HRVData] = []
        for day in 0..<7 {
            if let baseDate = calendar.date(byAdding: .day, value: -day, to: now) {
                let isFatiguedDay = day == 2
                let baseHrvVal = isFatiguedDay ? 32.0 : 58.0
                for hrOffset in [4, 12, 20] {
                    if let date = calendar.date(byAdding: .hour, value: hrOffset, to: calendar.startOfDay(for: baseDate)) {
                        let finalHrv = baseHrvVal + Double.random(in: -8...10)
                        mockHRV.append(HRVData(date: date, value: finalHrv.rounded()))
                    }
                }
            }
        }
        self.hrvRecords = mockHRV.sorted(by: { $0.date < $1.date })
        
        // 5. Resting Heart Rate
        var mockRHR: [RHRData] = []
        for day in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -day, to: now) {
                let isFatiguedDay = day == 2
                let baseRhrVal = isFatiguedDay ? 64.0 : 54.0
                let finalRhr = baseRhrVal + Double.random(in: -2...3)
                mockRHR.append(RHRData(date: calendar.startOfDay(for: date), value: finalRhr.rounded()))
            }
        }
        self.rhrRecords = mockRHR.sorted(by: { $0.date < $1.date })
        
        // 6. Oxygen Saturation
        var mockSpO2: [SpO2Data] = []
        for day in 0..<7 {
            if let baseDate = calendar.date(byAdding: .day, value: -day, to: now) {
                for hour in [10, 14, 17] {
                    if let date = calendar.date(byAdding: .hour, value: hour, to: baseDate) {
                        let val = Double.random(in: 0.96...1.00)
                        mockSpO2.append(SpO2Data(date: date, value: val))
                    }
                }
                let hasApneaDip = day == 3
                for hour in [2, 4] {
                    if let date = calendar.date(byAdding: .hour, value: hour, to: baseDate) {
                        let val = hasApneaDip && hour == 2 ? Double.random(in: 0.88...0.91) : Double.random(in: 0.93...0.97)
                        mockSpO2.append(SpO2Data(date: date, value: val))
                    }
                }
            }
        }
        self.spo2Records = mockSpO2.sorted(by: { $0.date < $1.date })
        
        // 7. Sleep
        var mockSleep: [SleepSegment] = []
        for day in 0..<7 {
            if let baseDate = calendar.date(byAdding: .day, value: -day, to: now) {
                let startSleep = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: baseDate)!
                let sleepStages: [(durationMin: Double, stage: String)] = [
                    (15, "Awake"), (75, "Core"), (45, "Deep"), (45, "Core"), (30, "REM"),
                    (75, "Core"), (30, "Deep"), (75, "Core"), (45, "REM"), (45, "Core")
                ]
                var currentStart = startSleep
                for item in sleepStages {
                    let durationMultiplier = day == 2 ? 0.65 : 1.0
                    let actualDuration = item.durationMin * 60 * durationMultiplier
                    let currentEnd = currentStart.addingTimeInterval(actualDuration)
                    mockSleep.append(SleepSegment(
                        startDate: currentStart,
                        endDate: currentEnd,
                        duration: actualDuration,
                        stage: item.stage
                    ))
                    currentStart = currentEnd
                }
            }
        }
        self.sleepRecords = mockSleep.sorted(by: { $0.startDate < $1.startDate })
        
        // 8. Noise
        var mockNoise: [NoiseData] = []
        for day in 0..<7 {
            if let baseDate = calendar.date(byAdding: .day, value: -day, to: now) {
                if let date = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: baseDate) {
                    mockNoise.append(NoiseData(date: date, value: Double.random(in: 65...78)))
                }
                if let date = calendar.date(bySettingHour: 18, minute: 15, second: 0, of: baseDate) {
                    let loudNoise = day == 1 ? Double.random(in: 85...92) : Double.random(in: 72...82)
                    mockNoise.append(NoiseData(date: date, value: loudNoise))
                }
                for hour in [11, 15, 21] {
                    if let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: baseDate) {
                        mockNoise.append(NoiseData(date: date, value: Double.random(in: 32...48)))
                    }
                }
            }
        }
        self.noiseRecords = mockNoise.sorted(by: { $0.date < $1.date })
        
        // 9. Workouts
        var mockWorkouts: [WorkoutLog] = []
        let workoutTypes = ["Chạy bộ (Outdoor Run)", "Đạp xe (Outdoor Cycle)", "Bơi lội (Pool Swim)", "Tập tạ (Functional Strength Training)"]
        for day in [1, 3, 5] {
            if let date = calendar.date(byAdding: .day, value: -day, to: now) {
                let workoutType = workoutTypes[day % workoutTypes.count]
                let duration = Double.random(in: 30...60) * 60
                let calories = (duration / 60) * Double.random(in: 7...11)
                let avgHR = Double.random(in: 130...155)
                mockWorkouts.append(WorkoutLog(
                    id: UUID(),
                    type: workoutType,
                    duration: duration,
                    calories: calories.rounded(),
                    avgHeartRate: avgHR.rounded(),
                    date: calendar.date(bySettingHour: 18, minute: 0, second: 0, of: date)!
                ))
            }
        }
        self.recentWorkouts = mockWorkouts.sorted(by: { $0.date < $1.date })
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

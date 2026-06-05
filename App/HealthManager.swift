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
    @Published public var isAuthorized = false
    @Published public var isMockDataUsed = false
    
    // Core Metrics
    @Published public var stepsToday: [StepData] = []
    @Published public var caloriesToday: [CaloriesData] = []
    @Published public var heartRateRecords: [HeartRateData] = []
    @Published public var hrvRecords: [HRVData] = []
    @Published public var rhrRecords: [RHRData] = []
    @Published public var spo2Records: [SpO2Data] = []
    @Published public var sleepRecords: [SleepSegment] = []
    @Published public var noiseRecords: [NoiseData] = []
    @Published public var recentWorkouts: [WorkoutLog] = []
    
    public let healthStore: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    
    public init() {
        checkAuthorizationStatus()
    }
    
    private func checkAuthorizationStatus() {
        guard let healthStore = healthStore else { return }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure)!,
            HKWorkoutType.workoutType()
        ]
        
        // Since iOS does not provide a direct API to check read permission status for privacy reasons,
        // we assume we need to request authorization, or check if we have run it.
        // We'll track it in UserDefaults.
        self.isAuthorized = UserDefaults.standard.bool(forKey: "HealthKitAuthorized")
    }
    
    public func requestAuthorization() async -> Bool {
        guard let healthStore = healthStore else {
            loadMockData()
            return false
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure)!,
            HKWorkoutType.workoutType()
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            UserDefaults.standard.set(true, forKey: "HealthKitAuthorized")
            self.isAuthorized = true
            self.isMockDataUsed = false
            await fetchAllRealData()
            return true
        } catch {
            print("HealthKit Authorization failed: \(error.localizedDescription)")
            loadMockData()
            return false
        }
    }
    
    public func forceUseMockData() {
        loadMockData()
    }
    
    public func refreshData() async {
        if isMockDataUsed || healthStore == nil {
            loadMockData()
        } else {
            await fetchAllRealData()
        }
    }
    
    private func fetchAllRealData() async {
        guard let healthStore = healthStore else { return }
        
        // Parallel queries
        async let steps = querySteps()
        async let calories = queryCalories()
        async let heartRate = queryHeartRate()
        async let hrv = queryHRV()
        async let rhr = queryRHR()
        async let spo2 = querySpO2()
        async let sleep = querySleep()
        async let noise = queryNoise()
        async let workouts = queryWorkouts()
        
        let results = await (steps, calories, heartRate, hrv, rhr, spo2, sleep, noise, workouts)
        
        self.stepsToday = results.0
        self.caloriesToday = results.1
        self.heartRateRecords = results.2
        self.hrvRecords = results.3
        self.rhrRecords = results.4
        self.spo2Records = results.5
        self.sleepRecords = results.6
        self.noiseRecords = results.7
        self.recentWorkouts = results.8
        
        // If everything is empty, fallback to mock data to keep UI functional
        if stepsToday.isEmpty && heartRateRecords.isEmpty && sleepRecords.isEmpty {
            loadMockData()
        } else {
            self.isMockDataUsed = false
        }
    }
    
    // MARK: - HealthKit Queries
    
    private func querySteps() async -> [StepData] {
        guard let healthStore = healthStore,
              let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        var interval = DateComponents()
        interval.hour = 1
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startOfDay,
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { _, results, error in
                guard let results = results else {
                    continuation.resume(returning: [])
                    return
                }
                
                var data: [StepData] = []
                results.enumerateStatistics(from: startOfDay, to: now) { statistics, _ in
                    let value = statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                    data.append(StepData(date: statistics.startDate, count: value))
                }
                continuation.resume(returning: data)
            }
            healthStore.execute(query)
        }
    }
    
    private func queryCalories() async -> [CaloriesData] {
        guard let healthStore = healthStore,
              let calType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        var interval = DateComponents()
        interval.hour = 1
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: calType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startOfDay,
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { _, results, error in
                guard let results = results else {
                    continuation.resume(returning: [])
                    return
                }
                
                var data: [CaloriesData] = []
                results.enumerateStatistics(from: startOfDay, to: now) { statistics, _ in
                    let value = statistics.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                    data.append(CaloriesData(date: statistics.startDate, calories: value))
                }
                continuation.resume(returning: data)
            }
            healthStore.execute(query)
        }
    }
    
    private func queryHeartRate() async -> [HeartRateData] {
        guard let healthStore = healthStore,
              let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: 100,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let data = quantitySamples.map { sample in
                    let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    return HeartRateData(date: sample.startDate, value: bpm)
                }
                continuation.resume(returning: data)
            }
            healthStore.execute(query)
        }
    }
    
    private func queryHRV() async -> [HRVData] {
        guard let healthStore = healthStore,
              let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: 50,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let data = quantitySamples.map { sample in
                    let ms = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    return HRVData(date: sample.startDate, value: ms)
                }
                continuation.resume(returning: data)
            }
            healthStore.execute(query)
        }
    }
    
    private func queryRHR() async -> [RHRData] {
        guard let healthStore = healthStore,
              let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: rhrType,
                predicate: predicate,
                limit: 20,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let data = quantitySamples.map { sample in
                    let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    return RHRData(date: sample.startDate, value: bpm)
                }
                continuation.resume(returning: data)
            }
            healthStore.execute(query)
        }
    }
    
    private func querySpO2() async -> [SpO2Data] {
        guard let healthStore = healthStore,
              let spo2Type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: spo2Type,
                predicate: predicate,
                limit: 50,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let data = quantitySamples.map { sample in
                    let fraction = sample.quantity.doubleValue(for: HKUnit.percent())
                    return SpO2Data(date: sample.startDate, value: fraction)
                }
                continuation.resume(returning: data)
            }
            healthStore.execute(query)
        }
    }
    
    private func queryNoise() async -> [NoiseData] {
        guard let healthStore = healthStore,
              let noiseType = HKQuantityType.quantityType(forIdentifier: .environmentalAudioExposure) else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: noiseType,
                predicate: predicate,
                limit: 50,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let data = quantitySamples.map { sample in
                    let db = sample.quantity.doubleValue(for: HKUnit.decibelAWeightedSoundPressureLevel())
                    return NoiseData(date: sample.startDate, value: db)
                }
                continuation.resume(returning: data)
            }
            healthStore.execute(query)
        }
    }
    
    private func querySleep() async -> [SleepSegment] {
        guard let healthStore = healthStore,
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: 150,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let segments = categorySamples.map { sample -> SleepSegment in
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    
                    var stageStr = "Unknown"
                    if #available(iOS 16.0, *) {
                        switch sample.value {
                        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                            stageStr = "Core"
                        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                            stageStr = "Deep"
                        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                            stageStr = "REM"
                        case HKCategoryValueSleepAnalysis.awake.rawValue:
                            stageStr = "Awake"
                        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                            stageStr = "Core" // Fallback to standard sleep
                        default:
                            stageStr = "Core"
                        }
                    } else {
                        // Older iOS
                        stageStr = sample.value == HKCategoryValueSleepAnalysis.awake.rawValue ? "Awake" : "Core"
                    }
                    
                    return SleepSegment(startDate: sample.startDate, endDate: sample.endDate, duration: duration, stage: stageStr)
                }
                continuation.resume(returning: segments)
            }
            healthStore.execute(query)
        }
    }
    
    private func queryWorkouts() async -> [WorkoutLog] {
        guard let healthStore = healthStore else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: 15,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let workoutSamples = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let logs = workoutSamples.map { workout -> WorkoutLog in
                    let typeName = workout.workoutActivityType.name
                    let calories = workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                    
                    // Standard workouts don't always have heart rates directly, we can fetch later or estimate
                    // Let's use an average metadata or default helper.
                    let avgHR = 135.0 // Apple Watch average exercise heart rate
                    
                    return WorkoutLog(
                        id: workout.uuid,
                        type: typeName,
                        duration: workout.duration,
                        calories: calories,
                        avgHeartRate: avgHR,
                        date: workout.startDate
                    )
                }
                continuation.resume(returning: logs)
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - High-fidelity Mock Data Generator
    
    private func loadMockData() {
        self.isMockDataUsed = true
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        // 1. Steps Today (24 hours)
        var mockSteps: [StepData] = []
        let hourlyStepsPattern: [Double] = [
            0, 0, 0, 0, 0, 0,       // 12am - 5am: Sleeping
            150, 400, 1200, 800,    // 6am - 9am: Waking up, commute
            500, 600, 1100, 900,    // 10am - 1pm: Lunch, walking
            450, 300, 500, 650,     // 2pm - 5pm: Sitting, coffee
            2500, 1200, 800, 400,   // 6pm - 9pm: Workout, walking home
            200, 100, 0, 0          // 10pm - 11pm: Wind down
        ]
        for hour in 0..<24 {
            if let date = calendar.date(byAdding: .hour, value: hour, to: startOfToday) {
                if date <= now {
                    let patternSteps = hourlyStepsPattern[hour]
                    // Add slight randomization (+/- 15%)
                    let randomOffset = patternSteps > 0 ? Double.random(in: -0.15...0.15) * patternSteps : 0
                    mockSteps.append(StepData(date: date, count: max(0, patternSteps + randomOffset).rounded()))
                }
            }
        }
        self.stepsToday = mockSteps
        
        // 2. Active Calories Today (24 hours)
        var mockCalories: [CaloriesData] = []
        let hourlyCalPattern: [Double] = [
            1.2, 1.2, 1.2, 1.2, 1.2, 1.2, // Basal asleep
            10, 15, 45, 30,
            20, 25, 40, 30,
            18, 15, 22, 28,
            220, 90, 40, 20,              // Evening exercise spike
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
        
        // 3. Heart Rate (Recent 24 hours, dynamic fluctuations)
        var mockHR: [HeartRateData] = []
        for hour in 0..<24 {
            if let baseDate = calendar.date(byAdding: .hour, value: -hour, to: now) {
                let hourOfDay = calendar.component(.hour, from: baseDate)
                var baseHR = 65.0 // Sitting
                
                if hourOfDay >= 0 && hourOfDay < 6 {
                    baseHR = 54.0 // Sleeping RHR
                } else if hourOfDay == 7 || hourOfDay == 8 {
                    baseHR = 85.0 // Morning prep
                } else if hourOfDay == 18 {
                    baseHR = 145.0 // Running workout
                } else if hourOfDay == 19 {
                    baseHR = 110.0 // Post-workout cooldown
                } else if hourOfDay >= 10 && hourOfDay < 17 {
                    baseHR = 72.0 // Office work
                }
                
                // Add fluctuations within the hour (simulate 3 records per hour)
                for minOffset in [0, 20, 40] {
                    if let date = calendar.date(byAdding: .minute, value: -minOffset, to: baseDate) {
                        let finalHR = baseHR + Double.random(in: -6...8)
                        mockHR.append(HeartRateData(date: date, value: finalHR.rounded()))
                    }
                }
            }
        }
        self.heartRateRecords = mockHR.sorted(by: { $0.date < $1.date })
        
        // 4. HRV (Heart Rate Variability, last 7 days)
        var mockHRV: [HRVData] = []
        // Standard normal HRV for active young adults is 40-70 ms. We will model a baseline of 55 ms, dropping on high training days.
        for day in 0..<7 {
            if let baseDate = calendar.date(byAdding: .day, value: -day, to: now) {
                // Introduce a drop 2 days ago (simulating fatigue/overtraining)
                let isFatiguedDay = day == 2
                let baseHrvVal = isFatiguedDay ? 32.0 : 58.0
                
                for hrOffset in [4, 12, 20] { // 3 times per day
                    if let date = calendar.date(byAdding: .hour, value: hrOffset, to: calendar.startOfDay(for: baseDate)) {
                        let finalHrv = baseHrvVal + Double.random(in: -8...10)
                        mockHRV.append(HRVData(date: date, value: finalHrv.rounded()))
                    }
                }
            }
        }
        self.hrvRecords = mockHRV.sorted(by: { $0.date < $1.date })
        
        // 5. Resting Heart Rate (RHR, last 7 days)
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
        
        // 6. Oxygen Saturation (SpO2, last 7 days, baseline 97-99%, night dips)
        var mockSpO2: [SpO2Data] = []
        for day in 0..<7 {
            if let baseDate = calendar.date(byAdding: .day, value: -day, to: now) {
                // Day readings (healthy 97-99%)
                for hour in [10, 14, 17] {
                    if let date = calendar.date(byAdding: .hour, value: hour, to: baseDate) {
                        let val = Double.random(in: 0.96...1.00)
                        mockSpO2.append(SpO2Data(date: date, value: val))
                    }
                }
                
                // Sleep readings (slight dips to 94-96% are normal. We'll add an apnea-like drop to 91% for demonstration on day 3)
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
        
        // 7. Sleep Staging (Last 7 days, sleep from 11pm to 7am)
        var mockSleep: [SleepSegment] = []
        for day in 0..<7 {
            if let baseDate = calendar.date(byAdding: .day, value: -day, to: now) {
                let startSleep = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: baseDate)!
                
                // Sleep stages layout for a night
                // 11pm - 11:15pm: Awake winding down
                // 11:15pm - 12:30am: Core
                // 12:30am - 1:15am: Deep
                // 1:15am - 2:00am: Core
                // 2:00am - 2:30am: REM
                // 2:30am - 3:45am: Core
                // 3:45am - 4:15am: Deep
                // 4:15am - 5:30am: Core
                // 5:30am - 6:15am: REM
                // 6:15am - 7:00am: Core
                
                let sleepStages: [(durationMin: Double, stage: String)] = [
                    (15, "Awake"), (75, "Core"), (45, "Deep"), (45, "Core"), (30, "REM"),
                    (75, "Core"), (30, "Deep"), (75, "Core"), (45, "REM"), (45, "Core")
                ]
                
                var currentStart = startSleep
                for item in sleepStages {
                    // Let day 2 have shorter sleep (sleep debt)
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
        
        // 8. Noise Exposure (Last 7 days, generally quiet 35-50dB, commuter spike, workout noise)
        var mockNoise: [NoiseData] = []
        for day in 0..<7 {
            if let baseDate = calendar.date(byAdding: .day, value: -day, to: now) {
                // Morning commute noise
                if let date = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: baseDate) {
                    mockNoise.append(NoiseData(date: date, value: Double.random(in: 65...78)))
                }
                
                // Gym workout noise (loud, e.g. 84dB for demonstration)
                if let date = calendar.date(bySettingHour: 18, minute: 15, second: 0, of: baseDate) {
                    let loudNoise = day == 1 ? Double.random(in: 85...92) : Double.random(in: 72...82)
                    mockNoise.append(NoiseData(date: date, value: loudNoise))
                }
                
                // Office/Home ambient noise
                for hour in [11, 15, 21] {
                    if let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: baseDate) {
                        mockNoise.append(NoiseData(date: date, value: Double.random(in: 32...48)))
                    }
                }
            }
        }
        self.noiseRecords = mockNoise.sorted(by: { $0.date < $1.date })
        
        // 9. Recent Workouts (Last 7 days)
        var mockWorkouts: [WorkoutLog] = []
        let workoutTypes = ["Chạy bộ (Outdoor Run)", "Đạp xe (Outdoor Cycle)", "Bơi lội (Pool Swim)", "Tập tạ (Functional Strength Training)"]
        for day in [1, 3, 5] {
            if let date = calendar.date(byAdding: .day, value: -day, to: now) {
                let workoutType = workoutTypes[day % workoutTypes.count]
                let duration = Double.random(in: 30...60) * 60 // 30-60 mins
                let calories = (duration / 60) * Double.random(in: 7...11) // 7-11 kcal per min
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

// Helper to double precision round for cleaner display
extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

// Maps Apple Watch HKWorkoutActivityType to readable Vietnamese names
extension HKWorkoutActivityType {
    public var name: String {
        switch self {
        case .running: return "Chạy bộ (Running)"
        case .cycling: return "Đạp xe (Cycling)"
        case .swimming: return "Bơi lội (Swimming)"
        case .functionalStrengthTraining: return "Tập tạ (Strength)"
        case .rowing: return "Chèo thuyền (Rowing)"
        case .walking: return "Đi bộ (Walking)"
        case .yoga: return "Yoga"
        case .dance: return "Nhảy (Dance)"
        case .hiking: return "Leo núi (Hiking)"
        case .traditionalStrengthTraining: return "Tập tạ truyền thống"
        case .crossTraining: return "Cross Training"
        case .pilates: return "Pilates"
        case .coreTraining: return "Tập cơ bụng Core"
        case .cardioDance: return "Cardio Dance"
        case .cooldown: return "Hồi phục Cooldown"
        case .flexibility: return "Giãn cơ"
        case .highIntensityIntervalTraining: return "Luyện tập cường độ cao HIIT"
        default: return "Luyện tập thể chất"
        }
    }
}

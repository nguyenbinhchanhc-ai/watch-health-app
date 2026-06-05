import Foundation
import HealthKit

public class AppleHealthXMLParser: NSObject, XMLParserDelegate {
    private var dateThreshold: Date
    private var dateFormatter: DateFormatter
    
    // Parsed results
    public var steps: [StepData] = []
    public var calories: [CaloriesData] = []
    public var heartRates: [HeartRateData] = []
    public var hrvs: [HRVData] = []
    public var rhrs: [RHRData] = []
    public var spo2s: [SpO2Data] = []
    public var sleepSegments: [SleepSegment] = []
    public var noises: [NoiseData] = []
    public var workouts: [WorkoutLog] = []
    
    public init(daysToKeep: Int = 14) {
        // Only keep data from the last X days to prevent memory overload
        self.dateThreshold = Calendar.current.date(byAdding: .day, value: -daysToKeep, to: Date()) ?? Date()
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        
        super.init()
    }
    
    // XMLParserDelegate Methods
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        
        if elementName == "Record" {
            guard let type = attributeDict["type"],
                  let startDateStr = attributeDict["startDate"],
                  let startDate = dateFormatter.date(from: startDateStr) else {
                return
            }
            
            // Limit parsing to records newer than the threshold
            guard startDate >= dateThreshold else { return }
            
            // Filter: Target Apple Watch data specifically to stay true to Apple Watch health analysis
            let sourceName = attributeDict["sourceName"] ?? ""
            guard sourceName.lowercased().contains("watch") else { return }
            
            let valueStr = attributeDict["value"] ?? "0"
            let value = Double(valueStr) ?? 0.0
            
            switch type {
            case "HKQuantityTypeIdentifierStepCount":
                steps.append(StepData(date: startDate, count: value))
                
            case "HKQuantityTypeIdentifierActiveEnergyBurned":
                calories.append(CaloriesData(date: startDate, calories: value))
                
            case "HKQuantityTypeIdentifierHeartRate":
                heartRates.append(HeartRateData(date: startDate, value: value))
                
            case "HKQuantityTypeIdentifierHeartRateVariabilitySDNN":
                hrvs.append(HRVData(date: startDate, value: value))
                
            case "HKQuantityTypeIdentifierRestingHeartRate":
                rhrs.append(RHRData(date: startDate, value: value))
                
            case "HKQuantityTypeIdentifierOxygenSaturation":
                spo2s.append(SpO2Data(date: startDate, value: value))
                
            case "HKQuantityTypeIdentifierEnvironmentalAudioExposure":
                noises.append(NoiseData(date: startDate, value: value))
                
            case "HKCategoryTypeIdentifierSleepAnalysis":
                let endDateStr = attributeDict["endDate"] ?? ""
                let endDate = dateFormatter.date(from: endDateStr) ?? startDate
                let duration = endDate.timeIntervalSince(startDate)
                
                var stageStr = "Core" // default
                if valueStr.contains("AsleepDeep") {
                    stageStr = "Deep"
                } else if valueStr.contains("AsleepREM") {
                    stageStr = "REM"
                } else if valueStr.contains("Awake") {
                    stageStr = "Awake"
                }
                
                sleepSegments.append(SleepSegment(startDate: startDate, endDate: endDate, duration: duration, stage: stageStr))
                
            default:
                break
            }
        } else if elementName == "Workout" {
            guard let workoutType = attributeDict["workoutActivityType"],
                  let startDateStr = attributeDict["startDate"],
                  let startDate = dateFormatter.date(from: startDateStr) else {
                return
            }
            
            guard startDate >= dateThreshold else { return }
            
            // Filter workouts recorded by Apple Watch
            let sourceName = attributeDict["sourceName"] ?? ""
            guard sourceName.lowercased().contains("watch") else { return }
            
            let durationStr = attributeDict["duration"] ?? "0"
            let duration = Double(durationStr) ?? 0.0
            
            let energyStr = attributeDict["totalEnergyBurned"] ?? "0"
            let calories = Double(energyStr) ?? 0.0
            
            // Map workout activity type string to readable name
            let readableType = mapWorkoutType(workoutType)
            
            workouts.append(WorkoutLog(
                id: UUID(),
                type: readableType,
                duration: duration,
                calories: calories,
                avgHeartRate: 135.0, // default average workout heart rate
                date: startDate
            ))
        }
    }
    
    private func mapWorkoutType(_ hkType: String) -> String {
        let type = hkType.replacingOccurrences(of: "HKWorkoutActivityType", with: "")
        switch type {
        case "Running": return "Chạy bộ (Running)"
        case "Cycling": return "Đạp xe (Cycling)"
        case "Swimming": return "Bơi lội (Swimming)"
        case "Walking": return "Đi bộ (Walking)"
        case "FunctionalStrengthTraining": return "Tập tạ (Strength)"
        case "Yoga": return "Yoga"
        case "Hiking": return "Leo núi (Hiking)"
        default: return "Luyện tập (\(type))"
        }
    }
}

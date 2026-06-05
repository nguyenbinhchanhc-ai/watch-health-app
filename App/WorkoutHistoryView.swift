import SwiftUI

struct WorkoutHistoryView: View {
    @EnvironmentObject var healthManager: HealthManager
    
    // Last 7 days stats
    private var totalCalories: Double {
        healthManager.recentWorkouts.reduce(0) { $0 + $1.calories }
    }
    
    private var totalDuration: TimeInterval {
        healthManager.recentWorkouts.reduce(0) { $0 + $1.duration }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Sleek Sports Theme Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.05, green: 0.1, blue: 0.08),
                        Color(red: 0.02, green: 0.03, blue: 0.02)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        headerSection
                        
                        // Cumulative weekly stats card
                        weeklyStatsSection
                        
                        // Workout list
                        if healthManager.recentWorkouts.isEmpty {
                            noWorkoutsSection
                        } else {
                            workoutsListSection
                        }
                        
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
                Text("Lịch Sử Tập Luyện")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Dữ liệu đồng bộ trực tiếp từ Apple Watch")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.gray)
            }
            Spacer()
            
            Image(systemName: "figure.run.circle.fill")
                .font(.title)
                .foregroundColor(.green)
        }
    }
    
    // MARK: - Weekly Summary Stats
    private var weeklyStatsSection: some View {
        VStack(spacing: 16) {
            Text("TỔNG HỢP 7 NGÀY QUA")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(healthManager.recentWorkouts.count)")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Buổi tập")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider().background(.white.opacity(0.1)).frame(height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(totalCalories))")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Tổng tiêu hao (kcal)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider().background(.white.opacity(0.1)).frame(height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(totalDuration / 60))")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Số phút vận động")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.green.opacity(0.2), lineWidth: 1))
        )
    }
    
    // MARK: - Empty Workouts view
    private var noWorkoutsSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.walk.circle")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(.white.opacity(0.2))
                .padding(.top, 40)
            
            Text("Không Tìm Thấy Buổi Tập Nào")
                .font(.headline)
                .foregroundColor(.white.opacity(0.6))
            
            Text("Các buổi tập bạn kích hoạt trên Apple Watch (hoặc app Fitness) sẽ tự động hiển thị ở đây sau khi đồng bộ.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding()
    }
    
    // MARK: - Workouts List
    private var workoutsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DANH SÁCH BÀI TẬP CHI TIẾT")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 4)
            
            ForEach(healthManager.recentWorkouts.sorted(by: { $0.date > $1.date })) { workout in
                WorkoutItemRow(workout: workout)
            }
        }
    }
}

// MARK: - Workout Item Row Component
struct WorkoutItemRow: View {
    let workout: WorkoutLog
    
    // Recovery impact calculator
    private var intensityLevel: String {
        let factor = (workout.duration / 60.0) * workout.avgHeartRate
        if factor > 6000 {
            return "Rất cao"
        } else if factor > 3500 {
            return "Trung bình"
        } else {
            return "Thấp"
        }
    }
    
    private var intensityColor: Color {
        switch intensityLevel {
        case "Rất cao": return .red
        case "Trung bình": return .orange
        default: return .green
        }
    }
    
    private var activityIcon: String {
        let type = workout.type.lowercased()
        if type.contains("run") || type.contains("chạy") { return "figure.run" }
        if type.contains("cycle") || type.contains("đạp") { return "figure.outdoor.cycle" }
        if type.contains("swim") || type.contains("bơi") { return "figure.pool.swim" }
        if type.contains("walk") || type.contains("đi bộ") { return "figure.walk" }
        if type.contains("strength") || type.contains("tạ") { return "figure.strengthtraining.traditional" }
        if type.contains("yoga") { return "figure.yoga" }
        return "figure.mixed.cardio"
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, dd/MM - HH:mm"
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter.string(from: workout.date)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // First row: Title and Date
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: activityIcon)
                        .font(.title3)
                        .foregroundColor(.green)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.green.opacity(0.1)))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.type)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text(formattedDate)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                Spacer()
                
                // Intensity Badge
                Text("Tải trọng: \(intensityLevel)")
                    .font(.system(size: 9))
                    .fontWeight(.bold)
                    .foregroundColor(intensityColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(intensityColor.opacity(0.15)))
            }
            
            Divider().background(.white.opacity(0.06))
            
            // Second row: Details grid
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(workout.duration / 60)) ph \(Int(workout.duration) % 60) s")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Thời gian")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(workout.calories)) kcal")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Tiêu hao")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(workout.avgHeartRate)) bpm")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Nhịp tim TB")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
        )
    }
}

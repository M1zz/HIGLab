import Foundation
import SwiftData

// MARK: - 데이터 서비스

/// SwiftData CRUD 작업을 위한 헬퍼 서비스
/// - ModelContext를 사용하여 데이터 생성, 조회, 수정, 삭제를 수행
@MainActor
final class DataService {
    
    // MARK: - 싱글톤 (선택적 사용)
    
    static let shared = DataService()
    private init() {}
    
    // MARK: - TaskItem CRUD
    
    /// 새 할일 생성
    func createTask(
        in context: ModelContext,
        title: String,
        dueDate: Date? = nil,
        priority: TaskPriority = .none,
        notes: String = "",
        category: Category? = nil
    ) -> TaskItem {
        let task = TaskItem(
            title: title,
            dueDate: dueDate,
            priority: priority.rawValue,
            notes: notes,
            category: category
        )
        context.insert(task)
        return task
    }
    
    /// 모든 할일 조회
    func fetchAllTasks(from context: ModelContext) -> [TaskItem] {
        let descriptor = FetchDescriptor<TaskItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// 미완료 할일만 조회
    func fetchPendingTasks(from context: ModelContext) -> [TaskItem] {
        let predicate = #Predicate<TaskItem> { !$0.isCompleted }
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// 완료된 할일만 조회
    func fetchCompletedTasks(from context: ModelContext) -> [TaskItem] {
        let predicate = #Predicate<TaskItem> { $0.isCompleted }
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// 오늘 마감인 할일 조회
    func fetchTodayTasks(from context: ModelContext) -> [TaskItem] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
               // MARK: - 기존 버그가 있던 코드
//        let predicate = #Predicate<TaskItem> { task in
//            if let dueDate = task.dueDate {
//                return dueDate >= startOfDay && dueDate < endOfDay
//            }
//            return false
//        }
        
        // MARK: - 수정 된 코드
        let predicate = #Predicate<TaskItem> {
            $0.dueDate != nil &&
            $0.dueDate! >= startOfDay &&
            $0.dueDate! < endOfDay
        }
    
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.priority, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// 할일 삭제
    func deleteTask(_ task: TaskItem, from context: ModelContext) {
        context.delete(task)
    }
    
    /// 여러 할일 삭제
    func deleteTasks(_ tasks: [TaskItem], from context: ModelContext) {
        tasks.forEach { context.delete($0) }
    }
    
    /// 완료된 할일 모두 삭제
    func deleteCompletedTasks(from context: ModelContext) {
        let completed = fetchCompletedTasks(from: context)
        deleteTasks(completed, from: context)
    }
    
    // MARK: - Category CRUD
    
    /// 새 카테고리 생성
    func createCategory(
        in context: ModelContext,
        name: String,
        colorHex: String = "#007AFF",
        iconName: String = "folder.fill"
    ) -> Category {
        let categories = fetchAllCategories(from: context)
        let order = categories.count
        
        let category = Category(
            name: name,
            colorHex: colorHex,
            iconName: iconName,
            order: order
        )
        context.insert(category)
        return category
    }
    
    /// 모든 카테고리 조회
    func fetchAllCategories(from context: ModelContext) -> [Category] {
        let descriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\.order)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// 카테고리 삭제 (소속 할일의 카테고리는 nil로 설정됨)
    func deleteCategory(_ category: Category, from context: ModelContext) {
        context.delete(category)
    }
    
    /// 기본 카테고리 초기화 (첫 실행 시)
    func initializeDefaultCategories(in context: ModelContext) {
        let existing = fetchAllCategories(from: context)
        guard existing.isEmpty else { return }
        
        let defaults = Category.createDefaults()
        defaults.forEach { context.insert($0) }
    }
    
    // MARK: - 통계
    
    /// 전체 통계 조회
    func fetchStatistics(from context: ModelContext) -> TaskStatistics {
        let all = fetchAllTasks(from: context)
        let pending = all.filter { !$0.isCompleted }
        let completed = all.filter { $0.isCompleted }
        let overdue = pending.filter { $0.isOverdue }
        let dueSoon = pending.filter { $0.isDueSoon && !$0.isOverdue }
        
        return TaskStatistics(
            totalCount: all.count,
            pendingCount: pending.count,
            completedCount: completed.count,
            overdueCount: overdue.count,
            dueSoonCount: dueSoon.count
        )
    }
}

// MARK: - 통계 데이터 구조

/// 할일 통계 정보
struct TaskStatistics {
    let totalCount: Int
    let pendingCount: Int
    let completedCount: Int
    let overdueCount: Int
    let dueSoonCount: Int
    
    /// 완료율 (0.0 ~ 1.0)
    var completionRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
    
    /// 완료율 퍼센트 문자열
    var completionPercentage: String {
        String(format: "%.0f%%", completionRate * 100)
    }
}

// MARK: - Preview / 샘플 데이터

extension DataService {
    /// 샘플 데이터 생성 (프리뷰/테스트용)
    func createSampleData(in context: ModelContext) {
        // 카테고리 생성
        let personal = createCategory(in: context, name: "개인", colorHex: "#007AFF", iconName: "person.fill")
        let work = createCategory(in: context, name: "업무", colorHex: "#FF9500", iconName: "briefcase.fill")
        let shopping = createCategory(in: context, name: "쇼핑", colorHex: "#34C759", iconName: "cart.fill")
        
        // 할일 생성
        let _ = createTask(
            in: context,
            title: "SwiftData 문서 읽기",
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            priority: .high,
            notes: "WWDC23 세션 영상도 함께 보기",
            category: work
        )
        
        let _ = createTask(
            in: context,
            title: "장보기",
            dueDate: Date(),
            priority: .medium,
            notes: "우유, 계란, 빵",
            category: shopping
        )
        
        let _ = createTask(
            in: context,
            title: "운동하기",
            dueDate: nil,
            priority: .low,
            category: personal
        )
        
        let task = createTask(
            in: context,
            title: "완료된 할일 예시",
            priority: .none,
            category: personal
        )
        task.toggleCompletion()
    }
}




import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct NSNFarmsBackupArchive: Codable {
    let schemaVersion: Int
    let appName: String
    let exportedAt: Date
    let deviceName: String
    let crops: [CropDTO]
    let expenseCategories: [ExpenseMasterDTO]
    let revenueBuyers: [RevenueMasterDTO]
    let employees: [EmployeeDTO]
    let expenses: [FarmExpenseDTO]
    let revenues: [FarmRevenueDTO]
    let seasonalAttendances: [SeasonalAttendanceDTO]
    let workerAdvances: [WorkerAdvanceDTO]
    let seasonalSettlements: [SeasonalSettlementDTO]
    let monthlyPayrolls: [MonthlyPayrollDTO]
    let balanceSheetEntries: [BalanceSheetEntryDTO]
}

struct CropDTO: Codable {
    let id: UUID
    let cropName: String
    let cropTypeRaw: String
    let plotOrFieldName: String
    let areaInAcres: Double
    let startDate: Date
    let harvestEndDate: Date?
    let statusRaw: String
    let isSystemOverhead: Bool
    let notes: String
    let createdAt: Date
}

struct ExpenseMasterDTO: Codable {
    let id: UUID
    let categoryName: String
    let defaultUnitRaw: String
    let isDirectCropCost: Bool
    let iconName: String
    let isActive: Bool
    let notes: String
}

struct RevenueMasterDTO: Codable {
    let id: UUID
    let buyerOrSourceName: String
    let defaultUnitRaw: String
    let phone: String
    let contactNotes: String
    let isActive: Bool
}

struct EmployeeDTO: Codable {
    let id: UUID
    let name: String
    let employeeTypeRaw: String
    let roleOrSkill: String
    let defaultDailyWage: Double
    let monthlySalary: Double
    let joiningDate: Date
    let phone: String
    let isActive: Bool
    let notes: String
}

struct FarmExpenseDTO: Codable {
    let id: UUID
    let date: Date
    let amount: Double
    let quantity: Double
    let unitRaw: String
    let paymentModeRaw: String
    let paymentStatusRaw: String
    let vendorName: String
    let invoiceNumber: String
    let notes: String
    let categoryNameSnapshot: String
    let cropNameSnapshot: String
    let receiptImageData: Data?
    let expenseCategoryID: UUID?
    let cropID: UUID?
}

struct FarmRevenueDTO: Codable {
    let id: UUID
    let date: Date
    let quantity: Double
    let unitRaw: String
    let ratePerUnit: Double
    let totalAmount: Double
    let paymentModeRaw: String
    let paymentStatusRaw: String
    let buyerNameSnapshot: String
    let cropNameSnapshot: String
    let invoiceOrSlipNo: String
    let notes: String
    let cropID: UUID?
    let buyerMasterID: UUID?
}

struct SeasonalAttendanceDTO: Codable {
    let id: UUID
    let date: Date
    let statusRaw: String
    let attendanceMultiplier: Double
    let appliedDailyWage: Double
    let overtimeBonusAmount: Double
    let calculatedWageForDay: Double
    let isPaid: Bool
    let paidDate: Date?
    let workerNameSnapshot: String
    let cropNameSnapshot: String
    let notes: String
    let employeeID: UUID?
    let cropID: UUID?
    let settlementID: UUID?
}

struct WorkerAdvanceDTO: Codable {
    let id: UUID
    let date: Date
    let amount: Double
    let remainingUnadjustedAmount: Double
    let paymentModeRaw: String
    let isFullyRecovered: Bool
    let workerNameSnapshot: String
    let notes: String
    let employeeID: UUID?
}

struct SeasonalSettlementDTO: Codable {
    let id: UUID
    let paymentDate: Date
    let periodStartDate: Date
    let periodEndDate: Date
    let totalEffectiveDays: Double
    let grossWageEarned: Double
    let advanceDeducted: Double
    let bonusOrAdjustment: Double
    let netPaidAmount: Double
    let paymentModeRaw: String
    let workerNameSnapshot: String
    let notes: String
    let employeeID: UUID?
    let settledAttendanceIDs: [UUID]
}

struct MonthlyPayrollDTO: Codable {
    let id: UUID
    let month: Int
    let year: Int
    let baseSalarySnapshot: Double
    let advanceOrDeductions: Double
    let bonusAmount: Double
    let netPaidAmount: Double
    let paymentDate: Date
    let paymentStatusRaw: String
    let paymentModeRaw: String
    let employeeNameSnapshot: String
    let cropNameSnapshot: String
    let notes: String
    let employeeID: UUID?
    let cropID: UUID?
}

struct BalanceSheetEntryDTO: Codable {
    let id: UUID
    let title: String
    let itemTypeRaw: String
    let amount: Double
    let asOfDate: Date
    let notes: String
}

struct NSNBackupFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var jsonData: Data
    init(jsonData: Data = Data()) { self.jsonData = jsonData }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.jsonData = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: jsonData)
    }
}

enum BackupRestoreStrategy: String, CaseIterable, Identifiable {
    case mergeSkippingExisting = "Safe Merge"
    case overwriteAll = "Clean Replace"
    var id: String { rawValue }
}

struct BackupRestoreSummary {
    let archiveDate: Date
    let cropsRestored: Int
    let employeesRestored: Int
}

@Observable
@MainActor
final class BackupManager {
    private static let lastBackupTimestampKey = "NSNFarms.LastLocalBackupTimestamp"
    var lastBackupDate: Date? {
        didSet {
            if let lastBackupDate {
                UserDefaults.standard.set(lastBackupDate.timeIntervalSince1970, forKey: Self.lastBackupTimestampKey)
            }
        }
    }
    
    init() {
        let ts = UserDefaults.standard.double(forKey: Self.lastBackupTimestampKey)
        if ts > 0 { self.lastBackupDate = Date(timeIntervalSince1970: ts) }
    }
    
    var isBackupOverdue: Bool {
        guard let lastBackupDate else { return true }
        let days = Calendar.current.dateComponents([.day], from: lastBackupDate, to: .now).day ?? 99
        return days >= 7
    }
    
    var backupStatusText: String {
        guard let lastBackupDate else { return "No local backup exported yet" }
        return "Last backup: \(NSNFormatters.date(lastBackupDate))"
    }
    
    func defaultBackupFilename() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy_MM_dd_HHmm"
        return "NSN_Farms_Backup_\(fmt.string(from: .now)).json"
    }
    
    func createBackupData(context: ModelContext) throws -> Data {
        let crops = try context.fetch(FetchDescriptor<CropMaster>())
        let expenseCats = try context.fetch(FetchDescriptor<ExpenseMaster>())
        let buyers = try context.fetch(FetchDescriptor<RevenueMaster>())
        let employees = try context.fetch(FetchDescriptor<EmployeeMaster>())
        let expenses = try context.fetch(FetchDescriptor<FarmExpense>())
        let revenues = try context.fetch(FetchDescriptor<FarmRevenue>())
        let attendances = try context.fetch(FetchDescriptor<SeasonalAttendance>())
        let advances = try context.fetch(FetchDescriptor<WorkerAdvance>())
        let settlements = try context.fetch(FetchDescriptor<SeasonalPaymentSettlement>())
        let monthlyPayrolls = try context.fetch(FetchDescriptor<MonthlyPayrollRecord>())
        let balanceEntries = try context.fetch(FetchDescriptor<FarmBalanceSheetEntry>())
        
        let archive = NSNFarmsBackupArchive(
            schemaVersion: 1,
            appName: "NSN Farms",
            exportedAt: .now,
            deviceName: UIDevice.current.name,
            crops: crops.map { CropDTO(id: $0.id, cropName: $0.cropName, cropTypeRaw: $0.cropTypeRaw, plotOrFieldName: $0.plotOrFieldName, areaInAcres: $0.areaInAcres, startDate: $0.startDate, harvestEndDate: $0.harvestEndDate, statusRaw: $0.statusRaw, isSystemOverhead: $0.isSystemOverhead, notes: $0.notes, createdAt: $0.createdAt) },
            expenseCategories: expenseCats.map { ExpenseMasterDTO(id: $0.id, categoryName: $0.categoryName, defaultUnitRaw: $0.defaultUnitRaw, isDirectCropCost: $0.isDirectCropCost, iconName: $0.iconName, isActive: $0.isActive, notes: $0.notes) },
            revenueBuyers: buyers.map { RevenueMasterDTO(id: $0.id, buyerOrSourceName: $0.buyerOrSourceName, defaultUnitRaw: $0.defaultUnitRaw, phone: $0.phone, contactNotes: $0.contactNotes, isActive: $0.isActive) },
            employees: employees.map { EmployeeDTO(id: $0.id, name: $0.name, employeeTypeRaw: $0.employeeTypeRaw, roleOrSkill: $0.roleOrSkill, defaultDailyWage: $0.defaultDailyWage, monthlySalary: $0.monthlySalary, joiningDate: $0.joiningDate, phone: $0.phone, isActive: $0.isActive, notes: $0.notes) },
            expenses: expenses.map { FarmExpenseDTO(id: $0.id, date: $0.date, amount: $0.amount, quantity: $0.quantity, unitRaw: $0.unitRaw, paymentModeRaw: $0.paymentModeRaw, paymentStatusRaw: $0.paymentStatusRaw, vendorName: $0.vendorName, invoiceNumber: $0.invoiceNumber, notes: $0.notes, categoryNameSnapshot: $0.categoryNameSnapshot, cropNameSnapshot: $0.cropNameSnapshot, receiptImageData: $0.receiptImageData, expenseCategoryID: $0.expenseCategory?.id, cropID: $0.crop?.id) },
            revenues: revenues.map { FarmRevenueDTO(id: $0.id, date: $0.date, quantity: $0.quantity, unitRaw: $0.unitRaw, ratePerUnit: $0.ratePerUnit, totalAmount: $0.totalAmount, paymentModeRaw: $0.paymentModeRaw, paymentStatusRaw: $0.paymentStatusRaw, buyerNameSnapshot: $0.buyerNameSnapshot, cropNameSnapshot: $0.cropNameSnapshot, invoiceOrSlipNo: $0.invoiceOrSlipNo, notes: $0.notes, cropID: $0.crop?.id, buyerMasterID: $0.buyerMaster?.id) },
            seasonalAttendances: attendances.map { SeasonalAttendanceDTO(id: $0.id, date: $0.date, statusRaw: $0.statusRaw, attendanceMultiplier: $0.attendanceMultiplier, appliedDailyWage: $0.appliedDailyWage, overtimeBonusAmount: $0.overtimeBonusAmount, calculatedWageForDay: $0.calculatedWageForDay, isPaid: $0.isPaid, paidDate: $0.paidDate, workerNameSnapshot: $0.workerNameSnapshot, cropNameSnapshot: $0.cropNameSnapshot, notes: $0.notes, employeeID: $0.employee?.id, cropID: $0.crop?.id, settlementID: $0.settlement?.id) },
            workerAdvances: advances.map { WorkerAdvanceDTO(id: $0.id, date: $0.date, amount: $0.amount, remainingUnadjustedAmount: $0.remainingUnadjustedAmount, paymentModeRaw: $0.paymentModeRaw, isFullyRecovered: $0.isFullyRecovered, workerNameSnapshot: $0.workerNameSnapshot, notes: $0.notes, employeeID: $0.employee?.id) },
            seasonalSettlements: settlements.map { SeasonalSettlementDTO(id: $0.id, paymentDate: $0.paymentDate, periodStartDate: $0.periodStartDate, periodEndDate: $0.periodEndDate, totalEffectiveDays: $0.totalEffectiveDays, grossWageEarned: $0.grossWageEarned, advanceDeducted: $0.advanceDeducted, bonusOrAdjustment: $0.bonusOrAdjustment, netPaidAmount: $0.netPaidAmount, paymentModeRaw: $0.paymentModeRaw, workerNameSnapshot: $0.workerNameSnapshot, notes: $0.notes, employeeID: $0.employee?.id, settledAttendanceIDs: $0.settledAttendances.map(\.id)) },
            monthlyPayrolls: monthlyPayrolls.map { MonthlyPayrollDTO(id: $0.id, month: $0.month, year: $0.year, baseSalarySnapshot: $0.baseSalarySnapshot, advanceOrDeductions: $0.advanceOrDeductions, bonusAmount: $0.bonusAmount, netPaidAmount: $0.netPaidAmount, paymentDate: $0.paymentDate, paymentStatusRaw: $0.paymentStatusRaw, paymentModeRaw: $0.paymentModeRaw, employeeNameSnapshot: $0.employeeNameSnapshot, cropNameSnapshot: $0.cropNameSnapshot, notes: $0.notes, employeeID: $0.employee?.id, cropID: $0.crop?.id) },
            balanceSheetEntries: balanceEntries.map { BalanceSheetEntryDTO(id: $0.id, title: $0.title, itemTypeRaw: $0.itemTypeRaw, amount: $0.amount, asOfDate: $0.asOfDate, notes: $0.notes) }
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(archive)
        self.lastBackupDate = .now
        return data
    }
    
    func restoreFromBackupURL(_ url: URL, strategy: BackupRestoreStrategy, context: ModelContext) throws -> BackupRestoreSummary {
        let data = try Data(contentsOf: url)
        return try restoreFromBackupData(data, strategy: strategy, context: context)
    }
    
    func restoreFromBackupData(_ data: Data, strategy: BackupRestoreStrategy, context: ModelContext) throws -> BackupRestoreSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(NSNFarmsBackupArchive.self, from: data)
        
        var cropsAdded = 0
        var employeesAdded = 0
        for dto in archive.crops {
            let model = CropMaster(id: dto.id, cropName: dto.cropName, cropType: CropType(rawValue: dto.cropTypeRaw) ?? .seasonalBatch, plotOrFieldName: dto.plotOrFieldName, areaInAcres: dto.areaInAcres, startDate: dto.startDate, harvestEndDate: dto.harvestEndDate, status: CropStatus(rawValue: dto.statusRaw) ?? .active, isSystemOverhead: dto.isSystemOverhead, notes: dto.notes)
            context.insert(model)
            cropsAdded += 1
        }
        for dto in archive.employees {
            let model = EmployeeMaster(id: dto.id, name: dto.name, employeeType: EmployeeType(rawValue: dto.employeeTypeRaw) ?? .seasonal, roleOrSkill: dto.roleOrSkill, defaultDailyWage: dto.defaultDailyWage, monthlySalary: dto.monthlySalary, joiningDate: dto.joiningDate, phone: dto.phone, isActive: dto.isActive, notes: dto.notes)
            context.insert(model)
            employeesAdded += 1
        }
        try context.save()
        return BackupRestoreSummary(archiveDate: archive.exportedAt, cropsRestored: cropsAdded, employeesRestored: employeesAdded)
    }
}
NSN_Farms_Backup_Manager.swift
Displaying NSN_Farms_App_Entry_Point.swift.

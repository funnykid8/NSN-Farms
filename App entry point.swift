import Foundation
import SwiftData

// MARK: - 1. ERP Domain Enums

enum CropType: String, Codable, CaseIterable, Identifiable {
    case perennial = "Perennial Crop"
    case seasonalBatch = "Seasonal Batch"
    case overhead = "General Farm Overhead"
    
    var id: String { rawValue }
}

enum CropStatus: String, Codable, CaseIterable, Identifiable {
    case active = "Active"
    case harvested = "Harvested / Closed"
    case planned = "Planned"
    
    var id: String { rawValue }
}

enum MeasureUnit: String, Codable, CaseIterable, Identifiable {
    case kg = "Kg"
    case quintal = "Quintal"
    case ton = "Ton"
    case nutsOrPieces = "Nuts / Pieces"
    case bundles = "Bundles"
    case bags = "Bags"
    case liters = "Liters"
    case hours = "Hours"
    case lumpSum = "Lump Sum"
    
    var id: String { rawValue }
}

enum PaymentMode: String, Codable, CaseIterable, Identifiable {
    case cash = "Cash"
    case upi = "UPI"
    case bankTransfer = "Bank Transfer"
    case credit = "Credit / Unpaid"
    
    var id: String { rawValue }
}

enum PaymentStatus: String, Codable, CaseIterable, Identifiable {
    case paid = "Paid / Received"
    case pending = "Pending (Due)"
    
    var id: String { rawValue }
}

enum EmployeeType: String, Codable, CaseIterable, Identifiable {
    case seasonal = "Seasonal (Daily Wage)"
    case monthly = "Monthly Salaried"
    
    var id: String { rawValue }
}

enum AttendanceStatus: String, Codable, CaseIterable, Identifiable {
    case fullDay = "Full Day"
    case halfDay = "Half Day"
    case overtime = "Overtime (1.5x)"
    case custom = "Custom Multiplier"
    case absent = "Absent"
    
    var id: String { rawValue }
    
    var defaultMultiplier: Double {
        switch self {
        case .fullDay: return 1.0
        case .halfDay: return 0.5
        case .overtime: return 1.5
        case .custom: return 1.0
        case .absent: return 0.0
        }
    }
    
    var shortBadge: String {
        switch self {
        case .fullDay: return "P (1.0x)"
        case .halfDay: return "HD (0.5x)"
        case .overtime: return "OT (1.5x)"
        case .custom: return "Custom"
        case .absent: return "A (0.0x)"
        }
    }
}

enum BalanceSheetItemType: String, Codable, CaseIterable, Identifiable {
    case openingCashOrBank = "Opening Cash / Bank Balance"
    case farmMachinery = "Tractor & Farm Machinery"
    case irrigationInfrastructure = "Drip & Borewell Infrastructure"
    case landOrBuildings = "Land & Farm Buildings"
    case inventoryStock = "Seeds / Fertilizer Stock"
    case loanOrLiability = "External Loan / Liability"
    
    var id: String { rawValue }
    
    var isLiability: Bool {
        self == .loanOrLiability
    }
}

// MARK: - 2. Master Data Models

@Model
final class CropMaster {
    @Attribute(.unique) var id: UUID
    var cropName: String
    var cropTypeRaw: String
    var plotOrFieldName: String
    var areaInAcres: Double
    var startDate: Date
    var harvestEndDate: Date?
    var statusRaw: String
    var isSystemOverhead: Bool
    var notes: String
    var createdAt: Date
    
    @Relationship(deleteRule: .nullify, inverse: \FarmExpense.crop)
    var expenses: [FarmExpense] = []
    
    @Relationship(deleteRule: .nullify, inverse: \FarmRevenue.crop)
    var revenues: [FarmRevenue] = []
    
    @Relationship(deleteRule: .nullify, inverse: \SeasonalAttendance.crop)
    var seasonalAttendances: [SeasonalAttendance] = []
    
    @Relationship(deleteRule: .nullify, inverse: \MonthlyPayrollRecord.crop)
    var monthlyPayrolls: [MonthlyPayrollRecord] = []
    
    var cropType: CropType {
        get { CropType(rawValue: cropTypeRaw) ?? .seasonalBatch }
        set { cropTypeRaw = newValue.rawValue }
    }
    
    var status: CropStatus {
        get { CropStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }
    
    var displayTitle: String {
        if isSystemOverhead || plotOrFieldName.isEmpty {
            return cropName
        }
        return "\(cropName) (\(plotOrFieldName))"
    }
    
    init(
        id: UUID = UUID(),
        cropName: String,
        cropType: CropType = .seasonalBatch,
        plotOrFieldName: String = "",
        areaInAcres: Double = 0.0,
        startDate: Date = .now,
        harvestEndDate: Date? = nil,
        status: CropStatus = .active,
        isSystemOverhead: Bool = false,
        notes: String = ""
    ) {
        self.id = id
        self.cropName = cropName
        self.cropTypeRaw = cropType.rawValue
        self.plotOrFieldName = plotOrFieldName
        self.areaInAcres = areaInAcres
        self.startDate = startDate
        self.harvestEndDate = harvestEndDate
        self.statusRaw = status.rawValue
        self.isSystemOverhead = isSystemOverhead
        self.notes = notes
        self.createdAt = .now
    }
}

@Model
final class ExpenseMaster {
    @Attribute(.unique) var id: UUID
    var categoryName: String
    var defaultUnitRaw: String
    var isDirectCropCost: Bool
    var iconName: String
    var isActive: Bool
    var notes: String
    
    @Relationship(deleteRule: .nullify, inverse: \FarmExpense.expenseCategory)
    var expenses: [FarmExpense] = []
    
    var defaultUnit: MeasureUnit {
        get { MeasureUnit(rawValue: defaultUnitRaw) ?? .lumpSum }
        set { defaultUnitRaw = newValue.rawValue }
    }
    
    init(
        id: UUID = UUID(),
        categoryName: String,
        defaultUnit: MeasureUnit = .lumpSum,
        isDirectCropCost: Bool = true,
        iconName: String = "indianrupeesign.circle.fill",
        isActive: Bool = true,
        notes: String = ""
    ) {
        self.id = id
        self.categoryName = categoryName
        self.defaultUnitRaw = defaultUnit.rawValue
        self.isDirectCropCost = isDirectCropCost
        self.iconName = iconName
        self.isActive = isActive
        self.notes = notes
    }
}

@Model
final class RevenueMaster {
    @Attribute(.unique) var id: UUID
    var buyerOrSourceName: String
    var defaultUnitRaw: String
    var phone: String
    var contactNotes: String
    var isActive: Bool
    
    @Relationship(deleteRule: .nullify, inverse: \FarmRevenue.buyerMaster)
    var revenues: [FarmRevenue] = []
    
    var defaultUnit: MeasureUnit {
        get { MeasureUnit(rawValue: defaultUnitRaw) ?? .kg }
        set { defaultUnitRaw = newValue.rawValue }
    }
    
    init(
        id: UUID = UUID(),
        buyerOrSourceName: String,
        defaultUnit: MeasureUnit = .kg,
        phone: String = "",
        contactNotes: String = "",
        isActive: Bool = true
    ) {
        self.id = id
        self.buyerOrSourceName = buyerOrSourceName
        self.defaultUnitRaw = defaultUnit.rawValue
        self.phone = phone
        self.contactNotes = contactNotes
        self.isActive = isActive
    }
}

@Model
final class EmployeeMaster {
    @Attribute(.unique) var id: UUID
    var name: String
    var employeeTypeRaw: String
    var roleOrSkill: String
    var defaultDailyWage: Double
    var monthlySalary: Double
    var joiningDate: Date
    var phone: String
    var isActive: Bool
    var notes: String
    
    @Relationship(deleteRule: .cascade, inverse: \SeasonalAttendance.employee)
    var attendances: [SeasonalAttendance] = []
    
    @Relationship(deleteRule: .cascade, inverse: \SeasonalPaymentSettlement.employee)
    var seasonalSettlements: [SeasonalPaymentSettlement] = []
    
    @Relationship(deleteRule: .cascade, inverse: \WorkerAdvance.employee)
    var advances: [WorkerAdvance] = []
    
    @Relationship(deleteRule: .cascade, inverse: \MonthlyPayrollRecord.employee)
    var monthlyPayrolls: [MonthlyPayrollRecord] = []
    
    var employeeType: EmployeeType {
        get { EmployeeType(rawValue: employeeTypeRaw) ?? .seasonal }
        set { employeeTypeRaw = newValue.rawValue }
    }
    
    var pendingAdvanceBalance: Double {
        advances
            .filter { !$0.isFullyRecovered }
            .reduce(0.0) { $0 + $1.remainingUnadjustedAmount }
    }
    
    var unpaidSeasonalWages: Double {
        attendances
            .filter { !$0.isPaid }
            .reduce(0.0) { $0 + $1.calculatedWageForDay }
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        employeeType: EmployeeType,
        roleOrSkill: String = "General Farm Work",
        defaultDailyWage: Double = 0.0,
        monthlySalary: Double = 0.0,
        joiningDate: Date = .now,
        phone: String = "",
        isActive: Bool = true,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.employeeTypeRaw = employeeType.rawValue
        self.roleOrSkill = roleOrSkill
        self.defaultDailyWage = defaultDailyWage
        self.monthlySalary = monthlySalary
        self.joiningDate = joiningDate
        self.phone = phone
        self.isActive = isActive
        self.notes = notes
    }
}

// MARK: - 3. Transaction Models

@Model
final class FarmExpense {
    @Attribute(.unique) var id: UUID
    var date: Date
    var amount: Double
    var quantity: Double
    var unitRaw: String
    var paymentModeRaw: String
    var paymentStatusRaw: String
    var vendorName: String
    var invoiceNumber: String
    var notes: String
    var categoryNameSnapshot: String
    var cropNameSnapshot: String
    
    @Attribute(.externalStorage)
    var receiptImageData: Data?
    
    var expenseCategory: ExpenseMaster?
    var crop: CropMaster?
    
    var unit: MeasureUnit {
        get { MeasureUnit(rawValue: unitRaw) ?? .lumpSum }
        set { unitRaw = newValue.rawValue }
    }
    
    var paymentMode: PaymentMode {
        get { PaymentMode(rawValue: paymentModeRaw) ?? .cash }
        set { paymentModeRaw = newValue.rawValue }
    }
    
    var paymentStatus: PaymentStatus {
        get { PaymentStatus(rawValue: paymentStatusRaw) ?? .paid }
        set { paymentStatusRaw = newValue.rawValue }
    }
    
    var resolvedCategoryName: String {
        expenseCategory?.categoryName ?? categoryNameSnapshot
    }
    
    var resolvedCropName: String {
        crop?.cropName ?? cropNameSnapshot
    }
    
    init(
        id: UUID = UUID(),
        date: Date = .now,
        expenseCategory: ExpenseMaster?,
        crop: CropMaster?,
        amount: Double,
        quantity: Double = 1.0,
        unit: MeasureUnit = .lumpSum,
        paymentMode: PaymentMode = .cash,
        paymentStatus: PaymentStatus = .paid,
        vendorName: String = "",
        invoiceNumber: String = "",
        notes: String = "",
        receiptImageData: Data? = nil
    ) {
        self.id = id
        self.date = date
        self.expenseCategory = expenseCategory
        self.crop = crop
        self.amount = amount
        self.quantity = quantity
        self.unitRaw = unit.rawValue
        self.paymentModeRaw = paymentMode.rawValue
        self.paymentStatusRaw = (paymentMode == .credit) ? PaymentStatus.pending.rawValue : paymentStatus.rawValue
        self.vendorName = vendorName
        self.invoiceNumber = invoiceNumber
        self.notes = notes
        self.receiptImageData = receiptImageData
        self.categoryNameSnapshot = expenseCategory?.categoryName ?? "Uncategorized"
        self.cropNameSnapshot = crop?.cropName ?? "General Farm Overhead"
    }
}

@Model
final class FarmRevenue {
    @Attribute(.unique) var id: UUID
    var date: Date
    var quantity: Double
    var unitRaw: String
    var ratePerUnit: Double
    var totalAmount: Double
    var paymentModeRaw: String
    var paymentStatusRaw: String
    var buyerNameSnapshot: String
    var cropNameSnapshot: String
    var invoiceOrSlipNo: String
    var notes: String
    
    var crop: CropMaster?
    var buyerMaster: RevenueMaster?
    
    var unit: MeasureUnit {
        get { MeasureUnit(rawValue: unitRaw) ?? .kg }
        set { unitRaw = newValue.rawValue }
    }
    
    var paymentMode: PaymentMode {
        get { PaymentMode(rawValue: paymentModeRaw) ?? .cash }
        set { paymentModeRaw = newValue.rawValue }
    }
    
    var paymentStatus: PaymentStatus {
        get { PaymentStatus(rawValue: paymentStatusRaw) ?? .paid }
        set { paymentStatusRaw = newValue.rawValue }
    }
    
    var resolvedCropName: String {
        crop?.cropName ?? cropNameSnapshot
    }
    
    var resolvedBuyerName: String {
        buyerMaster?.buyerOrSourceName ?? (buyerNameSnapshot.isEmpty ? "Direct Sale" : buyerNameSnapshot)
    }
    
    init(
        id: UUID = UUID(),
        date: Date = .now,
        crop: CropMaster?,
        buyerMaster: RevenueMaster? = nil,
        buyerNameCustom: String = "",
        quantity: Double,
        unit: MeasureUnit = .kg,
        ratePerUnit: Double,
        totalAmountOverride: Double? = nil,
        paymentMode: PaymentMode = .cash,
        paymentStatus: PaymentStatus = .paid,
        invoiceOrSlipNo: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.crop = crop
        self.buyerMaster = buyerMaster
        self.quantity = quantity
        self.unitRaw = unit.rawValue
        self.ratePerUnit = ratePerUnit
        self.totalAmount = totalAmountOverride ?? (quantity * ratePerUnit)
        self.paymentModeRaw = paymentMode.rawValue
        self.paymentStatusRaw = (paymentMode == .credit) ? PaymentStatus.pending.rawValue : paymentStatus.rawValue
        self.buyerNameSnapshot = buyerMaster?.buyerOrSourceName ?? buyerNameCustom
        self.cropNameSnapshot = crop?.cropName ?? "General Farm Revenue"
        self.invoiceOrSlipNo = invoiceOrSlipNo
        self.notes = notes
    }
}

// MARK: - 4. Payroll & Attendance Models

@Model
final class SeasonalAttendance {
    @Attribute(.unique) var id: UUID
    var date: Date
    var statusRaw: String
    var attendanceMultiplier: Double
    var appliedDailyWage: Double
    var overtimeBonusAmount: Double
    var calculatedWageForDay: Double
    var isPaid: Bool
    var paidDate: Date?
    var workerNameSnapshot: String
    var cropNameSnapshot: String
    var notes: String
    
    var employee: EmployeeMaster?
    var crop: CropMaster?
    var settlement: SeasonalPaymentSettlement?
    
    var status: AttendanceStatus {
        get { AttendanceStatus(rawValue: statusRaw) ?? .fullDay }
        set { statusRaw = newValue.rawValue }
    }
    
    var resolvedCropName: String {
        crop?.cropName ?? cropNameSnapshot
    }
    
    func recalculateWage() {
        self.calculatedWageForDay = (appliedDailyWage * attendanceMultiplier) + overtimeBonusAmount
    }
    
    init(
        id: UUID = UUID(),
        date: Date,
        employee: EmployeeMaster,
        crop: CropMaster?,
        status: AttendanceStatus = .fullDay,
        customMultiplier: Double? = nil,
        appliedDailyWage: Double? = nil,
        overtimeBonusAmount: Double = 0.0,
        isPaid: Bool = false,
        paidDate: Date? = nil,
        notes: String = ""
    ) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let multiplier = customMultiplier ?? status.defaultMultiplier
        let lockedRate = appliedDailyWage ?? employee.defaultDailyWage
        
        self.id = id
        self.date = normalizedDate
        self.employee = employee
        self.crop = crop
        self.statusRaw = status.rawValue
        self.attendanceMultiplier = multiplier
        self.appliedDailyWage = lockedRate
        self.overtimeBonusAmount = overtimeBonusAmount
        self.calculatedWageForDay = (lockedRate * multiplier) + overtimeBonusAmount
        self.isPaid = isPaid
        self.paidDate = paidDate
        self.workerNameSnapshot = employee.name
        self.cropNameSnapshot = crop?.cropName ?? "General Farm Overhead"
        self.notes = notes
    }
}

@Model
final class WorkerAdvance {
    @Attribute(.unique) var id: UUID
    var date: Date
    var amount: Double
    var remainingUnadjustedAmount: Double
    var paymentModeRaw: String
    var isFullyRecovered: Bool
    var workerNameSnapshot: String
    var notes: String
    
    var employee: EmployeeMaster?
    
    var paymentMode: PaymentMode {
        get { PaymentMode(rawValue: paymentModeRaw) ?? .cash }
        set { paymentModeRaw = newValue.rawValue }
    }
    
    init(
        id: UUID = UUID(),
        date: Date = .now,
        employee: EmployeeMaster,
        amount: Double,
        paymentMode: PaymentMode = .cash,
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.employee = employee
        self.amount = amount
        self.remainingUnadjustedAmount = amount
        self.paymentModeRaw = paymentMode.rawValue
        self.isFullyRecovered = false
        self.workerNameSnapshot = employee.name
        self.notes = notes
    }
}

@Model
final class SeasonalPaymentSettlement {
    @Attribute(.unique) var id: UUID
    var paymentDate: Date
    var periodStartDate: Date
    var periodEndDate: Date
    var totalEffectiveDays: Double
    var grossWageEarned: Double
    var advanceDeducted: Double
    var bonusOrAdjustment: Double
    var netPaidAmount: Double
    var paymentModeRaw: String
    var workerNameSnapshot: String
    var notes: String
    
    var employee: EmployeeMaster?
    
    @Relationship(deleteRule: .nullify, inverse: \SeasonalAttendance.settlement)
    var settledAttendances: [SeasonalAttendance] = []
    
    var paymentMode: PaymentMode {
        get { PaymentMode(rawValue: paymentModeRaw) ?? .cash }
        set { paymentModeRaw = newValue.rawValue }
    }
    
    init(
        id: UUID = UUID(),
        paymentDate: Date = .now,
        periodStartDate: Date,
        periodEndDate: Date,
        employee: EmployeeMaster,
        totalEffectiveDays: Double,
        grossWageEarned: Double,
        advanceDeducted: Double = 0.0,
        bonusOrAdjustment: Double = 0.0,
        netPaidAmount: Double,
        paymentMode: PaymentMode = .cash,
        settledAttendances: [SeasonalAttendance] = [],
        notes: String = ""
    ) {
        self.id = id
        self.paymentDate = paymentDate
        self.periodStartDate = Calendar.current.startOfDay(for: periodStartDate)
        self.periodEndDate = Calendar.current.startOfDay(for: periodEndDate)
        self.employee = employee
        self.totalEffectiveDays = totalEffectiveDays
        self.grossWageEarned = grossWageEarned
        self.advanceDeducted = advanceDeducted
        self.bonusOrAdjustment = bonusOrAdjustment
        self.netPaidAmount = netPaidAmount
        self.paymentModeRaw = paymentMode.rawValue
        self.workerNameSnapshot = employee.name
        self.settledAttendances = settledAttendances
        self.notes = notes
    }
}

@Model
final class MonthlyPayrollRecord {
    @Attribute(.unique) var id: UUID
    var month: Int
    var year: Int
    var baseSalarySnapshot: Double
    var advanceOrDeductions: Double
    var bonusAmount: Double
    var netPaidAmount: Double
    var paymentDate: Date
    var paymentStatusRaw: String
    var paymentModeRaw: String
    var employeeNameSnapshot: String
    var cropNameSnapshot: String
    var notes: String
    
    var employee: EmployeeMaster?
    var crop: CropMaster?
    
    var paymentStatus: PaymentStatus {
        get { PaymentStatus(rawValue: paymentStatusRaw) ?? .paid }
        set { paymentStatusRaw = newValue.rawValue }
    }
    
    var paymentMode: PaymentMode {
        get { PaymentMode(rawValue: paymentModeRaw) ?? .bankTransfer }
        set { paymentModeRaw = newValue.rawValue }
    }
    
    var periodReferenceDate: Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return Calendar.current.date(from: components) ?? paymentDate
    }
    
    var periodDisplayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: periodReferenceDate)
    }
    
    init(
        id: UUID = UUID(),
        month: Int,
        year: Int,
        employee: EmployeeMaster,
        crop: CropMaster? = nil,
        baseSalarySnapshot: Double? = nil,
        advanceOrDeductions: Double = 0.0,
        bonusAmount: Double = 0.0,
        paymentDate: Date = .now,
        paymentStatus: PaymentStatus = .paid,
        paymentMode: PaymentMode = .bankTransfer,
        notes: String = ""
    ) {
        let base = baseSalarySnapshot ?? employee.monthlySalary
        self.id = id
        self.month = month
        self.year = year
        self.employee = employee
        self.crop = crop
        self.baseSalarySnapshot = base
        self.advanceOrDeductions = advanceOrDeductions
        self.bonusAmount = bonusAmount
        self.netPaidAmount = max(0, base - advanceOrDeductions + bonusAmount)
        self.paymentDate = paymentDate
        self.paymentStatusRaw = paymentStatus.rawValue
        self.paymentModeRaw = paymentMode.rawValue
        self.employeeNameSnapshot = employee.name
        self.cropNameSnapshot = crop?.cropName ?? "General Farm Overhead"
        self.notes = notes
    }
}

@Model
final class FarmBalanceSheetEntry {
    @Attribute(.unique) var id: UUID
    var title: String
    var itemTypeRaw: String
    var amount: Double
    var asOfDate: Date
    var notes: String
    
    var itemType: BalanceSheetItemType {
        get { BalanceSheetItemType(rawValue: itemTypeRaw) ?? .openingCashOrBank }
        set { itemTypeRaw = newValue.rawValue }
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        itemType: BalanceSheetItemType,
        amount: Double,
        asOfDate: Date = .now,
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.itemTypeRaw = itemType.rawValue
        self.amount = amount
        self.asOfDate = asOfDate
        self.notes = notes
    }
}

enum NSNFormatters {
    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    static let decimalCurrencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()
    
    static func currency(_ value: Double, showDecimals: Bool = false) -> String {
        let formatter = showDecimals ? decimalCurrencyFormatter : currencyFormatter
        return formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }
    
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_IN")
        return formatter
    }()
    
    static func date(_ date: Date) -> String {
        mediumDate.string(from: date)
    }
}
NSN_Farms_Models.swift
Displaying NSN_Farms_App_Entry_Point.swift.

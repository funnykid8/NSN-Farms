
import Foundation
import SwiftData
import Observation

enum ReportPeriodPreset: String, CaseIterable, Identifiable {
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case last90Days = "Last 90 Days"
    case thisFinancialYear = "This Financial Year (Apr–Mar)"
    case allTime = "All Time"
    case custom = "Custom Range"
    
    var id: String { rawValue }
    
    func resolvedDateRange(customStart: Date, customEnd: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let now = Date.now
        let todayEnd = Self.endOfDay(for: now, calendar: calendar)
        
        switch self {
        case .thisMonth:
            let comps = calendar.dateComponents([.year, .month], from: now)
            let start = calendar.date(from: comps) ?? now
            return (calendar.startOfDay(for: start), todayEnd)
        case .lastMonth:
            let thisMonthComps = calendar.dateComponents([.year, .month], from: now)
            let thisMonthStart = calendar.date(from: thisMonthComps) ?? now
            let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) ?? now
            let lastMonthEnd = calendar.date(byAdding: .second, value: -1, to: thisMonthStart) ?? now
            return (calendar.startOfDay(for: lastMonthStart), lastMonthEnd)
        case .last90Days:
            let start = calendar.date(byAdding: .day, value: -90, to: now) ?? now
            return (calendar.startOfDay(for: start), todayEnd)
        case .thisFinancialYear:
            let year = calendar.component(.year, from: now)
            let month = calendar.component(.month, from: now)
            let fyStartYear = (month >= 4) ? year : (year - 1)
            var fyStartComps = DateComponents()
            fyStartComps.year = fyStartYear
            fyStartComps.month = 4
            fyStartComps.day = 1
            let start = calendar.date(from: fyStartComps) ?? now
            return (calendar.startOfDay(for: start), todayEnd)
        case .allTime:
            let distantPast = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? .distantPast
            let distantFuture = calendar.date(from: DateComponents(year: 2100, month: 12, day: 31)) ?? .distantFuture
            return (distantPast, distantFuture)
        case .custom:
            let normalizedStart = calendar.startOfDay(for: min(customStart, customEnd))
            let normalizedEnd = Self.endOfDay(for: max(customStart, customEnd), calendar: calendar)
            return (normalizedStart, normalizedEnd)
        }
    }
    
    static func endOfDay(for date: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }
}

struct DashboardKPISummary {
    let totalRevenue: Double
    let totalDirectExpenses: Double
    let totalLaborCost: Double
    let netFarmProfit: Double
    let pendingReceivables: Double
    let unpaidSeasonalWages: Double
    let unpaidVendorPayables: Double
    let activeWorkersCount: Int
    let activeCropsCount: Int
}

struct SeasonalSettlementPreview: Identifiable {
    var id: UUID { employee.id }
    let employee: EmployeeMaster
    let periodStart: Date
    let periodEnd: Date
    let unpaidRecords: [SeasonalAttendance]
    let totalEffectiveDays: Double
    let grossWageEarned: Double
    let openAdvanceBalance: Double
    let suggestedAdvanceDeduction: Double
    
    func netPayable(advanceDeduction: Double, bonusOrAdjustment: Double) -> Double {
        max(0, grossWageEarned - advanceDeduction + bonusOrAdjustment)
    }
}

struct CropProfitabilityRow: Identifiable {
    let id: UUID
    let crop: CropMaster?
    let cropName: String
    let plotName: String
    let areaInAcres: Double
    let isOverhead: Bool
    let realizedRevenue: Double
    let pendingRevenue: Double
    let totalRevenue: Double
    let directExpenses: Double
    let seasonalLaborCost: Double
    let seasonalWorkerDays: Double
    let monthlyLaborCost: Double
    
    var totalLaborCost: Double { seasonalLaborCost + monthlyLaborCost }
    var totalCost: Double { directExpenses + totalLaborCost }
    var grossMargin: Double { totalRevenue - totalCost }
    var roiPercentage: Double {
        guard totalCost > 0 else { return 0.0 }
        return (grossMargin / totalCost) * 100.0
    }
}

struct FarmPnLSummaryReport {
    let periodStart: Date
    let periodEnd: Date
    let cropRows: [CropProfitabilityRow]
    let overheadRow: CropProfitabilityRow
    
    var totalCropRevenue: Double { cropRows.reduce(0) { $0 + $1.totalRevenue } + overheadRow.totalRevenue }
    var totalCropDirectExpenses: Double { cropRows.reduce(0) { $0 + $1.directExpenses } }
    var totalCropDirectLabor: Double { cropRows.reduce(0) { $0 + $1.totalLaborCost } }
    var netFarmProfit: Double {
        cropRows.reduce(0) { $0 + $1.grossMargin } + overheadRow.grossMargin
    }
}

struct FarmBalanceSheetStatement {
    let asOfDate: Date
    let openingCashAndBank: Double
    let netOperatingCashSurplus: Double
    var closingCashAndBankBalance: Double { openingCashAndBank + netOperatingCashSurplus }
    let accountsReceivableFromBuyers: Double
    let unadjustedWorkerAdvancesAsset: Double
    let machineryAndEquipmentValue: Double
    let irrigationInfrastructureValue: Double
    let landAndBuildingsValue: Double
    let inventoryStockValue: Double
    
    var totalCurrentAssets: Double { closingCashAndBankBalance + accountsReceivableFromBuyers + unadjustedWorkerAdvancesAsset + inventoryStockValue }
    var totalFixedAssets: Double { machineryAndEquipmentValue + irrigationInfrastructureValue + landAndBuildingsValue }
    var totalAssets: Double { totalCurrentAssets + totalFixedAssets }
    
    let accountsPayableToVendors: Double
    let unpaidSeasonalWagesLiability: Double
    let unpaidMonthlySalariesLiability: Double
    let externalLoansAndLiabilities: Double
    
    var totalCurrentLiabilities: Double { accountsPayableToVendors + unpaidSeasonalWagesLiability + unpaidMonthlySalariesLiability }
    var totalLiabilities: Double { totalCurrentLiabilities + externalLoansAndLiabilities }
    var netFarmEquity: Double { totalAssets - totalLiabilities }
}

struct MonthlyCashflowChartPoint: Identifiable {
    var id: String { "\(year)-\(month)" }
    let monthLabel: String
    let monthDate: Date
    let month: Int
    let year: Int
    let revenue: Double
    let expenses: Double
    let labor: Double
    var totalCost: Double { expenses + labor }
}

struct CategoryCostSlice: Identifiable {
    var id: String { categoryName }
    let categoryName: String
    let amount: Double
    let percentage: Double
}

@Observable
@MainActor
final class ERPCalculationEngine {
    var selectedPreset: ReportPeriodPreset = .thisFinancialYear
    var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    var customEndDate: Date = .now
    
    var activeDateRange: (start: Date, end: Date) {
        selectedPreset.resolvedDateRange(customStart: customStartDate, customEnd: customEndDate)
    }
    
    func fetchOrPrepareDailyAttendance(for date: Date, defaultCrop: CropMaster?, context: ModelContext) throws -> [SeasonalAttendance] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let dayEnd = ReportPeriodPreset.endOfDay(for: dayStart, calendar: cal)
        
        let attendanceDescriptor = FetchDescriptor<SeasonalAttendance>(
            predicate: #Predicate { $0.date >= dayStart && $0.date <= dayEnd }
        )
        let existingRecords = try context.fetch(attendanceDescriptor)
        
        let workerDescriptor = FetchDescriptor<EmployeeMaster>(
            predicate: #Predicate { $0.isActive == true }
        )
        let allActiveEmployees = try context.fetch(workerDescriptor)
        let seasonalWorkers = allActiveEmployees.filter { $0.employeeType == .seasonal }
        
        let resolvedCrop = try defaultCrop ?? fetchSystemOverheadCrop(context: context)
        var results = existingRecords
        let recordedEmployeeIDs = Set(existingRecords.compactMap { $0.employee?.id })
        
        for worker in seasonalWorkers where !recordedEmployeeIDs.contains(worker.id) {
            let newAttendance = SeasonalAttendance(
                date: dayStart,
                employee: worker,
                crop: resolvedCrop,
                status: .fullDay,
                appliedDailyWage: worker.defaultDailyWage
            )
            context.insert(newAttendance)
            results.append(newAttendance)
        }
        
        if context.hasChanges { try context.save() }
        return results.sorted { $0.workerNameSnapshot < $1.workerNameSnapshot }
    }
    
    func updateAttendanceRecord(
        _ record: SeasonalAttendance,
        status: AttendanceStatus,
        crop: CropMaster?,
        context: ModelContext
    ) throws {
        guard !record.isPaid else { throw ERPError.cannotModifySettledAttendance }
        record.status = status
        record.attendanceMultiplier = status.defaultMultiplier
        if let crop = crop {
            record.crop = crop
            record.cropNameSnapshot = crop.cropName
        }
        record.recalculateWage()
        try context.save()
    }
    
    func markAllUnpaidWorkersPresent(records: [SeasonalAttendance], assignedCrop: CropMaster?, context: ModelContext) throws {
        for record in records where !record.isPaid {
            record.status = .fullDay
            record.attendanceMultiplier = AttendanceStatus.fullDay.defaultMultiplier
            if let assignedCrop {
                record.crop = assignedCrop
                record.cropNameSnapshot = assignedCrop.cropName
            }
            record.recalculateWage()
        }
        try context.save()
    }
    
    func previewSeasonalSettlement(for employee: EmployeeMaster, from startDate: Date, to endDate: Date) -> SeasonalSettlementPreview {
        let cal = Calendar.current
        let normalizedStart = cal.startOfDay(for: min(startDate, endDate))
        let normalizedEnd = ReportPeriodPreset.endOfDay(for: max(startDate, endDate), calendar: cal)
        
        let unpaidInPeriod = employee.attendances
            .filter { !$0.isPaid && $0.date >= normalizedStart && $0.date <= normalizedEnd }
            .sorted { $0.date < $1.date }
        
        var effectiveDays = 0.0
        var grossEarned = 0.0
        for att in unpaidInPeriod {
            effectiveDays += att.attendanceMultiplier
            grossEarned += att.calculatedWageForDay
        }
        
        let openAdvance = employee.pendingAdvanceBalance
        let suggestedDeduction = min(grossEarned, openAdvance)
        
        return SeasonalSettlementPreview(
            employee: employee,
            periodStart: normalizedStart,
            periodEnd: normalizedEnd,
            unpaidRecords: unpaidInPeriod,
            totalEffectiveDays: effectiveDays,
            grossWageEarned: grossEarned,
            openAdvanceBalance: openAdvance,
            suggestedAdvanceDeduction: suggestedDeduction
        )
    }
    
    func previewAllSeasonalSettlements(from startDate: Date, to endDate: Date, context: ModelContext) throws -> [SeasonalSettlementPreview] {
        let allEmployees = try context.fetch(FetchDescriptor<EmployeeMaster>())
        let seasonalWorkers = allEmployees.filter { $0.employeeType == .seasonal }.sorted { $0.name < $1.name }
        return seasonalWorkers
            .map { previewSeasonalSettlement(for: $0, from: startDate, to: endDate) }
            .filter { !$0.unpaidRecords.isEmpty }
    }
    
    @discardableResult
    func executeSeasonalSettlement(
        preview: SeasonalSettlementPreview,
        advanceToDeduct: Double,
        bonusOrAdjustment: Double = 0.0,
        paymentMode: PaymentMode = .cash,
        notes: String = "",
        context: ModelContext
    ) throws -> SeasonalPaymentSettlement {
        guard !preview.unpaidRecords.isEmpty else { throw ERPError.noUnpaidAttendanceInRange }
        let clampedAdvanceDeduction = max(0, min(advanceToDeduct, min(preview.openAdvanceBalance, preview.grossWageEarned + bonusOrAdjustment)))
        let netPaid = preview.netPayable(advanceDeduction: clampedAdvanceDeduction, bonusOrAdjustment: bonusOrAdjustment)
        
        if clampedAdvanceDeduction > 0 {
            var remainingToRecover = clampedAdvanceDeduction
            let openAdvances = preview.employee.advances
                .filter { !$0.isFullyRecovered && $0.remainingUnadjustedAmount > 0 }
                .sorted { $0.date < $1.date }
            
            for advance in openAdvances {
                guard remainingToRecover > 0 else { break }
                let deduction = min(advance.remainingUnadjustedAmount, remainingToRecover)
                advance.remainingUnadjustedAmount -= deduction
                remainingToRecover -= deduction
                if advance.remainingUnadjustedAmount <= 0.009 {
                    advance.remainingUnadjustedAmount = 0.0
                    advance.isFullyRecovered = true
                }
            }
        }
        
        let settlement = SeasonalPaymentSettlement(
            paymentDate: .now,
            periodStartDate: preview.periodStart,
            periodEndDate: preview.periodEnd,
            employee: preview.employee,
            totalEffectiveDays: preview.totalEffectiveDays,
            grossWageEarned: preview.grossWageEarned,
            advanceDeducted: clampedAdvanceDeduction,
            bonusOrAdjustment: bonusOrAdjustment,
            netPaidAmount: netPaid,
            paymentMode: paymentMode,
            settledAttendances: preview.unpaidRecords,
            notes: notes
        )
        context.insert(settlement)
        
        for attendance in preview.unpaidRecords {
            attendance.isPaid = true
            attendance.paidDate = .now
            attendance.settlement = settlement
        }
        
        try context.save()
        return settlement
    }
    
    func generateMonthlyPayrollSheet(month: Int, year: Int, context: ModelContext) throws -> [MonthlyPayrollRecord] {
        let payrollDescriptor = FetchDescriptor<MonthlyPayrollRecord>(
            predicate: #Predicate { $0.month == month && $0.year == year }
        )
        let existingRecords = try context.fetch(payrollDescriptor)
        let recordedEmployeeIDs = Set(existingRecords.compactMap { $0.employee?.id })
        
        let allActiveEmployees = try context.fetch(
            FetchDescriptor<EmployeeMaster>(predicate: #Predicate { $0.isActive == true })
        )
        let monthlyStaff = allActiveEmployees.filter { $0.employeeType == .monthly }
        
        var result = existingRecords
        for staff in monthlyStaff where !recordedEmployeeIDs.contains(staff.id) {
            let newRecord = MonthlyPayrollRecord(
                month: month,
                year: year,
                employee: staff,
                baseSalarySnapshot: staff.monthlySalary,
                paymentStatus: .pending
            )
            context.insert(newRecord)
            result.append(newRecord)
        }
        if context.hasChanges { try context.save() }
        return result.sorted { $0.employeeNameSnapshot < $1.employeeNameSnapshot }
    }
    
    func generateCropWisePnLReport(from startDate: Date, to endDate: Date, context: ModelContext) throws -> FarmPnLSummaryReport {
        let cal = Calendar.current
        let start = cal.startOfDay(for: min(startDate, endDate))
        let end = ReportPeriodPreset.endOfDay(for: max(startDate, endDate), calendar: cal)
        
        let allCrops = try context.fetch(FetchDescriptor<CropMaster>())
        let allExpenses = try context.fetch(
            FetchDescriptor<FarmExpense>(predicate: #Predicate { $0.date >= start && $0.date <= end })
        )
        let allRevenues = try context.fetch(
            FetchDescriptor<FarmRevenue>(predicate: #Predicate { $0.date >= start && $0.date <= end })
        )
        let allAttendances = try context.fetch(
            FetchDescriptor<SeasonalAttendance>(predicate: #Predicate { $0.date >= start && $0.date <= end })
        )
        let allMonthlyPayrolls = try context.fetch(FetchDescriptor<MonthlyPayrollRecord>())
            .filter { $0.periodReferenceDate >= start && $0.periodReferenceDate <= end }
        
        let overheadCrop = allCrops.first(where: { $0.isSystemOverhead })
        let cultivatedCrops = allCrops.filter { !$0.isSystemOverhead }.sorted { $0.cropName < $1.cropName }
        
        var cropRows: [CropProfitabilityRow] = []
        for crop in cultivatedCrops {
            let cropID = crop.id
            let revs = allRevenues.filter { $0.crop?.id == cropID }
            let realized = revs.filter { $0.paymentStatus == .paid }.reduce(0.0) { $0 + $1.totalAmount }
            let pending = revs.filter { $0.paymentStatus == .pending }.reduce(0.0) { $0 + $1.totalAmount }
            
            let directExp = allExpenses.filter { $0.crop?.id == cropID }.reduce(0.0) { $0 + $1.amount }
            let atts = allAttendances.filter { $0.crop?.id == cropID }
            let seasonalCost = atts.reduce(0.0) { $0 + $1.calculatedWageForDay }
            let seasonalDays = atts.reduce(0.0) { $0 + $1.attendanceMultiplier }
            let monthlyCost = allMonthlyPayrolls.filter { $0.crop?.id == cropID }.reduce(0.0) { $0 + $1.netPaidAmount }
            
            cropRows.append(CropProfitabilityRow(
                id: crop.id,
                crop: crop,
                cropName: crop.cropName,
                plotName: crop.plotOrFieldName,
                areaInAcres: crop.areaInAcres,
                isOverhead: false,
                realizedRevenue: realized,
                pendingRevenue: pending,
                totalRevenue: realized + pending,
                directExpenses: directExp,
                seasonalLaborCost: seasonalCost,
                seasonalWorkerDays: seasonalDays,
                monthlyLaborCost: monthlyCost
            ))
        }
        
        let isOverheadMatch: (CropMaster?) -> Bool = { crop in
            guard let crop else { return true }
            return crop.isSystemOverhead
        }
        
        let ohRevs = allRevenues.filter { isOverheadMatch($0.crop) }
        let ohRealized = ohRevs.filter { $0.paymentStatus == .paid }.reduce(0.0) { $0 + $1.totalAmount }
        let ohPending = ohRevs.filter { $0.paymentStatus == .pending }.reduce(0.0) { $0 + $1.totalAmount }
        let ohExp = allExpenses.filter { isOverheadMatch($0.crop) }.reduce(0.0) { $0 + $1.amount }
        let ohAtts = allAttendances.filter { isOverheadMatch($0.crop) }
        let ohSeasonalCost = ohAtts.reduce(0.0) { $0 + $1.calculatedWageForDay }
        let ohMonthlyCost = allMonthlyPayrolls.filter { isOverheadMatch($0.crop) }.reduce(0.0) { $0 + $1.netPaidAmount }
        
        let overheadRow = CropProfitabilityRow(
            id: overheadCrop?.id ?? UUID(),
            crop: overheadCrop,
            cropName: overheadCrop?.cropName ?? "General Farm Overhead",
            plotName: "Shared Costs",
            areaInAcres: 0.0,
            isOverhead: true,
            realizedRevenue: ohRealized,
            pendingRevenue: ohPending,
            totalRevenue: ohRealized + ohPending,
            directExpenses: ohExp,
            seasonalLaborCost: ohSeasonalCost,
            seasonalWorkerDays: ohAtts.reduce(0.0) { $0 + $1.attendanceMultiplier },
            monthlyLaborCost: ohMonthlyCost
        )
        
        return FarmPnLSummaryReport(periodStart: start, periodEnd: end, cropRows: cropRows, overheadRow: overheadRow)
    }
    
    func generateBalanceSheet(asOf date: Date, context: ModelContext) throws -> FarmBalanceSheetStatement {
        let cutoff = ReportPeriodPreset.endOfDay(for: date)
        let capitalEntries = try context.fetch(FetchDescriptor<FarmBalanceSheetEntry>(predicate: #Predicate { $0.asOfDate <= cutoff }))
        let expenses = try context.fetch(FetchDescriptor<FarmExpense>(predicate: #Predicate { $0.date <= cutoff }))
        let revenues = try context.fetch(FetchDescriptor<FarmRevenue>(predicate: #Predicate { $0.date <= cutoff }))
        let attendances = try context.fetch(FetchDescriptor<SeasonalAttendance>(predicate: #Predicate { $0.date <= cutoff }))
        let settlements = try context.fetch(FetchDescriptor<SeasonalPaymentSettlement>(predicate: #Predicate { $0.paymentDate <= cutoff }))
        let advances = try context.fetch(FetchDescriptor<WorkerAdvance>(predicate: #Predicate { $0.date <= cutoff }))
        
        let openingCash = capitalEntries.filter { $0.itemType == .openingCashOrBank }.reduce(0.0) { $0 + $1.amount }
        let machinery = capitalEntries.filter { $0.itemType == .farmMachinery }.reduce(0.0) { $0 + $1.amount }
        let irrigation = capitalEntries.filter { $0.itemType == .irrigationInfrastructure }.reduce(0.0) { $0 + $1.amount }
        let land = capitalEntries.filter { $0.itemType == .landOrBuildings }.reduce(0.0) { $0 + $1.amount }
        let inventory = capitalEntries.filter { $0.itemType == .inventoryStock }.reduce(0.0) { $0 + $1.amount }
        let loans = capitalEntries.filter { $0.itemType == .loanOrLiability }.reduce(0.0) { $0 + $1.amount }
        
        let cashRev = revenues.filter { $0.paymentStatus == .paid }.reduce(0.0) { $0 + $1.totalAmount }
        let ar = revenues.filter { $0.paymentStatus == .pending }.reduce(0.0) { $0 + $1.totalAmount }
        let cashExp = expenses.filter { $0.paymentStatus == .paid }.reduce(0.0) { $0 + $1.amount }
        let ap = expenses.filter { $0.paymentStatus == .pending }.reduce(0.0) { $0 + $1.amount }
        
        let settlementsOut = settlements.reduce(0.0) { $0 + $1.netPaidAmount }
        let advancesOut = advances.reduce(0.0) { $0 + $1.amount }
        let unadjustedAdv = advances.reduce(0.0) { $0 + $1.remainingUnadjustedAmount }
        let unpaidWages = attendances.filter { !$0.isPaid }.reduce(0.0) { $0 + $1.calculatedWageForDay }
        
        let netOpCash = cashRev - cashExp - settlementsOut - advancesOut
        
        return FarmBalanceSheetStatement(
            asOfDate: cutoff,
            openingCashAndBank: openingCash,
            netOperatingCashSurplus: netOpCash,
            accountsReceivableFromBuyers: ar,
            unadjustedWorkerAdvancesAsset: unadjustedAdv,
            machineryAndEquipmentValue: machinery,
            irrigationInfrastructureValue: irrigation,
            landAndBuildingsValue: land,
            inventoryStockValue: inventory,
            accountsPayableToVendors: ap,
            unpaidSeasonalWagesLiability: unpaidWages,
            unpaidMonthlySalariesLiability: 0.0,
            externalLoansAndLiabilities: loans
        )
    }
    
    func computeDashboardKPIs(from startDate: Date, to endDate: Date, context: ModelContext) throws -> DashboardKPISummary {
        let pnl = try generateCropWisePnLReport(from: startDate, to: endDate, context: context)
        let bs = try generateBalanceSheet(asOf: .now, context: context)
        let activeWorkers = try context.fetchCount(FetchDescriptor<EmployeeMaster>(predicate: #Predicate { $0.isActive == true }))
        let activeCrops = try context.fetchCount(FetchDescriptor<CropMaster>(predicate: #Predicate { $0.isSystemOverhead == false }))
        
        let totalExp = pnl.cropRows.reduce(0) { $0 + $1.directExpenses } + pnl.overheadRow.directExpenses
        let totalLab = pnl.cropRows.reduce(0) { $0 + $1.totalLaborCost } + pnl.overheadRow.totalLaborCost
        
        return DashboardKPISummary(
            totalRevenue: pnl.totalCropRevenue,
            totalDirectExpenses: totalExp,
            totalLaborCost: totalLab,
            netFarmProfit: pnl.netFarmProfit,
            pendingReceivables: bs.accountsReceivableFromBuyers,
            unpaidSeasonalWages: bs.unpaidSeasonalWagesLiability,
            unpaidVendorPayables: bs.accountsPayableToVendors,
            activeWorkersCount: activeWorkers,
            activeCropsCount: activeCrops
        )
    }
    
    func generateSixMonthCashflowSeries(context: ModelContext) throws -> [MonthlyCashflowChartPoint] {
        let cal = Calendar.current
        let now = Date.now
        let currentMonthComps = cal.dateComponents([.year, .month], from: now)
        let currentMonthStart = cal.date(from: currentMonthComps) ?? now
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM yy"
        
        var points: [MonthlyCashflowChartPoint] = []
        for offset in stride(from: -5, through: 0, by: 1) {
            guard let monthStart = cal.date(byAdding: .month, value: offset, to: currentMonthStart),
                  let nextMonthStart = cal.date(byAdding: .month, value: 1, to: monthStart),
                  let monthEnd = cal.date(byAdding: .second, value: -1, to: nextMonthStart) else { continue }
            
            let pnl = try generateCropWisePnLReport(from: monthStart, to: monthEnd, context: context)
            let exp = pnl.cropRows.reduce(0) { $0 + $1.directExpenses } + pnl.overheadRow.directExpenses
            let lab = pnl.cropRows.reduce(0) { $0 + $1.totalLaborCost } + pnl.overheadRow.totalLaborCost
            
            points.append(MonthlyCashflowChartPoint(
                monthLabel: monthFormatter.string(from: monthStart),
                monthDate: monthStart,
                month: cal.component(.month, from: monthStart),
                year: cal.component(.year, from: monthStart),
                revenue: pnl.totalCropRevenue,
                expenses: exp,
                labor: lab
            ))
        }
        return points
    }
    
    func generateCostCategoryBreakdown(from startDate: Date, to endDate: Date, context: ModelContext) throws -> [CategoryCostSlice] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: min(startDate, endDate))
        let end = ReportPeriodPreset.endOfDay(for: max(startDate, endDate), calendar: cal)
        
        let expenses = try context.fetch(FetchDescriptor<FarmExpense>(predicate: #Predicate { $0.date >= start && $0.date <= end }))
        let attendances = try context.fetch(FetchDescriptor<SeasonalAttendance>(predicate: #Predicate { $0.date >= start && $0.date <= end }))
        
        var totals: [String: Double] = [:]
        for exp in expenses { totals[exp.resolvedCategoryName, default: 0.0] += exp.amount }
        let laborTotal = attendances.reduce(0.0) { $0 + $1.calculatedWageForDay }
        if laborTotal > 0 { totals["Seasonal Wages", default: 0.0] += laborTotal }
        
        let grandTotal = totals.values.reduce(0.0, +)
        guard grandTotal > 0 else { return [] }
        
        return totals.map { CategoryCostSlice(categoryName: $0.key, amount: $0.value, percentage: ($0.value / grandTotal) * 100.0) }
            .sorted { $0.amount > $1.amount }
    }
    
    func fetchSystemOverheadCrop(context: ModelContext) throws -> CropMaster? {
        var descriptor = FetchDescriptor<CropMaster>(predicate: #Predicate { $0.isSystemOverhead == true })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

enum ERPError: LocalizedError {
    case cannotModifySettledAttendance
    case noUnpaidAttendanceInRange
    
    var errorDescription: String? {
        switch self {
        case .cannotModifySettledAttendance: return "This attendance record has already been settled and paid."
        case .noUnpaidAttendanceInRange: return "No unpaid attendance records in this date range."
        }
    }
}
NSN_Farms_Calculation_Engine.swift
Displaying NSN_Farms_App_Entry_Point.swift.

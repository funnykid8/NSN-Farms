
import SwiftUI
import SwiftData
import Charts

enum NSNTheme {
    static let forestGreen = Color(red: 0.11, green: 0.26, blue: 0.20)
    static let earthGold = Color(red: 0.83, green: 0.64, blue: 0.45)
    static let backgroundCream = Color(red: 0.97, green: 0.98, blue: 0.96)
    static let cardBackground = Color.white
    static let accentRed = Color(red: 0.75, green: 0.15, blue: 0.15)
    static let accentBlue = Color(red: 0.15, green: 0.45, blue: 0.75)
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.pie.fill") }
            TransactionsView()
                .tabItem { Label("Transactions", systemImage: "indianrupeesign.arrow.circlepath") }
            PayrollTabView()
                .tabItem { Label("Payroll", systemImage: "person.3.fill") }
            ReportsTabView()
                .tabItem { Label("Reports & P&L", systemImage: "doc.text.fill") }
            MastersTabView()
                .tabItem { Label("Masters & Backup", systemImage: "gearshape.fill") }
        }
        .accentColor(NSNTheme.forestGreen)
    }
}

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(BackupManager.self) private var backupManager
    private let engine = ERPCalculationEngine()
    
    @State private var kpi: DashboardKPISummary = DashboardKPISummary(
        totalRevenue: 0, totalDirectExpenses: 0, totalLaborCost: 0, netFarmProfit: 0,
        pendingReceivables: 0, unpaidSeasonalWages: 0, unpaidVendorPayables: 0,
        activeWorkersCount: 0, activeCropsCount: 0
    )
    @State private var chartPoints: [MonthlyCashflowChartPoint] = []
    @State private var costSlices: [CategoryCostSlice] = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        KPICard(title: "Net Farm Profit", amount: kpi.netFarmProfit, icon: "leaf.circle.fill", color: kpi.netFarmProfit >= 0 ? NSNTheme.forestGreen : NSNTheme.accentRed)
                        KPICard(title: "Total Revenue", amount: kpi.totalRevenue, icon: "arrow.down.right.circle.fill", color: NSNTheme.forestGreen)
                        KPICard(title: "Direct Expenses", amount: kpi.totalDirectExpenses, icon: "cart.circle.fill", color: NSNTheme.accentBlue)
                        KPICard(title: "Labor & Payroll", amount: kpi.totalLaborCost, icon: "person.2.circle.fill", color: NSNTheme.earthGold)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(NSNTheme.backgroundCream)
            .navigationTitle("NSN Farms Dashboard")
            .onAppear { loadData() }
        }
    }
    
    private func loadData() {
        do {
            let range = engine.selectedPreset.resolvedDateRange(customStart: engine.customStartDate, customEnd: engine.customEndDate)
            kpi = try engine.computeDashboardKPIs(from: range.start, to: range.end, context: modelContext)
            chartPoints = try engine.generateSixMonthCashflowSeries(context: modelContext)
            costSlices = try engine.generateCostCategoryBreakdown(from: range.start, to: range.end, context: modelContext)
        } catch {
            print("Dashboard load error: \(error.localizedDescription)")
        }
    }
}

struct KPICard: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                Spacer()
                Image(systemName: icon).foregroundColor(color)
            }
            Text(NSNFormatters.currency(amount)).font(.title3).fontWeight(.bold).foregroundColor(.primary)
        }
        .padding()
        .background(NSNTheme.cardBackground)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FarmExpense.date, order: .reverse) private var expenses: [FarmExpense]
    @Query(sort: \FarmRevenue.date, order: .reverse) private var revenues: [FarmRevenue]
    @State private var selectedSegment = 0
    @State private var showAddExpense = false
    @State private var showAddRevenue = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Type", selection: $selectedSegment) {
                    Text("Expenses").tag(0)
                    Text("Revenue").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                List {
                    if selectedSegment == 0 {
                        ForEach(expenses) { exp in
                            HStack {
                                Text(exp.resolvedCategoryName).fontWeight(.bold)
                                Spacer()
                                Text(NSNFormatters.currency(exp.amount)).foregroundColor(NSNTheme.accentRed)
                            }
                        }
                    } else {
                        ForEach(revenues) { rev in
                            HStack {
                                Text(rev.resolvedCropName).fontWeight(.bold)
                                Spacer()
                                Text(NSNFormatters.currency(rev.totalAmount)).foregroundColor(NSNTheme.forestGreen)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Transactions")
            .toolbar {
                Button {
                    if selectedSegment == 0 { showAddExpense = true } else { showAddRevenue = true }
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }
            .sheet(isPresented: $showAddExpense) { AddExpenseView() }
            .sheet(isPresented: $showAddRevenue) { AddRevenueView() }
        }
    }
}

struct AddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var crops: [CropMaster]
    @Query private var categories: [ExpenseMaster]
    
    @State private var amount = ""
    @State private var selectedCat: ExpenseMaster?
    @State private var selectedCrop: CropMaster?
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $selectedCat) {
                    ForEach(categories) { cat in Text(cat.categoryName).tag(cat as ExpenseMaster?) }
                }
                Picker("Crop", selection: $selectedCrop) {
                    Text("General Overhead").tag(nil as CropMaster?)
                    ForEach(crops) { crop in Text(crop.cropName).tag(crop as CropMaster?) }
                }
                TextField("Amount (₹)", text: $amount).keyboardType(.decimalPad)
            }
            .navigationTitle("Add Expense")
            .toolbar {
                Button("Save") {
                    if let cat = selectedCat, let amt = Double(amount) {
                        modelContext.insert(FarmExpense(expenseCategory: cat, crop: selectedCrop, amount: amt))
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddRevenueView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var crops: [CropMaster]
    @Query private var buyers: [RevenueMaster]
    
    @State private var amount = ""
    @State private var selectedCrop: CropMaster?
    @State private var selectedBuyer: RevenueMaster?
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("Crop", selection: $selectedCrop) {
                    Text("Select Crop").tag(nil as CropMaster?)
                    ForEach(crops) { crop in Text(crop.cropName).tag(crop as CropMaster?) }
                }
                TextField("Total Amount (₹)", text: $amount).keyboardType(.decimalPad)
            }
            .navigationTitle("Add Revenue")
            .toolbar {
                Button("Save") {
                    if let crop = selectedCrop, let amt = Double(amount) {
                        modelContext.insert(FarmRevenue(crop: crop, quantity: 1, ratePerUnit: amt, totalAmountOverride: amt))
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
NSN_Farms_Views_Part_1.swift
Displaying NSN_Farms_App_Entry_Point.swift.

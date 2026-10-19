


import SwiftUI
import SwiftData

struct PayrollTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EmployeeMaster.name) private var employees: [EmployeeMaster]
    private let engine = ERPCalculationEngine()
    @State private var attendanceRecords: [SeasonalAttendance] = []
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(attendanceRecords) { rec in
                    HStack {
                        Text(rec.workerNameSnapshot).fontWeight(.bold)
                        Spacer()
                        Text(NSNFormatters.currency(rec.calculatedWageForDay))
                    }
                }
            }
            .navigationTitle("Payroll & Attendance")
            .onAppear {
                attendanceRecords = (try? engine.fetchOrPrepareDailyAttendance(for: .now, defaultCrop: nil, context: modelContext)) ?? []
            }
        }
    }
}

struct ReportsTabView: View {
    @Environment(\.modelContext) private var modelContext
    private let engine = ERPCalculationEngine()
    @State private var report: FarmPnLSummaryReport?
    @State private var showExport = false
    @State private var fileURL: URL?
    
    var body: some View {
        NavigationStack {
            List {
                if let report {
                    ForEach(report.cropRows) { row in
                        HStack {
                            Text(row.cropName).fontWeight(.bold)
                            Spacer()
                            Text(NSNFormatters.currency(row.grossMargin))
                                .foregroundColor(row.grossMargin >= 0 ? .green : .red)
                        }
                    }
                }
            }
            .navigationTitle("Crop P&L Reports")
            .toolbar {
                Button("Export PDF") {
                    if let report, let bs = try? engine.generateBalanceSheet(asOf: .now, context: modelContext) {
                        fileURL = try? ReportExporter.exportExecutiveFinancialPDF(pnl: report, balanceSheet: bs)
                        showExport = true
                    }
                }
            }
            .sheet(isPresented: $showExport) {
                if let fileURL { ShareSheet(activityItems: [fileURL]) }
            }
            .onAppear {
                report = try? engine.generateCropWisePnLReport(from: .distantPast, to: .distantFuture, context: modelContext)
            }
        }
    }
}

struct MastersTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(BackupManager.self) private var backupManager
    @Query private var crops: [CropMaster]
    @State private var showExporter = false
    @State private var fileDoc = NSNBackupFileDocument()
    
    var body: some View {
        NavigationStack {
            List {
                Section("Offline Backup") {
                    Button("Export JSON Backup") {
                        if let data = try? backupManager.createBackupData(context: modelContext) {
                            fileDoc = NSNBackupFileDocument(jsonData: data)
                            showExporter = true
                        }
                    }
                }
                Section("Crops") {
                    ForEach(crops) { crop in Text(crop.cropName) }
                }
                Section("Demo Data") {
                    Button("Load Sample Data") {
                        DataSeeder.seedSampleTransactions(context: modelContext)
                    }
                }
            }
            .navigationTitle("Masters & Backup")
            .fileExporter(isPresented: $showExporter, document: fileDoc, contentType: .json, defaultFilename: backupManager.defaultBackupFilename()) { _ in }
        }
    }
}
NSN_Farms_Views_Part_2.swift
Displaying NSN_Farms_App_Entry_Point.swift.

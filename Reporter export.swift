


import Foundation
import UIKit

@MainActor
enum ReportExporter {
    private static func escapeCSV(_ field: String) -> String {
        let cleaned = field.replacingOccurrences(of: "\"", with: "\"\"")
        if cleaned.contains(",") || cleaned.contains("\"") || cleaned.contains("\n") {
            return "\"\(cleaned)\""
        }
        return cleaned
    }
    
    private static func writeCSVToTemporaryFile(csvContent: String, fileName: String) throws -> URL {
        let bomPrefixedContent = "\u{FEFF}" + csvContent
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        guard let data = bomPrefixedContent.data(using: .utf8) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url, options: .atomic)
        return url
    }
    
    static func exportCropPnLAndBalanceSheetCSV(pnl: FarmPnLSummaryReport, balanceSheet: FarmBalanceSheetStatement) throws -> URL {
        var lines: [String] = []
        lines.append("NSN FARMS - P&L STATEMENT")
        lines.append("Crop Name,Total Revenue (INR),Total Cost (INR),Gross Margin (INR),ROI (%)")
        for row in pnl.cropRows {
            lines.append("\(escapeCSV(row.cropName)),\(row.totalRevenue),\(row.totalCost),\(row.grossMargin),\(row.roiPercentage)")
        }
        return try writeCSVToTemporaryFile(csvContent: lines.joined(separator: "\n"), fileName: "NSN_Farms_Report.csv")
    }
    
    static func exportExecutiveFinancialPDF(pnl: FarmPnLSummaryReport, balanceSheet: FarmBalanceSheetStatement) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            context.beginPage()
            let title = "NSN FARMS - EXECUTIVE STATEMENT"
            NSString(string: title).draw(at: CGPoint(x: 40, y: 40), withAttributes: [.font: UIFont.systemFont(ofSize: 18, weight: .bold)])
            let profitText = "Net Farm Profit: \(NSNFormatters.currency(pnl.netFarmProfit))"
            NSString(string: profitText).draw(at: CGPoint(x: 40, y: 80), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("NSN_Farms_Statement.pdf")
        try data.write(to: url, options: .atomic)
        return url
    }
}
NSN_Farms_Report_Exporter.swift
Displaying NSN_Farms_App_Entry_Point.swift.

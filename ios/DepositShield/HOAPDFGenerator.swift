import UIKit

/// HOA-specific PDFs — notice letters, the Consistency Ledger summary, and
/// inspection reports — built on the same primitives as PDFReportGenerator
/// (same A4 page size, same Ledger palette) so every document in the app
/// feels like one family.
struct LedgerCategoryStat {
    var category: String
    var opened: Int
    var noticesSent: Int
    var resolved: Int
    var avgDaysToResolution: Double?
}

struct InspectionReportEntry {
    var areaName: String
    var performedAt: String
    var condition: InspectionCondition
    var notes: String?
    var photos: [ReportPhotoData]
}

enum HOAPDFGenerator {
    private static var pageSize: CGSize { PDFReportGenerator.pageSize }
    private static var margin: CGFloat { PDFReportGenerator.margin }

    // MARK: Violation notice

    static func noticePDF(kind: ViolationEventKind, association: Association, violation: Violation, photos: [ReportPhotoData], fineAmountCents: Int?, cureDeadlineDays: Int, note: String?) -> Data {
        let evidencePages = photos.isEmpty ? 0 : estimatedPageCount(photoCount: photos.count)
        let totalPages = 1 + evidencePages
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            drawNoticeCover(ctx: ctx.cgContext, kind: kind, association: association, violation: violation, fineAmountCents: fineAmountCents, cureDeadlineDays: cureDeadlineDays, note: note, pageNumber: 1, totalPages: totalPages)

            var index = 0
            var page = 2
            while index < photos.count {
                ctx.beginPage()
                let bounds = CGRect(origin: .zero, size: pageSize)
                UIColor.white.setFill()
                ctx.cgContext.fill(bounds)
                let contentRect = bounds.insetBy(dx: margin, dy: margin)
                PDFReportGenerator.drawPageHeader(ctx: ctx.cgContext, title: "Photo evidence", subtitle: noticeLabel(kind), in: contentRect)
                let gridRect = CGRect(x: contentRect.minX, y: contentRect.minY + 34, width: contentRect.width, height: contentRect.height - 34 - 24)
                index = drawEvidenceGrid(ctx: ctx.cgContext, photos: photos, startIndex: index, contentRect: gridRect)
                PDFReportGenerator.drawFooter(ctx: ctx.cgContext, label: "\(association.name) \u{b7} Notice evidence", pageNumber: page, totalPages: totalPages, in: bounds)
                page += 1
            }
        }
    }

    private static func drawNoticeCover(ctx: CGContext, kind: ViolationEventKind, association: Association, violation: Violation, fineAmountCents: Int?, cureDeadlineDays: Int, note: String?, pageNumber: Int, totalPages: Int) {
        let bounds = CGRect(origin: .zero, size: pageSize)
        PDFPalette.ink.setFill()
        ctx.fill(bounds)

        let contentRect = bounds.insetBy(dx: 48, dy: 48)
        var y = contentRect.minY

        PDFReportGenerator.drawSeal(ctx: ctx, center: CGPoint(x: contentRect.minX + 11, y: y + 11), radius: 11, color: PDFPalette.brass)
        PDFReportGenerator.draw(text: association.name, font: PDFFont.serif(14), color: .white, in: CGRect(x: contentRect.minX + 30, y: y, width: contentRect.width - 30, height: 20))
        y += 60

        PDFReportGenerator.draw(text: noticeLabel(kind).uppercased(), font: PDFFont.sans(10, weight: .semibold), color: PDFPalette.brass, tracking: 2, in: CGRect(x: contentRect.minX, y: y, width: contentRect.width, height: 16))
        y += 26
        PDFReportGenerator.draw(text: violation.unit_label ?? violation.address ?? "Unit on file", font: PDFFont.serif(28), color: .white, in: CGRect(x: contentRect.minX, y: y, width: contentRect.width, height: 36))
        y += 46

        ctx.setStrokeColor(UIColor(red: 0.16, green: 0.21, blue: 0.31, alpha: 1).cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: contentRect.minX, y: y))
        ctx.addLine(to: CGPoint(x: contentRect.minX + 340, y: y))
        ctx.strokePath()
        y += 20

        func row(_ label: String, _ value: String) {
            PDFReportGenerator.draw(text: label, font: PDFFont.sans(10), color: UIColor(white: 0.6, alpha: 1), in: CGRect(x: contentRect.minX, y: y, width: 140, height: 14))
            PDFReportGenerator.draw(text: value, font: PDFFont.mono(9), color: .white, alignment: .right, in: CGRect(x: contentRect.minX + 140, y: y, width: 200, height: 14))
            y += 22
        }
        row("Category", violation.category)
        if let rule = violation.rule_reference, !rule.isEmpty { row("Rule reference", rule) }
        row("Opened", Formatters.dateTime(violation.opened_at))
        if let fine = fineAmountCents { row("Fine amount", Formatters.cents(fine)) }
        row("Deadline to cure", "\(cureDeadlineDays) days from this notice")

        y += 14
        if let description = violation.description, !description.isEmpty {
            y += PDFReportGenerator.drawParagraph(text: description, font: PDFFont.sans(10), color: UIColor(white: 0.88, alpha: 1), in: CGRect(x: contentRect.minX, y: y, width: contentRect.width, height: 70)) + 12
        }
        if let note, !note.isEmpty {
            y += PDFReportGenerator.drawParagraph(text: note, font: PDFFont.sans(10), color: UIColor(white: 0.88, alpha: 1), in: CGRect(x: contentRect.minX, y: y, width: contentRect.width, height: 70)) + 12
        }

        PDFReportGenerator.draw(text: "This notice is generated from a timestamped, hash-verified evidence record. \u{2014} Deposit Shield", font: PDFFont.sans(8), color: UIColor(white: 0.55, alpha: 1), wrapped: true, in: CGRect(x: contentRect.minX, y: contentRect.maxY - 24, width: contentRect.width, height: 24))
    }

    private static func noticeLabel(_ kind: ViolationEventKind) -> String {
        switch kind {
        case .courtesy_notice: return "Courtesy notice"
        case .warning: return "Warning notice"
        case .fine: return "Fine notice"
        case .resolved: return "Resolution notice"
        case .dismissed: return "Dismissal notice"
        case .comment: return "Notice"
        }
    }

    // MARK: Consistency Ledger summary

    static func ledgerSummaryPDF(association: Association, stats: [LedgerCategoryStat], generatedDate: String) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            let bounds = CGRect(origin: .zero, size: pageSize)
            UIColor.white.setFill()
            ctx.cgContext.fill(bounds)
            let contentRect = bounds.insetBy(dx: margin, dy: margin)

            PDFReportGenerator.draw(text: "CONSISTENCY LEDGER", font: PDFFont.sans(10, weight: .semibold), color: PDFPalette.brass, tracking: 2, in: CGRect(x: contentRect.minX, y: contentRect.minY, width: contentRect.width, height: 14))
            PDFReportGenerator.draw(text: association.name, font: PDFFont.serif(26), color: PDFPalette.ink, in: CGRect(x: contentRect.minX, y: contentRect.minY + 18, width: contentRect.width, height: 36))
            PDFReportGenerator.draw(text: "Even enforcement, documented. Generated \(generatedDate).", font: PDFFont.sans(10), color: PDFPalette.smallGray, in: CGRect(x: contentRect.minX, y: contentRect.minY + 54, width: contentRect.width, height: 14))

            var y = contentRect.minY + 84
            ctx.cgContext.setStrokeColor(PDFPalette.hairline.cgColor)
            ctx.cgContext.move(to: CGPoint(x: contentRect.minX, y: y))
            ctx.cgContext.addLine(to: CGPoint(x: contentRect.maxX, y: y))
            ctx.cgContext.strokePath()
            y += 16

            let columns: [(String, CGFloat)] = [("Category", 0.32), ("Opened", 0.14), ("Notices", 0.14), ("Resolved", 0.14), ("Avg days", 0.26)]
            var x = contentRect.minX
            for (label, widthFrac) in columns {
                PDFReportGenerator.draw(text: label.uppercased(), font: PDFFont.sans(8.5, weight: .semibold), color: PDFPalette.smallGray, tracking: 0.4, in: CGRect(x: x, y: y, width: contentRect.width * widthFrac, height: 12))
                x += contentRect.width * widthFrac
            }
            y += 18

            for stat in stats {
                x = contentRect.minX
                let rowValues = [stat.category, "\(stat.opened)", "\(stat.noticesSent)", "\(stat.resolved)", stat.avgDaysToResolution.map { String(format: "%.1f days", $0) } ?? "\u{2014}"]
                for (i, (_, widthFrac)) in columns.enumerated() {
                    PDFReportGenerator.draw(text: rowValues[i], font: i == 0 ? PDFFont.serif(11) : PDFFont.mono(10), color: PDFPalette.ink, in: CGRect(x: x, y: y, width: contentRect.width * widthFrac, height: 16))
                    x += contentRect.width * widthFrac
                }
                y += 22
                ctx.cgContext.setStrokeColor(PDFPalette.hairline.withAlphaComponent(0.6).cgColor)
                ctx.cgContext.move(to: CGPoint(x: contentRect.minX, y: y))
                ctx.cgContext.addLine(to: CGPoint(x: contentRect.maxX, y: y))
                ctx.cgContext.strokePath()
                y += 10
            }

            y += 10
            PDFReportGenerator.draw(text: "The defense against selective-enforcement claims is a consistent, timestamped record. This summary reflects every violation this association has logged in Deposit Shield.", font: PDFFont.sans(9), color: PDFPalette.smallGray, wrapped: true, in: CGRect(x: contentRect.minX, y: y, width: contentRect.width, height: 40))

            PDFReportGenerator.drawFooter(ctx: ctx.cgContext, label: "\(association.name) \u{b7} Consistency Ledger", pageNumber: 1, totalPages: 1, in: bounds)
        }
    }

    // MARK: Inspection report

    static func inspectionReportPDF(association: Association, title: String, entries: [InspectionReportEntry]) -> Data {
        var totalPages = 1
        for entry in entries { totalPages += entry.photos.isEmpty ? 0 : estimatedPageCount(photoCount: entry.photos.count) }

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { ctx in
            var pageNumber = 1
            ctx.beginPage()
            drawInspectionCover(ctx: ctx.cgContext, association: association, title: title, entries: entries, pageNumber: pageNumber, totalPages: totalPages)
            pageNumber += 1

            for entry in entries where !entry.photos.isEmpty {
                var index = 0
                while index < entry.photos.count {
                    ctx.beginPage()
                    let bounds = CGRect(origin: .zero, size: pageSize)
                    UIColor.white.setFill()
                    ctx.cgContext.fill(bounds)
                    let contentRect = bounds.insetBy(dx: margin, dy: margin)
                    PDFReportGenerator.drawPageHeader(ctx: ctx.cgContext, title: entry.areaName, subtitle: Formatters.dateTime(entry.performedAt), in: contentRect)
                    let gridRect = CGRect(x: contentRect.minX, y: contentRect.minY + 34, width: contentRect.width, height: contentRect.height - 34 - 24)
                    index = drawEvidenceGrid(ctx: ctx.cgContext, photos: entry.photos, startIndex: index, contentRect: gridRect)
                    PDFReportGenerator.drawFooter(ctx: ctx.cgContext, label: "\(association.name) \u{b7} Inspection", pageNumber: pageNumber, totalPages: totalPages, in: bounds)
                    pageNumber += 1
                }
            }
        }
    }

    private static func drawInspectionCover(ctx: CGContext, association: Association, title: String, entries: [InspectionReportEntry], pageNumber: Int, totalPages: Int) {
        let bounds = CGRect(origin: .zero, size: pageSize)
        UIColor.white.setFill()
        ctx.fill(bounds)
        let contentRect = bounds.insetBy(dx: margin, dy: margin)

        PDFReportGenerator.draw(text: "INSPECTION REPORT", font: PDFFont.sans(10, weight: .semibold), color: PDFPalette.brass, tracking: 2, in: CGRect(x: contentRect.minX, y: contentRect.minY, width: contentRect.width, height: 14))
        PDFReportGenerator.draw(text: title, font: PDFFont.serif(24), color: PDFPalette.ink, in: CGRect(x: contentRect.minX, y: contentRect.minY + 18, width: contentRect.width, height: 32))
        PDFReportGenerator.draw(text: association.name, font: PDFFont.sans(11), color: PDFPalette.smallGray, in: CGRect(x: contentRect.minX, y: contentRect.minY + 50, width: contentRect.width, height: 16))

        var y = contentRect.minY + 80
        for entry in entries {
            let conditionColor: UIColor = entry.condition == .good ? PDFPalette.emerald : (entry.condition == .fair ? PDFPalette.brass : PDFPalette.clay)
            PDFReportGenerator.draw(text: entry.areaName, font: PDFFont.serif(14), color: PDFPalette.ink, in: CGRect(x: contentRect.minX, y: y, width: contentRect.width * 0.5, height: 18))
            PDFReportGenerator.draw(text: entry.condition.label.uppercased(), font: PDFFont.sans(9, weight: .semibold), color: conditionColor, alignment: .right, in: CGRect(x: contentRect.minX + contentRect.width * 0.5, y: y, width: contentRect.width * 0.25, height: 14))
            PDFReportGenerator.draw(text: Formatters.dateTime(entry.performedAt), font: PDFFont.mono(9), color: PDFPalette.smallGray, alignment: .right, in: CGRect(x: contentRect.minX + contentRect.width * 0.75, y: y, width: contentRect.width * 0.25, height: 14))
            y += 20
            if let notes = entry.notes, !notes.isEmpty {
                y += PDFReportGenerator.drawParagraph(text: notes, font: PDFFont.sans(9.5), color: PDFPalette.ink, in: CGRect(x: contentRect.minX, y: y, width: contentRect.width, height: 40)) + 8
            }
            ctx.setStrokeColor(PDFPalette.hairline.cgColor)
            ctx.move(to: CGPoint(x: contentRect.minX, y: y))
            ctx.addLine(to: CGPoint(x: contentRect.maxX, y: y))
            ctx.strokePath()
            y += 14
            if y > contentRect.maxY - 40 { break }
        }

        PDFReportGenerator.drawFooter(ctx: ctx, label: "\(association.name) \u{b7} Inspection report", pageNumber: pageNumber, totalPages: totalPages, in: bounds)
    }

    // MARK: Shared evidence grid

    private static func estimatedPageCount(photoCount: Int) -> Int {
        max(1, Int(ceil(Double(photoCount) / 9.0)))
    }

    /// Draws as many photos as fit starting at `startIndex`; returns the next
    /// index to resume from (== photos.count when finished).
    @discardableResult
    private static func drawEvidenceGrid(ctx: CGContext, photos: [ReportPhotoData], startIndex: Int, contentRect: CGRect) -> Int {
        let columns = 3
        let gap: CGFloat = 10
        let cardWidth = (contentRect.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let imageHeight: CGFloat = 110
        let cardHeight: CGFloat = imageHeight + 40

        var i = startIndex
        var col = 0
        var row = 0
        while i < photos.count {
            let x = contentRect.minX + CGFloat(col) * (cardWidth + gap)
            let y = contentRect.minY + CGFloat(row) * (cardHeight + 12)
            if y + cardHeight > contentRect.maxY { break }

            let photo = photos[i]
            let cardRect = CGRect(x: x, y: y, width: cardWidth, height: cardHeight)
            ctx.setStrokeColor(UIColor(white: 0.9, alpha: 1).cgColor)
            ctx.setLineWidth(1)
            ctx.stroke(cardRect)

            let imageRect = CGRect(x: cardRect.minX + 4, y: cardRect.minY + 4, width: cardRect.width - 8, height: imageHeight)
            if let image = photo.image {
                PDFReportGenerator.drawAspectFilled(image: image, in: imageRect, ctx: ctx)
            } else {
                UIColor(white: 0.93, alpha: 1).setFill()
                ctx.fill(imageRect)
            }

            var ty = imageRect.maxY + 4
            PDFReportGenerator.draw(text: photo.capturedAt, font: PDFFont.sans(7.5), color: PDFPalette.ink, in: CGRect(x: cardRect.minX + 4, y: ty, width: cardRect.width - 8, height: 10))
            ty += 11
            if let note = photo.note, !note.isEmpty {
                PDFReportGenerator.draw(text: note, font: PDFFont.sans(7.5), color: PDFPalette.ink, in: CGRect(x: cardRect.minX + 4, y: ty, width: cardRect.width - 8, height: 10))
                ty += 11
            }
            PDFReportGenerator.draw(text: "\(photo.sha256.prefix(14))\u{2026}", font: PDFFont.mono(6.5), color: PDFPalette.footerGray, in: CGRect(x: cardRect.minX + 4, y: ty, width: cardRect.width - 8, height: 10))

            col += 1
            if col == columns { col = 0; row += 1 }
            i += 1
        }
        return i
    }
}

import UIKit

// Ports src/lib/pdf/*.tsx (react-pdf) to native UIGraphicsPDFRenderer output —
// same page set, same palette, same copy, drawn with Core Graphics instead of
// a headless browser renderer.

struct ReportPhotoData {
    var image: UIImage?
    var capturedAt: String
    var condition: PhotoCondition
    var note: String?
    var sha256: String
}

struct ReportRoomData {
    var name: String
    var photos: [ReportPhotoData]
}

struct ReportPropertyInfo {
    var displayName: String
    var addressLines: [String]
    var tenantEmail: String
    var depositAmountLabel: String
    var dateLabel: String
    var stateName: String?
    var stateDeadlineDays: Int?
}

enum PDFPalette {
    static let ink = UIColor(red: 0x0B/255, green: 0x12/255, blue: 0x20/255, alpha: 1)
    static let brass = UIColor(red: 0xB0/255, green: 0x8D/255, blue: 0x4C/255, alpha: 1)
    static let emerald = UIColor(red: 0x0E/255, green: 0x9F/255, blue: 0x6E/255, alpha: 1)
    static let clay = UIColor(red: 0xC4/255, green: 0x55/255, blue: 0x3B/255, alpha: 1)
    static let paper = UIColor(red: 0xFA/255, green: 0xF7/255, blue: 0xF2/255, alpha: 1)
    static let mutedOnInk = UIColor(white: 1, alpha: 0.55)
    static let hairline = UIColor(red: 0xD8/255, green: 0xDB/255, blue: 0xE2/255, alpha: 1)
    static let footerGray = UIColor(red: 0x90/255, green: 0x99/255, blue: 0xA6/255, alpha: 1)
    static let smallGray = UIColor(red: 0x5B/255, green: 0x64/255, blue: 0x72/255, alpha: 1)
}

enum PDFFont {
    static func serif(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
    static func mono(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.monospaced) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
    static func sans(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        .systemFont(ofSize: size, weight: weight)
    }
}

enum PDFReportGenerator {
    static let pageSize = CGSize(width: 595, height: 842) // A4 @ 72dpi
    static let margin: CGFloat = 40

    // MARK: Condition report (move-in / move-out)

    static func conditionReportPDF(title: String, phaseLabel: String, property: ReportPropertyInfo, rooms: [ReportRoomData], watermark: Bool) -> Data {
        let totalPages = 1 + rooms.count + 2
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { ctx in
            var pageNumber = 1
            ctx.beginPage()
            drawCoverPage(ctx: ctx.cgContext, title: title, property: property, watermark: watermark)
            pageNumber += 1

            for room in rooms {
                ctx.beginPage()
                drawRoomPage(ctx: ctx.cgContext, room: room, phaseLabel: phaseLabel, watermark: watermark, pageNumber: pageNumber, totalPages: totalPages)
                pageNumber += 1
            }

            ctx.beginPage()
            drawIntegrityAppendixPage(ctx: ctx.cgContext, label: phaseLabel, pageNumber: pageNumber, totalPages: totalPages)
            pageNumber += 1

            ctx.beginPage()
            drawSignaturePage(ctx: ctx.cgContext, label: phaseLabel, pageNumber: pageNumber, totalPages: totalPages)
        }
    }

    // MARK: Evidence packet

    static func evidencePacketPDF(
        property: ReportPropertyInfo,
        moveInRooms: [ReportRoomData],
        moveOutRooms: [ReportRoomData],
        stateName: String,
        deadlineDays: Int,
        itemizedRequired: Bool,
        smallClaimsLimit: String,
        deadlineDateLabel: String?,
        letterLines: [String],
        checklistItems: [String]
    ) -> Data {
        let totalPages = 1 + moveInRooms.count + moveOutRooms.count + 1 + 1 + 1 + 1 + 1
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { ctx in
            var pageNumber = 1
            ctx.beginPage()
            drawCoverPage(ctx: ctx.cgContext, title: "Evidence packet", property: property, watermark: false)
            pageNumber += 1

            for room in moveInRooms {
                ctx.beginPage()
                drawRoomPage(ctx: ctx.cgContext, room: room, phaseLabel: "Move-in", watermark: false, pageNumber: pageNumber, totalPages: totalPages)
                pageNumber += 1
            }
            for room in moveOutRooms {
                ctx.beginPage()
                drawRoomPage(ctx: ctx.cgContext, room: room, phaseLabel: "Move-out", watermark: false, pageNumber: pageNumber, totalPages: totalPages)
                pageNumber += 1
            }

            ctx.beginPage()
            drawStateDeadlinePage(ctx: ctx.cgContext, stateName: stateName, deadlineDays: deadlineDays, itemizedRequired: itemizedRequired, smallClaimsLimit: smallClaimsLimit, deadlineDateLabel: deadlineDateLabel, pageNumber: pageNumber, totalPages: totalPages)
            pageNumber += 1

            ctx.beginPage()
            drawDemandLetterPage(ctx: ctx.cgContext, lines: letterLines, pageNumber: pageNumber, totalPages: totalPages)
            pageNumber += 1

            ctx.beginPage()
            drawSmallClaimsChecklistPage(ctx: ctx.cgContext, items: checklistItems, pageNumber: pageNumber, totalPages: totalPages)
            pageNumber += 1

            ctx.beginPage()
            drawIntegrityAppendixPage(ctx: ctx.cgContext, label: "Evidence packet", pageNumber: pageNumber, totalPages: totalPages)
            pageNumber += 1

            ctx.beginPage()
            drawSignaturePage(ctx: ctx.cgContext, label: "Evidence packet", pageNumber: pageNumber, totalPages: totalPages)
        }
    }

    // MARK: - Page drawing

    private static func drawCoverPage(ctx: CGContext, title: String, property: ReportPropertyInfo, watermark: Bool) {
        let bounds = CGRect(origin: .zero, size: pageSize)
        PDFPalette.ink.setFill()
        ctx.fill(bounds)

        if watermark { drawWatermark(ctx: ctx) }

        let contentRect = bounds.insetBy(dx: 48, dy: 48)
        var y = contentRect.minY

        // Seal + wordmark
        drawSeal(ctx: ctx, center: CGPoint(x: contentRect.minX + 11, y: y + 11), radius: 11, color: PDFPalette.brass)
        draw(text: "Deposit Shield", font: PDFFont.serif(14), color: .white, in: CGRect(x: contentRect.minX + 30, y: y, width: 220, height: 20))
        y += 60

        draw(text: title.uppercased(), font: PDFFont.sans(10, weight: .semibold), color: PDFPalette.brass, tracking: 2, in: CGRect(x: contentRect.minX, y: y, width: contentRect.width, height: 16))
        y += 26
        draw(text: property.displayName, font: PDFFont.serif(30), color: .white, in: CGRect(x: contentRect.minX, y: y, width: contentRect.width, height: 40))
        y += 42
        for line in property.addressLines {
            draw(text: line, font: PDFFont.sans(11), color: UIColor(white: 0.85, alpha: 1), in: CGRect(x: contentRect.minX, y: y, width: contentRect.width, height: 16))
            y += 18
        }

        y += 24
        ctx.setStrokeColor(UIColor(red: 0.16, green: 0.21, blue: 0.31, alpha: 1).cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: contentRect.minX, y: y))
        ctx.addLine(to: CGPoint(x: contentRect.minX + 320, y: y))
        ctx.strokePath()
        y += 20

        func row(_ label: String, _ value: String) {
            draw(text: label, font: PDFFont.sans(10), color: UIColor(white: 0.6, alpha: 1), in: CGRect(x: contentRect.minX, y: y, width: 140, height: 14))
            draw(text: value, font: PDFFont.mono(9), color: .white, alignment: .right, in: CGRect(x: contentRect.minX + 140, y: y, width: 180, height: 14))
            y += 22
        }
        row("Prepared for", property.tenantEmail)
        row("Date", property.dateLabel)
        row("Security deposit", property.depositAmountLabel)
        if let stateName = property.stateName, let days = property.stateDeadlineDays {
            row("Return deadline", "\(days) days after move-out (\(stateName))")
        }

        draw(text: "Generated by Deposit Shield. Documentation tool only \u{2014} not legal advice.", font: PDFFont.sans(8), color: UIColor(white: 0.55, alpha: 1), in: CGRect(x: contentRect.minX, y: contentRect.maxY - 14, width: contentRect.width, height: 14))
    }

    private static func drawRoomPage(ctx: CGContext, room: ReportRoomData, phaseLabel: String, watermark: Bool, pageNumber: Int, totalPages: Int) {
        let bounds = CGRect(origin: .zero, size: pageSize)
        UIColor.white.setFill()
        ctx.fill(bounds)
        if watermark { drawWatermark(ctx: ctx) }

        let contentRect = bounds.insetBy(dx: margin, dy: margin)
        drawPageHeader(ctx: ctx, title: room.name, subtitle: phaseLabel, in: contentRect)

        let y = contentRect.minY + 34
        if room.photos.isEmpty {
            draw(text: "No photos captured for this room.", font: PDFFont.sans(9), color: PDFPalette.smallGray, in: CGRect(x: contentRect.minX, y: y, width: contentRect.width, height: 14))
        } else {
            let columns = 3
            let gap: CGFloat = 10
            let cardWidth = (contentRect.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
            let imageHeight: CGFloat = 110
            let cardHeight: CGFloat = imageHeight + 58

            for (i, photo) in room.photos.enumerated() {
                let col = i % columns
                let rowIdx = i / columns
                let x = contentRect.minX + CGFloat(col) * (cardWidth + gap)
                let cardY = y + CGFloat(rowIdx) * (cardHeight + 12)
                if cardY + cardHeight > contentRect.maxY - 24 { break } // keep to one page, mirrors react-pdf `wrap` best-effort
                let cardRect = CGRect(x: x, y: cardY, width: cardWidth, height: cardHeight)

                ctx.setStrokeColor(UIColor(red: 0.89, green: 0.91, blue: 0.93, alpha: 1).cgColor)
                ctx.setLineWidth(1)
                ctx.stroke(cardRect)

                let imageRect = CGRect(x: cardRect.minX + 4, y: cardRect.minY + 4, width: cardRect.width - 8, height: imageHeight)
                if let image = photo.image {
                    drawAspectFilled(image: image, in: imageRect, ctx: ctx)
                } else {
                    UIColor(white: 0.93, alpha: 1).setFill()
                    ctx.fill(imageRect)
                }

                var ty = imageRect.maxY + 4
                draw(text: photo.capturedAt, font: PDFFont.sans(8), color: PDFPalette.ink, in: CGRect(x: cardRect.minX + 4, y: ty, width: cardRect.width - 8, height: 10))
                ty += 11
                draw(text: "Condition: \(photo.condition.label)", font: PDFFont.sans(8), color: PDFPalette.ink, in: CGRect(x: cardRect.minX + 4, y: ty, width: cardRect.width - 8, height: 10))
                ty += 11
                if let note = photo.note, !note.isEmpty {
                    draw(text: note, font: PDFFont.sans(8), color: PDFPalette.ink, in: CGRect(x: cardRect.minX + 4, y: ty, width: cardRect.width - 8, height: 10))
                    ty += 11
                }
                draw(text: "\(photo.sha256.prefix(16))\u{2026}", font: PDFFont.mono(6.5), color: PDFPalette.footerGray, in: CGRect(x: cardRect.minX + 4, y: ty, width: cardRect.width - 8, height: 10))
            }
        }

        drawFooter(ctx: ctx, label: "Deposit Shield \u{b7} \(phaseLabel)", pageNumber: pageNumber, totalPages: totalPages, in: bounds)
    }

    private static func drawIntegrityAppendixPage(ctx: CGContext, label: String, pageNumber: Int, totalPages: Int) {
        let bounds = CGRect(origin: .zero, size: pageSize)
        UIColor.white.setFill()
        ctx.fill(bounds)
        let contentRect = bounds.insetBy(dx: margin, dy: margin)
        drawPageHeader(ctx: ctx, title: "Integrity appendix", subtitle: label, in: contentRect)

        var y = contentRect.minY + 40
        let paragraphs = [
            "Every photo in this report was fingerprinted the moment it was captured, using a cryptographic function called SHA-256. Think of it as a tamper-evident seal: the fingerprint is calculated from the exact bytes of the photo, so if even a single pixel changed after capture, the fingerprint would be completely different.",
            "Each photo page in this report shows a truncated version of that fingerprint beneath the image. The full fingerprint is stored alongside the capture timestamp at the moment the photo was taken, before it was uploaded anywhere \u{2014} this is what makes the record trustworthy as evidence, rather than just a photo album.",
            "If a landlord or a court disputes the authenticity of a photo, the original file can be re-hashed and compared against the fingerprint recorded at capture time to confirm nothing has been altered.",
        ]
        for p in paragraphs {
            let h = drawParagraph(text: p, font: PDFFont.sans(10), color: PDFPalette.ink, in: CGRect(x: contentRect.minX, y: y, width: contentRect.width, height: 80))
            y += h + 10
        }

        ctx.setStrokeColor(PDFPalette.hairline.cgColor)
        ctx.move(to: CGPoint(x: contentRect.minX, y: y + 2))
        ctx.addLine(to: CGPoint(x: contentRect.maxX, y: y + 2))
        ctx.strokePath()
        y += 14

        draw(text: "This report is a documentation aid. It does not constitute legal advice, and Deposit Shield is not a law firm. Consult your state housing authority or an attorney for guidance specific to your situation.", font: PDFFont.sans(9), color: PDFPalette.smallGray, wrapped: true, in: CGRect(x: contentRect.minX, y: y, width: contentRect.width, height: 40))

        drawFooter(ctx: ctx, label: "Deposit Shield \u{b7} Integrity appendix", pageNumber: pageNumber, totalPages: totalPages, in: bounds)
    }

    private static func drawSignaturePage(ctx: CGContext, label: String, pageNumber: Int, totalPages: Int) {
        let bounds = CGRect(origin: .zero, size: pageSize)
        UIColor.white.setFill()
        ctx.fill(bounds)
        let contentRect = bounds.insetBy(dx: margin, dy: margin)
        drawPageHeader(ctx: ctx, title: "Acknowledgment", subtitle: label, in: contentRect)

        var y = contentRect.minY + 40
        let h = drawParagraph(text: "The undersigned confirms that the photographs and notes in this report accurately reflect the condition of the property on the date indicated above.", font: PDFFont.sans(10), color: PDFPalette.ink, in: CGRect(x: contentRect.minX, y: y, width: contentRect.width, height: 40))
        y += h + 50

        func signatureLine(_ label: String) {
            ctx.setStrokeColor(PDFPalette.ink.cgColor)
            ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: contentRect.minX, y: y + 40))
            ctx.addLine(to: CGPoint(x: contentRect.maxX, y: y + 40))
            ctx.strokePath()
            draw(text: label, font: PDFFont.sans(8), color: PDFPalette.smallGray, in: CGRect(x: contentRect.minX, y: y + 44, width: 300, height: 12))
            draw(text: "Date: ______________", font: PDFFont.sans(8), color: PDFPalette.smallGray, alignment: .right, in: CGRect(x: contentRect.maxX - 200, y: y + 44, width: 200, height: 12))
            y += 76
        }
        signatureLine("Tenant signature")
        signatureLine("Landlord / property manager signature (optional)")

        drawFooter(ctx: ctx, label: "Deposit Shield \u{b7} Acknowledgment", pageNumber: pageNumber, totalPages: totalPages, in: bounds)
    }

    private static func drawStateDeadlinePage(ctx: CGContext, stateName: String, deadlineDays: Int, itemizedRequired: Bool, smallClaimsLimit: String, deadlineDateLabel: String?, pageNumber: Int, totalPages: Int) {
        let bounds = CGRect(origin: .zero, size: pageSize)
        UIColor.white.setFill()
        ctx.fill(bounds)
        let contentRect = bounds.insetBy(dx: margin, dy: margin)
        drawPageHeader(ctx: ctx, title: "\(stateName) deposit return rules", subtitle: "Evidence packet", in: contentRect)

        var y = contentRect.minY + 40
        let deadlineSuffix = deadlineDateLabel.map { ", which in this case is on or before \($0)" } ?? ""
        let deadlineText = "In \(stateName), landlords generally must return a tenant's security deposit within \(deadlineDays) days of move-out\(deadlineSuffix)."
        y += drawParagraph(text: deadlineText, font: PDFFont.sans(10), color: PDFPalette.ink, in: CGRect(x: contentRect.minX, y: y, width: contentRect.width, height: 60)) + 10

        if itemizedRequired {
            y += drawParagraph(text: "An itemized statement of any deductions is generally required alongside the returned portion of the deposit.", font: PDFFont.sans(10), color: PDFPalette.ink, in: CGRect(x: contentRect.minX, y: y, width: contentRect.width, height: 40)) + 10
        }

        y += drawParagraph(text: "The small-claims court limit in this state is approximately \(smallClaimsLimit), which is typically the venue used to recover a wrongfully withheld deposit without hiring an attorney.", font: PDFFont.sans(10), color: PDFPalette.ink, in: CGRect(x: contentRect.minX, y: y, width: contentRect.width, height: 40)) + 14

        ctx.setStrokeColor(PDFPalette.hairline.cgColor)
        ctx.move(to: CGPoint(x: contentRect.minX, y: y))
        ctx.addLine(to: CGPoint(x: contentRect.maxX, y: y))
        ctx.strokePath()
        y += 14
        draw(text: "General guidance only, reviewed periodically \u{2014} not legal advice. Confirm current rules with your state housing authority or an attorney before relying on them.", font: PDFFont.sans(9), color: PDFPalette.smallGray, wrapped: true, in: CGRect(x: contentRect.minX, y: y, width: contentRect.width, height: 40))

        drawFooter(ctx: ctx, label: "Deposit Shield \u{b7} State deadline", pageNumber: pageNumber, totalPages: totalPages, in: bounds)
    }

    private static func drawDemandLetterPage(ctx: CGContext, lines: [String], pageNumber: Int, totalPages: Int) {
        let bounds = CGRect(origin: .zero, size: pageSize)
        UIColor.white.setFill()
        ctx.fill(bounds)
        let contentRect = bounds.insetBy(dx: margin, dy: margin)
        drawPageHeader(ctx: ctx, title: "Demand letter (draft)", subtitle: "Evidence packet", in: contentRect)

        var y = contentRect.minY + 34
        for line in lines {
            if line.isEmpty { y += 10; continue }
            y += drawParagraph(text: line, font: PDFFont.sans(10), color: PDFPalette.ink, in: CGRect(x: contentRect.minX, y: y, width: contentRect.width, height: 60)) + 8
        }

        drawFooter(ctx: ctx, label: "Deposit Shield \u{b7} Demand letter", pageNumber: pageNumber, totalPages: totalPages, in: bounds)
    }

    private static func drawSmallClaimsChecklistPage(ctx: CGContext, items: [String], pageNumber: Int, totalPages: Int) {
        let bounds = CGRect(origin: .zero, size: pageSize)
        UIColor.white.setFill()
        ctx.fill(bounds)
        let contentRect = bounds.insetBy(dx: margin, dy: margin)
        drawPageHeader(ctx: ctx, title: "Small-claims checklist", subtitle: "Evidence packet", in: contentRect)

        var y = contentRect.minY + 34
        for item in items {
            draw(text: "\u{2610}", font: PDFFont.sans(10), color: PDFPalette.ink, in: CGRect(x: contentRect.minX, y: y, width: 16, height: 14))
            let h = drawParagraph(text: item, font: PDFFont.sans(10), color: PDFPalette.ink, in: CGRect(x: contentRect.minX + 18, y: y, width: contentRect.width - 18, height: 50))
            y += max(h, 14) + 8
        }

        drawFooter(ctx: ctx, label: "Deposit Shield \u{b7} Small-claims checklist", pageNumber: pageNumber, totalPages: totalPages, in: bounds)
    }

    // MARK: - Primitives

    static func drawPageHeader(ctx: CGContext, title: String, subtitle: String, in contentRect: CGRect) {
        draw(text: title, font: PDFFont.serif(13), color: PDFPalette.ink, in: CGRect(x: contentRect.minX, y: contentRect.minY, width: contentRect.width * 0.7, height: 18))
        draw(text: subtitle, font: PDFFont.sans(8), color: PDFPalette.smallGray, alignment: .right, in: CGRect(x: contentRect.minX + contentRect.width * 0.5, y: contentRect.minY + 2, width: contentRect.width * 0.5, height: 14))
        ctx.setStrokeColor(PDFPalette.hairline.cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: contentRect.minX, y: contentRect.minY + 22))
        ctx.addLine(to: CGPoint(x: contentRect.maxX, y: contentRect.minY + 22))
        ctx.strokePath()
    }

    static func drawFooter(ctx: CGContext, label: String, pageNumber: Int, totalPages: Int, in bounds: CGRect) {
        let y = bounds.maxY - 34
        draw(text: label, font: PDFFont.sans(8), color: PDFPalette.footerGray, in: CGRect(x: margin, y: y, width: bounds.width / 2, height: 12))
        draw(text: "Page \(pageNumber) of \(totalPages)", font: PDFFont.sans(8), color: PDFPalette.footerGray, alignment: .right, in: CGRect(x: bounds.width / 2, y: y, width: bounds.width / 2 - margin, height: 12))
    }

    static func drawWatermark(ctx: CGContext) {
        ctx.saveGState()
        let text = "PREVIEW \u{2014} UNLOCK TO REMOVE"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: PDFFont.serif(40, weight: .bold),
            .foregroundColor: PDFPalette.clay.withAlphaComponent(0.2),
        ]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        let size = attributed.size()
        ctx.translateBy(x: pageSize.width / 2, y: pageSize.height / 2)
        ctx.rotate(by: -.pi / 7)
        attributed.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2))
        ctx.restoreGState()
    }

    static func drawSeal(ctx: CGContext, center: CGPoint, radius: CGFloat, color: UIColor) {
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(1.6)
        ctx.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        ctx.move(to: CGPoint(x: center.x - radius * 0.35, y: center.y))
        ctx.addLine(to: CGPoint(x: center.x - radius * 0.05, y: center.y + radius * 0.3))
        ctx.addLine(to: CGPoint(x: center.x + radius * 0.4, y: center.y - radius * 0.3))
        ctx.strokePath()
        ctx.restoreGState()
    }

    static func drawAspectFilled(image: UIImage, in rect: CGRect, ctx: CGContext) {
        ctx.saveGState()
        ctx.clip(to: rect)
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { ctx.restoreGState(); return }
        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(x: rect.midX - drawSize.width / 2, y: rect.midY - drawSize.height / 2)
        image.draw(in: CGRect(origin: origin, size: drawSize))
        ctx.restoreGState()
    }

    @discardableResult
    static func draw(text: String, font: UIFont, color: UIColor, tracking: CGFloat = 0, alignment: NSTextAlignment = .left, wrapped: Bool = false, in rect: CGRect) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = wrapped ? .byWordWrapping : .byTruncatingTail
        var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        if tracking > 0 { attrs[.kern] = tracking }
        let attributed = NSAttributedString(string: text, attributes: attrs)
        attributed.draw(in: rect)
        return rect.height
    }

    /// Draws word-wrapped body copy and returns the height actually used.
    @discardableResult
    static func drawParagraph(text: String, font: UIFont, color: UIColor, in rect: CGRect) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        let bounding = attributed.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil)
        attributed.draw(with: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: ceil(bounding.height) + 2), options: [.usesLineFragmentOrigin], context: nil)
        return ceil(bounding.height)
    }
}

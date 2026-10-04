import { jsPDF } from 'jspdf'
import autoTable from 'jspdf-autotable'
import {
  ANALYTICS_TABS,
  buildAnalyticsReportSections,
  type AnalyticsSnapshot,
  type AnalyticsTab,
  type ReportCell,
} from './analytics'
import { defaultDateRange, formatDateRangeLabel, type DateRange } from './analyticsOverview'

/** jsPDF core fonts only cover Latin-1, so dashes outside it would render as garbage. */
function pdfText(value: ReportCell): string {
  return String(value).replace(/\u2014/g, 'N/A').replace(/\u2013/g, '-')
}

const PDF_NAVY: [number, number, number] = [15, 23, 42]
const PDF_BLUE: [number, number, number] = [0, 82, 212]
const PDF_MUTED: [number, number, number] = [100, 116, 139]
const PDF_STRIPE: [number, number, number] = [248, 250, 252]
const PDF_BORDER: [number, number, number] = [226, 232, 240]

export function buildAnalyticsPdf(data: AnalyticsSnapshot, range?: DateRange, tab?: AnalyticsTab): jsPDF {
  const effectiveRange = range ?? defaultDateRange()
  const tabLabel = tab && tab !== 'overview' ? ANALYTICS_TABS.find((t) => t.id === tab)?.label : undefined
  const doc = new jsPDF({ unit: 'pt', format: 'a4' })
  const pageWidth = doc.internal.pageSize.getWidth()
  const pageHeight = doc.internal.pageSize.getHeight()
  const margin = 40

  doc.setFillColor(...PDF_NAVY)
  doc.rect(0, 0, pageWidth, 78, 'F')
  doc.setTextColor(255, 255, 255)
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(18)
  doc.text('ACCESS VisionCheck', margin, 36)
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(11)
  doc.text('Analytics Report', margin, 56)

  doc.setTextColor(...PDF_MUTED)
  doc.setFontSize(9)
  const meta = [
    `Period: ${pdfText(formatDateRangeLabel(effectiveRange))}`,
    `Generated: ${new Date().toLocaleString()}`,
    ...(tabLabel ? [`View: ${tabLabel}`] : []),
  ]
  doc.text(meta.join('    '), margin, 100)

  let cursorY = 120
  for (const section of buildAnalyticsReportSections(data, effectiveRange)) {
    if (section.rows.length === 0) continue
    if (cursorY > pageHeight - 110) {
      doc.addPage()
      cursorY = margin
    }
    doc.setTextColor(...PDF_NAVY)
    doc.setFont('helvetica', 'bold')
    doc.setFontSize(11)
    doc.text(section.title, margin, cursorY)

    autoTable(doc, {
      startY: cursorY + 6,
      margin: { left: margin, right: margin, bottom: 48 },
      head: [section.headers.map(pdfText)],
      body: section.rows.map((row) => row.map(pdfText)),
      theme: 'grid',
      styles: {
        font: 'helvetica',
        fontSize: 8.5,
        cellPadding: 4,
        textColor: PDF_NAVY,
        lineColor: PDF_BORDER,
        lineWidth: 0.5,
        overflow: 'linebreak',
      },
      headStyles: { fillColor: PDF_BLUE, textColor: 255, fontStyle: 'bold' },
      alternateRowStyles: { fillColor: PDF_STRIPE },
    })

    const last = (doc as unknown as { lastAutoTable?: { finalY: number } }).lastAutoTable
    cursorY = (last?.finalY ?? cursorY) + 26
  }

  const pageCount = doc.getNumberOfPages()
  for (let page = 1; page <= pageCount; page++) {
    doc.setPage(page)
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(8)
    doc.setTextColor(...PDF_MUTED)
    doc.text('ACCESS VisionCheck Analytics Report', margin, pageHeight - 24)
    doc.text(`Page ${page} of ${pageCount}`, pageWidth - margin, pageHeight - 24, { align: 'right' })
  }

  return doc
}

export function exportAnalyticsPdf(data: AnalyticsSnapshot, range: DateRange, tab?: AnalyticsTab) {
  const start = range.start.toISOString().slice(0, 10)
  const end = range.end.toISOString().slice(0, 10)
  const tabSuffix = tab && tab !== 'overview' ? `-${tab}` : ''
  buildAnalyticsPdf(data, range, tab).save(`access-analytics-${start}_to_${end}${tabSuffix}.pdf`)
}

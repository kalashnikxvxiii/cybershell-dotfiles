#include "sparklineitem.hpp"

#include <QPainter>
#include <QPainterPath>
#include <QLinearGradient>
#include <QFont>

SparklineItem::SparklineItem(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setAntialiasing(true);
}

void SparklineItem::paint(QPainter *painter) {
    const int w = static_cast<int>(width());
    const int h = static_cast<int>(height());
    if (w <= 0 || h <= 0) return;

    // Clip path with diagonal cut on bottom left
    if (m_cuts[0] > 0 || m_cuts[1] > 0
        || m_cuts[2] > 0 || m_cuts[3] > 0) {
        QPainterPath clip;
        clip.moveTo(m_cuts[0], 0);      // after TL cut
        clip.lineTo(w - m_cuts[1], 0);  // before TR cut
        clip.lineTo(w, m_cuts[1]);      // TR cut
        clip.lineTo(w, h - m_cuts[3]);  // before BR cut
        clip.lineTo(w - m_cuts[3], h);  // BR cut
        clip.lineTo(m_cuts[2], h);      // before BL cut
        clip.lineTo(0, h - m_cuts[2]);  // BL cut
        clip.lineTo(0, m_cuts[0]);      // TL cut
        clip.closeSubpath();
        painter->setClipPath(clip);
    }

    // Background
    painter->fillRect(0, 0, w, h, m_bgColor);

    // Header area
    const int headerH = 14;
    const int sparkMargin = 4;
    const int sparkX = sparkMargin;
    const int sparkY = headerH;
    const int sparkW = w - sparkMargin * 2;
    const int sparkH = h - headerH - sparkMargin;

    // Label (top-left)
    if (!m_label.isEmpty()) {
        QFont labelFont("Oxanium", 7);
        labelFont.setLetterSpacing(QFont::AbsoluteSpacing, 1);
        painter->setFont(labelFont);
        painter->setPen(m_labelColor);
        painter->drawText(4, 10, m_label);
    }

    // Value text (top-right)
    if (!m_valueText.isEmpty()) {
        QFont valueFont("Oxanium", 9);
        painter->setFont(valueFont);
        painter->setPen(m_valueColor);
        QRect textRect(0, 0, w - 4, 12);
        painter->drawText(textRect, Qt::AlignRight | Qt::AlignTop, m_valueText);
    }

    // Sparkline
    const int n = m_values.size();
    if (n < 2 || sparkW <= 0 || sparkH <= 0) return;

    // Build points
    QVector<QPointF> points(n);
    for (int i = 0; i < n; ++i) {
        qreal x = sparkX + (static_cast<qreal>(i) / (n - 1)) * sparkW;
        qreal y = sparkY + sparkH - (qMin(m_values[i], 100.0) / 100.0) * sparkH;
        points[i] = QPointF(x, y);
    }

    painter->save();
    painter->setClipRect(sparkX, sparkY, sparkW, sparkH, Qt::IntersectClip);

    // Gradient fill via QPainterPath
    QPainterPath fillPath;
    fillPath.moveTo(sparkX, sparkY + sparkH);
    for (int i = 0; i < n; ++i) fillPath.lineTo(points[i]);
    fillPath.lineTo(sparkX + sparkW, sparkY + sparkH);
    fillPath.closeSubpath();

    QLinearGradient grad(sparkX, sparkY, sparkX, sparkY + sparkH);
    QColor fillTop = m_lineColor;
    fillTop.setAlphaF(m_fillOpacity);
    grad.setColorAt(0, fillTop);
    grad.setColorAt(1, QColor(0, 0, 0, 0));
    painter->fillPath(fillPath, QBrush(grad));

    // Stroke line
    QPen pen(m_lineColor, m_lineWidth);
    pen.setCosmetic(true);
    painter->setPen(pen);
    painter->setBrush(Qt::NoBrush);
    painter->drawPolyline(points.constData(), points.size());

    painter->restore();

    // Cut border (follow the same path of the clip)
    if (m_strokeColor.alpha() > 0 && m_strokeWidth > 0) {
        painter->save();
        painter->setClipping(false);
        QPainterPath border;
        qreal tl = m_cuts[0], tr = m_cuts[1], bl = m_cuts[2], br = m_cuts[3];
        border.moveTo(tl, 0);
        border.lineTo(w - tr, 0);
        border.lineTo(w, tr);
        border.lineTo(w, h - br);
        border.lineTo(w - br, h);
        border.lineTo(bl, h);
        border.lineTo(0, h - bl);
        border.lineTo(0, tl);
        border.closeSubpath();
        painter->setPen(QPen(m_strokeColor, m_strokeWidth));
        painter->setBrush(Qt::NoBrush);
        painter->drawPath(border);
        painter->restore();
    }
}

// ── Setters ────────────────────────────────────────────────

void SparklineItem::setValues(const QList<qreal> &v) {
    if (m_values != v) { m_values = v; emit valuesChanged(); if (isVisible()) update(); }
}

void SparklineItem::setLineColor(const QColor &c) {
    if (m_lineColor != c) { m_lineColor = c; emit lineColorChanged(); update(); }
}

void SparklineItem::setLineWidth(qreal w) {
    if (!qFuzzyCompare(m_lineWidth, w)) { m_lineWidth = w; emit lineWidthChanged(); update(); }
}

void SparklineItem::setFillOpacity(qreal o) {
    if (!qFuzzyCompare(m_fillOpacity, o)) { m_fillOpacity = o; emit fillOpacityChanged(); update(); }
}

void SparklineItem::setLabel(const QString &s) {
    if (m_label != s) { m_label = s; emit labelChanged(); update(); }
}

void SparklineItem::setValueText(const QString &s) {
    if (m_valueText != s) { m_valueText = s; emit valueTextChanged(); update(); }
}

void SparklineItem::setValueColor(const QColor &c) {
    if (m_valueColor != c) { m_valueColor = c; emit valueColorChanged(); update(); }
}

void SparklineItem::setLabelColor(const QColor &c) {
    if (m_labelColor != c) { m_labelColor = c; emit labelColorChanged(); update(); }
}

void SparklineItem::setBgColor(const QColor &c) {
    if (m_bgColor != c) { m_bgColor = c; emit bgColorChanged(); update(); }
}

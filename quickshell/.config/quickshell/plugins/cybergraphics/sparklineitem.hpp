#pragma once

#include <QQuickPaintedItem>
#include <QColor>
#include <QList>

class SparklineItem : public QQuickPaintedItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QList<qreal> values READ values WRITE setValues NOTIFY valuesChanged)
    Q_PROPERTY(QColor lineColor READ lineColor WRITE setLineColor NOTIFY lineColorChanged)
    Q_PROPERTY(qreal lineWidth READ lineWidth WRITE setLineWidth NOTIFY lineWidthChanged)
    Q_PROPERTY(qreal fillOpacity READ fillOpacity WRITE setFillOpacity NOTIFY fillOpacityChanged)
    Q_PROPERTY(QString label READ label WRITE setLabel NOTIFY labelChanged)
    Q_PROPERTY(QString valueText READ valueText WRITE setValueText NOTIFY valueTextChanged)
    Q_PROPERTY(QColor valueColor READ valueColor WRITE setValueColor NOTIFY valueColorChanged)
    Q_PROPERTY(QColor labelColor READ labelColor WRITE setLabelColor NOTIFY labelColorChanged)
    Q_PROPERTY(QColor bgColor READ bgColor WRITE setBgColor NOTIFY bgColorChanged)
    Q_PROPERTY(qreal cutTopLeft READ cutTopLeft WRITE setCutTopLeft NOTIFY cutChanged)
    Q_PROPERTY(qreal cutTopRight READ cutTopRight WRITE setCutTopRight NOTIFY cutChanged)
    Q_PROPERTY(qreal cutBottomLeft READ cutBottomLeft WRITE setCutBottomLeft NOTIFY cutChanged)
    Q_PROPERTY(qreal cutBottomRight READ cutBottomRight WRITE setCutBottomRight NOTIFY cutChanged)
    Q_PROPERTY(QColor strokeColor READ strokeColor WRITE setStrokeColor NOTIFY strokeChanged)
    Q_PROPERTY(qreal strokeWidth READ strokeWidth WRITE setStrokeWidth NOTIFY strokeChanged)

public:
    explicit SparklineItem(QQuickItem *parent = nullptr);

    void paint(QPainter *painter) override;

    QList<qreal> values() const { return m_values; }
    void setValues(const QList<qreal> &v);

    QColor lineColor() const { return m_lineColor; }
    void setLineColor(const QColor &c);

    qreal lineWidth() const { return m_lineWidth; }
    void setLineWidth(qreal w);

    qreal fillOpacity() const { return m_fillOpacity; }
    void setFillOpacity(qreal o);

    QString label() const { return m_label; }
    void setLabel(const QString &s);

    QString valueText() const { return m_valueText; }
    void setValueText(const QString &s);

    QColor valueColor() const { return m_valueColor; }
    void setValueColor(const QColor &c);

    QColor labelColor() const { return m_labelColor; }
    void setLabelColor(const QColor &c);

    QColor bgColor() const { return m_bgColor; }
    void setBgColor(const QColor &c);

    qreal cutTopLeft() const { return m_cuts[0]; }
    void setCutTopLeft(qreal v) { if (!qFuzzyCompare(m_cuts[0], v)) { m_cuts[0] = v; emit cutChanged(); update(); } }
    qreal cutTopRight() const { return m_cuts[1]; }
    void setCutTopRight(qreal v) { if (!qFuzzyCompare(m_cuts[1], v)) { m_cuts[1] = v; emit cutChanged(); update(); } }
    qreal cutBottomLeft() const { return m_cuts[2]; }
    void setCutBottomLeft(qreal v) { if (!qFuzzyCompare(m_cuts[2], v)) { m_cuts[2] = v; emit cutChanged(); update(); } }
    qreal cutBottomRight() const { return m_cuts[3]; }
    void setCutBottomRight(qreal v) { if (!qFuzzyCompare(m_cuts[3], v)) { m_cuts[3] = v; emit cutChanged(); update(); }}

    QColor strokeColor() const { return m_strokeColor; }
    void setStrokeColor(const QColor &c) { if (m_strokeColor != c) { m_strokeColor = c; emit strokeChanged(); update(); } }
    qreal strokeWidth() const { return m_strokeWidth; }
    void setStrokeWidth(qreal w) { if (!qFuzzyCompare(m_strokeWidth, w)) { m_strokeWidth = w; emit strokeChanged(); update(); } }

signals:
    void valuesChanged();
    void lineColorChanged();
    void lineWidthChanged();
    void fillOpacityChanged();
    void labelChanged();
    void valueTextChanged();
    void valueColorChanged();
    void labelColorChanged();
    void bgColorChanged();
    void cutChanged();
    void strokeChanged();

private:
    QList<qreal> m_values;
    QColor m_lineColor{0, 255, 210};
    qreal m_lineWidth{1.5};
    qreal m_fillOpacity{0.2};
    QString m_label;
    QString m_valueText;
    QColor m_valueColor{255, 255, 255};
    QColor m_labelColor{255, 255, 255, 100};
    QColor m_bgColor{0, 0, 0, 77};
    qreal m_cuts[4]{0, 0, 0, 0};    // TL, TR, BL, BR
    QColor m_strokeColor{Qt::transparent};
    qreal m_strokeWidth{1.0};
};
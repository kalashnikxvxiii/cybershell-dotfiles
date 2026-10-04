#pragma once

#include <QColor>
#include <QFutureWatcher>
#include <QImage>
#include <QPointer>
#include <QQuickItem>
#include <QRectF>
#include <QString>

// Asynchronous dominant-colour / luminance extraction from an image.
// The source is either a file path (or file:// URL) or a live QML Item,
// which is grabbed to an image before analysis. Work runs on a Qt Concurrent
// thread; results land back on the GUI thread through the future watcher.
class ImageAnalyser : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(QQuickItem *sourceItem READ sourceItem WRITE setSourceItem NOTIFY sourceItemChanged)
    Q_PROPERTY(int rescaleSize READ rescaleSize WRITE setRescaleSize NOTIFY rescaleSizeChanged)
    Q_PROPERTY(QRectF sampleRect READ sampleRect WRITE setSampleRect NOTIFY sampleRectChanged)
    Q_PROPERTY(QColor dominantColour READ dominantColour NOTIFY dominantColourChanged)
    Q_PROPERTY(qreal luminance READ luminance NOTIFY luminanceChanged)

public:
    explicit ImageAnalyser(QObject *parent = nullptr);

    QString source() const { return m_source; }
    void setSource(const QString &source);

    QQuickItem *sourceItem() const { return m_sourceItem; }
    void setSourceItem(QQuickItem *sourceItem);

    int rescaleSize() const { return m_rescaleSize; }
    void setRescaleSize(int rescaleSize);

    QRectF sampleRect() const { return m_sampleRect; }
    void setSampleRect(const QRectF &sampleRect);

    QColor dominantColour() const { return m_dominantColour; }
    qreal luminance() const { return m_luminance; }

    Q_INVOKABLE void requestUpdate();

signals:
    void sourceChanged();
    void sourceItemChanged();
    void rescaleSizeChanged();
    void sampleRectChanged();
    void dominantColourChanged();
    void luminanceChanged();

private:
    using AnalyseResult = QPair<QColor, qreal>;

    QFutureWatcher<AnalyseResult> *const m_futureWatcher;

    QString m_source;
    QPointer<QQuickItem> m_sourceItem;
    int m_rescaleSize;
    QRectF m_sampleRect;

    QColor m_dominantColour;
    qreal m_luminance;

    void update();
    // Turns a QML source string (plain path or file:// URL) into a local path.
    // Remote schemes yield an empty string: use sourceItem for those.
    static QString localPath(const QString &source);
    static void analyse(QPromise<AnalyseResult> &promise, const QImage &image, int rescaleSize,
        const QRectF &sampleRect);
};

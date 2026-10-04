#include "imageanalyser.hpp"

#include <QLoggingCategory>
#include <QQuickItemGrabResult>
#include <QQuickWindow>
#include <QUrl>
#include <QtConcurrent/QtConcurrentRun>

#include <cmath>
#include <unordered_map>

Q_LOGGING_CATEGORY(lcImageAnalyser, "cybergraphics.imageanalyser", QtWarningMsg)

ImageAnalyser::ImageAnalyser(QObject *parent)
    : QObject(parent)
    , m_futureWatcher(new QFutureWatcher<AnalyseResult>(this))
    , m_rescaleSize(128)
    , m_sampleRect(0, 0, 1, 1)
    , m_dominantColour(0, 0, 0)
    , m_luminance(0) {
    connect(m_futureWatcher, &QFutureWatcher<AnalyseResult>::finished, this, [this]() {
        // A cancelled or bailed-out run leaves no result at all.
        if (m_futureWatcher->future().resultCount() == 0)
            return;

        const AnalyseResult result = m_futureWatcher->result();
        if (m_dominantColour != result.first) {
            m_dominantColour = result.first;
            emit dominantColourChanged();
        }
        if (!qFuzzyCompare(m_luminance + 1.0, result.second + 1.0)) {
            m_luminance = result.second;
            emit luminanceChanged();
        }
    });
}

void ImageAnalyser::setSource(const QString &source) {
    if (m_source == source)
        return;

    m_source = source;
    emit sourceChanged();

    // The two sources are mutually exclusive: setting one clears the other.
    if (m_sourceItem) {
        m_sourceItem = nullptr;
        emit sourceItemChanged();
    }

    requestUpdate();
}

void ImageAnalyser::setSourceItem(QQuickItem *sourceItem) {
    if (m_sourceItem == sourceItem)
        return;

    m_sourceItem = sourceItem;
    emit sourceItemChanged();

    if (!m_source.isEmpty()) {
        m_source.clear();
        emit sourceChanged();
    }

    requestUpdate();
}

void ImageAnalyser::setRescaleSize(int rescaleSize) {
    if (m_rescaleSize == rescaleSize)
        return;

    m_rescaleSize = rescaleSize;
    emit rescaleSizeChanged();

    requestUpdate();
}

// The region of interest, in normalised 0..1 image coordinates. Callers that
// only care about part of the image (the patch of wallpaper behind a window,
// say) crop here instead of analysing the whole thing.
void ImageAnalyser::setSampleRect(const QRectF &sampleRect) {
    if (m_sampleRect == sampleRect)
        return;

    m_sampleRect = sampleRect;
    emit sampleRectChanged();

    requestUpdate();
}

void ImageAnalyser::requestUpdate() {
    if (m_source.isEmpty() && !m_sourceItem)
        return;

    if (!m_sourceItem) {
        update();
        return;
    }

    // An item can only be grabbed once it has a visible window and a size.
    // Otherwise wait for whichever precondition is missing, then retry.
    QQuickWindow *window = m_sourceItem->window();
    if (window && window->isVisible() && m_sourceItem->width() > 0 && m_sourceItem->height() > 0) {
        update();
        return;
    }

    if (!window)
        connect(m_sourceItem, &QQuickItem::windowChanged, this, &ImageAnalyser::requestUpdate,
            Qt::SingleShotConnection);
    else if (!window->isVisible())
        connect(window, &QQuickWindow::visibleChanged, this, &ImageAnalyser::requestUpdate,
            Qt::SingleShotConnection);
    if (m_sourceItem->width() <= 0)
        connect(m_sourceItem, &QQuickItem::widthChanged, this, &ImageAnalyser::requestUpdate,
            Qt::SingleShotConnection);
    if (m_sourceItem->height() <= 0)
        connect(m_sourceItem, &QQuickItem::heightChanged, this, &ImageAnalyser::requestUpdate,
            Qt::SingleShotConnection);
}

QString ImageAnalyser::localPath(const QString &source) {
    if (source.isEmpty())
        return QString();

    if (source.startsWith(QStringLiteral("file:")))
        return QUrl(source).toLocalFile();

    // Any other scheme (http, https, image:// providers) cannot be read by
    // QImage directly; those callers should point sourceItem at an Image.
    const qsizetype scheme = source.indexOf(QStringLiteral("://"));
    if (scheme > 0)
        return QString();

    return source;
}

void ImageAnalyser::update() {
    if (m_futureWatcher->isRunning())
        m_futureWatcher->cancel();

    if (m_sourceItem) {
        const QSharedPointer<const QQuickItemGrabResult> grabResult = m_sourceItem->grabToImage();
        if (!grabResult) {
            connect(m_sourceItem, &QQuickItem::windowChanged, this, &ImageAnalyser::requestUpdate,
                Qt::SingleShotConnection);
            return;
        }
        connect(grabResult.data(), &QQuickItemGrabResult::ready, this, [grabResult, this]() {
            m_futureWatcher->setFuture(
                QtConcurrent::run(&ImageAnalyser::analyse, grabResult->image(), m_rescaleSize, m_sampleRect));
        });
        return;
    }

    const QString path = localPath(m_source);
    if (path.isEmpty()) {
        qCWarning(lcImageAnalyser) << "cannot read source as a local file:" << m_source;
        return;
    }

    const int rescaleSize = m_rescaleSize;
    const QRectF sampleRect = m_sampleRect;
    m_futureWatcher->setFuture(QtConcurrent::run([path, rescaleSize, sampleRect](QPromise<AnalyseResult> &promise) {
        analyse(promise, QImage(path), rescaleSize, sampleRect);
    }));
}

void ImageAnalyser::analyse(
    QPromise<AnalyseResult> &promise, const QImage &image, int rescaleSize, const QRectF &sampleRect) {
    if (image.isNull()) {
        qCWarning(lcImageAnalyser) << "analyse: image is null";
        return;
    }

    QImage img = image;

    // Crop first: everything below then works on the region of interest only.
    if (sampleRect.isValid() && sampleRect != QRectF(0, 0, 1, 1)) {
        const QRect region = QRect(qRound(sampleRect.x() * img.width()), qRound(sampleRect.y() * img.height()),
            qRound(sampleRect.width() * img.width()), qRound(sampleRect.height() * img.height()))
                                 .intersected(img.rect());
        if (region.width() > 0 && region.height() > 0)
            img = img.copy(region);
    }

    if (rescaleSize > 0 && (img.width() > rescaleSize || img.height() > rescaleSize))
        img = img.scaled(rescaleSize, rescaleSize, Qt::KeepAspectRatio, Qt::FastTransformation);

    if (promise.isCanceled())
        return;

    if (img.format() != QImage::Format_ARGB32)
        img = img.convertToFormat(QImage::Format_ARGB32);

    if (promise.isCanceled())
        return;

    const uchar *data = img.bits();
    const int width = img.width();
    const int height = img.height();
    const qsizetype bytesPerLine = img.bytesPerLine();

    // Colours are bucketed to 5 bits per channel so near-identical shades vote
    // together; the winning bucket is the dominant colour.
    std::unordered_map<quint32, int> colours;
    qreal totalLuminance = 0.0;
    int count = 0;

    for (int y = 0; y < height; ++y) {
        if (promise.isCanceled())
            return;

        const uchar *line = data + y * bytesPerLine;
        for (int x = 0; x < width; ++x) {
            const uchar *pixel = line + x * 4;

            if (pixel[3] == 0)
                continue;

            const quint32 mr = static_cast<quint32>(pixel[2] & 0xF8);
            const quint32 mg = static_cast<quint32>(pixel[1] & 0xF8);
            const quint32 mb = static_cast<quint32>(pixel[0] & 0xF8);
            ++colours[(mr << 16) | (mg << 8) | mb];

            const qreal r = pixel[2] / 255.0;
            const qreal g = pixel[1] / 255.0;
            const qreal b = pixel[0] / 255.0;
            totalLuminance += std::sqrt(0.299 * r * r + 0.587 * g * g + 0.114 * b * b);
            ++count;
        }
    }

    quint32 dominantColour = 0;
    int maxCount = 0;
    for (const auto &[colour, colourCount] : colours) {
        if (colourCount > maxCount) {
            dominantColour = colour;
            maxCount = colourCount;
        }
    }

    promise.addResult(qMakePair(QColor(0xFF000000u | dominantColour), count == 0 ? 0.0 : totalLuminance / count));
}

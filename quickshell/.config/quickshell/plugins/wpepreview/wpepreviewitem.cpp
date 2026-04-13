#include "wpepreviewitem.hpp"
#include <QPainter>
#include <cstring>

WpePreviewItem::WpePreviewItem(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
}

WpePreviewItem::~WpePreviewItem()
{
    stopWpe();
}

void WpePreviewItem::paint(QPainter *painter)
{
    if (m_currentFrame.isNull()) return;

    QRectF target = boundingRect();
    QSizeF imgSize = m_currentFrame.size().scaled(target.size().toSize(), Qt::KeepAspectRatioByExpanding);
    QRectF source(
        (imgSize.width() - target.width()) / 2.0,
        (imgSize.height() - target.height()) / 2.0,
        target.width(),
        target.height()
    );

    QImage scaled = m_currentFrame.scaled(imgSize.toSize(), Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    painter->drawImage(target, scaled, source);
}

void WpePreviewItem::setScenePath(const QString &path)
{
    if (m_scenePath == path) return;
    m_scenePath = path;
    emit scenePathChanged();

    if (path.isEmpty())
        stopWpe();
    else
        startWpe();
    // If dimensions not ready yet, geometryChange will trigger startWpe
}

void WpePreviewItem::setFps(int fps)
{
    fps = qBound(1, fps, 60);
    if (m_fps == fps) return;
    m_fps = fps;
    emit fpsChanged();
}

void WpePreviewItem::startWpe()
{
    stopWpe();

    int w = 640;
    int h = 360;

    m_process = new QProcess(this);
    m_process->setProgram("linux-wallpaperengine-headless");
    m_process->setArguments({
        "--headless-pipe", QString("%1x%2").arg(w).arg(h),
        "--fps", QString::number(m_fps),
        "--silent",
        "--disable-mouse",
        "--disable-parallax",
        m_scenePath
    });

    m_process->setProcessChannelMode(QProcess::SeparateChannels);

    connect(m_process, &QProcess::started, this, [this, w, h]() {
        m_running = true;
        emit runningChanged();
    });

    connect(m_process, &QProcess::readyReadStandardOutput,
            this, &WpePreviewItem::onReadyRead);

    connect(m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError err) {
        qWarning() << "WpePreviewItem: Process error:" << err << m_process->errorString();
    });

    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int code, QProcess::ExitStatus status) {
        m_running = false;
        m_ready = false;
        emit runningChanged();
        emit readyChanged();
    });

    m_headerRead = false;
    m_frameWidth = 0;
    m_frameHeight = 0;
    m_buffer.clear();

    m_process->start();
}

void WpePreviewItem::stopWpe()
{
    if (m_process) {
        m_process->disconnect();
        m_process->kill();
        m_process->waitForFinished(500);
        m_process->deleteLater();
        m_process = nullptr;
    }

    m_headerRead = false;
    m_buffer.clear();

    if (m_running) { m_running = false; emit runningChanged(); }
    if (m_ready) { m_ready = false; emit readyChanged(); }

    m_currentFrame = QImage();
    update();
}

void WpePreviewItem::onReadyRead()
{
    m_buffer.append(m_process->readAllStandardOutput());

    // Read header (8 bytes: uint32 width, uint32 height)
    if (!m_headerRead) {
        if (m_buffer.size() < 8) return;
        uint32_t header[2];
        memcpy(header, m_buffer.constData(), 8);
        m_frameWidth = header[0];
        m_frameHeight = header[1];
        m_buffer.remove(0, 8);
        m_headerRead = true;
    }

    // Process complete frames
    const int frameSize = m_frameWidth * m_frameHeight * 4;
    if (frameSize == 0) return;

    while (m_buffer.size() >= frameSize) {
        // Create QImage from BGRA data (OpenGL bottom-left origin, need to flip)
        QImage frame(
            reinterpret_cast<const uchar *>(m_buffer.constData()),
            m_frameWidth, m_frameHeight,
            m_frameWidth * 4,
            QImage::Format_ARGB32
        );

        m_currentFrame = frame.flipped(Qt::Vertical).copy();
        m_buffer.remove(0, frameSize);

        if (!m_ready) {
            m_ready = true;
            emit readyChanged();
        }

        update();
    }
}

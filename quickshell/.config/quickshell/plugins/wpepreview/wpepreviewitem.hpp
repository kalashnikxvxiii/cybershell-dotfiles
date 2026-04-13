#pragma once

#include <QQuickPaintedItem>
#include <QProcess>
#include <QTimer>
#include <QImage>

class WpePreviewItem : public QQuickPaintedItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString scenePath READ scenePath WRITE setScenePath NOTIFY scenePathChanged)
    Q_PROPERTY(int fps READ fps WRITE setFps NOTIFY fpsChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)

public:
    explicit WpePreviewItem(QQuickItem *parent = nullptr);
    ~WpePreviewItem() override;

    void paint(QPainter *painter) override;

    QString scenePath() const { return m_scenePath; }
    void setScenePath(const QString &path);

    int fps() const { return m_fps; }
    void setFps(int fps);

    bool running() const { return m_running; }
    bool ready() const { return m_ready; }

signals:
    void scenePathChanged();
    void fpsChanged();
    void runningChanged();
    void readyChanged();

private slots:
    void onReadyRead();

private:
    void startWpe();
    void stopWpe();

    QString m_scenePath;
    int m_fps{15};
    bool m_running{false};
    bool m_ready{false};

    QProcess *m_process{nullptr};
    QImage m_currentFrame;

    // Frame parsing state
    bool m_headerRead{false};
    uint32_t m_frameWidth{0};
    uint32_t m_frameHeight{0};
    QByteArray m_buffer;
};

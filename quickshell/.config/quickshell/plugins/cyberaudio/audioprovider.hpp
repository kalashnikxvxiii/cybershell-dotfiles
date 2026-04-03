#pragma once
#include <QObject>
#include <QThread>
#include <QTimer>
#include "service.hpp"
#include "audiocollector.hpp"

namespace cyberaudio {

class AudioProcessor : public QObject {
    Q_OBJECT
public:
    explicit AudioProcessor(QObject* parent = nullptr);
    ~AudioProcessor() override;

public slots:
    void start();
    void stop();

protected:
    virtual void process() = 0;

private:
    QTimer* m_timer = nullptr;
};

class AudioProvider : public Service {
    Q_OBJECT
public:
    explicit AudioProvider(QObject* parent = nullptr);
    ~AudioProvider() override;

protected:
    AudioProcessor* m_processor = nullptr;
    void init();

    void start() override;
    void stop() override;

private:
    QThread* m_thread = nullptr;
};

} // namespace cyberaudio

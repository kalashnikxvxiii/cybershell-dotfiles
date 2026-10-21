#pragma once
#include <QObject>
#include <QString>
#include <atomic>
#include <functional>
#include <mutex>
#include <thread>
#include <vector>
#include "service.hpp"

namespace cyberaudio {

namespace ac {
    constexpr quint32 SAMPLE_RATE = 44100;
    constexpr quint32 CHUNK_SIZE = 512;
}

class PipeWireWorker;

class AudioCollector : public Service {
    Q_OBJECT
public:
    static AudioCollector& instance();

    void clearBuffer();
    void loadChunk(const qint16* samples, quint32 count);
    quint32 readChunk(float* out, quint32 count = 0);
    quint32 readChunk(double* out, quint32 count = 0);

    // Configurazione letta dal PipeWireWorker al momento della connessione
    [[nodiscard]] QString streamName()  const { return m_streamName; }
    [[nodiscard]] bool    captureSink() const { return m_captureSink; }
    [[nodiscard]] QString target()      const { return m_target; }
    [[nodiscard]] quint32 channels()    const { return m_channels; }

    // The worker registers a callback that makes its loop return right away;
    // stop() calls it so the join does not wait for the next idle timer tick.
    void setWake(std::function<void()> fn);

protected:
    explicit AudioCollector(QObject* parent = nullptr);
    AudioCollector(QString streamName, bool captureSink, quint32 channels, QObject* parent = nullptr);

    void start() override;
    void stop() override;

    QString m_streamName = QStringLiteral("cyberaudio-capture");
    bool    m_captureSink = true;
    quint32 m_channels = 1;
    QString m_target;                  // vuoto = lascia scegliere il default a PipeWire

private:
    std::jthread m_thread;
    std::mutex m_wakeMutex;
    std::function<void()> m_wake;
    std::vector<float> m_buffer1, m_buffer2;
    std::atomic<std::vector<float>*> m_readBuffer;
    std::atomic<std::vector<float>*> m_writeBuffer;
    quint32 m_sampleCount = 0;
};

// Cattura la *source* di default (microfono) invece del monitor del sink.
class MicCollector : public AudioCollector {
    Q_OBJECT
public:
    static MicCollector& instance();

    // Riconnette lo stream a un altro nodo (PW_KEY_TARGET_OBJECT).
    void setTarget(const QString& target);

protected:
    void start() override;
    void stop() override;

private:
    explicit MicCollector(QObject* parent = nullptr);
    bool m_active = false;
};

// Cattura il monitor del sink di default in STEREO, per i VU meter.
class SinkLevelCollector : public AudioCollector {
    Q_OBJECT
public:
    static SinkLevelCollector& instance();

private:
    explicit SinkLevelCollector(QObject* parent = nullptr);
};

} // namespace cyberaudio

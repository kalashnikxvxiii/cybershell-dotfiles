#pragma once
#include <QObject>
#include <atomic>
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

protected:
    void start() override;
    void stop() override;

private:
    explicit AudioCollector(QObject* parent = nullptr);
    std::jthread m_thread;
    std::vector<float> m_buffer1, m_buffer2;
    std::atomic<std::vector<float>*> m_readBuffer;
    std::atomic<std::vector<float>*> m_writeBuffer;
    quint32 m_sampleCount = 0;
};

} // namespace cyberaudio

#include "audiocollector.hpp"
#include <QDebug>
#include <algorithm>
#include <cstddef>

#include <pipewire/pipewire.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/latency-utils.h>

namespace cyberaudio {

// ── PipeWire Worker ──────────────────────────────────────────────

class PipeWireWorker {
public:
    PipeWireWorker(AudioCollector* collector, std::stop_token token)
        : m_collector(collector), m_token(std::move(token)) {}

    void run() {
        pw_init(nullptr, nullptr);
        m_loop = pw_main_loop_new(nullptr);

        auto* props = pw_properties_new(
            PW_KEY_MEDIA_TYPE, "Audio",
            PW_KEY_MEDIA_CATEGORY, "Capture",
            PW_KEY_MEDIA_ROLE, "Music",
            PW_KEY_NODE_VIRTUAL, "true",
            PW_KEY_STREAM_DONT_REMIX, "false",
            nullptr
        );

        if (m_collector->captureSink()) {
            pw_properties_set(props, PW_KEY_STREAM_CAPTURE_SINK, "true");
            // Passivo solo sul monitor: non deve tenere sveglio il sink.
            pw_properties_set(props, PW_KEY_NODE_PASSIVE, "true");
        }

        const QByteArray target = m_collector->target().toUtf8();
        if (!target.isEmpty())
            pw_properties_set(props, PW_KEY_TARGET_OBJECT, target.constData());

        static const pw_stream_events events = {
            .version = PW_VERSION_STREAM_EVENTS,
            .state_changed = [](void* data, pw_stream_state, pw_stream_state state, const char*) {
                auto* self = static_cast<PipeWireWorker*>(data);
                self->streamStateChanged(state);
            },
            .process = [](void* data) {
                static_cast<PipeWireWorker*>(data)->processStream();
            },
        };

        const QByteArray streamName = m_collector->streamName().toUtf8();
        m_stream = pw_stream_new_simple(
            pw_main_loop_get_loop(m_loop),
            streamName.constData(),
            props,
            &events,
            this
        );

        uint8_t buffer[1024];
        spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
        spa_audio_info_raw rawInfo = {};
        rawInfo.format = SPA_AUDIO_FORMAT_S16;
        rawInfo.rate = ac::SAMPLE_RATE;
        rawInfo.channels = m_collector->channels();
        auto* audioInfo = spa_format_audio_raw_build(
            &b, SPA_PARAM_EnumFormat, &rawInfo
        );
        const spa_pod* params[] = { audioInfo };

        pw_stream_connect(
            m_stream,
            PW_DIRECTION_INPUT,
            PW_ID_ANY,
            static_cast<pw_stream_flags>(
                PW_STREAM_FLAG_AUTOCONNECT |
                PW_STREAM_FLAG_MAP_BUFFERS |
                PW_STREAM_FLAG_RT_PROCESS
            ),
            params, 1
        );

        // Idle detection timer
        auto* timerSource = pw_loop_add_timer(
            pw_main_loop_get_loop(m_loop),
            [](void* data, uint64_t expirations) {
                static_cast<PipeWireWorker*>(data)->handleTimeout(expirations);
            },
            this
        );
        timespec ts = { .tv_sec = 0, .tv_nsec = 10000000 }; // 10ms
        pw_loop_update_timer(pw_main_loop_get_loop(m_loop), timerSource, &ts, nullptr, false);
        m_timer = timerSource;

        // Run until stop requested
        while (!m_token.stop_requested()) {
            pw_main_loop_run(m_loop);
        }

        pw_stream_destroy(m_stream);
        pw_main_loop_destroy(m_loop);
        pw_deinit();
    }

private:
    AudioCollector* m_collector;
    std::stop_token m_token;
    pw_main_loop* m_loop = nullptr;
    pw_stream* m_stream = nullptr;
    spa_source* m_timer = nullptr;
    bool m_idle = true;
    int m_expirations = 0;

    void streamStateChanged(pw_stream_state state) {
        if (state == PW_STREAM_STATE_ERROR || state == PW_STREAM_STATE_UNCONNECTED) {
            pw_main_loop_quit(m_loop);
        }
    }

    void processStream() {
        auto* buf = pw_stream_dequeue_buffer(m_stream);
        if (!buf) return;

        auto* d = buf->buffer->datas;
        if (d[0].data) {
            auto* samples = static_cast<const qint16*>(d[0].data);
            quint32 count = d[0].chunk->size / sizeof(qint16);
            m_collector->loadChunk(samples, count);
        }
        pw_stream_queue_buffer(m_stream, buf);
        m_idle = false;
        m_expirations = 0;
    }

    void handleTimeout(uint64_t expirations) {
        Q_UNUSED(expirations)

        if (m_token.stop_requested()) {
            pw_main_loop_quit(m_loop);
            return;
        }

        m_expirations++;
        if (!m_idle && m_expirations >= 10) {
            m_idle = true;
            m_collector->clearBuffer();
        }

        // Ri-arma SEMPRE: il timer e' one-shot (interval = nullptr).
        // Saltare un rearm significa non controllare mai piu' stop_requested()
        // e bloccare per sempre il join() in stop().
        timespec ts = { .tv_sec = 0, .tv_nsec = m_idle ? 500000000L : 10000000L };
        pw_loop_update_timer(pw_main_loop_get_loop(m_loop), m_timer, &ts, nullptr, false);
    }

    static unsigned int nextPowerOf2(unsigned int n) {
        n--;
        n |= n >> 1; n |= n >> 2; n |= n >> 4;
        n |= n >> 8; n |= n >> 16;
        return n + 1;
    }
};

// ── AudioCollector ───────────────────────────────────────────────

AudioCollector& AudioCollector::instance() {
    static AudioCollector inst;
    return inst;
}

AudioCollector::AudioCollector(QObject* parent)
    : AudioCollector(QStringLiteral("cyberaudio-capture"), true, 1, parent) {}

AudioCollector::AudioCollector(QString streamName, bool captureSink, quint32 channels, QObject* parent)
    : Service(parent)
    , m_streamName(std::move(streamName))
    , m_captureSink(captureSink)
    , m_channels(channels)
    , m_buffer1(ac::CHUNK_SIZE, 0.0f)
    , m_buffer2(ac::CHUNK_SIZE, 0.0f) {
    m_readBuffer.store(&m_buffer1, std::memory_order_relaxed);
    m_writeBuffer.store(&m_buffer2, std::memory_order_relaxed);
}

void AudioCollector::start() {
    m_thread = std::jthread([this](std::stop_token token) {
        PipeWireWorker worker(this, std::move(token));
        worker.run();
    });
}

void AudioCollector::stop() {
    m_thread.request_stop();
    if (m_thread.joinable()) m_thread.join();
}

void AudioCollector::clearBuffer() {
    auto* wb = m_writeBuffer.load(std::memory_order_relaxed);
    std::fill(wb->begin(), wb->end(), 0.0f);
    m_sampleCount = 0;
    // Swap
    auto* rb = m_readBuffer.exchange(wb, std::memory_order_acq_rel);
    m_writeBuffer.store(rb, std::memory_order_release);
}

void AudioCollector::loadChunk(const qint16* samples, quint32 count) {
    auto* wb = m_writeBuffer.load(std::memory_order_relaxed);
    for (quint32 i = 0; i < count && i < ac::CHUNK_SIZE; ++i) {
        (*wb)[i] = static_cast<float>(samples[i]) / 32768.0f;
    }
    m_sampleCount = std::min(count, ac::CHUNK_SIZE);
    // Swap buffers
    auto* rb = m_readBuffer.exchange(wb, std::memory_order_acq_rel);
    m_writeBuffer.store(rb, std::memory_order_release);
}

quint32 AudioCollector::readChunk(float* out, quint32 count) {
    auto* rb = m_readBuffer.load(std::memory_order_acquire);
    quint32 n = count == 0 ? ac::CHUNK_SIZE : std::min(count, ac::CHUNK_SIZE);
    std::copy_n(rb->begin(), n, out);
    return m_sampleCount;
}

quint32 AudioCollector::readChunk(double* out, quint32 count) {
    auto* rb = m_readBuffer.load(std::memory_order_acquire);
    quint32 n = count == 0 ? ac::CHUNK_SIZE : std::min(count, ac::CHUNK_SIZE);
    for (quint32 i = 0; i < n; ++i) out[i] = static_cast<double>((*rb)[i]);
    return m_sampleCount;
}

// ── MicCollector ─────────────────────────────────────────────────

MicCollector& MicCollector::instance() {
    static MicCollector inst;
    return inst;
}

MicCollector::MicCollector(QObject* parent)
    : AudioCollector(QStringLiteral("cyberaudio-mic"), false, 1, parent) {}

void MicCollector::start() {
    m_active = true;
    AudioCollector::start();
}

void MicCollector::stop() {
    m_active = false;
    AudioCollector::stop();
}

void MicCollector::setTarget(const QString& target) {
    if (target == m_target) return;
    m_target = target;
    if (!m_active) return;              // si applicherà alla prossima connessione
    AudioCollector::stop();             // il worker rilegge la config allo start
    AudioCollector::start();
}

// ── SinkLevelCollector ───────────────────────────────────────────

SinkLevelCollector& SinkLevelCollector::instance() {
    static SinkLevelCollector inst;
    return inst;
}

SinkLevelCollector::SinkLevelCollector(QObject* parent)
    : AudioCollector(QStringLiteral("cyberaudio-level"), true, 2, parent) {}

} // namespace cyberaudio

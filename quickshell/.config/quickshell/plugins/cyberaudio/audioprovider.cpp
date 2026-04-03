#include "audioprovider.hpp"
#include <QMetaObject>

namespace cyberaudio {

// ── AudioProcessor ───────────────────────────────────────────────

AudioProcessor::AudioProcessor(QObject* parent) : QObject(parent) {}

AudioProcessor::~AudioProcessor() {
    delete m_timer;
}

void AudioProcessor::start() {
    if (!m_timer) {
        m_timer = new QTimer(this);
        m_timer->setInterval(static_cast<int>(ac::CHUNK_SIZE * 1000.0 / ac::SAMPLE_RATE));
        connect(m_timer, &QTimer::timeout, this, &AudioProcessor::process);
    }
    m_timer->start();
}

void AudioProcessor::stop() {
    if (m_timer) m_timer->stop();
}

// ── AudioProvider ────────────────────────────────────────────────

AudioProvider::AudioProvider(QObject* parent) : Service(parent) {}

AudioProvider::~AudioProvider() {
    if (m_thread) {
        m_thread->quit();
        m_thread->wait();
        delete m_thread;
    }
}

void AudioProvider::init() {
    if (!m_processor) return;

    m_thread = new QThread(this);
    m_processor->moveToThread(m_thread);

    connect(m_thread, &QThread::started, m_processor, [this]() {
        // Ensure AudioCollector singleton exists on main thread
        QMetaObject::invokeMethod(this, []() {
            AudioCollector::instance();
        }, Qt::BlockingQueuedConnection);
    });
    connect(m_thread, &QThread::finished, m_processor, &QObject::deleteLater);

    m_thread->start();
}

void AudioProvider::start() {
    AudioCollector::instance().ref(this);
    QMetaObject::invokeMethod(m_processor, &AudioProcessor::start, Qt::QueuedConnection);
}

void AudioProvider::stop() {
    QMetaObject::invokeMethod(m_processor, &AudioProcessor::stop, Qt::QueuedConnection);
    AudioCollector::instance().unref(this);
}

} // namespace cyberaudio

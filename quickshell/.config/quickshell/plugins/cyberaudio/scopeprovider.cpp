#include "scopeprovider.hpp"
#include <algorithm>
#include <cmath>

namespace cyberaudio {

// ── ScopeProcessor ───────────────────────────────────────────────

ScopeProcessor::ScopeProcessor(QObject* parent) : AudioProcessor(parent) {}

void ScopeProcessor::setPoints(int points) {
    m_points = std::clamp(points, 2, static_cast<int>(ac::CHUNK_SIZE));
}

void ScopeProcessor::process() {
    MicCollector::instance().readChunk(m_raw, ac::CHUNK_SIZE);

    const int n = m_points;
    if (m_samples.size() != n) m_samples.resize(n);

    const int bucket = static_cast<int>(ac::CHUNK_SIZE) / n;
    double peak = 0.0;

    for (int i = 0; i < n; ++i) {
        double acc = 0.0;
        for (int j = 0; j < bucket; ++j) {
            const double v = static_cast<double>(m_raw[i * bucket + j]);
            acc += v;
            peak = std::max(peak, std::abs(v));
        }
        m_samples[i] = acc / bucket;
    }

    emit framed(m_samples, peak);
}

// ── ScopeProvider ────────────────────────────────────────────────

ScopeProvider::ScopeProvider(QObject* parent) : AudioProvider(parent) {
    m_samples.resize(m_points, 0.0);
    m_processor = new ScopeProcessor();
    init();
    connect(
        static_cast<ScopeProcessor*>(m_processor), &ScopeProcessor::framed,
        this, &ScopeProvider::updateFrame
    );
}

AudioCollector& ScopeProvider::collector() { return MicCollector::instance(); }

int ScopeProvider::points() const { return m_points; }

void ScopeProvider::setPoints(int points) {
    points = std::clamp(points, 2, static_cast<int>(ac::CHUNK_SIZE));
    if (m_points == points) return;
    m_points = points;
    m_samples.resize(points, 0.0);
    emit pointsChanged();
    emit samplesChanged();
    QMetaObject::invokeMethod(
        static_cast<ScopeProcessor*>(m_processor),
        &ScopeProcessor::setPoints,
        Qt::QueuedConnection, points
    );
}

QVector<double> ScopeProvider::samples() const { return m_samples; }
double ScopeProvider::peak() const { return m_peak; }
QString ScopeProvider::target() const { return m_target; }

void ScopeProvider::setTarget(const QString& target) {
    if (m_target == target) return;
    m_target = target;
    MicCollector::instance().setTarget(target);
    emit targetChanged();
}

void ScopeProvider::updateFrame(QVector<double> samples, double peak) {
    m_samples = std::move(samples);
    m_peak = peak;
    emit samplesChanged();
}

} // namespace cyberaudio

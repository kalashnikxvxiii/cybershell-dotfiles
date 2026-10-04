#include "nodelevelprovider.hpp"
#include <algorithm>
#include <cmath>

namespace cyberaudio {

// -- NodeLevelCollector ---------------------------------------

NodeLevelCollector::NodeLevelCollector(QObject* parent)
    : AudioCollector(QStringLiteral("cyberaudio-nodelevel"), true, 2, parent) {}

void NodeLevelCollector::start() { m_active = true;  AudioCollector::start(); }
void NodeLevelCollector::stop()  { m_active = false; AudioCollector::stop(); }

void NodeLevelCollector::reconfigure(const QString& target, bool captureSink) {
    if (target == m_target && captureSink == m_captureSink) return;
    m_target      = target;
    m_captureSink = captureSink;
    if (!m_active) return;          // si applica alla prossima connessione
    AudioCollector::stop();
    AudioCollector::start();
}

// -- NodeLevelProcessor ----------------------------------------

NodeLevelProcessor::NodeLevelProcessor(NodeLevelCollector* collector, QObject* parent)
    : AudioProcessor(parent), m_collector(collector) {}

void NodeLevelProcessor::process() {
    if (!m_collector) return;
    m_collector->readChunk(m_raw, ac::CHUNK_SIZE);

    const int frames = static_cast<int>(ac::CHUNK_SIZE) / 2;
    double pL = 0.0, pR = 0.0;
    for (int i = 0; i < frames; ++i) {
        pL = std::max(pL, std::abs(static_cast<double>(m_raw[i * 2])));
        pR = std::max(pR, std::abs(static_cast<double>(m_raw[i * 2 + 1])));
    }

    // Attacco istantaneo, rilascio esponenziale (~70ms)
    constexpr double release = 0.85;
    m_peakL = std::max(pL, m_peakL * release);
    m_peakR = std::max(pR, m_peakR * release);
    emit framed(std::max(m_peakL, m_peakR), m_peakL, m_peakR);
}

// -- NodeLevelProvider ----------------------------------------

NodeLevelProvider::NodeLevelProvider(QObject* parent) : AudioProvider(parent) {
    m_collector = new NodeLevelCollector(this);   // prima di init(): init() chiama collector()
    m_processor = new NodeLevelProcessor(m_collector);
    init();
    connect(static_cast<NodeLevelProcessor*>(m_processor), &NodeLevelProcessor::framed,
            this, &NodeLevelProvider::updatePeak);
}

AudioCollector& NodeLevelProvider::collector() { return *m_collector; }

void NodeLevelProvider::setTarget(const QString& t) {
    if (m_target == t) return;
    m_target = t;
    emit targetChanged();
    _apply();
}

void NodeLevelProvider::setCaptureSink(bool v) {
    if (m_captureSink == v) return;
    m_captureSink = v;
    emit captureSinkChanged();
    _apply();
}

void NodeLevelProvider::_apply() { m_collector->reconfigure(m_target, m_captureSink); }

void NodeLevelProvider::updatePeak(double peak, double peakL, double peakR) {
    m_peak = peak;
    m_peakL = peakL;
    m_peakR = peakR;
    emit peakChanged();
}

} // namespace cyberaudio

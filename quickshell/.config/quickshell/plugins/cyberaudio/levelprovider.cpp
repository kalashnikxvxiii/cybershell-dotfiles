#include "levelprovider.hpp"
#include <algorithm>
#include <cmath>

namespace cyberaudio {

// ── LevelProcessor ───────────────────────────────────────────────

LevelProcessor::LevelProcessor(QObject* parent) : AudioProcessor(parent) {}

void LevelProcessor::process() {
    SinkLevelCollector::instance().readChunk(m_raw, ac::CHUNK_SIZE);

    // Il buffer e' PCM interleaved a 2 canali: pari = L, dispari = R.
    const int frames = static_cast<int>(ac::CHUNK_SIZE) / 2;
    double pL = 0.0, pR = 0.0, sL = 0.0, sR = 0.0;

    for (int i = 0; i < frames; ++i) {
        const double l = static_cast<double>(m_raw[i * 2]);
        const double r = static_cast<double>(m_raw[i * 2 + 1]);
        pL = std::max(pL, std::abs(l));
        pR = std::max(pR, std::abs(r));
        sL += l * l;
        sR += r * r;
    }

    // Ballistica da VU: attacco istantaneo, rilascio esponenziale (~70ms).
    constexpr double release = 0.85;
    m_peakL = std::max(pL, m_peakL * release);
    m_peakR = std::max(pR, m_peakR * release);

    emit framed(m_peakL, m_peakR,
                std::sqrt(sL / frames), std::sqrt(sR / frames));
}

// ── LevelProvider ────────────────────────────────────────────────

LevelProvider::LevelProvider(QObject* parent) : AudioProvider(parent) {
    m_processor = new LevelProcessor();
    init();
    connect(
        static_cast<LevelProcessor*>(m_processor), &LevelProcessor::framed,
        this, &LevelProvider::updateLevel
    );
}

AudioCollector& LevelProvider::collector() { return SinkLevelCollector::instance(); }

double LevelProvider::peakL() const { return m_peakL; }
double LevelProvider::peakR() const { return m_peakR; }
double LevelProvider::rmsL()  const { return m_rmsL; }
double LevelProvider::rmsR()  const { return m_rmsR; }

void LevelProvider::updateLevel(double peakL, double peakR, double rmsL, double rmsR) {
    m_peakL = peakL;
    m_peakR = peakR;
    m_rmsL  = rmsL;
    m_rmsR  = rmsR;
    emit levelChanged();
}

} // namespace cyberaudio

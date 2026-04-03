#include "cavaprovider.hpp"
#include <QMetaObject>
#include <algorithm>
#include <cava/cavacore.h>

namespace cyberaudio {

// ── CavaProcessor ────────────────────────────────────────────────

CavaProcessor::CavaProcessor(QObject* parent) : AudioProcessor(parent) {
    m_in = new double[ac::CHUNK_SIZE];
}

CavaProcessor::~CavaProcessor() {
    cleanup();
    delete[] m_in;
}

void CavaProcessor::setBars(int bars) {
    m_bars = bars;
    reload();
}

void CavaProcessor::initCava() {
    if (m_plan || m_bars == 0) return;
    m_plan = cava_init(m_bars, ac::SAMPLE_RATE, 1, 1, 0.85, 50, 10000);
    m_out = new double[m_bars];
}

void CavaProcessor::cleanup() {
    if (m_plan) {
        cava_destroy(m_plan);
        m_plan = nullptr;
    }
    delete[] m_out;
    m_out = nullptr;
}

void CavaProcessor::reload() {
    cleanup();
    initCava();
}

void CavaProcessor::process() {
    if (!m_plan || m_bars == 0 || !m_out) return;

    const int count = AudioCollector::instance().readChunk(m_in);
    cava_execute(m_in, count, m_out, m_plan);

    // Monstercat smoothing
    QVector<double> values(m_bars);
    const double inv = 1.0 / 1.5;

    // Left-to-right pass
    double carry = 0.0;
    for (int i = 0; i < m_bars; ++i) {
        carry = std::max(m_out[i], carry * inv);
        values[i] = carry;
    }

    // Right-to-left pass
    carry = 0.0;
    for (int i = m_bars - 1; i >= 0; --i) {
        carry = std::max(m_out[i], carry * inv);
        values[i] = std::max(values[i], carry);
    }

    if (values != m_values) {
        m_values = std::move(values);
        emit valuesChanged(m_values);
    }
}

// ── CavaProvider ─────────────────────────────────────────────────

CavaProvider::CavaProvider(QObject* parent) : AudioProvider(parent) {
    m_processor = new CavaProcessor();
    init();
    connect(
        static_cast<CavaProcessor*>(m_processor), &CavaProcessor::valuesChanged,
        this, &CavaProvider::updateValues
    );
}

int CavaProvider::bars() const { return m_bars; }

void CavaProvider::setBars(int bars) {
    if (bars < 0) bars = 0;
    if (m_bars == bars) return;
    m_values.resize(bars, 0.0);
    m_bars = bars;
    emit barsChanged();
    emit valuesChanged();
    QMetaObject::invokeMethod(
        static_cast<CavaProcessor*>(m_processor),
        &CavaProcessor::setBars,
        Qt::QueuedConnection, bars
    );
}

QVector<double> CavaProvider::values() const { return m_values; }

void CavaProvider::updateValues(QVector<double> values) {
    m_values = std::move(values);
    emit valuesChanged();
}

} // namespace cyberaudio

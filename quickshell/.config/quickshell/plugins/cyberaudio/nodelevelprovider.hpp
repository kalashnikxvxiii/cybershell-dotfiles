#pragma once
#include <QObject>
#include <QString>
#include <qqmlintegration.h>
#include "audioprovider.hpp"

namespace cyberaudio {

// Collector ISTANZIABILE (non singleton): una capture per nodo.
class NodeLevelCollector : public AudioCollector {
    Q_OBJECT
public:
    explicit NodeLevelCollector(QObject* parent = nullptr);
    void reconfigure(const QString& target, bool captureSink);

protected:
    void start() override;
    void stop() override;

private:
    bool m_active = false;
};

class NodeLevelProcessor : public AudioProcessor {
    Q_OBJECT
public:
    explicit NodeLevelProcessor(NodeLevelCollector* collector, QObject* parent = nullptr);

signals:
    void framed(double peak, double peakL, double peakR);

protected:
    void process() override;

private:
    NodeLevelCollector* m_collector = nullptr;
    float  m_raw[ac::CHUNK_SIZE] = {};
    double m_peakL = 0.0;
    double m_peakR = 0.0;
};

class NodeLevelProvider : public AudioProvider {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString target READ target WRITE setTarget NOTIFY targetChanged)
    Q_PROPERTY(bool captureSink READ captureSink WRITE setCaptureSink NOTIFY captureSinkChanged)
    Q_PROPERTY(double peak READ peak NOTIFY peakChanged)
    Q_PROPERTY(double peakL READ peakL NOTIFY peakChanged)
    Q_PROPERTY(double peakR READ peakR NOTIFY peakChanged)
public:
    explicit NodeLevelProvider(QObject* parent = nullptr);

    [[nodiscard]] QString target()      const { return m_target; }
    [[nodiscard]] bool    captureSink() const { return m_captureSink; }
    [[nodiscard]] double  peak()        const { return m_peak; }
    [[nodiscard]] double  peakL()       const { return m_peakL; }
    [[nodiscard]] double  peakR()       const { return m_peakR; }
    void setTarget(const QString& t);
    void setCaptureSink(bool v);

signals:
    void targetChanged();
    void captureSinkChanged();
    void peakChanged();

protected:
    AudioCollector& collector() override;

private:
    NodeLevelCollector* m_collector = nullptr;
    QString m_target;
    bool    m_captureSink = true;
    double  m_peak = 0.0;
    double  m_peakL = 0.0;
    double  m_peakR = 0.0;
    void updatePeak(double peak, double peakL, double peakR);
    void _apply();
};

} // namespace cyberaudio

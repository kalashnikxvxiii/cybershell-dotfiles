#pragma once
#include <QObject>
#include <qqmlintegration.h>
#include "audioprovider.hpp"

namespace cyberaudio {

class LevelProcessor : public AudioProcessor {
    Q_OBJECT
public:
    explicit LevelProcessor(QObject* parent = nullptr);

signals:
    void framed(double peakL, double peakR, double rmsL, double rmsR);

protected:
    void process() override;

private:
    float  m_raw[ac::CHUNK_SIZE] = {};
    double m_peakL = 0.0;
    double m_peakR = 0.0;
};

class LevelProvider : public AudioProvider {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(double peakL READ peakL NOTIFY levelChanged)
    Q_PROPERTY(double peakR READ peakR NOTIFY levelChanged)
    Q_PROPERTY(double rmsL  READ rmsL  NOTIFY levelChanged)
    Q_PROPERTY(double rmsR  READ rmsR  NOTIFY levelChanged)
public:
    explicit LevelProvider(QObject* parent = nullptr);

    [[nodiscard]] double peakL() const;
    [[nodiscard]] double peakR() const;
    [[nodiscard]] double rmsL()  const;
    [[nodiscard]] double rmsR()  const;

signals:
    void levelChanged();

protected:
    AudioCollector& collector() override;

private:
    double m_peakL = 0.0, m_peakR = 0.0, m_rmsL = 0.0, m_rmsR = 0.0;
    void updateLevel(double peakL, double peakR, double rmsL, double rmsR);
};

} // namespace cyberaudio

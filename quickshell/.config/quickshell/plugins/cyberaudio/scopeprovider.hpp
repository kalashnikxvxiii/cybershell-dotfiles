#pragma once
#include <QObject>
#include <QString>
#include <QVector>
#include <qqmlintegration.h>
#include "audioprovider.hpp"

namespace cyberaudio {

class ScopeProcessor : public AudioProcessor {
    Q_OBJECT
public:
    explicit ScopeProcessor(QObject* parent = nullptr);

public slots:
    void setPoints(int points);

signals:
    void framed(QVector<double> samples, double peak);

protected:
    void process() override;

private:
    int m_points = 64;
    QVector<double> m_samples;
    float m_raw[ac::CHUNK_SIZE] = {};
};

class ScopeProvider : public AudioProvider {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int points READ points WRITE setPoints NOTIFY pointsChanged)
    Q_PROPERTY(QVector<double> samples READ samples NOTIFY samplesChanged)
    Q_PROPERTY(double peak READ peak NOTIFY samplesChanged)
    Q_PROPERTY(QString target READ target WRITE setTarget NOTIFY targetChanged)
public:
    explicit ScopeProvider(QObject* parent = nullptr);

    [[nodiscard]] int points() const;
    void setPoints(int points);
    [[nodiscard]] QVector<double> samples() const;
    [[nodiscard]] double peak() const;
    [[nodiscard]] QString target() const;
    void setTarget(const QString& target);

signals:
    void pointsChanged();
    void samplesChanged();
    void targetChanged();

protected:
    AudioCollector& collector() override;

private:
    int m_points = 64;
    QVector<double> m_samples;
    double m_peak = 0.0;
    QString m_target;
    void updateFrame(QVector<double> samples, double peak);
};

} // namespace cyberaudio

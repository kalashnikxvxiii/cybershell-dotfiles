#pragma once
#include <QObject>
#include <QVector>
#include <qqmlintegration.h>
#include "audioprovider.hpp"

struct cava_plan;  // Forward declare nel namespace globale

namespace cyberaudio {

class CavaProcessor : public AudioProcessor {
    Q_OBJECT
public:
    explicit CavaProcessor(QObject* parent = nullptr);
    ~CavaProcessor() override;
    void setBars(int bars);

signals:
    void valuesChanged(QVector<double> values);

protected:
    void process() override;

private:
    ::cava_plan* m_plan = nullptr;
    double* m_in = nullptr;
    double* m_out = nullptr;
    int m_bars = 0;
    QVector<double> m_values;

    void reload();
    void initCava();
    void cleanup();
};

class CavaProvider : public AudioProvider {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int bars READ bars WRITE setBars NOTIFY barsChanged)
    Q_PROPERTY(QVector<double> values READ values NOTIFY valuesChanged)
public:
    explicit CavaProvider(QObject* parent = nullptr);
    [[nodiscard]] int bars() const;
    void setBars(int bars);
    [[nodiscard]] QVector<double> values() const;

signals:
    void barsChanged();
    void valuesChanged();

private:
    int m_bars = 0;
    QVector<double> m_values;
    void updateValues(QVector<double> values);
};

} // namespace cyberaudio

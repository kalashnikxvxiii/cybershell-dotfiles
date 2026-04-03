#pragma once
#include <QObject>
#include <qqmlintegration.h>
#include <aubio/aubio.h>
#include "audioprovider.hpp"

namespace cyberaudio {

class BeatProcessor : public AudioProcessor {
    Q_OBJECT
public:
    explicit BeatProcessor(QObject* parent = nullptr);
    ~BeatProcessor() override;

signals:
    void beat(smpl_t bpm);

protected:
    void process() override;

private:
    aubio_tempo_t* m_tempo = nullptr;
    fvec_t* m_in = nullptr;
    fvec_t* m_out = nullptr;
};

class BeatTracker : public AudioProvider {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(smpl_t bpm READ bpm NOTIFY bpmChanged)
public:
    explicit BeatTracker(QObject* parent = nullptr);
    [[nodiscard]] smpl_t bpm() const;

signals:
    void bpmChanged();
    void beat(smpl_t bpm);

private:
    smpl_t m_bpm = 120;
    void updateBpm(smpl_t bpm);
};

} // namespace cyberaudio

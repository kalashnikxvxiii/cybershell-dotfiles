#pragma once
#include <QObject>
#include <QSet>

namespace cyberaudio {

class Service : public QObject {
    Q_OBJECT
public:
    explicit Service(QObject* parent = nullptr);
    void ref(QObject* sender);
    void unref(QObject* sender);

protected:
    virtual void start() = 0;
    virtual void stop() = 0;

private:
    QSet<QObject*> m_refs;
};

} // namespace cyberaudio

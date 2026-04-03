#include "service.hpp"

namespace cyberaudio {

Service::Service(QObject* parent) : QObject(parent) {}

void Service::ref(QObject* sender) {
    if (!sender || m_refs.contains(sender)) return;
    m_refs.insert(sender);
    connect(sender, &QObject::destroyed, this, [this, sender]() {
        unref(sender);
    });
    if (m_refs.size() == 1) start();
}

void Service::unref(QObject* sender) {
    if (!sender || !m_refs.remove(sender)) return;
    if (m_refs.isEmpty()) stop();
}

} // namespace cyberaudio

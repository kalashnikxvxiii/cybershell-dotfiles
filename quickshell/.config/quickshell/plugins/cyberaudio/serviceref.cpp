#include "serviceref.hpp"

namespace cyberaudio {

ServiceRef::ServiceRef(QObject* parent) : QObject(parent) {}

ServiceRef::~ServiceRef() {
    if (m_service) m_service->unref(this);
}

Service* ServiceRef::service() const {
    return m_service;
}

void ServiceRef::setService(Service* service) {
    if (m_service == service) return;
    if (m_service) m_service->unref(this);
    m_service = service;
    if (m_service) m_service->ref(this);
    emit serviceChanged();
}

} // namespace cyberaudio

#pragma once
#include <QObject>
#include <QPointer>
#include <qqmlintegration.h>
#include "service.hpp"

namespace cyberaudio {

class ServiceRef : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(cyberaudio::Service* service READ service WRITE setService NOTIFY serviceChanged)
public:
    explicit ServiceRef(QObject* parent = nullptr);
    ~ServiceRef() override;

    [[nodiscard]] Service* service() const;
    void setService(Service* service);

signals:
    void serviceChanged();

private:
    QPointer<Service> m_service;
};

} // namespace cyberaudio

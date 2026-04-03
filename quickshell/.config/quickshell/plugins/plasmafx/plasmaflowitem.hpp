#pragma once

#include <QQuickItem>
#include <QColor>
#include <QTimer>

class PlasmaFlowItem : public QQuickItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(qreal power READ power WRITE setPower NOTIFY powerChanged)
    Q_PROPERTY(QColor baseColor READ baseColor WRITE setBaseColor NOTIFY baseColorChanged)
    Q_PROPERTY(QColor glowColor READ glowColor WRITE setGlowColor NOTIFY glowColorChanged)
    Q_PROPERTY(bool animated READ animated WRITE setAnimated NOTIFY animatedChanged)

    public:
        explicit PlasmaFlowItem(QQuickItem *parent = nullptr);
        
        qreal power() const { return m_power; }
        void setPower(qreal v);
        
        QColor baseColor() const { return m_baseColor; }
        void setBaseColor(const QColor &c);

        QColor glowColor() const { return m_glowColor; }
        void setGlowColor(const QColor &c);

        bool animated() const { return m_animated; }
        void setAnimated(bool v);

    signals:
        void powerChanged();
        void baseColorChanged();
        void glowColorChanged();
        void animatedChanged();

    protected:
        QSGNode *updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *) override;
    
    private:
        qreal m_power{0.0};
        QColor m_baseColor{255, 182, 39};       // #ffb627
        QColor m_glowColor{255, 136, 0};        // #ff8800
        bool m_animated{true};
        float m_time{0.0f};
        QTimer m_timer;
};
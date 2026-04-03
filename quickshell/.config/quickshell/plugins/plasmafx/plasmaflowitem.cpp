#include "plasmaflowitem.hpp"
#include "plasmaflowmaterial.hpp"

#include <QSGGeometryNode>
#include <QSGGeometry>

PlasmaFlowItem::PlasmaFlowItem(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents, true);

    m_timer.setInterval(16);        // ~60fps
    connect(&m_timer, &QTimer::timeout, this, [this]() {
        m_time += 0.016f;
        update();
    });

    if (m_animated)
        m_timer.start();
}

void PlasmaFlowItem::setPower(qreal v) {
    v = qBound(0.0, v, 1.0);
    if (qFuzzyCompare(m_power, v)) return;
    m_power = v;
    emit powerChanged();
    update();
}

void PlasmaFlowItem::setBaseColor(const QColor &c) {
    if (m_baseColor == c) return;
    m_baseColor = c;
    emit baseColorChanged();
    update();
}

void PlasmaFlowItem::setGlowColor(const QColor &c) {
    if (m_glowColor == c) return;
    m_glowColor = c;
    emit glowColorChanged();
    update();
}

void PlasmaFlowItem::setAnimated(bool v) {
    if (m_animated == v) return;
    m_animated = v;
    if (v) m_timer.start();
    else m_timer.stop();
    emit animatedChanged();
}

QSGNode *PlasmaFlowItem::updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *) {
    auto *node = static_cast<QSGGeometryNode *>(oldNode);

    if (!node) {
        node = new QSGGeometryNode;

        auto *geometry = new QSGGeometry(QSGGeometry::defaultAttributes_TexturedPoint2D(), 4);
        geometry->setDrawingMode(QSGGeometry::DrawTriangleStrip);
        node->setGeometry(geometry);
        node->setFlag(QSGNode::OwnsGeometry);

        auto *material = new PlasmaFlowMaterial;
        node->setMaterial(material);
        node->setFlag(QSGNode::OwnsMaterial);
    }

    // Update geometry to fill item
    auto *verts = node->geometry()->vertexDataAsTexturedPoint2D();
    const float w = static_cast<float>(width());
    const float h = static_cast<float>(height());
    // Triangle strip: BL, TL, BR, TR
    verts[0].set(0, h, 0, 1);
    verts[1].set(0, 0, 0, 0);
    verts[2].set(w, h, 1, 1);
    verts[3].set(w, 0, 1, 0);
    node->markDirty(QSGNode::DirtyGeometry);

    // Update material uniforms
    auto *mat = static_cast<PlasmaFlowMaterial *>(node->material());
    mat->time = m_time;
    mat->power = static_cast<float>(m_power);
    mat->resolution = QVector2D(w, h);
    mat->baseColor = QVector3D(
        static_cast<float>(m_baseColor.redF()),
        static_cast<float>(m_baseColor.greenF()),
        static_cast<float>(m_baseColor.blueF()));
    mat->glowColor = QVector3D(
        static_cast<float>(m_glowColor.redF()),
        static_cast<float>(m_glowColor.greenF()),
        static_cast<float>(m_glowColor.blueF()));
    node->markDirty(QSGNode::DirtyMaterial);

    return node;
}
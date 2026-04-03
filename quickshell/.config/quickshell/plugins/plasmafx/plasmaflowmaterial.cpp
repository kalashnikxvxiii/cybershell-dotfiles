#include "plasmaflowmaterial.hpp"
#include <cstring>

QSGMaterialType *PlasmaFlowMaterial::type() const {
    static QSGMaterialType t;
    return &t;
}

QSGMaterialShader *PlasmaFlowMaterial::createShader(QSGRendererInterface::RenderMode) const {
    return new PlasmaFlowShader;
}

int PlasmaFlowMaterial::compare (const QSGMaterial *other) const {
    auto *o = static_cast<const PlasmaFlowMaterial *>(other);
    if (time != o->time) return time < o->time ? -1 : 1;
    if (power != o->power) return power < o->power ? -1 : 1;
    return 0;
}

PlasmaFlowShader::PlasmaFlowShader() {
    setShaderFileName(VertexStage,
        QStringLiteral(":/PlasmaFX/shaders/plasmaflow.vert.qsb"));
    setShaderFileName(FragmentStage,
        QStringLiteral(":/PlasmaFX/shaders/plasmaflow.frag.qsb"));
}

bool PlasmaFlowShader::updateUniformData(RenderState &state,
                                        QSGMaterial *newMaterial,
                                        QSGMaterial * /*oldMaterial*/) {
    auto *mat = static_cast<PlasmaFlowMaterial *>(newMaterial);
    QByteArray *buf = state.uniformData();

    // UBO layout (std140):
    // offset 0: mat4 qt_Matrix         (64 bytes, provided by Qt)
    // offset 64: float u_time          (4)
    // offset 68: float u_power         (4)
    // offset 72: vec2 u_resolution     (8)
    // offset 80: vec3 u_baseColor      (12)
    // offset 92: float _pad0           (4)
    // offset 96: vec3 u_glowColor      (12)
    // offset 108: float _pad1          (4)
    // total: 112 bytes

    if (state.isMatrixDirty()) {
        const QMatrix4x4 m = state.combinedMatrix();
        memcpy(buf->data(), m.constData(), 64);
    }

    memcpy(buf->data() + 64, &mat->time, 4);
    memcpy(buf->data() + 68, &mat->power, 4);
    float res[2] = { mat->resolution.x(), mat->resolution.y() };
    memcpy(buf->data() + 72, res, 8);
    float bc[3] = { mat->baseColor.x(), mat->baseColor.y(), mat->baseColor.z() };
    memcpy(buf->data() + 80, bc, 12);
    float gc[3] = { mat->glowColor.x(), mat->glowColor.y(), mat->glowColor.z() };
    memcpy(buf->data() + 96, gc, 12);

    return true;
}
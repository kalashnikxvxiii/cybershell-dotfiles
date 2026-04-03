#pragma once

#include <QSGMaterial>
#include <QSGMaterialShader>
#include <QVector2D>
#include <QVector3D>

class PlasmaFlowMaterial : public QSGMaterial {
public:
    QSGMaterialType *type() const override;
    QSGMaterialShader *createShader(QSGRendererInterface::RenderMode) const override;
    int compare(const QSGMaterial *other) const override;

    float time{0.0f};
    float power{0.0f};
    QVector2D resolution{1.0f, 1.0f};
    QVector3D baseColor{1.0f, 0.714f, 0.153f};
    QVector3D glowColor{1.0f, 0.533f, 0.0f};
};

class PlasmaFlowShader : public QSGMaterialShader {
public:
    PlasmaFlowShader();

    bool updateUniformData(RenderState &state,
                            QSGMaterial *newMaterial,
                            QSGMaterial *oldMaterial) override;
};
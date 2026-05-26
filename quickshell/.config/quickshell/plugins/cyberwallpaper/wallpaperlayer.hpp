#pragma once

#include <QQuickPaintedItem>
#include <QImage>
#include <QString>
#include <QTimer>

class QMovie;
class QPainterPath;

class WallpaperLayer : public QQuickPaintedItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(bool backdropBlur READ backdropBlur WRITE setBackdropBlur NOTIFY backdropBlurChanged)
    Q_PROPERTY(qreal backdropDarken READ backdropDarken WRITE setBackdropDarken NOTIFY backdropDarkenChanged)
    Q_PROPERTY(qreal backdropSaturation READ backdropSaturation WRITE setBackdropSaturation NOTIFY backdropSaturationChanged)
    Q_PROPERTY(int blurRadius READ blurRadius WRITE setBlurRadius NOTIFY blurRadiusChanged)

    // Transition properties (default from AWWW_* env vars)
    Q_PROPERTY(QString transitionType READ transitionType WRITE setTransitionType NOTIFY transitionTypeChanged)
    Q_PROPERTY(qreal transitionDuration READ transitionDuration WRITE setTransitionDuration NOTIFY transitionDurationChanged)
    Q_PROPERTY(int transitionFps READ transitionFps WRITE setTransitionFps NOTIFY transitionFpsChanged)
    Q_PROPERTY(int transitionStep READ transitionStep WRITE setTransitionStep NOTIFY transitionStepChanged)
    Q_PROPERTY(qreal transitionAngle READ transitionAngle WRITE setTransitionAngle NOTIFY transitionAngleChanged)
    Q_PROPERTY(QString transitionPos READ transitionPos WRITE setTransitionPos NOTIFY transitionPosChanged)
    Q_PROPERTY(QString transitionBezier READ transitionBezier WRITE setTransitionBezier NOTIFY transitionBezierChanged)
    Q_PROPERTY(QString transitionWave READ transitionWave WRITE setTransitionWave NOTIFY transitionWaveChanged)
    Q_PROPERTY(bool invertY READ invertY WRITE setInvertY NOTIFY invertYChanged)

public:
    explicit WallpaperLayer(QQuickItem *parent = nullptr);
    ~WallpaperLayer() override;

    QString source() const { return m_source; }
    void setSource(const QString &path);

    bool backdropBlur() const { return m_backdropBlur; }
    void setBackdropBlur(bool b);

    qreal backdropDarken() const { return m_backdropDarken; }
    void setBackdropDarken(qreal d);

    qreal backdropSaturation() const { return m_backdropSaturation; }
    void setBackdropSaturation(qreal s);

    int blurRadius() const { return m_blurRadius; }
    void setBlurRadius(int r);

    QString transitionType() const { return m_transitionType; }
    void setTransitionType(const QString &t);

    qreal transitionDuration() const { return m_transitionDuration; }
    void setTransitionDuration(qreal d);

    int transitionFps() const { return m_transitionFps; }
    void setTransitionFps(int fps);

    int transitionStep() const { return m_transitionStep; }
    void setTransitionStep(int s);

    qreal transitionAngle() const { return m_transitionAngle; }
    void setTransitionAngle(qreal a);

    QString transitionPos() const { return m_transitionPos; }
    void setTransitionPos(const QString &p);

    QString transitionBezier() const { return m_transitionBezier; }
    void setTransitionBezier(const QString &b);

    QString transitionWave() const { return m_transitionWave; }
    void setTransitionWave(const QString &w);

    bool invertY() const { return m_invertY; }
    void setInvertY(bool i);

    void paint(QPainter *painter) override;

signals:
    void sourceChanged();
    void backdropBlurChanged();
    void backdropDarkenChanged();
    void backdropSaturationChanged();
    void blurRadiusChanged();
    void transitionTypeChanged();
    void transitionDurationChanged();
    void transitionFpsChanged();
    void transitionStepChanged();
    void transitionAngleChanged();
    void transitionPosChanged();
    void transitionBezierChanged();
    void transitionWaveChanged();
    void invertYChanged();

private slots:
    void onMovieFrameChanged();
    void onTransitionTick();

private:
    void clearSource();
    void loadSource();
    void rebuildBackdrop();
    void startTransition();
    void readEnvDefaults();
    QString resolveTransitionType(const QString &type) const;
    qreal applyBezier(qreal x) const;
    void drawWallpaper(QPainter *painter, const QImage &fg, const QImage &bd, const QRectF &target) const;
    void drawWithMask(QPainter *painter, const QImage &fg, const QImage &bd, const QRectF &target, const QString &type, qreal progress);

    QImage gaussianBlur(const QImage &src, int radius, qreal darken, qreal saturation) const;

    QString m_source;
    QImage m_foreground;
    QImage m_backdrop;
    QMovie *m_movie {nullptr};

    bool m_backdropBlur {true};
    qreal m_backdropDarken {0.15};
    qreal m_backdropSaturation {-0.2};
    int m_blurRadius {40};

    // Transition config
    QString m_transitionType {"simple"};
    qreal m_transitionDuration {3.0};
    int m_transitionFps {30};
    int m_transitionStep {90};
    qreal m_transitionAngle {45.0};
    QString m_transitionPos {"center"};
    QString m_transitionBezier {"0.54,0,0.34,0.99"};
    QString m_transitionWave {"20,20"};
    bool m_invertY {false};

    // Transition state
    QImage m_oldForeground;
    QImage m_oldBackdrop;
    qreal m_transitionProgress {1.0};
    qint64 m_transitionStartTime {0};
    QString m_activeTransition;   // resolved (e.g. "any" -> "left")
    QTimer *m_transitionTimer {nullptr};
    qreal m_bezierP1x{0.54}, m_bezierP1y{0.0}, m_bezierP2x{0.34}, m_bezierP2y{0.99};
};

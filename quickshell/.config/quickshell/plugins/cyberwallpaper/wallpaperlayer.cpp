#include "wallpaperlayer.hpp"

#include <QPainter>
#include <QPainterPath>
#include <QMovie>
#include <QFileInfo>
#include <QImageReader>
#include <QVector>
#include <QDateTime>
#include <QtMath>
#include <QRandomGenerator>

WallpaperLayer::WallpaperLayer(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setRenderTarget(QQuickPaintedItem::FramebufferObject);
    readEnvDefaults();

    m_transitionTimer = new QTimer(this);
    connect(m_transitionTimer, &QTimer::timeout, this, &WallpaperLayer::onTransitionTick);
}

WallpaperLayer::~WallpaperLayer()
{
    clearSource();
}

void WallpaperLayer::readEnvDefaults()
{
    auto envStr = [](const char *name, const QString &def) -> QString {
        QByteArray v = qgetenv(name);
        return v.isEmpty() ? def : QString::fromUtf8(v);
    };
    auto envDouble = [](const char *name, qreal def) -> qreal {
        QByteArray v = qgetenv(name);
        bool ok = false;
        qreal r = v.toDouble(&ok);
        return ok ? r : def;
    };
    auto envInt = [](const char *name, int def) -> int {
        QByteArray v = qgetenv(name);
        bool ok = false;
        int r = v.toInt(&ok);
        return ok ? r : def;
    };
    auto envBool = [](const char *name, bool def) -> bool {
        QByteArray v = qgetenv(name);
        if (v.isEmpty()) return def;
        return v == "1" || v.toLower() == "true";
    };

    m_transitionType = envStr("AWWW_TRANSITION", "fade");
    m_transitionDuration = envDouble("AWWW_TRANSITION_DURATION", 3.0);
    m_transitionFps = envInt("AWWW_TRANSITION_FPS", 30);
    int defaultStep = (m_transitionType == "fade") ? 2 : 90;
    m_transitionStep = envInt("AWWW_TRANSITION_STEP", defaultStep);
    m_transitionAngle = envDouble("AWWW_TRANSITION_ANGLE", 45.0);
    m_transitionPos = envStr("AWWW_TRANSITION_POS", "center");
    m_transitionBezier = envStr("AWWW_TRANSITION_BEZIER", "0.54,0,0.34,0.99");
    m_transitionWave = envStr("AWWW_TRANSITION_WAVE", "20,20");
    m_invertY = envBool("INVERT_Y", false);

    QStringList parts = m_transitionBezier.split(',');
    if (parts.size() == 4) {
        m_bezierP1x = parts[0].toDouble();
        m_bezierP1y = parts[1].toDouble();
        m_bezierP2x = parts[2].toDouble();
        m_bezierP2y = parts[3].toDouble();
    }
}

void WallpaperLayer::setSource(const QString &path)
{
    if (m_source == path) return;
    m_source = path;
    emit sourceChanged();

    if (!m_foreground.isNull()) {
        m_oldForeground = m_foreground.copy();
        m_oldBackdrop = m_backdrop.copy();
    }

    loadSource();
    startTransition();
    update();
}

void WallpaperLayer::setBackdropBlur(bool b)
{
    if (m_backdropBlur == b) return;
    m_backdropBlur = b;
    emit backdropBlurChanged();
    rebuildBackdrop();
    update();
}

void WallpaperLayer::setBackdropDarken(qreal d)
{
    if (qFuzzyCompare(m_backdropDarken, d)) return;
    m_backdropDarken = d;
    emit backdropDarkenChanged();
    rebuildBackdrop();
    update();
}

void WallpaperLayer::setBackdropSaturation(qreal s)
{
    if (qFuzzyCompare(m_backdropSaturation, s)) return;
    m_backdropSaturation = s;
    emit backdropSaturationChanged();
    rebuildBackdrop();
    update();
}

void WallpaperLayer::setBlurRadius(int r)
{
    if (m_blurRadius == r) return;
    m_blurRadius = qMax(1, r);
    emit blurRadiusChanged();
    rebuildBackdrop();
    update();
}

void WallpaperLayer::setTransitionType(const QString &t) {
    if (m_transitionType == t) return;
    m_transitionType = t;
    emit transitionTypeChanged();
}
void WallpaperLayer::setTransitionDuration(qreal d) {
    if (qFuzzyCompare(m_transitionDuration, d)) return;
    m_transitionDuration = d;
    emit transitionDurationChanged();
}
void WallpaperLayer::setTransitionFps(int fps) {
    if (m_transitionFps == fps) return;
    m_transitionFps = fps;
    emit transitionFpsChanged();
}
void WallpaperLayer::setTransitionStep(int s) {
    if (m_transitionStep == s) return;
    m_transitionStep = s;
    emit transitionStepChanged();
}
void WallpaperLayer::setTransitionAngle(qreal a) {
    if (qFuzzyCompare(m_transitionAngle, a)) return;
    m_transitionAngle = a;
    emit transitionAngleChanged();
}
void WallpaperLayer::setTransitionPos(const QString &p) {
    if (m_transitionPos == p) return;
    m_transitionPos = p;
    emit transitionPosChanged();
}
void WallpaperLayer::setTransitionBezier(const QString &b) {
    if (m_transitionBezier == b) return;
    m_transitionBezier = b;
    QStringList parts = b.split(',');
    
    if (parts.size() == 4) {
        m_bezierP1x = parts[0].toDouble();
        m_bezierP1y = parts[1].toDouble();
        m_bezierP2x = parts[2].toDouble();
        m_bezierP2y = parts[3].toDouble();
    }
    emit transitionBezierChanged();
}
void WallpaperLayer::setTransitionWave(const QString &w) {
    if (m_transitionWave == w) return;
    m_transitionWave = w;
    emit transitionWaveChanged();
}
void WallpaperLayer::setInvertY(bool i) {
    if (m_invertY == i) return;
    m_invertY = i;
    emit invertYChanged();
}

void WallpaperLayer::clearSource()
{
    if (m_movie) {
        m_movie->stop();
        m_movie->deleteLater();
        m_movie = nullptr;
    }
    m_foreground = QImage();
    m_backdrop = QImage();
}

void WallpaperLayer::loadSource()
{
    clearSource();

    if (m_source.isEmpty()) {
        update();
        return;
    }

    QFileInfo fi(m_source);
    QString ext = fi.suffix().toLower();
    bool isGif = (ext == "gif");

    if (isGif) {
        m_movie = new QMovie(m_source, QByteArray(), this);
        if (!m_movie->isValid()) {
            m_movie->deleteLater();
            m_movie = nullptr;
            return;
        }
        connect(m_movie, &QMovie::frameChanged, this, &WallpaperLayer::onMovieFrameChanged);
        m_movie->start();
        m_foreground = m_movie->currentImage();
    } else {
        QImageReader reader(m_source);
        reader.setAutoTransform(true);
        m_foreground = reader.read();
    }

    rebuildBackdrop();
}

void WallpaperLayer::onMovieFrameChanged()
{
    if (m_movie) {
        m_foreground = m_movie->currentImage();
        update();
    }
}

void WallpaperLayer::rebuildBackdrop()
{
    if (m_foreground.isNull() || !m_backdropBlur) {
        m_backdrop = QImage();
        return;
    }
    m_backdrop = gaussianBlur(m_foreground, m_blurRadius, m_backdropDarken, m_backdropSaturation);
}

QImage WallpaperLayer::gaussianBlur(const QImage &src, int radius, qreal darken, qreal saturation) const
{
    if (src.isNull()) return QImage();

    constexpr int kMaxBlurDim = 480;
    QImage small = src.scaled(kMaxBlurDim, kMaxBlurDim,
                              Qt::KeepAspectRatio, Qt::SmoothTransformation)
                       .convertToFormat(QImage::Format_ARGB32_Premultiplied);

    auto boxBlur = [](QImage &img, int r) {
        if (r < 1) return;
        const int w = img.width();
        const int h = img.height();
        for (int y = 0; y < h; ++y) {
            auto *line = reinterpret_cast<QRgb*>(img.scanLine(y));
            QVector<QRgb> tmp(w);
            for (int x = 0; x < w; ++x) {
                int rr = 0, gg = 0, bb = 0, count = 0;
                for (int k = -r; k <= r; ++k) {
                    int xi = qBound(0, x + k, w - 1);
                    rr += qRed(line[xi]);
                    gg += qGreen(line[xi]);
                    bb += qBlue(line[xi]);
                    ++count;
                }
                tmp[x] = qRgb(rr / count, gg / count, bb / count);
            }
            memcpy(line, tmp.constData(), w * sizeof(QRgb));
        }
        QVector<QRgb> col(h);
        for (int x = 0; x < w; ++x) {
            for (int y = 0; y < h; ++y) {
                col[y] = reinterpret_cast<QRgb*>(img.scanLine(y))[x];
            }
            QVector<QRgb> tmp(h);
            for (int y = 0; y < h; ++y) {
                int rr = 0, gg = 0, bb = 0, count = 0;
                for (int k = -r; k <= r; ++k) {
                    int yi = qBound(0, y + k, h - 1);
                    rr += qRed(col[yi]);
                    gg += qGreen(col[yi]);
                    bb += qBlue(col[yi]);
                    ++count;
                }
                tmp[y] = qRgb(rr / count, gg / count, bb / count);
            }
            for (int y = 0; y < h; ++y) {
                reinterpret_cast<QRgb*>(img.scanLine(y))[x] = tmp[y];
            }
        }
    };

    boxBlur(small, qMax(1, radius / 8));
    boxBlur(small, qMax(1, radius / 8));

    if (!qFuzzyIsNull(darken) || !qFuzzyIsNull(saturation)) {
        const int w = small.width();
        const int h = small.height();
        const qreal mulDark = 1.0 - darken;
        for (int y = 0; y < h; ++y) {
            auto *line = reinterpret_cast<QRgb*>(small.scanLine(y));
            for (int x = 0; x < w; ++x) {
                int r = qRed(line[x]);
                int g = qGreen(line[x]);
                int b = qBlue(line[x]);
                qreal gray = 0.299 * r + 0.587 * g + 0.114 * b;
                r = qBound(0, int((r - gray) * (1.0 + saturation) + gray), 255);
                g = qBound(0, int((g - gray) * (1.0 + saturation) + gray), 255);
                b = qBound(0, int((b - gray) * (1.0 + saturation) + gray), 255);
                r = qBound(0, int(r * mulDark), 255);
                g = qBound(0, int(g * mulDark), 255);
                b = qBound(0, int(b * mulDark), 255);
                line[x] = qRgb(r, g, b);
            }
        }
    }

    return small;
}

void WallpaperLayer::startTransition()
{
    m_activeTransition = resolveTransitionType(m_transitionType);
    bool hasOld = !m_oldForeground.isNull();
    bool wantsAnim = hasOld && m_activeTransition != "none" && m_transitionDuration > 0;

    if (wantsAnim) {
        m_transitionProgress = 0.0;
        m_transitionStartTime = QDateTime::currentMSecsSinceEpoch();
        m_transitionTimer->start(1000 / qMax(1, m_transitionFps));
    } else {
        m_transitionProgress = 1.0;
        m_oldForeground = QImage();
        m_oldBackdrop = QImage();
        m_transitionTimer->stop();
    }
}

QString WallpaperLayer::resolveTransitionType(const QString &type) const
{
    // Legacy migration: simple->fade (with bezier), center->grow (pos center default)
    if (type == "simple") return "fade";
    if (type == "center") return "grow";

    if (type == "random") {
        static const QStringList all = {
            "fade", "left", "right", "top", "bottom",
            "wipe", "wave", "grow", "outer"
        };
        return all[QRandomGenerator::global()->bounded(all.size())];
    }
    if (type == "rand-wipe") {
        static const QStringList dirs = {"left", "right", "top", "bottom"};
        return dirs[QRandomGenerator::global()->bounded(dirs.size())];
    }
    return type;
}

qreal WallpaperLayer::applyBezier(qreal x) const
{
    // CSS-style cubic bezier easing
    // x(t) = 3(1-t)²t·P1x + 3(1-t)t²·P2x + t³  (P0=(0,0), P2=(1,1))
    // Solve t such that x(t) == x via Newton's method, then return y(t)
    qreal t = x;    // initial guess
    for (int i = 0; i < 12; i++) {
        qreal mt = 1.0 - t;
        qreal xAtT = 3.0*mt*mt*t*m_bezierP1x
                    + 3.0*mt*t*t*m_bezierP2x
                    + t*t*t;
        qreal dxdt = 3.0*mt*mt*m_bezierP1x
                    + 6.0*mt*t*(m_bezierP2x - m_bezierP1x)
                    + 3.0*t*t*(1.0 - m_bezierP2x);
        qreal err = xAtT - x;
        if (qAbs(err) < 1e-5) break;
        if (qAbs(dxdt) < 1e-6) break;
        t -= err / dxdt;
        t = qBound(0.0, t, 1.0);
    }
    qreal mt = 1.0 - t;
    return 3.0*mt*mt*t*m_bezierP1y
        + 3.0*mt*t*t*m_bezierP2y
        + t*t*t;
}

void WallpaperLayer::onTransitionTick()
{
    qint64 elapsed = QDateTime::currentMSecsSinceEpoch() - m_transitionStartTime;
    qreal raw = elapsed / (m_transitionDuration * 1000.0);

    if (raw >= 1.0) {
        m_transitionProgress = 1.0;
        m_transitionTimer->stop();
        m_oldForeground = QImage();
        m_oldBackdrop = QImage();
    } else {
        if (m_activeTransition == "fade") {
            m_transitionProgress = applyBezier(raw);
        } else {
            m_transitionProgress = raw;
        }
    }
    update();
}

void WallpaperLayer::drawWallpaper(QPainter *painter, const QImage &fg, const QImage &bd, const QRectF &target) const
{
    if (fg.isNull()) return;

    if (m_backdropBlur && !bd.isNull()) {
        QSizeF cover = QSizeF(bd.size())
                            .scaled(target.size(), Qt::KeepAspectRatioByExpanding);
        QRectF coverRect(
            target.center().x() - cover.width() / 2,
            target.center().y() - cover.height() / 2,
            cover.width(), cover.height()
        );
        painter->drawImage(coverRect, bd);
    } else {
        painter->fillRect(target, Qt::black);
    }

    QSizeF fit = QSizeF(fg.size())
                        .scaled(target.size(), Qt::KeepAspectRatio);
    QRectF fitRect(
        target.center().x() - fit.width() / 2,
        target.center().y() - fit.height() / 2,
        fit.width(), fit.height()
    );
    painter->drawImage(fitRect, fg);
}

void WallpaperLayer::drawWithMask(QPainter *painter, const QImage &fg, const QImage &bd, const QRectF &target, const QString &type, qreal progress)
{
    // --- Alpha-based (simple, fade) ---
    if (type == "fade") {
        painter->setOpacity(progress);
        drawWallpaper(painter, fg, bd, target);
        painter->setOpacity(1.0);
        return;
    }

    QPainterPath clipPath;
    bool useClip = false;
    const QPointF c = target.center();
    const qreal diag = qSqrt(target.width() * target.width()
                            + target.height() * target.height());
    
    // --- Directional: left/right/top/bottom = wipe a specific angle ---
    if (type == "left" || type == "right" || type == "top"
        || type == "bottom" || type == "wipe") {
        qreal angle;
        if      (type == "right")   angle = 0;
        else if (type == "top")     angle = 90;
        else if (type == "left")    angle = 180;
        else if (type == "bottom")  angle = 270;
        else                        angle = m_transitionAngle;

        const qreal rad = qDegreesToRadians(angle);
        const QPointF dir(-qCos(rad), qSin(rad));

        const QPointF corners[] = {
            target.topLeft(), target.topRight(),
            target.bottomRight(), target.bottomLeft()
        };
        qreal minP = std::numeric_limits<qreal>::max();
        qreal maxP = std::numeric_limits<qreal>::lowest();
        for (const auto &corner : corners) {
            const QPointF rel = corner - c;
            const qreal p = rel.x() * dir.x() + rel.y() * dir.y();
            minP = qMin(minP, p);
            maxP = qMax(maxP, p);
        }
        const qreal linePos = minP + progress * (maxP - minP);

        QPolygonF polygon;
        for (int i = 0; i < 4; ++i) {
            const QPointF a = corners[i];
            const QPointF b = corners[(i + 1) % 4];
            const qreal pa = (a - c).x() * dir.x() + (a - c).y() * dir.y();
            const qreal pb = (b - c).x() * dir.x() + (b - c).y() * dir.y();

            if (pa < linePos) polygon << a;

            if ((pa < linePos) != (pb < linePos) && !qFuzzyCompare(pa, pb)) {
                const qreal t = (linePos - pa) / (pb - pa);
                polygon << (a + t * (b - a));
            }
        }
        if (polygon.size() >= 3) {
            clipPath.addPolygon(polygon);
            clipPath.closeSubpath();
            useClip = true;
        }
    }

    // -- Radial: grow / center / outer --
    else if (type == "grow" || type == "outer") {
        QPointF origin = c;
        const QStringList parts = m_transitionPos.split(',');
        if (parts.size() == 2) {
            bool xOk = false, yOk = false;
            qreal x = parts[0].toDouble(&xOk);
            qreal y = parts[1].toDouble(&yOk);
            if (xOk && yOk) {
                // floats in [0,1] = percentage of target; else pixel
                if (x >= 0.0 && x <= 1.0) x = target.left() + x * target.width();
                if (y >= 0.0 && y <= 1.0) y = target.top()  + y * target.height();
                if (m_invertY) y = target.bottom() - (y - target.top());
                origin = QPointF(x, y);
            }
        }

        // Distance from origin to the farthest corner (so progress=1 covers full screen)
        qreal maxR = 0;
        for (const auto &corner : {target.topLeft(), target.topRight(),
                                    target.bottomLeft(), target.bottomRight()}) {
            maxR = qMax(maxR, QLineF(origin, corner).length());
        }

        if (type == "outer") {
            // Ring: the older image's "hole" shrink thru the center
            const qreal r = maxR * (1.0 - progress);
            QPainterPath outer;
            outer.addRect(target);
            QPainterPath inner;
            inner.addEllipse(origin, r, r);
            clipPath = outer.subtracted(inner);
        } else {
            const qreal r = maxR * progress;
            clipPath.addEllipse(origin, r, r);
        }
        useClip = true;
    }
    // --- Wave: like wipe but with with sinusoide border ---
    else if (type == "wave") {
        const qreal rad = qDegreesToRadians(m_transitionAngle);
        const QPointF dir(-qCos(rad), qSin(rad));
        const QPointF perp(-dir.y(), dir.x());

        qreal amplitude = 20, period = 20;
        const QStringList wp = m_transitionWave.split(',');
        if (wp.size() == 2) {
            amplitude = wp[0].toDouble();
            period    = wp[1].toDouble();
            if (period <= 0) period = 20;
        }

        const QPointF corners[] = {
            target.topLeft(), target.topRight(),
            target.bottomRight(), target.bottomLeft()
        };
        qreal minP = std::numeric_limits<qreal>::max();
        qreal maxP = std::numeric_limits<qreal>::lowest();
        for (const auto &corner : corners) {
            const QPointF rel = corner - c;
            const qreal p = rel.x() * dir.x() + rel.y() * dir.y();
            minP = qMin(minP, p);
            maxP = qMax(maxP, p);
        }
        // Extra range to cover the wave's range
        const qreal linePos = (minP - amplitude)
                            + progress * ((maxP - minP) + 2 * amplitude);
        const int nSamples = qMax(64, int(diag / 4));
        QPolygonF polygon;
        QPointF firstWave, lastWave;
        for (int i = 0; i <= nSamples; ++i) {
            const qreal s = -diag / 2.0 + (qreal(i) / nSamples) * diag;
            const qreal off = amplitude * qSin(2.0 * M_PI * s / period);
            const QPointF pt = c + (linePos + off) * dir + s * perp;
            if (i == 0)         firstWave = pt;
            if (i == nSamples)  lastWave = pt;
            polygon << pt;
        }
        // Extends the edges in "behind" direction (opposite to dir) to close the region
        const QPointF behind = -dir * diag * 2.0;
        polygon.prepend(firstWave + behind);
        polygon.append(lastWave + behind);

        clipPath.addPolygon(polygon);
        clipPath.closeSubpath();
        useClip = true;
    }
    // --- Fallback per type not recognized: alpha fade ---
    else {
        painter->setOpacity(progress);
        drawWallpaper(painter, fg, bd, target);
        painter->setOpacity(1.0);
        return;
    }

    if (useClip) {
        painter->save();
        painter->setClipPath(clipPath);
        drawWallpaper(painter, fg, bd, target);
        painter->restore();
    }
}

void WallpaperLayer::paint(QPainter *painter)
{
    if (m_foreground.isNull() && m_oldForeground.isNull()) return;

    const QRectF target = boundingRect();
    painter->setRenderHint(QPainter::SmoothPixmapTransform);

    if (m_transitionProgress >= 1.0 || m_oldForeground.isNull()) {
        drawWallpaper(painter, m_foreground, m_backdrop, target);
        return;
    }

    drawWallpaper(painter, m_oldForeground, m_oldBackdrop, target);
    drawWithMask(painter, m_foreground, m_backdrop, target, m_activeTransition, m_transitionProgress);
}

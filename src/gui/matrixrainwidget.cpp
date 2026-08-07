#include "matrixrainwidget.h"

#include <QPainter>
#include <QRandomGenerator>
#include <QResizeEvent>

#include "base/global.h"

namespace
{
    // Matrix character set: digits + uppercase + Katakana block
    const QString CHARS =
        u"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        u"ァアィイゥウェエォオ"
        u"カガキギクグケゲコゴ"
        u"サザシジスズセゼソゾ"
        u"チヂッツヅテデトドナ"_s;

    const QColor COL_HEAD  { 180, 255, 180 };   // near-white green head
    const QColor COL_BRIGHT{ 0,   255,  65 };   // bright green body
    const QColor COL_MID   { 0,   180,  40 };
    const QColor COL_DIM   { 0,    90,  20 };
    const QColor COL_FADE  { 0,    35,   8 };
    const QColor COL_BG    { 0,     4,   0 };   // near-black green tint
}

MatrixRainWidget::MatrixRainWidget(QWidget *parent)
    : QWidget(parent)
    , m_timer(new QTimer(this))
{
    setAttribute(Qt::WA_TransparentForMouseEvents);
    setAttribute(Qt::WA_NoSystemBackground);
    setAttribute(Qt::WA_TranslucentBackground);
    setFocusPolicy(Qt::NoFocus);

    connect(m_timer, &QTimer::timeout, this, &MatrixRainWidget::tick);
    m_timer->start(55); // ~18 fps — enough for the effect without hammering CPU
}

QChar MatrixRainWidget::randomChar() const
{
    return CHARS[QRandomGenerator::global()->bounded(CHARS.size())];
}

void MatrixRainWidget::initColumns()
{
    if (m_charW <= 0 || m_charH <= 0) return;
    m_cols = width()  / m_charW;
    m_rows = height() / m_charH + 1;

    m_columns.resize(m_cols);
    for (auto &col : m_columns)
    {
        col.length = QRandomGenerator::global()->bounded(8, 30);
        col.speed  = QRandomGenerator::global()->bounded(1, 3);
        // stagger starts so columns don't all drop at once
        col.headY  = -QRandomGenerator::global()->bounded(m_rows);
        col.chars.resize(col.length);
        for (auto &ch : col.chars)
            ch = randomChar();
    }
}

void MatrixRainWidget::resizeEvent(QResizeEvent *event)
{
    QWidget::resizeEvent(event);
    m_buffer = QImage(size(), QImage::Format_ARGB32_Premultiplied);
    m_buffer.fill(Qt::transparent);
    initColumns();
}

void MatrixRainWidget::tick()
{
    if (m_cols == 0 || m_rows == 0) return;

    // Fade the existing buffer rather than clearing — gives the trail effect
    QPainter fade(&m_buffer);
    fade.setCompositionMode(QPainter::CompositionMode_Source);
    fade.fillRect(m_buffer.rect(), QColor(COL_BG.red(), COL_BG.green(), COL_BG.blue(), 18));
    fade.end();

    QPainter p(&m_buffer);
    p.setFont(QFont(u"Menlo"_s, 11, QFont::Bold));

    for (int c = 0; c < m_cols && c < m_columns.size(); ++c)
    {
        Column &col = m_columns[c];
        col.headY += col.speed;

        // Randomly mutate a char in the trail
        if (!col.chars.isEmpty())
        {
            const int idx = QRandomGenerator::global()->bounded(col.chars.size());
            col.chars[idx] = randomChar();
        }

        // Draw trail: head at headY, trail extends upward
        for (int t = 0; t < col.length; ++t)
        {
            const int row = col.headY - t;
            if (row < 0 || row >= m_rows) continue;

            QColor color;
            if (t == 0)
                color = COL_HEAD;
            else if (t < 3)
                color = COL_BRIGHT;
            else if (t < 8)
                color = COL_MID;
            else if (t < 16)
                color = COL_DIM;
            else
                color = COL_FADE;

            p.setPen(color);
            const QChar ch = (t < col.chars.size()) ? col.chars[t] : randomChar();
            p.drawText(c * m_charW, row * m_charH + m_charH - 2, QString(ch));
        }

        // Reset column when head has scrolled off screen
        if (col.headY - col.length > m_rows)
        {
            col.length = QRandomGenerator::global()->bounded(8, 30);
            col.speed  = QRandomGenerator::global()->bounded(1, 3);
            col.headY  = -QRandomGenerator::global()->bounded(4, 12);
            col.chars.resize(col.length);
            for (auto &ch : col.chars)
                ch = randomChar();
        }
    }

    update();
}

void MatrixRainWidget::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.drawImage(0, 0, m_buffer);
}

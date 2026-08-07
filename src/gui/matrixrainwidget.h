#pragma once

#include <QImage>
#include <QTimer>
#include <QVector>
#include <QWidget>

class MatrixRainWidget final : public QWidget
{
    Q_OBJECT

public:
    explicit MatrixRainWidget(QWidget *parent = nullptr);

protected:
    void paintEvent(QPaintEvent *event) override;
    void resizeEvent(QResizeEvent *event) override;

private:
    void tick();
    void initColumns();
    QChar randomChar() const;

    struct Column
    {
        int headY;    // current head row (can be negative = above screen)
        int speed;    // rows advanced per tick
        int length;   // trail length in rows
        QVector<QChar> chars; // one char per visible row in trail
    };

    QTimer *m_timer;
    QVector<Column> m_columns;
    QImage m_buffer;

    int m_charW = 13;
    int m_charH = 18;
    int m_cols  = 0;
    int m_rows  = 0;
};

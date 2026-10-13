using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

namespace RinUsage {
    public static class TrayIconArtwork {
        private static void Facet(Graphics g, string color, params PointF[] points) {
            using (var brush = new SolidBrush(ColorTranslator.FromHtml(color))) g.FillPolygon(brush, points);
        }
        public static Bitmap Render(int size) {
            if (size < 16 || size > 256) throw new ArgumentOutOfRangeException("size");
            using (var canvas = new Bitmap(size * 4, size * 4, PixelFormat.Format32bppArgb)) {
                using (var g = Graphics.FromImage(canvas)) {
                    g.SmoothingMode = SmoothingMode.AntiAlias;
                    g.ScaleTransform(canvas.Width / 100f, canvas.Height / 100f);
                    using (var ring = new Pen(ColorTranslator.FromHtml("#B89CB3"), 4.5f))
                        g.DrawEllipse(ring, 4, 4, 92, 92);
                    // Broad facets remain recognizable at the 16-pixel tray size.
                    var a = new PointF(28, 22); var b = new PointF(72, 22);
                    var c = new PointF(85, 43); var d = new PointF(50, 86); var e = new PointF(15, 43);
                    var f = new PointF(37, 43); var h = new PointF(63, 43);
                    Facet(g, "#EE9BAA", a, b, h, f);
                    Facet(g, "#C9506C", a, f, e);
                    Facet(g, "#E47A91", b, c, h);
                    Facet(g, "#A32C4B", e, f, d);
                    Facet(g, "#DA4A6E", f, h, d);
                    Facet(g, "#77203B", h, c, d);
                    using (var outline = new Pen(ColorTranslator.FromHtml("#F5C3CD"), 2.4f))
                        g.DrawPolygon(outline, new[] { a, b, c, d, e });
                }
                var result = new Bitmap(size, size, PixelFormat.Format32bppArgb);
                using (var g = Graphics.FromImage(result)) {
                    g.CompositingMode = CompositingMode.SourceCopy;
                    g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                    g.DrawImage(canvas, new Rectangle(0, 0, size, size));
                }
                return result;
            }
        }
    }
}

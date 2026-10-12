using System;
using System.Windows;
using System.Windows.Media;

namespace RinUsage {
    public sealed class RingGauge : FrameworkElement {
        public static readonly DependencyProperty RemainingProperty = DependencyProperty.Register(
            "Remaining", typeof(double), typeof(RingGauge),
            new FrameworkPropertyMetadata(double.NaN, FrameworkPropertyMetadataOptions.AffectsRender));
        public double Remaining { get { return (double)GetValue(RemainingProperty); } set { SetValue(RemainingProperty, value); } }
        public Brush ValueBrush { get; set; }
        public Brush TrackBrush { get; set; }
        public Brush ScaleBrush { get; set; }
        public Color GemColor { get; set; }
        public RingGauge() {
            ValueBrush = new SolidColorBrush(Color.FromRgb(186,64,92));
            TrackBrush = new SolidColorBrush(Color.FromRgb(67,52,64));
            ScaleBrush = new SolidColorBrush(Color.FromRgb(181,166,176));
            GemColor = Color.FromRgb(205,86,115);
            SnapsToDevicePixels = false;
            IsHitTestVisible = false;
        }
        private static Point Polar(Point center, double radius, double angle) {
            double a=angle*Math.PI/180;
            return new Point(center.X+Math.Cos(a)*radius,center.Y+Math.Sin(a)*radius);
        }
        protected override void OnRender(DrawingContext dc) {
            base.OnRender(dc);
            double size=Math.Min(ActualWidth,ActualHeight);
            if(size<=0)return;
            double s=size/100, radius=39*s;
            var center=new Point(ActualWidth/2,ActualHeight/2);
            for(int i=0;i<20;i++) {
                bool major=i%5==0;
                dc.PushOpacity(major ? 0.60 : 0.38);
                dc.DrawLine(new Pen(ScaleBrush,(major?1:.8)*s),
                    Polar(center,(major?44:46)*s,-90+i*18),Polar(center,49*s,-90+i*18));
                dc.Pop();
            }
            dc.DrawEllipse(null,new Pen(TrackBrush,3.2*s),center,radius,radius);
            if(double.IsNaN(Remaining)||double.IsInfinity(Remaining))return;
            double value=Math.Max(0,Math.Min(100,Remaining));
            if(value<=0)return;
            var pen=new Pen(ValueBrush,3.2*s) { StartLineCap=PenLineCap.Round,EndLineCap=PenLineCap.Round };
            double angle=-90+value*3.6;
            var end=Polar(center,radius,angle);
            if(value>=100)dc.DrawEllipse(null,pen,center,radius,radius);
            else {
                var arc=new StreamGeometry();
                using(var path=arc.Open()) {
                    path.BeginFigure(Polar(center,radius,-90),false,false);
                    path.ArcTo(end,new Size(radius,radius),0,value>50,SweepDirection.Clockwise,true,false);
                }
                arc.Freeze();dc.DrawGeometry(null,pen,arc);
            }
            var glow=new SolidColorBrush(Color.FromArgb(30,GemColor.R,GemColor.G,GemColor.B));
            dc.DrawEllipse(glow,null,end,5.4*s,5.4*s);
            var gem=new StreamGeometry();
            using(var path=gem.Open()) {
                path.BeginFigure(new Point(0,-3.2*s),true,true);
                path.LineTo(new Point(3.2*s,0),true,false);
                path.LineTo(new Point(0,3.2*s),true,false);
                path.LineTo(new Point(-3.2*s,0),true,false);
            }
            gem.Freeze();
            var transform=new TransformGroup();
            transform.Children.Add(new RotateTransform(value*3.6));
            transform.Children.Add(new TranslateTransform(end.X,end.Y));
            dc.PushTransform(transform);
            dc.DrawGeometry(new SolidColorBrush(GemColor),null,gem);
            dc.Pop();
        }
    }
}

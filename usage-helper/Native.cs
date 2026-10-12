using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace RinUsage {
    public sealed class RpcClient : IDisposable {
        private Process process;
        private System.IO.Stream input;
        private readonly ConcurrentQueue<string> messages = new ConcurrentQueue<string>();
        public bool Running { get { return process != null && !process.HasExited; } }
        public string Take() { string line; return messages.TryDequeue(out line) ? line : null; }
        public void Start(string executable) {
            var info = new ProcessStartInfo(executable, "app-server --listen stdio://") {
                UseShellExecute = false, CreateNoWindow = true,
                RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true,
                StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8
            };
            process = new Process { StartInfo = info };
            process.OutputDataReceived += (sender, e) => { if (e.Data != null) messages.Enqueue(e.Data); };
            // Drain stderr without persisting server logs or credentials.
            process.ErrorDataReceived += (sender, e) => { };
            Encoding previousEncoding = Console.InputEncoding;
            try {
                Console.InputEncoding = new UTF8Encoding(false);
                if (!process.Start()) throw new InvalidOperationException("Unable to start Codex app-server.");
                input = process.StandardInput.BaseStream;
            } finally { Console.InputEncoding = previousEncoding; }
            process.BeginOutputReadLine(); process.BeginErrorReadLine();
            Send("{\"id\":1,\"method\":\"initialize\",\"params\":{\"clientInfo\":{\"name\":\"rin_usage_helper\",\"version\":\"0.1.0\"}}}");
        }
        public void Send(string json) {
            if (!Running) throw new InvalidOperationException("App-server stopped.");
            // .NET Framework's default redirected-input writer can emit a BOM,
            // which breaks the first JSON-RPC line. Write explicit UTF-8 bytes.
            byte[] bytes = new UTF8Encoding(false).GetBytes(json + "\n");
            input.Write(bytes, 0, bytes.Length); input.Flush();
        }
        public void Dispose() {
            if (process == null) return;
            try { if (!process.HasExited) { process.StandardInput.Close(); if (!process.WaitForExit(1000)) process.Kill(); } } catch { }
            process.Dispose(); process = null;
        }
    }
    public sealed class PetWindow {
        public long Handle; public int Left, Top, Width, Height, Dpi;
        public int WorkLeft, WorkTop, WorkRight, WorkBottom;
        public string ClassName;
    }
    public static class Desktop {
        [StructLayout(LayoutKind.Sequential)] private struct Rect { public int Left, Top, Right, Bottom; }
        [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
        [StructLayout(LayoutKind.Sequential)] private struct MonitorInfo { public int Size; public Rect Monitor, Work; public int Flags; }
        private delegate bool EnumProc(IntPtr window, IntPtr state);
        [DllImport("user32.dll")] private static extern bool EnumWindows(EnumProc callback, IntPtr state);
        [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr window, out Rect rect);
        [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr window);
        [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetClassName(IntPtr window, StringBuilder name, int size);
        [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] private static extern IntPtr GetWindowLongPtr(IntPtr window, int index);
        [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")] private static extern IntPtr SetWindowLongPtr(IntPtr window, int index, IntPtr value);
        [DllImport("user32.dll")] private static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
        [DllImport("user32.dll")] private static extern uint GetDpiForWindow(IntPtr window);
        [DllImport("user32.dll")] private static extern IntPtr MonitorFromWindow(IntPtr window, uint flags);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);
        [DllImport("user32.dll")] public static extern bool GetCursorPos(out Point point);
        [DllImport("user32.dll")] private static extern short GetAsyncKeyState(int key);
        [DllImport("user32.dll")] private static extern bool SetWindowPos(IntPtr window, IntPtr after, int x, int y, int width, int height, uint flags);
        [DllImport("dwmapi.dll")] private static extern int DwmGetWindowAttribute(IntPtr window, int attribute, out int value, int size);
        private static IntPtr cached; private static DateTime nextScan;
        public static void EnableDpiAwareness() { try { SetThreadDpiAwarenessContext(new IntPtr(-4)); } catch { } }
        public static bool LeftButtonDown { get { return (GetAsyncKeyState(1) & 0x8000) != 0; } }
        public static void MakePassive(long handle) {
            var h = new IntPtr(handle); long style = GetWindowLongPtr(h, -20).ToInt64();
            SetWindowLongPtr(h, -20, new IntPtr(style | 0x20 | 0x80 | 0x08000000));
        }
        public static void Place(long handle, int x, int y, int width, int height) {
            SetWindowPos(new IntPtr(handle), new IntPtr(-1), x, y, width, height, 0x0010);
        }
        public static PetWindow WindowRect(long handle) { return Read(new IntPtr(handle)); }
        public static bool IsTopmostAtPet(long petHandle, int x, int y, long ownHandle) {
            // Ignore our card and unrelated windows that do not cover the hover point.
            bool clear = false;
            EnumWindows((h, unused) => {
                if (h.ToInt64() == petHandle) { clear = true; return false; }
                if (h.ToInt64() == ownHandle || !Visible(h)) return true;
                Rect r; if (!GetWindowRect(h, out r)) return true;
                if (x >= r.Left && x < r.Right && y >= r.Top && y < r.Bottom) {
                    long style = GetWindowLongPtr(h, -20).ToInt64();
                    if ((style & 0x20) == 0) return false;
                }
                return true;
            }, IntPtr.Zero);
            return clear;
        }
        private static bool Visible(IntPtr h) {
            if (!IsWindowVisible(h)) return false;
            int cloaked; return DwmGetWindowAttribute(h, 14, out cloaked, 4) != 0 || cloaked == 0;
        }
        private static PetWindow Read(IntPtr h) {
            if (!Visible(h)) return null;
            Rect r; if (!GetWindowRect(h, out r)) return null;
            var m = new MonitorInfo { Size = Marshal.SizeOf(typeof(MonitorInfo)) };
            GetMonitorInfo(MonitorFromWindow(h, 2), ref m);
            int dpi = 96; try { dpi = (int)GetDpiForWindow(h); } catch { }
            var cls = new StringBuilder(128); GetClassName(h, cls, cls.Capacity);
            return new PetWindow { Handle = h.ToInt64(), Left = r.Left, Top = r.Top, Width = r.Right-r.Left,
                Height = r.Bottom-r.Top, Dpi = dpi > 0 ? dpi : 96,
                ClassName=cls.ToString(),
                WorkLeft=m.Work.Left, WorkTop=m.Work.Top, WorkRight=m.Work.Right, WorkBottom=m.Work.Bottom };
        }
        public static PetWindow FindPet() {
            if (cached != IntPtr.Zero) { var pet = Read(cached); if (pet != null) return pet; cached = IntPtr.Zero; }
            if (DateTime.UtcNow < nextScan) return null;
            nextScan = DateTime.UtcNow.AddSeconds(1);
            var pids = new HashSet<uint>();
            foreach (string name in new [] { "ChatGPT", "Codex" })
                foreach (var p in Process.GetProcessesByName(name)) { pids.Add((uint)p.Id); p.Dispose(); }
            IntPtr best = IntPtr.Zero; long bestScore = -1;
            EnumWindows((h, unused) => {
                uint pid; GetWindowThreadProcessId(h, out pid); if (!pids.Contains(pid) || !Visible(h)) return true;
                long ex = GetWindowLongPtr(h, -20).ToInt64(), style = GetWindowLongPtr(h, -16).ToInt64();
                if ((ex & 0x80) == 0 || (ex & 0x80000) == 0 || (style & 0xC00000) != 0) return true;
                var cls = new StringBuilder(128); GetClassName(h, cls, cls.Capacity);
                if (cls.ToString() != "Chrome_WidgetWin_1") return true;
                var r = Read(h); if (r == null || r.Width < 40 || r.Height < 40 || r.Width > 1800 || r.Height > 1800) return true;
                long score = ((ex & 8) != 0 ? 100 : 0) + ((ex & 0x20) != 0 ? 40 : 0);
                if (score > bestScore) { bestScore = score; best = h; }
                return true;
            }, IntPtr.Zero);
            cached = best; return best != IntPtr.Zero ? Read(best) : null;
        }
        public static PetWindow AccessibleMascot(long handle) {
            try {
                var root = System.Windows.Automation.AutomationElement.FromHandle(new IntPtr(handle));
                var nodes = root.FindAll(System.Windows.Automation.TreeScope.Descendants,
                    new System.Windows.Automation.OrCondition(
                        new System.Windows.Automation.PropertyCondition(System.Windows.Automation.AutomationElement.ControlTypeProperty, System.Windows.Automation.ControlType.Button),
                        new System.Windows.Automation.PropertyCondition(System.Windows.Automation.AutomationElement.ControlTypeProperty, System.Windows.Automation.ControlType.Image)));
                PetWindow unnamedImage = null; int imageCount = 0;
                foreach (System.Windows.Automation.AutomationElement node in nodes) {
                    var name = node.Current.Name ?? "";
                    var r = node.Current.BoundingRectangle;
                    if (node.Current.IsOffscreen || r.Width < 20 || r.Width > 300 || r.Height < 20 || r.Height > 300) continue;
                    var rect = new PetWindow { Left=(int)r.Left, Top=(int)r.Top, Width=(int)r.Width, Height=(int)r.Height, Handle=handle };
                    if (System.Text.RegularExpressions.Regex.IsMatch(name, "drag.{0,40}pet|click.{0,40}change pets|change pet|\u62d6\u52a8.{0,20}\u5ba0\u7269|\u66f4\u6362\u5ba0\u7269", System.Text.RegularExpressions.RegexOptions.IgnoreCase)) return rect;
                    // New native overlays expose the sprite as one unnamed image,
                    // but no longer persist detailed mascot bounds in global state.
                    if (node.Current.ControlType == System.Windows.Automation.ControlType.Image &&
                        r.Width/r.Height >= 0.80 && r.Width/r.Height <= 1.10) { unnamedImage=rect; imageCount++; }
                }
                return imageCount==1 ? unnamedImage : null;
            } catch { }
            return null;
        }
    }
}

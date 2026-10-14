using System;
using System.Diagnostics;
using System.IO;
using System.Text;

namespace RinUsage {
    internal static class HiddenLauncher {
        private static string Quote(string value) {
            var result = new StringBuilder("\"");
            int slashes = 0;
            foreach (char c in value) {
                if (c == '\\') { slashes++; continue; }
                result.Append('\\', c == '"' ? slashes * 2 + 1 : slashes);
                result.Append(c); slashes = 0;
            }
            result.Append('\\', slashes * 2); result.Append('"');
            return result.ToString();
        }
        [STAThread]
        private static int Main(string[] args) {
            try {
                var arguments = new StringBuilder();
                foreach (string argument in args) {
                    if (arguments.Length > 0) arguments.Append(' ');
                    arguments.Append(Quote(argument));
                }
                var executable = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),
                    @"System32\WindowsPowerShell\v1.0\powershell.exe");
                var info = new ProcessStartInfo(executable, arguments.ToString()) {
                    UseShellExecute = false, CreateNoWindow = true
                };
                using (var process = Process.Start(info)) {
                    if (process == null) return 1;
                    process.WaitForExit(); return process.ExitCode;
                }
            } catch (Exception error) {
                try {
                    File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "launcher-error.txt"),
                        DateTime.UtcNow.ToString("o") + " " + error.GetType().Name);
                } catch { }
                return 1;
            }
        }
    }
}

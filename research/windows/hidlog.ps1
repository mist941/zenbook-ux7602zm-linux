param([string]$Match, [int]$Len, [string]$Log, [int]$Seconds = 300)
Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class HidLog {
  [DllImport("hid.dll")] static extern void HidD_GetHidGuid(out Guid g);
  [DllImport("setupapi.dll", SetLastError=true)] static extern IntPtr SetupDiGetClassDevs(ref Guid g, IntPtr e, IntPtr hwnd, int flags);
  [DllImport("setupapi.dll", SetLastError=true)] static extern bool SetupDiEnumDeviceInterfaces(IntPtr set, IntPtr di, ref Guid g, int idx, ref SP_DEVICE_INTERFACE_DATA d);
  [DllImport("setupapi.dll", SetLastError=true, CharSet=CharSet.Unicode)] static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr set, ref SP_DEVICE_INTERFACE_DATA d, IntPtr detail, int size, out int req, IntPtr di);
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern SafeFileHandle CreateFile(string n, uint acc, uint share, IntPtr sec, uint disp, uint flags, IntPtr tmpl);
  [StructLayout(LayoutKind.Sequential)] struct SP_DEVICE_INTERFACE_DATA { public int cbSize; public Guid g; public int flags; public IntPtr res; }
  public static string Find(string match) {
    Guid g; HidD_GetHidGuid(out g);
    IntPtr set = SetupDiGetClassDevs(ref g, IntPtr.Zero, IntPtr.Zero, 0x12);
    for (int i = 0; ; i++) {
      var d = new SP_DEVICE_INTERFACE_DATA(); d.cbSize = Marshal.SizeOf(d);
      if (!SetupDiEnumDeviceInterfaces(set, IntPtr.Zero, ref g, i, ref d)) break;
      int req; SetupDiGetDeviceInterfaceDetail(set, ref d, IntPtr.Zero, 0, out req, IntPtr.Zero);
      IntPtr buf = Marshal.AllocHGlobal(req); Marshal.WriteInt32(buf, 8);
      string p = null;
      if (SetupDiGetDeviceInterfaceDetail(set, ref d, buf, req, out req, IntPtr.Zero)) p = Marshal.PtrToStringUni(new IntPtr(buf.ToInt64() + 4));
      Marshal.FreeHGlobal(buf);
      if (p != null && System.Text.RegularExpressions.Regex.IsMatch(p, match)) return p;
    }
    return null;
  }
  public static void Run(string match, int len, string log, int seconds) {
    string path = Find(match);
    if (path == null) { File.AppendAllText(log, "no device " + match + "\n"); return; }
    var h = CreateFile(path, 0x80000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
    if (h.IsInvalid) { File.AppendAllText(log, "open failed " + Marshal.GetLastWin32Error() + " " + match + "\n"); return; }
    File.AppendAllText(log, "listening " + path + "\n");
    var fs = new FileStream(h, FileAccess.Read, len, false);
    var end = DateTime.Now.AddSeconds(seconds);
    var b = new byte[len];
    while (DateTime.Now < end) {
      int n = fs.Read(b, 0, len);
      if (n <= 0) break;
      File.AppendAllText(log, DateTime.Now.ToString("HH:mm:ss.fff") + " " + match + " " + BitConverter.ToString(b, 0, n).Replace("-", " ") + "\n");
    }
  }
}
"@
[HidLog]::Run($Match, $Len, $Log, $Seconds)

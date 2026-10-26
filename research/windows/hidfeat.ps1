param([string]$Match, [string[]]$Send, [int]$GetId = -1, [int]$Len = 64)
Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class HidIo {
  [DllImport("hid.dll")] static extern void HidD_GetHidGuid(out Guid g);
  [DllImport("hid.dll", SetLastError=true)] public static extern bool HidD_SetFeature(SafeFileHandle h, byte[] b, int len);
  [DllImport("hid.dll", SetLastError=true)] public static extern bool HidD_GetFeature(SafeFileHandle h, byte[] b, int len);
  [DllImport("setupapi.dll", SetLastError=true)] static extern IntPtr SetupDiGetClassDevs(ref Guid g, IntPtr e, IntPtr hwnd, int flags);
  [DllImport("setupapi.dll", SetLastError=true)] static extern bool SetupDiEnumDeviceInterfaces(IntPtr set, IntPtr di, ref Guid g, int idx, ref SP_DEVICE_INTERFACE_DATA d);
  [DllImport("setupapi.dll", SetLastError=true, CharSet=CharSet.Unicode)] static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr set, ref SP_DEVICE_INTERFACE_DATA d, IntPtr detail, int size, out int req, IntPtr di);
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern SafeFileHandle CreateFile(string n, uint acc, uint share, IntPtr sec, uint disp, uint flags, IntPtr tmpl);
  [StructLayout(LayoutKind.Sequential)] struct SP_DEVICE_INTERFACE_DATA { public int cbSize; public Guid g; public int flags; public IntPtr res; }
  public static List<string> Paths() {
    Guid g; HidD_GetHidGuid(out g);
    IntPtr set = SetupDiGetClassDevs(ref g, IntPtr.Zero, IntPtr.Zero, 0x12);
    var r = new List<string>();
    for (int i = 0; ; i++) {
      var d = new SP_DEVICE_INTERFACE_DATA(); d.cbSize = Marshal.SizeOf(d);
      if (!SetupDiEnumDeviceInterfaces(set, IntPtr.Zero, ref g, i, ref d)) break;
      int req; SetupDiGetDeviceInterfaceDetail(set, ref d, IntPtr.Zero, 0, out req, IntPtr.Zero);
      IntPtr buf = Marshal.AllocHGlobal(req); Marshal.WriteInt32(buf, 8);
      if (SetupDiGetDeviceInterfaceDetail(set, ref d, buf, req, out req, IntPtr.Zero)) r.Add(Marshal.PtrToStringUni(new IntPtr(buf.ToInt64() + 4)));
      Marshal.FreeHGlobal(buf);
    }
    return r;
  }
}
"@
$path = [HidIo]::Paths() | Where-Object { $_ -match $Match } | Select-Object -First 1
if (-not $path) { "no device matching $Match"; exit 1 }
"device: $path"
$h = [HidIo]::CreateFile($path, [uint32]"0xC0000000", 3, [IntPtr]::Zero, 3, 0, [IntPtr]::Zero)
if ($h.IsInvalid) { "open failed: " + [Runtime.InteropServices.Marshal]::GetLastWin32Error(); exit 1 }
foreach ($s in $Send) {
  $bytes = New-Object byte[] $Len
  $hex = $s -split '[ ,]+' | Where-Object { $_ }
  for ($i = 0; $i -lt $hex.Count; $i++) { $bytes[$i] = [Convert]::ToByte($hex[$i], 16) }
  $ok = [HidIo]::HidD_SetFeature($h, $bytes, $Len)
  "SET [$s] -> $ok " + $(if (-not $ok) { "err=" + [Runtime.InteropServices.Marshal]::GetLastWin32Error() })
}
if ($GetId -ge 0) {
  $b = New-Object byte[] $Len; $b[0] = [byte]$GetId
  $ok = [HidIo]::HidD_GetFeature($h, $b, $Len)
  "GET 0x{0:X2} -> {1} {2}" -f $GetId, $ok, (($b | ForEach-Object { $_.ToString('x2') }) -join ' ')
  if (-not $ok) { "err=" + [Runtime.InteropServices.Marshal]::GetLastWin32Error() }
}
$h.Close()

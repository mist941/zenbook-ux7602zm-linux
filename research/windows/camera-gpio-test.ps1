# Run from an elevated PowerShell. Reads ASUS WMI device states (DSTS) and checks
# whether WMI device 0x00060078 (GPIO 0x090E000F, "CLED" in the DSDT) also drives
# the webcam's privacy line. The original GPIO value is restored at the end.
$ErrorActionPreference = 'Stop'
$out = Join-Path $PSScriptRoot 'camera-gpio-test.result.txt'
function Log($s) { $s | Tee-Object -FilePath $out -Append }
Remove-Item $out -ErrorAction SilentlyContinue

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
[ComImport, Guid("29840822-5B84-11D0-BD3B-00A0C911CE86"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface ICreateDevEnum { [PreserveSig] int CreateClassEnumerator([In] ref Guid clsid, out IEnumMoniker e, int flags); }
[ComImport, Guid("C6E13370-30AC-11d0-A18C-00A0C9118956"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAMCameraControl {
  [PreserveSig] int GetRange(int p, out int min, out int max, out int step, out int def, out int caps);
  [PreserveSig] int Set(int p, int v, int flags);
  [PreserveSig] int Get(int p, out int v, out int flags);
}
[ComImport, Guid("55272A00-42CB-11CE-8135-00AA004BB851"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IPropertyBag { [PreserveSig] int Read([MarshalAs(UnmanagedType.LPWStr)] string name, out object val, IntPtr log); [PreserveSig] int Write(string n, ref object v); }
public static class Cam {
  static IAMCameraControl cc;
  public static int Privacy() {
    if (cc == null) {
      var de = (ICreateDevEnum)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("62BE5D10-60EB-11d0-BD3B-00A0C911CE86")));
      Guid cat = new Guid("860BB310-5D01-11d0-BD3B-00A0C911CE86");
      IEnumMoniker em; de.CreateClassEnumerator(ref cat, out em, 0);
      var m = new IMoniker[1];
      while (em != null && em.Next(1, m, IntPtr.Zero) == 0) {
        object bag; Guid bagIid = typeof(IPropertyBag).GUID;
        m[0].BindToStorage(null, null, ref bagIid, out bag);
        object name; ((IPropertyBag)bag).Read("FriendlyName", out name, IntPtr.Zero);
        if (!((string)name).Contains("FHD")) continue;
        object f; Guid bf = new Guid("56a86895-0ad4-11ce-b03a-0020af0ba770");
        m[0].BindToObject(null, null, ref bf, out f);
        cc = f as IAMCameraControl;
      }
    }
    if (cc == null) return -1;
    int v, fl; return cc.Get(8, out v, out fl) == 0 ? v : -2;
  }
}
"@

$w = Get-CimInstance -Namespace root\wmi -ClassName AsusAtkWmi_WMNB
if (-not $w) { Log 'AsusAtkWmi_WMNB instance not found (not elevated?)'; exit 1 }
function DSTS([uint32]$id) { [uint32](Invoke-CimMethod -InputObject $w -MethodName DSTS -Arguments @{Device_ID = $id}).device_status }
function DEVS([uint32]$id, [uint32]$v) { [uint32](Invoke-CimMethod -InputObject $w -MethodName DEVS -Arguments @{Device_ID = $id; Control_status = $v}).result }

Log ("== DSTS dump " + (Get-Date))
$ids = 0x00010011,0x00010013,0x00020011,0x00040017,0x00050021,0x00060013,0x00060023,0x00060026,0x00060059,0x00060061,0x00060068,0x00060069,0x00060076,0x00060078,0x00060079,0x00100023,0x00100051,0x00100063,0x00110013,0x00110014,0x00110019,0x00120057,0x00120061,0x0012006D,0x00120075
foreach ($id in $ids) { Log ("DSTS 0x{0:X8} = 0x{1:X8}" -f $id, (DSTS $id)) }

$orig = (DSTS 0x00060078) -band 1
Log ("== camera test: GPIO(CLED)={0} privacy={1}" -f $orig, [Cam]::Privacy())
$flip = 1 - $orig
Log ("DEVS 0x00060078 <- {0}: result=0x{1:X}" -f $flip, (DEVS 0x00060078 $flip))
for ($i = 0; $i -lt 8; $i++) { Start-Sleep -Milliseconds 250; Log ("  t+{0}ms GPIO={1} privacy={2}" -f (250*($i+1)), ((DSTS 0x00060078) -band 1), [Cam]::Privacy()) }
Log ("DEVS 0x00060078 <- {0} (restore): result=0x{1:X}" -f $orig, (DEVS 0x00060078 $orig))
for ($i = 0; $i -lt 8; $i++) { Start-Sleep -Milliseconds 250; Log ("  t+{0}ms GPIO={1} privacy={2}" -f (250*($i+1)), ((DSTS 0x00060078) -band 1), [Cam]::Privacy()) }
Log "done"

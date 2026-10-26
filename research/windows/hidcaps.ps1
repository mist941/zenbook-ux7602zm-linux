Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

public static class HidDump {
  [DllImport("hid.dll")] static extern void HidD_GetHidGuid(out Guid g);
  [DllImport("hid.dll")] static extern bool HidD_GetAttributes(SafeFileHandle h, byte[] attr);
  [DllImport("hid.dll")] static extern bool HidD_GetPreparsedData(SafeFileHandle h, out IntPtr pp);
  [DllImport("hid.dll")] static extern bool HidD_FreePreparsedData(IntPtr pp);
  [DllImport("hid.dll", CharSet=CharSet.Unicode)] static extern bool HidD_GetProductString(SafeFileHandle h, StringBuilder s, int len);
  [DllImport("hid.dll", CharSet=CharSet.Unicode)] static extern bool HidD_GetManufacturerString(SafeFileHandle h, StringBuilder s, int len);
  [DllImport("hid.dll")] static extern int HidP_GetCaps(IntPtr pp, byte[] caps);
  [DllImport("hid.dll")] static extern int HidP_GetValueCaps(int type, byte[] caps, ref ushort len, IntPtr pp);
  [DllImport("hid.dll")] static extern int HidP_GetButtonCaps(int type, byte[] caps, ref ushort len, IntPtr pp);
  [DllImport("hid.dll")] static extern int HidP_GetLinkCollectionNodes(byte[] nodes, ref uint len, IntPtr pp);
  [DllImport("setupapi.dll", SetLastError=true)] static extern IntPtr SetupDiGetClassDevs(ref Guid g, IntPtr e, IntPtr hwnd, int flags);
  [DllImport("setupapi.dll", SetLastError=true)] static extern bool SetupDiEnumDeviceInterfaces(IntPtr set, IntPtr di, ref Guid g, int idx, ref SP_DEVICE_INTERFACE_DATA d);
  [DllImport("setupapi.dll", SetLastError=true, CharSet=CharSet.Unicode)] static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr set, ref SP_DEVICE_INTERFACE_DATA d, IntPtr detail, int size, out int req, IntPtr di);
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] static extern SafeFileHandle CreateFile(string n, uint acc, uint share, IntPtr sec, uint disp, uint flags, IntPtr tmpl);
  [StructLayout(LayoutKind.Sequential)] struct SP_DEVICE_INTERFACE_DATA { public int cbSize; public Guid g; public int flags; public IntPtr res; }

  public static List<string> Paths() {
    Guid g; HidD_GetHidGuid(out g);
    IntPtr set = SetupDiGetClassDevs(ref g, IntPtr.Zero, IntPtr.Zero, 0x12);
    var r = new List<string>();
    for (int i = 0; ; i++) {
      var d = new SP_DEVICE_INTERFACE_DATA(); d.cbSize = Marshal.SizeOf(d);
      if (!SetupDiEnumDeviceInterfaces(set, IntPtr.Zero, ref g, i, ref d)) break;
      int req; SetupDiGetDeviceInterfaceDetail(set, ref d, IntPtr.Zero, 0, out req, IntPtr.Zero);
      IntPtr buf = Marshal.AllocHGlobal(req);
      Marshal.WriteInt32(buf, 8);
      if (SetupDiGetDeviceInterfaceDetail(set, ref d, buf, req, out req, IntPtr.Zero))
        r.Add(Marshal.PtrToStringUni(new IntPtr(buf.ToInt64() + 4)));
      Marshal.FreeHGlobal(buf);
    }
    return r;
  }

  static ushort U16(byte[] b, int o) { return BitConverter.ToUInt16(b, o); }
  static int I32(byte[] b, int o) { return BitConverter.ToInt32(b, o); }

  public static string Dump(string path) {
    var sb = new StringBuilder();
    var h = CreateFile(path, 0, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
    if (h.IsInvalid) return "  (cannot open)\n";
    byte[] a = new byte[12]; BitConverter.GetBytes(12).CopyTo(a, 0);
    HidD_GetAttributes(h, a);
    var ps = new StringBuilder(256); HidD_GetProductString(h, ps, 512);
    var ms = new StringBuilder(256); HidD_GetManufacturerString(h, ms, 512);
    sb.AppendFormat("  VID={0:X4} PID={1:X4} ver={2:X4} mfr='{3}' product='{4}'\n", U16(a,4), U16(a,6), U16(a,8), ms, ps);
    IntPtr pp;
    if (!HidD_GetPreparsedData(h, out pp)) { h.Close(); return sb.ToString() + "  (no preparsed data)\n"; }
    byte[] c = new byte[64]; HidP_GetCaps(pp, c);
    sb.AppendFormat("  TLC UsagePage=0x{0:X4} Usage=0x{1:X4} InLen={2} OutLen={3} FeatLen={4} LinkNodes={5}\n", U16(c,2), U16(c,0), U16(c,4), U16(c,6), U16(c,8), U16(c,44));
    uint nl = U16(c,44); byte[] nodes = new byte[24*nl];
    if (HidP_GetLinkCollectionNodes(nodes, ref nl, pp) == 0x110000)
      for (int i = 0; i < nl; i++)
        sb.AppendFormat("    collection[{0}] page=0x{1:X4} usage=0x{2:X4} parent={3} type={4}\n", i, U16(nodes,i*24+2), U16(nodes,i*24), U16(nodes,i*24+4), nodes[i*24+12]);
    string[] tn = {"In","Out","Feat"};
    for (int t = 0; t < 3; t++) {
      ushort nb = U16(c, 46 + t*6), nv = U16(c, 48 + t*6);
      if (nb > 0) { byte[] bc = new byte[72*nb];
        if (HidP_GetButtonCaps(t, bc, ref nb, pp) == 0x110000)
          for (int i = 0; i < nb; i++) { int o = i*72; bool rng = bc[o+12] != 0;
            sb.AppendFormat("    {0}-btn  rid=0x{1:X2} page=0x{2:X4} usage={3} link={4}\n", tn[t], bc[o+2], U16(bc,o), rng ? string.Format("0x{0:X4}-0x{1:X4}", U16(bc,o+56), U16(bc,o+58)) : string.Format("0x{0:X4}", U16(bc,o+56)), U16(bc,o+6)); } }
      if (nv > 0) { byte[] vc = new byte[72*nv];
        if (HidP_GetValueCaps(t, vc, ref nv, pp) == 0x110000)
          for (int i = 0; i < nv; i++) { int o = i*72; bool rng = vc[o+12] != 0;
            sb.AppendFormat("    {0}-val  rid=0x{1:X2} page=0x{2:X4} usage={3} bits={4}x{5} logical=[{6},{7}] link={8}\n", tn[t], vc[o+2], U16(vc,o), rng ? string.Format("0x{0:X4}-0x{1:X4}", U16(vc,o+56), U16(vc,o+58)) : string.Format("0x{0:X4}", U16(vc,o+56)), U16(vc,o+18), U16(vc,o+20), I32(vc,o+40), I32(vc,o+44), U16(vc,o+6)); } }
    }
    HidD_FreePreparsedData(pp); h.Close();
    return sb.ToString();
  }
}
"@
foreach ($p in [HidDump]::Paths()) {
  if ($p -match 'asup1413|asus2020|elan9008|vid_0b05&pid_8854|vid_8087') { "== $p"; [HidDump]::Dump($p) }
}

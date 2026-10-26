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
  public static string Probe() {
    var sb = new System.Text.StringBuilder();
    var t = Type.GetTypeFromCLSID(new Guid("62BE5D10-60EB-11d0-BD3B-00A0C911CE86"));
    var de = (ICreateDevEnum)Activator.CreateInstance(t);
    Guid cat = new Guid("860BB310-5D01-11d0-BD3B-00A0C911CE86");
    IEnumMoniker em;
    if (de.CreateClassEnumerator(ref cat, out em, 0) != 0 || em == null) return "no video devices";
    var m = new IMoniker[1];
    while (em.Next(1, m, IntPtr.Zero) == 0) {
      object bagObj; Guid bagIid = typeof(IPropertyBag).GUID;
      m[0].BindToStorage(null, null, ref bagIid, out bagObj);
      object name; ((IPropertyBag)bagObj).Read("FriendlyName", out name, IntPtr.Zero);
      object filt; Guid bf = new Guid("56a86895-0ad4-11ce-b03a-0020af0ba770");
      m[0].BindToObject(null, null, ref bf, out filt);
      var cc = filt as IAMCameraControl;
      if (cc == null) { sb.AppendLine(name + ": no IAMCameraControl"); continue; }
      int v, f, mn, mx, st, df, cp;
      int hr1 = cc.GetRange(8, out mn, out mx, out st, out df, out cp);
      int hr2 = cc.Get(8, out v, out f);
      sb.AppendLine(string.Format("{0}: privacy range hr=0x{1:X8} [{2},{3}] default={4} caps={5}; current hr=0x{6:X8} value={7} flags={8}", name, hr1, mn, mx, df, cp, hr2, v, f));
    }
    return sb.ToString();
  }
}
"@
[Cam]::Probe()

/*
 * Test-only SSDT for QEMU: a minimal ASUS ATK WMI device. WMNB answers
 * DSTS/DEVS for 0x00060078 like the UX7602ZM BIOS 303 (bit 0 = GPIO
 * 0x090E000F: 1 = camera available, 0 = blocked). The extra "TEST" method
 * raises the WMI hotkey event given in IIA0, standing in for the EC.
 */
DefinitionBlock ("", "SSDT", 2, "ZBTEST", "ATKWMI", 0x00000001)
{
    Scope (\_SB)
    {
        Device (ATKD)
        {
            Name (_HID, "PNP0C14")
            Name (_UID, "ATK")
            Name (_WDG, Buffer (0x28)
            {
                /* 97845ED0-4E6D-11DE-8A39-0800200C9A66: methods, object "NB" */
                0xD0, 0x5E, 0x84, 0x97, 0x6D, 0x4E, 0xDE, 0x11,
                0x8A, 0x39, 0x08, 0x00, 0x20, 0x0C, 0x9A, 0x66,
                0x4E, 0x42, 0x01, 0x02,
                /* 0B3CBB35-E3C2-45ED-91C2-4C5A6D195D1C: events, notify 0xFF */
                0x35, 0xBB, 0x3C, 0x0B, 0xC2, 0xE3, 0xED, 0x45,
                0x91, 0xC2, 0x4C, 0x5A, 0x6D, 0x19, 0x5D, 0x1C,
                0xFF, 0x00, 0x01, 0x08
            })
            Name (CAMG, Zero)
            Name (EVTC, Zero)

            Method (_WED, 1, NotSerialized)
            {
                Return (EVTC)
            }

            Method (WMNB, 3, Serialized)
            {
                CreateDWordField (Arg2, Zero, IIA0)
                CreateDWordField (Arg2, 0x04, IIA1)
                If ((Arg1 == 0x53545344))
                {
                    If ((IIA0 == 0x00060078))
                    {
                        Return ((CAMG | 0x00010000))
                    }
                    Return (0xFFFFFFFE)
                }
                If ((Arg1 == 0x53564544))
                {
                    If ((IIA0 == 0x00060078))
                    {
                        CAMG = (IIA1 & One)
                        Return (One)
                    }
                    Return (0xFFFFFFFE)
                }
                If ((Arg1 == 0x54534554))
                {
                    EVTC = IIA0
                    Notify (ATKD, 0xFF)
                    Return (Zero)
                }
                Return (0xFFFFFFFE)
            }
        }
    }
}

/* Excerpts from the UX7602ZM DSDT (BIOS 303), decompiled with iasl 20230628. */

/* ---- touchpad, touchscreen, ASUS Dial ---- */
        Device (ETPD)
        {
            Name (_ADR, One)  // _ADR: Address
            Name (ETPH, Package (0x01)
            {
                "ASUE1413"
            })
            Name (FTPH, Package (0x0C)
            {
                "FTE1001", 
                "FTE1200", 
                "FTE1200", 
                "FTE1300", 
                "FTE1300", 
                "FTE1201", 
                "FTE1200", 
                "FTE1200", 
                "FTE1201", 
                "FTE1201", 
                "FTE1200", 
                "FTE1200"
            })
            Name (PTPH, Package (0x01)
            {
                "ASUP1413"
            })
            Method (_HID, 0, NotSerialized)  // _HID: Hardware ID
            {
                If ((TPDI & 0x04))
                {
                    Return (DerefOf (ETPH [TPHI]))
                }

                If ((TPDI & 0x10))
                {
                    Return (DerefOf (FTPH [TPHI]))
                }

                If ((TPDI & 0x80))
                {
                    Return (DerefOf (PTPH [TPHI]))
                }

                Return ("ELAN1010")
            }

            Name (_CID, "PNP0C50" /* HID Protocol Device (I2C bus) */)  // _CID: Compatible ID
            Name (_UID, One)  // _UID: Unique ID
            Name (_S0W, 0x03)  // _S0W: S0 Device Wake State
            Method (_DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
            {
                If ((Arg0 == ToUUID ("3cdff6f7-4267-4555-ad05-b30a3d8938de") /* HID I2C Device */))
                {
                    If ((Arg2 == Zero))
                    {
                        If ((Arg1 == One))
                        {
                            Return (Buffer (One)
                            {
                                 0x03                                             // .
                            })
                        }
                        Else
                        {
                            Return (Buffer (One)
                            {
                                 0x00                                             // .
                            })
                        }
                    }

                    If ((Arg2 == One))
                    {
                        Return (One)
                    }
                }
                Else
                {
                    Return (Buffer (One)
                    {
                         0x00                                             // .
                    })
                }
            }

            Method (_STA, 0, NotSerialized)  // _STA: Status
            {
                If (((TPIF != One) || (DSYN && One)))
                {
                    Return (Zero)
                }

                Return (0x0F)
            }

            Method (_CRS, 0, Serialized)  // _CRS: Current Resource Settings
            {
                Name (SBFI, ResourceTemplate ()
                {
                    I2cSerialBusV2 (0x0015, ControllerInitiated, 0x00061A80,
                        AddressingMode7Bit, "\\_SB.PC00.I2C1",
                        0x00, ResourceConsumer, , Exclusive,
                        )
                    Interrupt (ResourceConsumer, Level, ActiveLow, Exclusive, ,, )
                    {
                        0x00000028,
                    }
                })
                Return (SBFI) /* \_SB_.PC00.I2C1.ETPD._CRS.SBFI */
            }
        }
    }

    Scope (_SB.PC00.I2C0)
    {
        Device (TPL0)
        {
            Name (_CID, "PNP0C50" /* HID Protocol Device (I2C bus) */)  // _CID: Compatible ID
            Name (_UID, One)  // _UID: Unique ID
            Name (_S0W, 0x03)  // _S0W: S0 Device Wake State
            Name (SADR, Buffer (One)
            {
                 0x10                                             // .
            })
            Name (HIDS, Package (0x01)
            {
                "ELAN9008"
            })
            Name (HIDA, Buffer (One)
            {
                 0x01                                             // .
            })
            Method (_HID, 0, NotSerialized)  // _HID: Hardware ID
            {
                Return (DerefOf (HIDS [TPLI]))
            }

            Method (_DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
            {
                If ((Arg0 == ToUUID ("3cdff6f7-4267-4555-ad05-b30a3d8938de") /* HID I2C Device */))
                {
                    If ((Arg2 == Zero))
                    {
                        If ((Arg1 == One))
                        {
                            Return (Buffer (One)
                            {
                                 0x03                                             // .
                            })
                        }
                        Else
                        {
                            Return (Buffer (One)
                            {
                                 0x00                                             // .
                            })
                        }
                    }

                    If ((Arg2 == One))
                    {
                        Return (DerefOf (HIDA [TPLI]))
                    }
                }
                Else
                {
                    Return (Buffer (One)
                    {
                         0x00                                             // .
                    })
                }
            }

            Method (_STA, 0, NotSerialized)  // _STA: Status
            {
                If ((TPLP == Zero))
                {
                    Return (Zero)
                }

                Return (0x0F)
            }

            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (SBFI, ResourceTemplate ()
                {
                    I2cSerialBusV2 (0x0000, ControllerInitiated, 0x00061A80,
                        AddressingMode7Bit, "\\_SB.PC00.I2C0",
                        0x00, ResourceConsumer, _Y4B, Exclusive,
                        )
                    Interrupt (ResourceConsumer, Level, ActiveLow, Exclusive, ,, )
                    {
                        0x00000039,
                    }
                })
                CreateWordField (SBFI, \_SB.PC00.I2C0.TPL0._CRS._Y4B._ADR, ADR1)  // _ADR: Address
                ADR1 = DerefOf (SADR [TPLI])
                Return (SBFI) /* \_SB_.PC00.I2C0.TPL0._CRS.SBFI */
            }
        }
    }

    Scope (_SB.PC00.XHCI.RHUB.HS10)
    {
        PowerResource (BTRT, 0x05, 0x0000)
        {
            Method (_STA, 0, NotSerialized)  // _STA: Status
            {
                Return (One)
            }

            Method (_ON, 0, NotSerialized)  // _ON_: Power On
            {
            }

            Method (_OFF, 0, NotSerialized)  // _OFF: Power Off
            {
            }

            Method (_RST, 0, NotSerialized)  // _RST: Device Reset
            {
                Local0 = Acquire (CNMT, 0x03E8)
                If (CondRefOf (RDLY))
                {
                    Local1 = RDLY /* \_SB_.PC00.XHCI.RHUB.HS10.RDLY */
                }
                Else
                {
                    Local1 = 0xC8
                }

                If ((Local0 == Zero))
                {
                    BTRK (Zero)
                    Sleep (Local1)
                    BTRK (One)
                    Sleep (Local1)
                }

                Release (CNMT)
            }
        }

        Method (_PRR, 0, NotSerialized)  // _PRR: Power Resource for Reset
        {
            Return (Package (0x01)
            {
                BTRT
            })
        }
    }

    Scope (\)
    {
        Name (DIBF, One)
        Method (DIDW, 1, NotSerialized)
        {
        }
    }

    Scope (_SB.PC00.I2C4)
    {
        Device (DIDV)
        {
            Name (_ADR, One)  // _ADR: Address
            Method (_HID, 0, NotSerialized)  // _HID: Hardware ID
            {
                Return ("ASUS2020")
            }

            Name (_CID, "PNP0C50" /* HID Protocol Device (I2C bus) */)  // _CID: Compatible ID
            Name (_UID, One)  // _UID: Unique ID
            Name (_S0W, 0x03)  // _S0W: S0 Device Wake State
            Method (_DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
            {
                If ((Arg0 == ToUUID ("3cdff6f7-4267-4555-ad05-b30a3d8938de") /* HID I2C Device */))
                {
                    If ((Arg2 == Zero))
                    {
                        If ((Arg1 == One))
                        {
                            Return (Buffer (One)
                            {
                                 0x03                                             // .
                            })
                        }
                        Else
                        {
                            Return (Buffer (One)
                            {
                                 0x00                                             // .
                            })
                        }
                    }

                    If ((Arg2 == One))
                    {
                        Return (One)
                    }
                }
                Else
                {
                    Return (Buffer (One)
                    {
                         0x00                                             // .
                    })
                }
            }

            Method (_STA, 0, NotSerialized)  // _STA: Status
            {
                If ((DIBF == One))
                {
                    Return (0x0F)
                }
                ElseIf ((DIBF == 0x02))
                {
                    If ((TPSD & One))
                    {
                        Return (0x0F)
                    }
                    Else
                    {
                        Return (Zero)
                    }
                }
                Else
                {
                    Return (Zero)
                }
            }

            Method (_CRS, 0, Serialized)  // _CRS: Current Resource Settings
            {
                Name (SBFI, ResourceTemplate ()
                {
                    I2cSerialBusV2 (0x001D, ControllerInitiated, 0x00061A80,
                        AddressingMode7Bit, "\\_SB.PC00.I2C4",
                        0x00, ResourceConsumer, , Exclusive,
                        )
                    Interrupt (ResourceConsumer, Level, ActiveLow, Exclusive, ,, )
                    {
                        0x00000037,
                    }
                })
                Return (SBFI) /* \_SB_.PC00.I2C4.DIDV._CRS.SBFI */
            }
        }
    }

/* ---- keyboard backlight (EC) ---- */
        {
             0x00, 0x55, 0xAA, 0xFF                           // .U..
        })
        Method (GLID, 0, Serialized)
        {
            Return (RPIN (One))
        }

        Method (GLKB, 1, NotSerialized)
        {
            If ((Arg0 == One))
            {
                Local0 = (KBLC & 0x80)
                If (Local0)
                {
                    Return (One)
                }
                Else
                {
                    Return (Zero)
                }
            }
            ElseIf ((Arg0 == 0x02))
            {
                Return (KBLV) /* \_SB_.KBLV */
            }
            ElseIf ((Arg0 == 0x03))
            {
                Return (0x80)
            }

            Return (Ones)
        }

        Method (SLKB, 1, NotSerialized)
        {
            KBLV = (Arg0 & 0x7F)
            If ((Arg0 & 0x80))
            {
                Local0 = DerefOf (PWKB [KBLV])
            }
            Else
            {
                Local0 = Zero
            }

            ST9E (0x1F, 0xFF, Local0)
            Return (One)
        }

        Method (CSEE, 1, Serialized)

/* ---- EC hotkey queries ---- */
        Name (BLCT, Zero)
        Name (DSTI, One)
        Method (_Q0A, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            Notify (SLPB, 0x80) // Status Change
        }

        Method (_Q0B, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            If ((MSOS () >= OSW8)){}
        }

        Method (KBLD, 0, NotSerialized)
        {
            If (ATKP)
            {
                Local1 = (KBLC & 0x80)
                If (Local1)
                {
                    ^^^^ATKD.IANE (0xC5)
                }
            }
        }

        Method (KBLU, 0, NotSerialized)
        {
            If (ATKP)
            {
                Local1 = (KBLC & 0x80)
                If (Local1)
                {
                    ^^^^ATKD.IANE (0xC7)
                }
            }
        }

        Method (_Q0C, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            KBLD ()
        }

        Method (_Q0D, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            KBLU ()
        }

        Method (_Q0E, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            If ((MSOS () >= OSW8))
            {
                BRTN (0x87)
            }

            Return (Zero)
        }

        Method (_Q0F, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            If ((MSOS () >= OSW8))
            {
                BRTN (0x86)
            }

            Return (Zero)
        }

        Method (_Q10, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            If ((BLCT == Zero))
            {
                If (ATKP)
                {
                    ^^^^ATKD.IANE (0x33)
                }
            }
            ElseIf ((BLCT == One))
            {
                If (ATKP)
                {
                    ^^^^ATKD.IANE (0x35)
                }
            }
        }

        Method (_Q11, 0, Serialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            If ((MSOS () >= OSW8))
            {
                STB2 (0xE0)
                STB2 (0x5B)
                Sleep (0x05)
                STB2 (0x19)
                Sleep (0x05)
                STB2 (0x99)
                Sleep (0x05)
                STB2 (0xE0)
                STB2 (0xDB)
                Return (Zero)
            }
        }

        Method (_Q12, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            If (!(DSYN & One))
            {
                If (ATKP)
                {
                    ^^^^ATKD.IANE (0x6B)
                }
            }
            ElseIf (ATKP)
            {
                ^^^^ATKD.IANE (0x6F)
            }
        }

        Method (_Q13, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            If ((MSOS () >= OSW8))
            {
                STB2 (0xE0)
                STB2 (0x20)
                STB2 (0xE0)
                STB2 (0xA0)
                Return (Zero)
            }

            If (ATKP)
            {
                ^^^^ATKD.IANE (0x32)
            }

            Return (Zero)
        }

        Method (_Q16, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            If (ATKP)
            {
                ^^^^ATKD.IANE (0x7C)
            }

            Return (Zero)
        }

        Method (_Q14, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            If ((MSOS () >= OSW8))
            {
                STB2 (0xE0)
                STB2 (0x2E)
                STB2 (0xE0)
                STB2 (0xAE)
                Return (Zero)
            }

            If (ATKP)
            {
                ^^^^ATKD.IANE (0x31)
            }

            Return (Zero)
        }

        Method (_Q15, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            If ((MSOS () >= OSW8))
            {
                STB2 (0xE0)
                STB2 (0x30)
                STB2 (0xE0)
                STB2 (0xB0)
                Return (Zero)
            }

            If (ATKP)
            {
                ^^^^ATKD.IANE (0x30)
            }

            Return (Zero)
        }

        Method (_Q17, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            If (ATKP)
            {
                ^^^^ATKD.IANE (0x85)
            }

            Return (Zero)
        }

        Method (_Q78, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            If (ATKP)
            {
                ^^^^ATKD.IANE (0x85)
            }

            Return (Zero)
        }

        Method (_Q18, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            If (ATKP)
            {
                ^^^^ATKD.IANE (0x86)
            }

            Return (Zero)
        }

        Method (_Q6F, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            If (ATKP)
            {
                ^^^^ATKD.IANE (0x45)
            }
        }

        Method (_Q6E, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            If (ATKP)
            {
                ^^^^ATKD.IANE (0x43)
            }
        }

        Method (_Q6C, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            If (ATKP)
            {
                ^^^^ATKD.IANE (0x40)
            }
        }

        Method (_Q6D, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            If (ATKP)
            {
                ^^^^ATKD.IANE (0x41)
            }
        }

        Method (_Q73, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            If (ATKP)
            {
                ^^^^ATKD.IANE (0x9D)
            }
        }

        Method (_Q71, 0, NotSerialized)  // _Qxx: EC Query, xx=0x00-0xFF
        {
            If (ATKP)
            {
                ^^^^ATKD.IANE (0x5B)
            }
        }


/* ---- PEPD: CLED/MLED saved and restored around display-off ---- */
                    If ((Arg2 == 0x03))
                    {
                        If ((S0ID == One))
                        {
                            D8XH (Zero, 0xC5)
                            D8XH (One, Zero)
                            ^^PC00.LPCB.EC0.CSEE (0xB7)
                            MLED = GGOV (0x09020007)
                            If ((MLED == Zero))
                            {
                                SGOV (0x09020007, One)
                            }

                            CLED = GGOV (0x090E000F)
                            If ((CLED == Zero))
                            {
                                SGOV (0x090E000F, One)
                            }
                        }
                    }

                    If ((Arg2 == 0x04))
                    {
                        If ((S0ID == One))
                        {
                            D8XH (Zero, 0xC5)
                            D8XH (One, 0xAB)
                        }

                        ^^PC00.LPCB.EC0.CSEE (0xB8)
                        If ((MLED == Zero))
                        {
                            SGOV (0x09020007, Zero)
                        }

                        If ((CLED == Zero))
                        {
                            SGOV (0x090E000F, Zero)
                        }
                    }

/* ---- WMNB (ATK WMI dispatcher) ---- */
            Method (WMNB, 3, Serialized)
            {
                CreateDWordField (Arg2, Zero, IIA0)
                CreateDWordField (Arg2, 0x04, IIA1)
                Local0 = (Arg1 & 0xFFFFFFFF)
                If ((Local0 == 0x54494E49))
                {
                    Return (INIT (IIA0))
                }

                If ((Local0 == 0x53545342))
                {
                    Return (BSTS ())
                }

                If ((Local0 == 0x4E554653))
                {
                    Return (SFUN ())
                }

                If ((Local0 == 0x474F4457))
                {
                    Return (WDOG (IIA0))
                }

                If ((Local0 == 0x494E424B))
                {
                    Return (KBNI ())
                }

                If ((Local0 == 0x47444353))
                {
                    Return (SCDG (IIA0, IIA1))
                }

                If ((Local0 == 0x43455053))
                {
                    Return (SPEC (IIA0))
                }

                If ((Local0 == 0x5256534F))
                {
                    OSVR (IIA0)
                    Return (One)
                }

                If ((Local0 == 0x53524556))
                {
                    Return (VERS (IIA0, IIA1))
                }

                If ((Local0 == 0x4C425053))
                {
                    Return (SPBL (IIA0))
                }

                If ((Local0 == 0x50534453))
                {
                    Return (SDSP (IIA0))
                }

                If ((Local0 == 0x50534447))
                {
                    Return (GDSP (IIA0))
                }

                If ((Local0 == 0x44434C47))
                {
                    Return (GLCD ())
                }

                If ((Local0 == 0x49564E41))
                {
                    Return (ANVI (IIA0))
                }

                If ((Local0 == 0x46494243))
                {
                    Return (CBIF (IIA0))
                }

                If ((Local0 == 0x4C4E4146))
                {
                    Return (FANL (IIA0))
                }

                If ((Local0 == 0x4647574D))
                {
                    If ((IIA0 == 0x00020013)){}
                    If ((IIA0 == 0x00010016))
                    {
                        Local0 = OFBD (IIA1)
                        If (Local0)
                        {
                            SMIF = One
                            Return (ASMI (IIA1))
                        }

                        Return (Zero)
                    }

                    If ((IIA0 == 0x0006001F))
                    {
                        SMIF = 0x02
                        Return (ASMI (Zero))
                    }

                    If ((IIA0 == 0x0010001F))
                    {
                        SMIF = 0x03
                        Return (ASMI (IIA1))
                    }
                }

                If ((Local0 == 0x53545344))
                {
                    If ((IIA0 == 0x00010002))
                    {
                        Return (Zero)
                    }

                    If ((IIA0 == 0x00050027))
                    {
                        Return (Zero)
                    }

                    If ((IIA0 == 0x00010011))
                    {
                        If (WLDP)
                        {
                            Return (0x00030001)
                        }
                        Else
                        {
                            Return (0x02)
                        }
                    }

                    If ((IIA0 == 0x00010013))
                    {
                        If (BTDP)
                        {
                            Return (0x00030001)
                        }
                        Else
                        {
                            Return (0x02)
                        }
                    }

                    If ((IIA0 == 0x00080041))
                    {
                        Return (Zero)
                    }

                    If ((IIA0 == 0x00080042))
                    {
                        Return (0x00010000)
                    }

                    If ((IIA0 == 0x00080043))
                    {
                        Return (Zero)
                    }

                    If ((IIA0 == 0x00080044))
                    {
                        Return (Zero)
                    }

                    If ((IIA0 == 0x00030022))
                    {
                        Local0 = Zero
                        Return (Local0)
                    }

                    If ((IIA0 == 0x00100054))
                    {
                        Local0 = Zero
                        Return (Local0)
                    }

                    If ((IIA0 == 0x00060061))
                    {
                        Return (0x00010000)
                    }

                    If ((IIA0 == 0x00020011))
                    {
                        Return ((GALE (One) | 0x00050000))
                    }

                    If ((IIA0 == 0x00020012))
                    {
                        Return ((GALE (0x02) | 0x00050000))
                    }

                    If ((IIA0 == 0x00020013))
                    {
                        Return ((GALE (0x04) | 0x00050000))
                    }

                    If ((IIA0 == 0x00040015))
                    {
                        Return ((GALE (0x08) | 0x00050000))
                    }

                    If ((IIA0 == 0x00020014))
                    {
                        Return ((GALE (0x10) | 0x00050000))
                    }

                    If ((IIA0 == 0x00020015))
                    {
                        Return ((GALE (0x20) | 0x00050000))
                    }

                    If ((IIA0 == 0x00020016))
                    {
                        Return ((GALE (0x40) | 0x00050000))
                    }

                    If ((IIA0 == 0x00040017))
                    {
                        Local0 = GGOV (0x09020007)
                        Local0 = ~Local0
                        Local0 &= One
                        Local0 |= 0x00010000
                        Return (Local0)
                        Return (Zero)
                    }

                    If ((IIA0 == 0x000600B1))
                    {
                        MEMD [Zero] = Zero
                        CA1M = CA14 /* \_SB_.CA14 */
                        If ((ToInteger (CA14) == Zero))
                        {
                            Return (MEMD) /* \_SB_.ATKD.MEMD */
                        }

                        Local2 = Zero
                        Local3 = One
                        Local1 = CA1M /* \_SB_.ATKD.CA1M */
                        MEMD [Zero] = 0x0200
                        While ((Local3 < 0x81))
                        {
                            MEMD [Local3] = RMEM ((Local1 + Local2))
                            Local2 += 0x04
                            Local3 += One
                        }

                        Return (MEMD) /* \_SB_.ATKD.MEMD */
                    }

                    If ((IIA0 == 0x00120078))
                    {
                        Local0 = Zero
                        Return (Local0)
                    }

                    If ((IIA0 == 0x00010032))
                    {
                        Return (0x00010000)
                    }

                    If ((IIA0 == 0x00100063))
                    {
                        If ((DIBF == 0x02))
                        {
                            Return (0x00010001)
                        }

                        If ((DIBF == One))
                        {
                            Return (0x00010001)
                        }

                        If ((DIBF == Zero))
                        {
                            Return (0x00010000)
                        }
                    }

                    If ((IIA0 == 0x00060069))
                    {
                        If ((PSHB == Zero))
                        {
                            Return (0x00010000)
                        }
                        Else
                        {
                            Return (0x00030000)
                        }
                    }

                    If ((IIA0 == 0x00130041))
                    {
                        Return (0x00010000)
                    }

                    If ((IIA0 == 0x00060076))
                    {
                        If (GGIV (0x09000003))
                        {
                            Return (0x00010001)
                        }
                        Else
                        {
                            Return (0x00010000)
                        }
                    }

                    If ((IIA0 == 0x00050042))
                    {
                        Return (0x36)
                    }

                    If ((IIA0 == 0x00050043))
                    {
                        Local0 = Zero
                        Local1 = 0x00010000
                        Local0 |= Local1
                        Local1 = Zero
                        Local0 |= Local1
                        Return (Local0)
                    }

                    If ((IIA0 == 0x00050002))
                    {
                        Return (0x00010000)
                    }

                    If ((IIA0 == 0x00110019))
                    {
                        Local0 = FANF /* \_SB_.FANF */
                        Local1 = 0x00070000
                        Local0 |= Local1
                        Return (Local0)
                    }

                    If ((IIA0 == 0x00110013))
                    {
                        Local0 = ^^PC00.LPCB.EC0.RTAH (Zero)
                        Local0 /= 0x64
                        Return ((0x00010000 + Local0))
                    }

                    If ((IIA0 == 0x00110014))
                    {
                        Local0 = ^^PC00.LPCB.EC0.RRAM (0xCC, 0x10)
                        If ((Local0 & 0x02))
                        {
                            Local0 = ^^PC00.LPCB.EC0.RTAH (One)
                            Local0 /= 0x64
                            Return ((0x00010000 + Local0))
                        }

                        Return (Zero)
                    }

                    If ((IIA0 == 0x00010001))
                    {
                        Return (0x00040000)
                    }

                    If ((IIA0 == 0x00120061))
                    {
                        Return (Zero)
                    }

                    If ((IIA0 == 0x00110015))
                    {
                        Return (Zero)
                    }

                    If ((IIA0 == 0x00110016))
                    {
                        Return (Zero)
                    }

                    If ((IIA0 == 0x00050021))
                    {
                        Return (0x00200000)
                    }

                    If ((IIA0 == 0x00100051))
                    {
                        Return (0x00010001)
                    }

                    If ((IIA0 == 0x00120057))
                    {
                        Name (RBU1, Buffer (0x02)
                        {
                             0x00, 0x00                                       // ..
                        })
                        RBU1 = ^^PC00.LPCB.EC0.REBC (0x05, 0x02)
                        Local1 = DerefOf (RBU1 [One])
                        Local0 = 0x00010000
                        Local0 |= 0x00080000
                        If ((Local1 & One))
                        {
                            Local0 |= 0x00100000
                        }

                        If ((Local1 & 0x80))
                        {
                            Local0 |= 0x0200
                        }

                        Local0 |= 0x00800000
                        If ((Local1 & 0x10))
                        {
                            Local0 |= 0x0800
                        }

                        Return (Local0)
                    }

                    If ((IIA0 == 0x0012006D))
                    {
                        Local0 = ^^PC00.LPCB.EC0.ST8E (0x4E, Zero)
                        Local1 = (Local0 & 0x03)
                        If ((Local1 != Zero))
                        {
                            Return (0x00010001)
                        }
                        Else
                        {
                            Return (0x00010000)
                        }
                    }

                    If ((IIA0 == 0x00100023))
                    {
                        If ((KFSK == 0x80))
                        {
                            Return (0x00010001)
                        }
                        Else
                        {
                            Return (0x00010002)
                        }
                    }

                    If ((IIA0 == 0x00060078))
                    {
                        Local0 = GGOV (0x090E000F)
                        Local0 = ~Local0
                        Local0 &= One
                        Local0 = ~Local0
                        Local0 &= One
                        Local0 |= 0x00010000
                        Local0 |= 0x00020000
                        Return (Local0)
                        Return (Zero)
                    }

                    If ((IIA0 == 0x00060079))
                    {
                        Return (Zero)
                    }

                    If ((IIA0 == 0x00050033))
                    {
                        Return (0x00010000)
                    }

                    If ((IIA0 == 0x00060059))
                    {
                        Return (0x00010000)
                    }

                    If ((IIA0 == 0x00060068))
                    {
                        Local0 = (0x00010000 | ASPS) /* \_SB_.ASPS */
                        Return (Local0)
                    }

                    If ((IIA0 == 0x00060023))
                    {
                        Local0 = (^^PC00.LPCB.EC0.STA8 (Zero) & 0x03)
                        If (Ones)
                        {
                            Local0 |= 0x04
                        }

                        If (((^^PC00.LPCB.EC0.STA8 (Zero) & 0x80) == 0x80))
                        {
                            If ((^^PC00.LPCB.EC0.STA8 (0x02) == 0x03))
                            {
                                Local0 |= 0x08
                            }
                        }

                        Return (Local0)
                    }

                    If ((IIA0 == 0x00060024))
                    {
                        Return (Package (0x03)
                        {
                            0x51ED8086, 
                            One, 
                            0xFFFFFFFF
                        })
                    }

                    If ((IIA0 == 0x00060026))
                    {
                        Local0 = ^^PC00.LPCB.EC0.STA8 (Zero)
                        Local0 &= 0x04
                        If ((Local0 == 0x04))
                        {
                            Return (0x00010001)
                        }
                        ElseIf ((Local0 == Zero))
                        {
                            Return (0x00010000)
                        }
                    }
                }

                If ((Local0 == 0x53564544))
                {
                    If ((IIA0 == 0x00010012))
                    {
                        WLED (IIA1)
                        Return (One)
                    }

                    If ((IIA0 == 0x00010013))
                    {
                        BLED (IIA1)
                        Return (One)
                    }

                    If ((IIA0 == 0x00010003))
                    {
                        Return (CWAP (IIA1))
                    }

                    If ((IIA0 == 0x00100054))
                    {
                        Return (Zero)
                    }

                    If ((IIA0 == 0x00060057))
                    {
                        Return (Zero)
                    }

                    If ((IIA0 == 0x00100013))
                    {
                        If ((IIA1 == Zero)){}
                        If ((IIA1 == One)){}
                        If ((IIA1 == 0x02))
                        {
                            If (^^PC00.LPCB.EC0.ECAV ())
                            {
                                Acquire (^^PC00.LPCB.EC0.MU4T, 0xFFFF)
                                ^^PC00.LPCB.EC0.CMD = 0xFF
                                ^^PC00.LPCB.EC0.EDA1 = 0xB6
                                ^^PC00.LPCB.EC0.EDA2 = Zero
                                ^^PC00.LPCB.EC0.ECAC ()
                                Release (^^PC00.LPCB.EC0.MU4T)
                                Return (One)
                            }
                        }

                        Return (Zero)
                    }

                    If ((IIA0 == 0x00120078))
                    {
                        Local0 = 0xCF
                        If (^^PC00.LPCB.EC0.ECAV ())
                        {
                            Acquire (^^PC00.LPCB.EC0.MU4T, 0xFFFF)
                            ^^PC00.LPCB.EC0.CMD = Local0
                            ^^PC00.LPCB.EC0.EDA1 = Local0
                            ^^PC00.LPCB.EC0.EDA3 = IIA1 /* \_SB_.ATKD.WMNB.IIA1 */
                            ^^PC00.LPCB.EC0.ECAC ()
                            Release (^^PC00.LPCB.EC0.MU4T)
                        }

                        Return (One)
                    }

                    If ((IIA0 == 0x00010032))
                    {
                        Local0 = (IIA1 & 0x03)
                        If ((Local0 & One))
                        {
                            SGOV (0x09080011, One)
                        }
                        Else
                        {
                            SGOV (0x09080011, Zero)
                        }

                        Return (One)
                    }

                    If ((IIA0 == 0x00100063))
                    {
                        Return (DIAL (IIA1))
                    }

                    If ((IIA0 == 0x00060069))
                    {
                        If (ATKP)
                        {
                            If ((IIA1 == One))
                            {
                                PSFD = Zero
                                ^^PC00.LPCB.EC0.PSNS ()
                            }

                            If ((IIA1 == Zero))
                            {
                                PSFD = One
                                ^^PC00.LPCB.EC0.PSNS ()
                            }
                        }

                        Return (One)
                    }

                    If ((IIA0 == 0x00040017))
                    {
                        If ((IIA1 == One))
                        {
                            SGOV (0x09020007, Zero)
                        }
                        Else
                        {
                            SGOV (0x09020007, One)
                        }

                        Return (One)
                    }

                    If ((IIA0 == 0x00110019))
                    {
                        FANL (IIA1)
                        Return (One)
                    }

                    If ((IIA0 == 0x00050011))
                    {
                        If ((IIA1 == 0x02))
                        {
                            ^^PC00.LPCB.EC0.BLCT = One
                        }

                        Return (One)
                    }

                    If ((IIA0 == 0x00050021))
                    {
                        ^^PC00.LPCB.EC0.SLKB (IIA1)
                        Return (One)
                    }

                    If ((IIA0 == 0x00100022))
                    {
                        Return (One)
                    }

                    If ((IIA0 == 0x00100021))
                    {
                        If ((IIA1 == 0x6C))
                        {
                            ^^PC00.LPCB.EC0._Q0A ()
                            Return (Zero)
                        }

                        If ((IIA1 == 0x88))
                        {
                            ^^PC00.LPCB.EC0._Q0B ()
                            Return (Zero)
                        }

                        If ((IIA1 == 0xC5))
                        {
                            ^^PC00.LPCB.EC0.KBLD ()
                            Return (Zero)
                        }

                        If ((IIA1 == 0xC4))
                        {
                            ^^PC00.LPCB.EC0.KBLU ()
                            Return (Zero)
                        }

                        If ((IIA1 == 0x10))
                        {
                            ^^PC00.LPCB.EC0._Q0E ()
                            Return (Zero)
                        }

                        If ((IIA1 == 0x20))
                        {
                            ^^PC00.LPCB.EC0._Q0F ()
                            Return (Zero)
                        }

                        If ((IIA1 == 0x35))
                        {
                            ^^PC00.LPCB.EC0._Q10 ()
                            Return (Zero)
                        }

                        If ((IIA1 == 0x6B))
                        {
                            ^^PC00.LPCB.EC0._Q12 ()
                            Return (Zero)
                        }

                        If ((IIA1 == 0x5B))
                        {
                            ^^PC00.LPCB.EC0._Q71 ()
                            Return (Zero)
                        }

                        If ((IIA1 == 0xC7))
                        {
                            IANE (IIA1)
                            Return (Zero)
                        }

                        If ((IIA1 == 0x85))
                        {
                            ^^PC00.LPCB.EC0._Q17 ()
                            Return (Zero)
                        }

                        If ((IIA1 == 0x86))
                        {
                            ^^PC00.LPCB.EC0._Q18 ()
                            Return (Zero)
                        }

                        If ((IIA1 == 0x4E))
                        {
                            ^^PC00.LPCB.EC0._QD5 ()
                            Return (Zero)
                        }

                        If ((IIA1 == 0x9D))
                        {
                            IANE (IIA1)
                            Return (Zero)
                        }

                        If ((IIA1 == 0x7C))
                        {
                            IANE (IIA1)
                            Return (Zero)
                        }

                        If ((IIA1 == 0x9E))
                        {
                            IANE (IIA1)
                            Return (Zero)
                        }

                        If ((IIA1 == 0xA8))
                        {
                            IANE (IIA1)
                            Return (Zero)
                        }

                        If ((IIA1 == 0xA9))
                        {
                            IANE (IIA1)
                            Return (Zero)
                        }

                        If ((IIA1 == 0xAA))
                        {
                            IANE (IIA1)
                            Return (Zero)
                        }

                        If ((IIA1 == 0xAB))
                        {
                            IANE (IIA1)
                            Return (Zero)
                        }

                        Return (One)
                    }

                    If ((IIA0 == 0x00110013))
                    {
                        Local0 = ^^PC00.LPCB.EC0.RRAM (0xCC, 0x30)
                        If ((IIA1 == Zero))
                        {
                            Local1 = (Local0 & 0xFFFFFFFFFFFFFFBF)
                        }
                        ElseIf ((IIA1 == One))
                        {
                            Local1 = (Local0 | 0x40)
                        }

                        ^^PC00.LPCB.EC0.WRAM (0xCD, 0x30, Local1)
                        Return (One)
                    }

                    If ((IIA0 == 0x00110014))
                    {
                        Local0 = ^^PC00.LPCB.EC0.RRAM (0xCC, 0x10)
                        If ((Local0 & 0x02))
                        {
                            Local0 = ^^PC00.LPCB.EC0.RRAM (0xCC, 0x30)
                            If ((IIA1 == Zero))
                            {
                                Local1 = (Local0 & 0xFFFFFFFFFFFFFFBF)
                            }
                            ElseIf ((IIA1 == One))
                            {
                                Local1 = (Local0 | 0x40)
                            }

                            ^^PC00.LPCB.EC0.WRAM (0xCD, 0x30, Local1)
                            Return (One)
                        }

                        Return (Zero)
                    }

                    If ((IIA0 == 0x00110015))
                    {
                        Return (Zero)
                    }

                    If ((IIA0 == 0x00110016))
                    {
                        Return (Zero)
                    }

                    If ((IIA0 == 0x00120057))
                    {
                        Local0 = ^^PC00.LPCB.EC0.SRSC (IIA1)
                        If ((ACPF == One))
                        {
                            Notify (^^PC00.LPCB.EC0.BAT0, 0x80) // Status Change
                        }

                        Return (Local0)
                    }

                    If ((IIA0 == 0x00100023))
                    {
                        If ((IIA1 == One))
                        {
                            Local0 = 0x08
                        }
                        ElseIf ((IIA1 == Zero))
                        {
                            Local0 = 0x04
                        }

                        Local0 = (KFSK | Local0)
                        ^^PC00.LPCB.EC0.ST9E (0x3C, 0xFF, Local0)
                        Return (One)
                    }

                    If ((IIA0 == 0x00060078))
                    {
                        If ((IIA1 == One))
                        {
                            Local2 = Zero
                            Local2 = ~Local2
                            Local2 &= One
                            SGOV (0x090E000F, Local2)
                            Local0 = One
                        }
                        ElseIf ((IIA1 == Zero))
                        {
                            Local2 = One
                            Local2 = ~Local2
                            Local2 &= One
                            SGOV (0x090E000F, Local2)
                            Local0 = 0x02
                        }

                        Return (One)
                    }

                    If ((IIA0 == 0x00060079))
                    {
                        Return (Zero)
                    }

                    Name (TPRZ, Zero)
                    Name (ECSS, Buffer (0x03)
                    {
                         0x00, 0x00, 0x00                                 // ...
                    })
                    Name (ECRF, Zero)
                    Name (ECWF, Zero)
                    If ((IIA0 == 0x00060059))
                    {
                        ECRF = Zero
                        ECWF = Zero
                        Local0 = (IIA1 & 0xFF)
                        TPRZ = (IIA1 & 0xFFFFFF00)
                        Local1 = (TPRZ >> 0x08)
                        Local2 = (Local1 & 0xFF)
                        ECSS [Zero] = Local2
                        Local1 >>= 0x08
                        Local2 = (Local1 & 0xFF)
                        ECSS [One] = Local2
                        Local1 >>= 0x08
                        Local2 = (Local1 & 0xFF)
                        ECSS [0x02] = Local2
                        If ((Local0 == 0xE2))
                        {
                            ECWF = One
                        }

                        If ((Local0 == 0xE4))
                        {
                            ECWF = One
                        }

                        If ((Local0 == 0xE6))
                        {
                            ECWF = One
                        }

                        If ((Local0 == 0xED))
                        {
                            ECWF = One
                        }

                        If ((Local0 == 0xEF))
                        {
                            ECWF = One
                        }

                        If ((Local0 == 0xE0))
                        {
                            ECRF = One
                        }

                        If ((Local0 == 0xE1))
                        {
                            ECRF = One
                        }

                        If ((Local0 == 0xE3))
                        {
                            ECRF = One
                        }

                        If ((Local0 == 0xE5))
                        {
                            ECRF = One
                        }

                        If ((Local0 == 0xEE))
                        {
                            ECRF = One
                        }

                        If ((One == ECWF))
                        {
                            Return (^^PC00.LPCB.EC0.WEBC (Local0, 0x03, ECSS))
                        }

                        If ((One == ECRF))
                        {
                            Return (^^PC00.LPCB.EC0.REB2 (Local0, 0x2E, ECSS, 0x03))
                        }
                    }

                    If ((IIA0 == 0x00060023))
                    {
                        Local0 = (IIA1 >> 0x09)
                        If (((Local0 & One) == One))
                        {
                            VBOF = One
                            Local0 = (IIA1 >> 0x18)
                            Local0 *= 0x0100
                            VBOF |= Local0 /* \_SB_.VBOF */
                        }
                        Else
                        {
                            VBOF = Zero
                        }

                        Local0 = (IIA1 & 0xFF)
                        ^^PC00.LPCB.EC0.STA9 (One, Local0)
                        Local0 = (IIA1 >> 0x08)
                        Local1 = ^^PC00.LPCB.EC0.STA8 (Zero)
                        If (((Local0 & One) == One))
                        {
                            Local1 |= 0x02
                            Local2 = (Local1 & 0x0F)
                            ^^PC00.LPCB.EC0.STA9 (Zero, Local1)
                        }
                        Else
                        {
                            Local1 &= 0xFD
                            Local2 = (Local1 & 0x0F)
                            ^^PC00.LPCB.EC0.STA9 (Zero, Local1)
                        }

                        Return (One)
                    }

                    If ((IIA0 == 0x00060026))
                    {
                        Local0 = ^^PC00.LPCB.EC0.STA8 (Zero)
                        If ((IIA1 == One))
                        {
                            Local0 |= 0x04
                            ^^PC00.LPCB.EC0.STA9 (Zero, Local0)
                        }
                        Else
                        {
                            Local0 &= 0xFB
                            ^^PC00.LPCB.EC0.STA9 (Zero, Local0)
                        }

                        Return (One)
                    }
                }

                Return (0xFFFFFFFE)
            }

            Method (_WED, 1, NotSerialized)  // _Wxx: Wake Event, xx=0x00-0xFF
            {
                If ((Arg0 == 0xFF))
                {
                    Return (GANQ ())
                }

                Return (Ones)
            }

            Name (WQMO, Buffer (0x0A7D)
            {
                /* 0000 */  0x46, 0x4F, 0x4D, 0x42, 0x01, 0x00, 0x00, 0x00,  // FOMB....
                /* 0008 */  0x6D, 0x0A, 0x00, 0x00, 0x6E, 0x38, 0x00, 0x00,  // m...n8..
                /* 0010 */  0x44, 0x53, 0x00, 0x01, 0x1A, 0x7D, 0xDA, 0x54,  // DS...}.T
                /* 0018 */  0x98, 0xD4, 0x9A, 0x00, 0x01, 0x06, 0x18, 0x42,  // .......B
                /* 0020 */  0x10, 0x05, 0x10, 0xD2, 0xA7, 0x8C, 0x42, 0x04,  // ......B.
                /* 0028 */  0x0A, 0x0D, 0xA1, 0x38, 0x44, 0x86, 0xA1, 0x12,  // ...8D...
                /* 0030 */  0x20, 0x24, 0x09, 0x42, 0x2E, 0x98, 0x98, 0x00,  //  $.B....
                /* 0038 */  0x21, 0x10, 0x92, 0x28, 0xC0, 0xBC, 0x00, 0xDD,  // !..(....
                /* 0040 */  0x02, 0x0C, 0x0B, 0xB0, 0x2D, 0xC0, 0xB4, 0x00,  // ....-...
                /* 0048 */  0xC7, 0x40, 0xEA, 0xDF, 0x1F, 0xA2, 0x34, 0x10,  // .@....4.
                /* 0050 */  0x89, 0x80, 0xA4, 0x52, 0x20, 0x24, 0x54, 0x80,  // ...R $T.
                /* 0058 */  0x72, 0x01, 0xBE, 0x05, 0x68, 0x47, 0x94, 0x64,  // r...hG.d
                /* 0060 */  0x01, 0x96, 0x61, 0x44, 0x60, 0xAF, 0xC8, 0x04,  // ..aD`...
                /* 0068 */  0x8D, 0x13, 0x94, 0x33, 0x0C, 0x14, 0xBC, 0x01,  // ...3....
                /* 0070 */  0xDB, 0x14, 0x60, 0x72, 0x10, 0x54, 0xF6, 0x20,  // ..`r.T. 
                /* 0078 */  0x50, 0x32, 0x20, 0xE4, 0x51, 0x80, 0x55, 0x38,  // P2 .Q.U8
                /* 0080 */  0x4D, 0x27, 0x81, 0xDD, 0x0B, 0x30, 0x27, 0xC0,  // M'...0'.
                /* 0088 */  0x9B, 0x00, 0x71, 0xA3, 0xD1, 0x0A, 0x5B, 0x84,  // ..q...[.
                /* 0090 */  0x92, 0x30, 0x01, 0xB6, 0x60, 0x84, 0x52, 0x1B,  // .0..`.R.
                /* 0098 */  0x8C, 0x50, 0x1A, 0x43, 0x10, 0x48, 0x9C, 0x28,  // .P.C.H.(
                /* 00A0 */  0x11, 0x1B, 0x14, 0xE0, 0x0C, 0x56, 0x28, 0x11,  // .....V(.
                /* 00A8 */  0xC3, 0x84, 0x88, 0x70, 0xA5, 0x31, 0xEC, 0x10,  // ...p.1..
                /* 00B0 */  0x4A, 0x68, 0x71, 0x23, 0xB4, 0x3F, 0x08, 0x12,  // Jhq#.?..
                /* 00B8 */  0x6D, 0xC5, 0x1A, 0xAA, 0x23, 0x8D, 0x06, 0x35,  // m...#..5
                /* 00C0 */  0xA2, 0x04, 0x07, 0xE6, 0xD1, 0x9C, 0x6A, 0xE7,  // ......j.
                /* 00C8 */  0x02, 0xA4, 0xCF, 0x55, 0x20, 0xC7, 0x7A, 0x8A,  // ...U .z.
                /* 00D0 */  0x75, 0x0E, 0x97, 0x80, 0x24, 0x30, 0x56, 0x82,  // u...$0V.
                /* 00D8 */  0x0E, 0x86, 0x08, 0xC5, 0x35, 0xA0, 0x26, 0x7E,  // ....5.&~
                /* 00E0 */  0x88, 0x4C, 0x10, 0x1C, 0x6A, 0x88, 0x1E, 0x6F,  // .L..j..o
                /* 00E8 */  0xB8, 0x13, 0x38, 0xEA, 0x23, 0x61, 0x10, 0xE7,  // ..8.#a..
                /* 00F0 */  0x74, 0x34, 0x98, 0x73, 0x80, 0xC7, 0x75, 0x32,  // t4.s..u2
                /* 00F8 */  0x67, 0x5C, 0xAA, 0x00, 0xB3, 0x43, 0xD7, 0x08,  // g\...C..
                /* 0100 */  0x13, 0x1C, 0x8F, 0xA1, 0xCF, 0xFE, 0x7C, 0x7A,  // ......|z
                /* 0108 */  0x86, 0x24, 0xF2, 0x07, 0x81, 0x1A, 0x99, 0xA1,  // .$......
                /* 0110 */  0x3D, 0xC6, 0xD3, 0x8A, 0x19, 0xF2, 0x29, 0xE0,  // =.....).
                /* 0118 */  0xB0, 0x98, 0xD8, 0x53, 0x02, 0x1D, 0x0F, 0xBC,  // ...S....
                /* 0120 */  0xFF, 0xFF, 0x78, 0xC0, 0xA3, 0xF8, 0x68, 0x20,  // ..x...h 
                /* 0128 */  0x84, 0x57, 0x82, 0xD8, 0x1E, 0xD0, 0xE3, 0x82,  // .W......
                /* 0130 */  0x81, 0xB1, 0x03, 0xB2, 0x5F, 0x01, 0x08, 0xC1,  // ...._...
                /* 0138 */  0xCB, 0x1C, 0x91, 0x9C, 0x22, 0x68, 0x4C, 0x9E,  // ...."hL.
                /* 0140 */  0x5C, 0xEB, 0x10, 0x02, 0x39, 0xA9, 0x43, 0x7E,  // \...9.C~
                /* 0148 */  0x59, 0x60, 0x88, 0xAF, 0x09, 0x9E, 0x7E, 0x85,  // Y`....~.
                /* 0150 */  0x80, 0x12, 0x39, 0x02, 0x94, 0x98, 0x11, 0xA0,  // ..9.....
                /* 0158 */  0xF0, 0x22, 0x87, 0x3C, 0x9B, 0x23, 0x38, 0x9E,  // .".<.#8.
                /* 0160 */  0x28, 0x27, 0x71, 0x40, 0x3E, 0x3A, 0x18, 0xE1,  // ('q@>:..
                /* 0168 */  0x10, 0xCA, 0x3D, 0x41, 0x10, 0xCD, 0x33, 0xD2,  // ..=A..3.
                /* 0170 */  0x34, 0xCE, 0xE9, 0x6D, 0xC0, 0x04, 0x73, 0xF8,  // 4..m..s.
                /* 0178 */  0x82, 0xE8, 0x04, 0xD2, 0x4B, 0x95, 0x8D, 0xA5,  // ....K...
                /* 0180 */  0x7A, 0xA4, 0x34, 0xFF, 0x19, 0x41, 0x33, 0x3C,  // z.4..A3<
                /* 0188 */  0x87, 0x10, 0x87, 0x98, 0xC0, 0xC9, 0x81, 0x74,  // .......t
                /* 0190 */  0xD2, 0xE0, 0x99, 0x49, 0x94, 0x7A, 0x34, 0x14,  // ...I.z4.
                /* 0198 */  0xCE, 0x39, 0x0F, 0x1C, 0x14, 0xC4, 0x80, 0x0E,  // .9......
                /* 01A0 */  0x01, 0xA1, 0x51, 0xF8, 0x1C, 0xC0, 0x07, 0xE1,  // ..Q.....
                /* 01A8 */  0x41, 0x3D, 0x2F, 0x18, 0xE2, 0x35, 0xC0, 0xA2,  // A=/..5..
                /* 01B0 */  0x0F, 0x0B, 0x74, 0x78, 0x3E, 0x06, 0x70, 0x0D,  // ..tx>.p.
                /* 01B8 */  0x10, 0xBA, 0x17, 0x18, 0xD9, 0x6A, 0x00, 0x29,  // .....j.)
                /* 01C0 */  0x18, 0x3F, 0x5C, 0x70, 0x82, 0xBA, 0xAE, 0x02,  // .?\p....
                /* 01C8 */  0xD0, 0x87, 0x79, 0x04, 0x9E, 0xC9, 0xBB, 0xC5,  // ..y.....
                /* 01D0 */  0x1F, 0x89, 0xF5, 0x1D, 0x05, 0x40, 0x01, 0xE4,  // .....@..
                /* 01D8 */  0xA9, 0x5B, 0xE9, 0xF0, 0xE9, 0x18, 0x42, 0x84,  // .[....B.
                /* 01E0 */  0x89, 0x66, 0x74, 0x1E, 0x7E, 0xAA, 0xA8, 0xB8,  // .ft.~...
                /* 01E8 */  0x53, 0xA5, 0x20, 0x9E, 0xEA, 0xFF, 0x3F, 0xC1,  // S. ...?.
                /* 01F0 */  0x28, 0x53, 0x45, 0xCF, 0xC4, 0x53, 0xE5, 0xF7,  // (SE..S..
                /* 01F8 */  0x03, 0x13, 0x58, 0xF8, 0x3D, 0x03, 0xDA, 0xA5,  // ..X.=...
                /* 0200 */  0x20, 0xE2, 0x13, 0x81, 0xA7, 0x61, 0x38, 0x4F,  //  ....a8O
                /* 0208 */  0x96, 0xC3, 0x79, 0xB2, 0x7C, 0x2C, 0xBE, 0x47,  // ..y.|,.G
                /* 0210 */  0xC0, 0x1F, 0x2D, 0x96, 0xA0, 0xC0, 0xD9, 0x82,  // ..-.....
                /* 0218 */  0x1C, 0x1E, 0x23, 0x78, 0xA4, 0x54, 0xD6, 0xB8,  // ..#x.T..
                /* 0220 */  0x50, 0x97, 0x03, 0x9F, 0x29, 0x18, 0xF6, 0x2B,  // P...)..+
                /* 0228 */  0xC2, 0xD1, 0xBC, 0x22, 0x9C, 0xE1, 0x53, 0xC4,  // ..."..S.
                /* 0230 */  0x41, 0x3D, 0x73, 0xD8, 0xA4, 0x4E, 0x93, 0x52,  // A=s..N.R
                /* 0238 */  0x61, 0x3D, 0x52, 0x0E, 0x6B, 0xB4, 0xB0, 0x07,  // a=R.k...
                /* 0240 */  0xFC, 0xBA, 0xE1, 0xB3, 0x8A, 0x67, 0x66, 0x8C,  // .....gf.
                /* 0248 */  0xB0, 0x1E, 0xAD, 0x03, 0xAD, 0x53, 0x97, 0x09,  // .....S..
                /* 0250 */  0x9C, 0x2C, 0x20, 0x5D, 0x33, 0x8E, 0xE8, 0x98,  // ., ]3...
                /* 0258 */  0x0E, 0x89, 0x09, 0xBA, 0x4C, 0x50, 0x08, 0x4B,  // ....LP.K
                /* 0260 */  0xA1, 0x90, 0x10, 0x08, 0x1D, 0x09, 0x78, 0x74,  // ......xt
                /* 0268 */  0x30, 0x0A, 0xE2, 0x91, 0x39, 0xD6, 0x91, 0x00,  // 0...9...
                /* 0270 */  0x2D, 0xEA, 0x0E, 0x41, 0x2F, 0x33, 0xB8, 0xC9,  // -..A/3..
                /* 0278 */  0x3E, 0xC4, 0x30, 0x90, 0x58, 0xEC, 0x62, 0xC0,  // >.0.X.b.
                /* 0280 */  0x0F, 0x06, 0x60, 0xFE, 0xFF, 0x13, 0xB0, 0x83,  // ..`.....
                /* 0288 */  0x01, 0xE0, 0x49, 0xA1, 0x53, 0xA9, 0x4E, 0x0F,  // ..I.S.N.
                /* 0290 */  0x06, 0xE0, 0x0A, 0x79, 0x30, 0x40, 0x4B, 0x05,  // ...y0@K.
                /* 0298 */  0xD2, 0x84, 0x6A, 0x3C, 0x40, 0xE9, 0xD6, 0x92,  // ..j<@...
                /* 02A0 */  0xC0, 0x22, 0x0F, 0x06, 0x28, 0x79, 0x14, 0x12,  // ."..(y..
                /* 02A8 */  0x77, 0x30, 0x40, 0xC9, 0x81, 0xA3, 0x20, 0x1E,  // w0@... .
                /* 02B0 */  0x99, 0xA3, 0x1E, 0x0C, 0xD0, 0xE3, 0x4C, 0x70,  // ......Lp
                /* 02B8 */  0x90, 0xC7, 0x72, 0x3C, 0x07, 0xF6, 0x5E, 0x73,  // ..r<..^s
                /* 02C0 */  0x36, 0x4F, 0x05, 0x1E, 0x7A, 0x9C, 0x40, 0x7C,  // 6O..z.@|
                /* 02C8 */  0x46, 0x86, 0x7A, 0xB5, 0x09, 0xF5, 0x7C, 0xE0,  // F.z...|.
                /* 02D0 */  0x53, 0x91, 0xC1, 0xDE, 0x11, 0x0C, 0xF5, 0x78,  // S......x
                /* 02D8 */  0x10, 0xD3, 0x93, 0x7B, 0xF9, 0xF2, 0x09, 0xC1,  // ...{....
                /* 02E0 */  0x68, 0xFC, 0x88, 0x00, 0x9C, 0xFF, 0xFF, 0x47,  // h......G
                /* 02E8 */  0x04, 0x60, 0xED, 0x54, 0xA3, 0x55, 0x9D, 0x47,  // .`.T.U.G
                /* 02F0 */  0x04, 0x70, 0x45, 0xBA, 0x26, 0xA1, 0x85, 0x01,  // .pE.&...
                /* 02F8 */  0x69, 0x1C, 0x87, 0xDB, 0xE7, 0x99, 0x4D, 0x04,  // i.....M.
                /* 0300 */  0x96, 0x04, 0xA4, 0x6B, 0x12, 0x17, 0x43, 0x21,  // ...k..C!
                /* 0308 */  0x19, 0x47, 0x04, 0x54, 0xF0, 0x83, 0x02, 0x05,  // .G.T....
                /* 0310 */  0x31, 0xA0, 0x53, 0x1D, 0x11, 0xD0, 0x87, 0x22,  // 1.S...."
                /* 0318 */  0x7B, 0x3F, 0x12, 0x90, 0x3B, 0xC1, 0x91, 0x9D,  // {?..;...
                /* 0320 */  0xCC, 0x99, 0xBD, 0x87, 0x9D, 0xEC, 0x5B, 0x81,  // ......[.
                /* 0328 */  0x87, 0xE4, 0x2B, 0x42, 0x98, 0x60, 0x0F, 0x06,  // ..+B.`..
                /* 0330 */  0x3E, 0x8F, 0xF9, 0xC2, 0xE5, 0xF3, 0x12, 0xE0,  // >.......
                /* 0338 */  0x4B, 0xC4, 0x98, 0x51, 0xB1, 0xC7, 0x4C, 0x41,  // K..Q..LA
                /* 0340 */  0x3C, 0x66, 0xDF, 0xF4, 0xFE, 0xFF, 0xC7, 0x8C,  // <f......
                /* 0348 */  0xFD, 0x08, 0x78, 0xBA, 0xB8, 0x2B, 0x86, 0xCF,  // ..x..+..
                /* 0350 */  0x32, 0xC0, 0xE5, 0xCC, 0x04, 0xB8, 0xF2, 0x2A,  // 2......*
                /* 0358 */  0xD1, 0xA7, 0xC7, 0x93, 0x05, 0xB8, 0xC2, 0x9D,  // ........
                /* 0360 */  0x65, 0xD0, 0x12, 0x81, 0xE4, 0xF2, 0xCE, 0xA4,  // e.......
                /* 0368 */  0x03, 0x9D, 0x09, 0x7C, 0x8E, 0xF1, 0x59, 0x86,  // ...|..Y.
                /* 0370 */  0x1F, 0x9D, 0x2C, 0xEA, 0x58, 0x80, 0x3A, 0x5C,  // ..,.X.:\
                /* 0378 */  0x18, 0xCC, 0x20, 0x1E, 0x99, 0x23, 0x1E, 0x0B,  // .. ..#..
                /* 0380 */  0xD0, 0x23, 0xF6, 0x79, 0xE0, 0xB1, 0xC0, 0xB7,  // .#.y....
                /* 0388 */  0x3D, 0x9F, 0xE8, 0xD8, 0x3D, 0xC6, 0x77, 0x26,  // =...=.w&
                /* 0390 */  0x76, 0x2E, 0x34, 0xD4, 0xAB, 0x41, 0x24, 0x8F,  // v.4..A$.
                /* 0398 */  0xEA, 0xCD, 0xCF, 0xA8, 0x8F, 0x33, 0xEF, 0x31,  // .....3.1
                /* 03A0 */  0xD8, 0xE3, 0x01, 0xBC, 0xFF, 0xFF, 0x39, 0x06,  // ......9.
                /* 03A8 */  0x30, 0xEA, 0x52, 0xE1, 0x0B, 0xED, 0xF1, 0x00,  // 0.R.....
                /* 03B0 */  0x5C, 0xA2, 0x56, 0xA1, 0xE3, 0x01, 0x2E, 0xDA,  // \.V.....
                /* 03B8 */  0x5A, 0x34, 0xA1, 0x33, 0x3B, 0xDD, 0xE7, 0x18,  // Z4.3;...
                /* 03C0 */  0x16, 0xEA, 0x1C, 0x83, 0xBA, 0xF3, 0x3A, 0xD2,  // ......:.
                /* 03C8 */  0xF1, 0x00, 0x15, 0xE2, 0x78, 0x40, 0x41, 0x3C,  // ....x@A<
                /* 03D0 */  0x2E, 0x87, 0x3B, 0x1E, 0xA0, 0xE5, 0xDD, 0x6D,  // ..;....m
                /* 03D8 */  0xC9, 0xC4, 0x7C, 0x03, 0xF1, 0x84, 0xA2, 0x3C,  // ..|....<
                /* 03E0 */  0x15, 0x3C, 0x17, 0xF0, 0x63, 0x8C, 0x0F, 0x06,  // .<..c...
                /* 03E8 */  0x6F, 0x4C, 0x3E, 0x20, 0x3C, 0x1F, 0xBC, 0x1A,  // oL> <...
                /* 03F0 */  0x60, 0xC0, 0x4E, 0x2B, 0x8E, 0x21, 0x5E, 0x65,  // `.N+.!^e
                /* 03F8 */  0x80, 0xE3, 0xFF, 0xFF, 0x6E, 0xC0, 0x52, 0x0C,  // ....n.R.
                /* 0400 */  0x0F, 0xAD, 0xE3, 0xD8, 0x40, 0x86, 0x16, 0xE1,  // ....@...
                /* 0408 */  0xEC, 0xCE, 0xCF, 0x53, 0x02, 0xEF, 0xB8, 0x7D,  // ...S...}
                /* 0410 */  0xDA, 0x01, 0xCE, 0xA7, 0x40, 0x9F, 0x0C, 0x78,  // ....@..x
                /* 0418 */  0xD8, 0x21, 0x51, 0x10, 0x9F, 0x10, 0x1C, 0xE4,  // .!Q.....
                /* 0420 */  0x9A, 0x0A, 0xE5, 0x32, 0x80, 0x39, 0x7A, 0x80,  // ...2.9z.
                /* 0428 */  0x7D, 0x20, 0x3E, 0x91, 0x01, 0xA2, 0x1C, 0x4A,  // } >....J
                /* 0430 */  0x3C, 0xE8, 0xE8, 0xFF, 0x7F, 0xF4, 0x00, 0x53,  // <......S
                /* 0438 */  0xA6, 0x13, 0x19, 0x5A, 0xD9, 0xD1, 0x83, 0x8C,  // ...Z....
                /* 0440 */  0xD2, 0x53, 0x4B, 0x60, 0x4D, 0x47, 0x0F, 0x94,  // .SK`MG..
                /* 0448 */  0x1A, 0x0A, 0xE9, 0x39, 0x7A, 0xA0, 0x14, 0x5C,  // ...9z..\
                /* 0450 */  0x87, 0xF9, 0x41, 0x87, 0xC6, 0x3B, 0xE8, 0x40,  // ..A..;.@
                /* 0458 */  0x39, 0x7A, 0xC0, 0xBB, 0x76, 0xE0, 0x0E, 0x55,  // 9z..v..U
                /* 0460 */  0x6C, 0x5C, 0x67, 0x68, 0xC8, 0x43, 0x7B, 0x34,  // l\gh.C{4
                /* 0468 */  0xF3, 0x81, 0x27, 0xB0, 0x2F, 0xC5, 0x80, 0xDF,  // ..'./...
                /* 0470 */  0xC3, 0xB9, 0x0F, 0x92, 0x3E, 0x6D, 0xF3, 0x1B,  // ....>m..
                /* 0478 */  0x19, 0xF0, 0xF8, 0xFF, 0xDF, 0x2C, 0x00, 0x41,  // .....,.A
                /* 0480 */  0x42, 0x2D, 0x3A, 0xBC, 0x3A, 0x82, 0xFF, 0xE6,  // B-:.:...
                /* 0488 */  0x78, 0x44, 0xB5, 0x4E, 0x49, 0x57, 0x47, 0x38,  // xD.NIWG8
                /* 0490 */  0xF7, 0x54, 0x1F, 0x09, 0x38, 0x99, 0xE1, 0x4C,  // .T..8..L
                /* 0498 */  0x61, 0x40, 0xA7, 0x3B, 0x12, 0xA0, 0xAF, 0x0B,  // a@.;....
                /* 04A0 */  0x1E, 0xCF, 0xC1, 0x3C, 0x56, 0x3C, 0x52, 0x78,  // ...<V<Rx
                /* 04A8 */  0x3C, 0xE7, 0xFA, 0x9E, 0x16, 0xE8, 0x3C, 0x7C,  // <.....<|
                /* 04B0 */  0x46, 0xF2, 0xE4, 0x43, 0xBD, 0x19, 0x78, 0x50,  // F..C..xP
                /* 04B8 */  0x06, 0x8A, 0xC5, 0xB4, 0x1F, 0x01, 0xC9, 0xF5,  // ........
                /* 04C0 */  0xCC, 0x27, 0x32, 0x76, 0xB2, 0x00, 0x8C, 0xFC,  // .'2v....
                /* 04C8 */  0xFF, 0x6F, 0xEF, 0x00, 0x87, 0x7C, 0x3A, 0xD5,  // .o...|:.
                /* 04D0 */  0xAA, 0xF4, 0x64, 0x01, 0x2E, 0xC5, 0x97, 0x39,  // ..d....9
                /* 04D8 */  0x74, 0xEE, 0xB5, 0xE8, 0x60, 0x71, 0x48, 0x98,  // t...`qH.
                /* 04E0 */  0xC4, 0x27, 0x0B, 0x54, 0x56, 0x0A, 0x25, 0x3B,  // .'.TV.%;
                /* 04E8 */  0x59, 0xA0, 0xB2, 0x9C, 0x2C, 0x28, 0x88, 0xC7,  // Y...,(..
                /* 04F0 */  0xE5, 0xDB, 0x3B, 0x7E, 0xF4, 0x3E, 0xE0, 0xBE,  // ..;~.>..
                /* 04F8 */  0x02, 0xB1, 0xC3, 0xA3, 0x47, 0x04, 0xE3, 0x56,  // ....G..V
                /* 0500 */  0x81, 0xFD, 0xFF, 0xDF, 0x2A, 0x80, 0xEB, 0x5D,  // ....*..]
                /* 0508 */  0x16, 0x7F, 0xD1, 0xF7, 0x8D, 0xE0, 0x99, 0x1B,  // ........
                /* 0510 */  0xCE, 0xC8, 0x80, 0xC7, 0x81, 0x0E, 0x78, 0x0B,  // ......x.
                /* 0518 */  0xBA, 0x1C, 0xA0, 0x24, 0x5C, 0x0E, 0x28, 0x88,  // ...$\.(.
                /* 0520 */  0xCF, 0x5B, 0x70, 0xC4, 0xCD, 0x90, 0x5C, 0x0D,  // .[p...\.
                /* 0528 */  0xC0, 0x71, 0x49, 0x30, 0x86, 0x6F, 0x33, 0xFC,  // .qI0.o3.
                /* 0530 */  0x6C, 0x07, 0x1C, 0xFE, 0xFF, 0x17, 0x11, 0xC0,  // l.......
                /* 0538 */  0x92, 0x56, 0x8B, 0x4A, 0x9D, 0x5E, 0x44, 0xC0,  // .V.J.^D.
                /* 0540 */  0x15, 0xE6, 0xC6, 0x84, 0xBE, 0x2D, 0xF9, 0x6C,  // .....-.l
                /* 0548 */  0xE7, 0xE9, 0x1F, 0xDA, 0x01, 0x90, 0x8B, 0x08,  // ........
                /* 0550 */  0x4A, 0x06, 0x85, 0x84, 0x1C, 0x0E, 0x50, 0xE7,  // J.....P.
                /* 0558 */  0x47, 0xC3, 0x19, 0xC4, 0x80, 0xCE, 0x75, 0x38,  // G.....u8
                /* 0560 */  0x40, 0x4F, 0xD9, 0x43, 0x39, 0xB3, 0x47, 0x3B,  // @O.C9.G;
                /* 0568 */  0x9F, 0x89, 0x7D, 0xA0, 0x3B, 0xD8, 0x17, 0x54,  // ..}.;..T
                /* 0570 */  0x23, 0x3D, 0x8E, 0x1C, 0xDD, 0x19, 0x9D, 0xD2,  // #=......
                /* 0578 */  0xAB, 0x99, 0x11, 0x62, 0x1D, 0x97, 0x2F, 0x08,  // ...b../.
                /* 0580 */  0x3E, 0xBD, 0x03, 0x6E, 0xFE, 0xFF, 0xF7, 0x3A,  // >..n...:
                /* 0588 */  0x80, 0x3F, 0x0A, 0x65, 0x1E, 0x2B, 0xC0, 0x15,  // .?.e.+..
                /* 0590 */  0xE0, 0x58, 0x81, 0x3E, 0x4F, 0x78, 0x42, 0x87,  // .X.>OxB.
                /* 0598 */  0xFB, 0x5C, 0xE1, 0x57, 0x09, 0x3F, 0x56, 0xF0,  // .\.W.?V.
                /* 05A0 */  0xE8, 0x24, 0x3A, 0x12, 0xC0, 0xCD, 0x72, 0x24,  // .$:...r$
                /* 05A8 */  0x40, 0x5F, 0x20, 0x7C, 0xAC, 0xC0, 0x5F, 0x3D,  // @_ |.._=
                /* 05B0 */  0xF9, 0x81, 0x02, 0xE6, 0xFF, 0xFF, 0x3A, 0x07,  // ......:.
                /* 05B8 */  0xB0, 0xD7, 0xA9, 0xC4, 0x0B, 0xC5, 0x03, 0x05,  // ........
                /* 05C0 */  0xB8, 0x42, 0x1C, 0x28, 0xD0, 0x52, 0x14, 0xFC,  // .B.(.R..
                /* 05C8 */  0xFF, 0x8F, 0xC3, 0x3E, 0x50, 0x60, 0x44, 0x1C,  // ...>P`D.
                /* 05D0 */  0x28, 0x50, 0xF1, 0x49, 0x7C, 0xEC, 0x41, 0x45,  // (P.I|.AE
                /* 05D8 */  0x1E, 0x37, 0x05, 0x31, 0xA0, 0xF3, 0x1C, 0x09,  // .7.1....
                /* 05E0 */  0xD0, 0x8A, 0xAE, 0x73, 0xA8, 0x23, 0x05, 0xC0,  // ...s.#..
                /* 05E8 */  0xD4, 0xFF, 0xFF, 0x91, 0x02, 0x58, 0x78, 0x3C,  // .....Xx<
                /* 05F0 */  0x52, 0x80, 0x2E, 0xCE, 0x3A, 0x75, 0xA4, 0xC0,  // R...:u..
                /* 05F8 */  0x89, 0x02, 0xD2, 0x91, 0xE2, 0xC8, 0x0E, 0xED,  // ........
                /* 0600 */  0x78, 0xD9, 0xAD, 0xD8, 0xFF, 0x09, 0x7A, 0x2E,  // x.....z.
                /* 0608 */  0x23, 0x32, 0x8E, 0x14, 0xA8, 0xE0, 0x60, 0x14,  // #2....`.
                /* 0610 */  0xC4, 0x23, 0x73, 0xA8, 0x23, 0x01, 0x5A, 0xD2,  // .#s.#.Z.
                /* 0618 */  0xA1, 0x8A, 0xDE, 0x08, 0x0C, 0xF2, 0xF0, 0xE7,  // ........
                /* 0620 */  0x19, 0x3D, 0x15, 0xBC, 0x95, 0xF9, 0xF0, 0xEE,  // .=......
                /* 0628 */  0xB1, 0x9E, 0xC8, 0x8B, 0x00, 0x3B, 0x17, 0x80,  // .....;..
                /* 0630 */  0x9B, 0xC0, 0xE7, 0x02, 0x40, 0x94, 0x4C, 0x87,  // ....@.L.
                /* 0638 */  0x12, 0xCF, 0x05, 0x30, 0xFF, 0xFF, 0xE7, 0x02,  // ...0....
                /* 0640 */  0x18, 0xE2, 0x4F, 0x2E, 0x68, 0x09, 0x40, 0x9A,  // ..O.h.@.
                /* 0648 */  0x53, 0x9D, 0x17, 0x5B, 0x61, 0x3F, 0x75, 0x90,  // S..[a?u.
                /* 0650 */  0x73, 0x01, 0x1D, 0x91, 0x63, 0x93, 0xE8, 0x48,  // s...c..H
                /* 0658 */  0xE0, 0x73, 0x01, 0x8F, 0x7A, 0x2E, 0xA0, 0x20,  // .s..z.. 
                /* 0660 */  0x06, 0x74, 0x8E, 0x73, 0x01, 0x5A, 0xC9, 0xC9,  // .t.s.Z..
                /* 0668 */  0x83, 0x0C, 0xF6, 0x48, 0x9F, 0x5A, 0x00, 0xD3,  // ...H.Z..
                /* 0670 */  0xE7, 0x3E, 0xC0, 0xCE, 0xFF, 0xFF, 0x38, 0x01,  // .>....8.
                /* 0678 */  0xCC, 0x0C, 0xEA, 0xD4, 0x6A, 0xF2, 0x38, 0x01,  // ....j.8.
                /* 0680 */  0xAE, 0x3C, 0xC7, 0x09, 0xB4, 0x2A, 0x20, 0x8D,  // .<...* .
                /* 0688 */  0xEC, 0x59, 0xD7, 0x1A, 0xA1, 0x88, 0x9E, 0x73,  // .Y.....s
                /* 0690 */  0x15, 0x4A, 0x09, 0x85, 0xB4, 0x9C, 0x5A, 0x50,  // .J....ZP
                /* 0698 */  0xE9, 0xC7, 0x4D, 0x41, 0x0C, 0xE8, 0x68, 0x27,  // ..MA..h'
                /* 06A0 */  0x61, 0x28, 0x63, 0x78, 0x02, 0xF6, 0x64, 0x1E,  // a(cx..d.
                /* 06A8 */  0x0A, 0x82, 0xBC, 0xB2, 0xF8, 0x06, 0xCC, 0x6F,  // .......o
                /* 06B0 */  0xC1, 0x6C, 0x4A, 0xBE, 0xBB, 0xF8, 0xEA, 0x12,  // .lJ.....
                /* 06B8 */  0xCE, 0x9A, 0xAF, 0x57, 0xE4, 0x8E, 0xF5, 0x86,  // ...W....
                /* 06C0 */  0xE4, 0x7B, 0x05, 0x60, 0xF7, 0xFF, 0x7F, 0xB9,  // .{.`....
                /* 06C8 */  0x02, 0xBC, 0x3B, 0x54, 0x68, 0x52, 0xE3, 0xBD,  // ..;ThR..
                /* 06D0 */  0x02, 0x5C, 0x42, 0x56, 0xA1, 0x7B, 0x05, 0x2E,  // .\BV.{..
                /* 06D8 */  0xCE, 0x5A, 0x34, 0x8B, 0xF3, 0x78, 0xBB, 0x7A,  // .Z4..x.z
                /* 06E0 */  0xAF, 0x60, 0x41, 0xEE, 0x15, 0xA8, 0x08, 0x14,  // .`A.....
                /* 06E8 */  0x0A, 0x71, 0xAF, 0x40, 0xC9, 0xBE, 0xFC, 0x50,  // .q.@...P
                /* 06F0 */  0x10, 0x8F, 0xCB, 0x41, 0x8E, 0x04, 0x68, 0x29,  // ...A..h)
                /* 06F8 */  0x20, 0xBA, 0x00, 0x3C, 0x3B, 0xFB, 0xC6, 0x6F,  //  ..<;..o
                /* 0700 */  0x90, 0x73, 0x7D, 0x09, 0x60, 0xD7, 0x09, 0xE0,  // .s}.`...
                /* 0708 */  0xF8, 0xFF, 0xBF, 0x11, 0xF8, 0x0A, 0x0B, 0xE7,  // ........
                /* 0710 */  0xEE, 0x81, 0x9F, 0xE9, 0x4B, 0x07, 0x9B, 0x15,  // ....K...
                /* 0718 */  0x78, 0x07, 0xEC, 0xBB, 0x11, 0xE0, 0x7B, 0x24,  // x.....{$
                /* 0720 */  0x3E, 0x74, 0x00, 0x7E, 0xFE, 0xFF, 0x87, 0x0E,  // >t.~....
                /* 0728 */  0x6E, 0xD3, 0xAB, 0xC7, 0x43, 0x07, 0xC8, 0x32,  // n...C..2
                /* 0730 */  0xDC, 0x8D, 0xD0, 0x97, 0x22, 0x1F, 0x61, 0x3D,  // ....".a=
                /* 0738 */  0xA6, 0x43, 0x62, 0x1A, 0x0E, 0x1D, 0xA8, 0xF4,  // .Cb.....
                /* 0740 */  0x24, 0x4A, 0x7E, 0x24, 0x40, 0x65, 0x3D, 0x12,  // $J~$@e=.
                /* 0748 */  0x50, 0x10, 0x03, 0xFA, 0xD0, 0x01, 0xF8, 0xB8,  // P.......
                /* 0750 */  0x4E, 0x00, 0x0B, 0x09, 0x17, 0x16, 0x54, 0xE8,  // N.....T.
                /* 0758 */  0xC9, 0x52, 0x10, 0x4F, 0xD6, 0x81, 0x26, 0x8B,  // .R.O..&.
                /* 0760 */  0xBE, 0x40, 0xF8, 0xCC, 0xE7, 0xC9, 0x62, 0x4E,  // .@....bN
                /* 0768 */  0x14, 0x8F, 0x45, 0xB8, 0x5B, 0x11, 0x30, 0xFB,  // ..E.[.0.
                /* 0770 */  0xFF, 0xDF, 0x28, 0x00, 0x1B, 0x3F, 0xD8, 0x52,  // ..(..?.R
                /* 0778 */  0x9D, 0xDE, 0x28, 0xC0, 0x25, 0xE5, 0x56, 0x84,  // ..(.%.V.
                /* 0780 */  0x0E, 0x74, 0xA3, 0x20, 0x43, 0x7A, 0xB6, 0x3C,  // .t. Cz.<
                /* 0788 */  0x24, 0x16, 0xE5, 0x46, 0x81, 0x3A, 0x6F, 0x3B,  // $..F.:o;
                /* 0790 */  0xC6, 0xA9, 0x00, 0x25, 0xFC, 0x56, 0x44, 0x41,  // ...%.VDA
                /* 0798 */  0x7C, 0x2B, 0x02, 0x9C, 0xA4, 0x19, 0x14, 0x5A,  // |+.....Z
                /* 07A0 */  0xCF, 0xAD, 0x08, 0xCA, 0xCD, 0x01, 0x3B, 0x2D,  // ......;-
                /* 07A8 */  0x70, 0xFE, 0xFF, 0xAF, 0x45, 0x00, 0x43, 0x25,  // p...E.C%
                /* 07B0 */  0x5A, 0xD4, 0x7A, 0xEA, 0x00, 0x59, 0x80, 0x6B,  // Z.z..Y.k
                /* 07B8 */  0x11, 0x5A, 0x06, 0x90, 0xEE, 0x67, 0x2F, 0xC8,  // .Z...g/.
                /* 07C0 */  0x1E, 0xDA, 0xF5, 0xF2, 0x53, 0x07, 0x8F, 0x6E,  // ....S..n
                /* 07C8 */  0xE0, 0xFF, 0x7F, 0x24, 0x80, 0x7D, 0x6D, 0x03,  // ...$.}m.
                /* 07D0 */  0xC7, 0xD9, 0xF3, 0xD4, 0x03, 0xBD, 0x78, 0x3C,  // ......x<
                /* 07D8 */  0x22, 0x03, 0xAC, 0xFD, 0xFF, 0x1F, 0x28, 0xC0,  // ".....(.
                /* 07E0 */  0xA0, 0xF1, 0x89, 0x5C, 0xE6, 0x81, 0x02, 0x64,  // ...\...d
                /* 07E8 */  0xAB, 0xA0, 0x67, 0x2D, 0x4B, 0x86, 0x41, 0x49,  // ..g-K.AI
                /* 07F0 */  0x80, 0x90, 0xA4, 0x21, 0xA0, 0x46, 0xE8, 0x39,  // ...!.F.9
                /* 07F8 */  0x37, 0x7F, 0x1A, 0x26, 0xD3, 0xF1, 0x05, 0xC2,  // 7..&....
                /* 0800 */  0x03, 0xB0, 0xB4, 0xB1, 0xA1, 0x4E, 0x44, 0x1E,  // .....ND.
                /* 0808 */  0xE4, 0xAB, 0x84, 0x6F, 0x44, 0xBE, 0x78, 0x19,  // ...oD.x.
                /* 0810 */  0x26, 0x81, 0xC7, 0xC6, 0xD0, 0xF8, 0x89, 0x00,  // &.......
                /* 0818 */  0x06, 0xE0, 0x21, 0xBE, 0xDB, 0x7B, 0x10, 0x9E,  // ..!..{..
                /* 0820 */  0xD9, 0x41, 0x60, 0x0E, 0x1D, 0xBE, 0x9C, 0xB6,  // .A`.....
                /* 0828 */  0x7A, 0x24, 0x40, 0xB8, 0xBF, 0x11, 0xE8, 0xC8,  // z$@.....
                /* 0830 */  0xFC, 0x22, 0xF0, 0x28, 0x6D, 0x10, 0x5B, 0x13,  // .".(m.[.
                /* 0838 */  0x60, 0x6B, 0xF2, 0x02, 0xF2, 0x69, 0x20, 0xCA,  // `k...i .
                /* 0840 */  0x29, 0x05, 0x8A, 0x13, 0x35, 0x4A, 0x73, 0x02,  // )...5Js.
                /* 0848 */  0x8C, 0x41, 0x21, 0x40, 0x62, 0xBD, 0x07, 0xD4,  // .A!@b...
                /* 0850 */  0x06, 0x26, 0xA8, 0x60, 0x61, 0x82, 0x18, 0xAA,  // .&.`a...
                /* 0858 */  0xFD, 0x41, 0x10, 0xF9, 0xCF, 0x00, 0x5D, 0x33,  // .A....]3
                /* 0860 */  0x1C, 0x69, 0x34, 0xA8, 0x83, 0x1A, 0x1F, 0xCD,  // .i4.....
                /* 0868 */  0xA9, 0x3E, 0x1C, 0xB1, 0xBB, 0x87, 0xA7, 0xF8,  // .>......
                /* 0870 */  0x50, 0x72, 0xB8, 0x3E, 0xF0, 0x9B, 0xE0, 0xE1,  // Pr.>....
                /* 0878 */  0xC1, 0x67, 0x08, 0x38, 0xAE, 0x01, 0x35, 0xF1,  // .g.8..5.
                /* 0880 */  0x43, 0x64, 0x9F, 0x14, 0xC3, 0xF1, 0x21, 0xFA,  // Cd....!.
                /* 0888 */  0x50, 0xE1, 0x09, 0xBC, 0x0D, 0x18, 0x90, 0x1D,  // P.......
                /* 0890 */  0x22, 0xE0, 0x8F, 0xC7, 0xD0, 0x4F, 0x11, 0xBE,  // "....O..
                /* 0898 */  0xA1, 0x7A, 0x6C, 0x1A, 0x04, 0xF9, 0xFF, 0x9F,  // .zl.....
                /* 08A0 */  0x34, 0xB0, 0xC3, 0x3C, 0xAD, 0x98, 0x21, 0x9F,  // 4..<..!.
                /* 08A8 */  0x02, 0x0E, 0x8B, 0x89, 0x3D, 0x3B, 0xD0, 0xF1,  // ....=;..
                /* 08B0 */  0x80, 0x5F, 0xF1, 0xD1, 0x40, 0x77, 0x17, 0x63,  // ._..@w.c
                /* 08B8 */  0xFB, 0xCC, 0xE2, 0x08, 0x07, 0x11, 0x28, 0xA0,  // ......(.
                /* 08C0 */  0x67, 0xE3, 0x33, 0x84, 0xEF, 0x05, 0xEC, 0x68,  // g.3....h
                /* 08C8 */  0xC1, 0x45, 0x1D, 0x2D, 0x50, 0x87, 0x06, 0x9F,  // .E.-P...
                /* 08D0 */  0x17, 0x18, 0xE2, 0xE3, 0x96, 0x21, 0x9E, 0x2C,  // .....!.,
                /* 08D8 */  0xD8, 0x21, 0x04, 0x9C, 0x23, 0xF1, 0x21, 0x04,  // .!..#.!.
                /* 08E0 */  0x3E, 0xC8, 0xCB, 0x8A, 0x21, 0x82, 0x04, 0x7F,  // >...!...
                /* 08E8 */  0x26, 0x38, 0x1D, 0x36, 0x34, 0x0C, 0x41, 0x91,  // &8.64.A.
                /* 08F0 */  0x23, 0x40, 0x1D, 0x3B, 0x3C, 0x02, 0x7E, 0x4E,  // #@.;<.~N
                /* 08F8 */  0x78, 0x20, 0x61, 0x23, 0x78, 0x27, 0xF1, 0x24,  // x a#x'.$
                /* 0900 */  0x0E, 0xC8, 0x67, 0x0B, 0x23, 0xC4, 0x2E, 0xF7,  // ..g.#...
                /* 0908 */  0x88, 0x41, 0x6E, 0x3F, 0xC7, 0xF7, 0x0C, 0x83,  // .An?....
                /* 0910 */  0x19, 0x13, 0xEE, 0xC4, 0xE0, 0x21, 0xF0, 0x01,  // .....!..
                /* 0918 */  0x3C, 0x5B, 0x9C, 0x9F, 0x4F, 0x28, 0x67, 0x85,  // <[..O(g.
                /* 0920 */  0x1B, 0x31, 0x9F, 0x12, 0x6E, 0x00, 0x18, 0x85,  // .1..n...
                /* 0928 */  0x36, 0x7D, 0x6A, 0x34, 0x6A, 0xD5, 0xA0, 0x4C,  // 6}j4j..L
                /* 0930 */  0x8D, 0x32, 0x0D, 0x6A, 0xF5, 0xA9, 0xD4, 0x98,  // .2.j....
                /* 0938 */  0x31, 0xA3, 0x50, 0x3A, 0xEE, 0xF9, 0x04, 0x60,  // 1.P:...`
                /* 0940 */  0x11, 0x8F, 0x00, 0x81, 0x58, 0x2C, 0x85, 0x8C,  // ....X,..
                /* 0948 */  0x8C, 0xCA, 0x0E, 0xFE, 0xFF, 0x40, 0x4C, 0xE5,  // .....@L.
                /* 0950 */  0xBB, 0x44, 0x40, 0xD6, 0x0C, 0x22, 0x20, 0xA7,  // .D@.." .
                /* 0958 */  0xB6, 0x00, 0xC4, 0x34, 0xBC, 0x31, 0x04, 0xE4,  // ...4.1..
                /* 0960 */  0x64, 0x1E, 0x80, 0x58, 0x4E, 0x10, 0x01, 0x59,  // d..XN..Y
                /* 0968 */  0xAA, 0x09, 0x20, 0xA6, 0x1B, 0x44, 0x40, 0xD6,  // .. ..D@.
                /* 0970 */  0xAA, 0x62, 0x10, 0x14, 0x44, 0x40, 0xD6, 0xF1,  // .b..D@..
                /* 0978 */  0x72, 0x10, 0x90, 0x55, 0x81, 0x08, 0xC8, 0xF9,  // r..U....
                /* 0980 */  0x6C, 0x00, 0xB1, 0xB0, 0x20, 0x02, 0xB2, 0x48,  // l... ..H
                /* 0988 */  0x1D, 0x40, 0x4C, 0x31, 0x88, 0x80, 0xAC, 0xCD,  // .@L1....
                /* 0990 */  0x07, 0x10, 0x53, 0x0A, 0xA2, 0x01, 0x91, 0x47,  // ..S....G
                /* 0998 */  0x81, 0x80, 0x2C, 0x81, 0x42, 0x40, 0x8E, 0x0B,  // ..,.B@..
                /* 09A0 */  0x22, 0x20, 0x87, 0x07, 0xA2, 0x39, 0xDE, 0x0F,  // " ...9..
                /* 09A8 */  0x02, 0x72, 0x28, 0x10, 0x01, 0x39, 0xC0, 0xB3,  // .r(..9..
                /* 09B0 */  0x41, 0x40, 0x8E, 0x03, 0x22, 0x20, 0x4B, 0xD2,  // A@.." K.
                /* 09B8 */  0x02, 0xC4, 0xF4, 0x81, 0x08, 0xC8, 0x21, 0x81,  // ......!.
                /* 09C0 */  0x68, 0x62, 0x20, 0x9A, 0xD8, 0x0B, 0x10, 0xCB,  // hb .....
                /* 09C8 */  0x0F, 0x22, 0x20, 0x87, 0x30, 0x03, 0xC4, 0x12,  // ." .0...
                /* 09D0 */  0x81, 0x08, 0xC8, 0xEA, 0xBF, 0x56, 0x02, 0x72,  // .....V.r
                /* 09D8 */  0x16, 0x10, 0x0D, 0x9F, 0xBC, 0x0A, 0x04, 0x64,  // .......d
                /* 09E0 */  0x45, 0x20, 0x02, 0x72, 0x7A, 0x20, 0xAA, 0xC5,  // E .rz ..
                /* 09E8 */  0xCE, 0xF9, 0x91, 0xBE, 0x0B, 0x05, 0xE4, 0x54,  // .......T
                /* 09F0 */  0x20, 0x02, 0x72, 0x02, 0x3F, 0x40, 0x2C, 0x0F,  //  .r.?@,.
                /* 09F8 */  0x88, 0x80, 0xAC, 0xC7, 0x10, 0x10, 0x53, 0x07,  // ......S.
                /* 0A00 */  0x22, 0x20, 0x47, 0x52, 0x04, 0xC4, 0xF2, 0x81,  // " GR....
                /* 0A08 */  0x08, 0xC8, 0x59, 0x1C, 0x01, 0xB1, 0x64, 0x20,  // ..Y...d 
                /* 0A10 */  0x02, 0xB2, 0x42, 0x4B, 0x40, 0x4C, 0x2E, 0x88,  // ..BK@L..
                /* 0A18 */  0x80, 0x2C, 0x4D, 0x13, 0x10, 0x13, 0x0A, 0x22,  // .,M...."
                /* 0A20 */  0x20, 0xC7, 0xF3, 0x04, 0xC4, 0xB2, 0x82, 0x08,  //  .......
                /* 0A28 */  0xC8, 0x4A, 0x5F, 0x1E, 0x02, 0xB2, 0x6C, 0x10,  // .J_...l.
                /* 0A30 */  0x01, 0x59, 0xA2, 0x29, 0x20, 0x26, 0x18, 0x44,  // .Y.) &.D
                /* 0A38 */  0x40, 0x8E, 0xA9, 0x0A, 0x88, 0x65, 0x06, 0x11,  // @....e..
                /* 0A40 */  0x90, 0x53, 0xBA, 0x02, 0xA2, 0xAE, 0xFE, 0xFF,  // .S......
                /* 0A48 */  0x03, 0xA0, 0xCF, 0x9C, 0x03, 0x60, 0x20, 0x02,  // .....` .
                /* 0A50 */  0x72, 0x6C, 0x20, 0xAA, 0xE1, 0x59, 0x26, 0x20,  // rl ..Y& 
                /* 0A58 */  0xE7, 0x05, 0x11, 0x90, 0xD3, 0x03, 0x51, 0xD9,  // ......Q.
                /* 0A60 */  0x6F, 0x11, 0x01, 0x39, 0x03, 0x88, 0x80, 0xAC,  // o..9....
                /* 0A68 */  0xF7, 0xC3, 0x13, 0x88, 0xA8, 0x07, 0xD1, 0x40,  // .......@
                /* 0A70 */  0xC8, 0x4B, 0x24, 0x08, 0xD1, 0xF8, 0x46, 0x12,  // .K$...F.
                /* 0A78 */  0x10, 0x01, 0xA1, 0xFF, 0x7F                     // .....
            })
            Method (IANE, 1, Serialized)
            {
                IANQ (Arg0)
                Notify (ATKD, 0xFF) // Hardware-Specific
            }


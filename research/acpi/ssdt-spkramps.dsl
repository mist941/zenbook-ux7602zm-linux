/*
 * Intel ACPI Component Architecture
 * AML/ASL+ Disassembler version 20230628 (64-bit version)
 * Copyright (c) 2000 - 2023 Intel Corporation
 * 
 * Disassembling to symbolic ASL+ operators
 *
 * Disassembly of SSD6_SPKRAMPS_00000002.aml, Sun Oct 25 05:35:20 2026
 *
 * Original Table Header:
 *     Signature        "SSDT"
 *     Length           0x000001A4 (420)
 *     Revision         0x01
 *     Checksum         0xFD
 *     OEM ID           "_ASUS_"
 *     OEM Table ID     "SPKRAMPS"
 *     OEM Revision     0x00000002 (2)
 *     Compiler ID      "INTL"
 *     Compiler Version 0x20200717 (538969879)
 */
DefinitionBlock ("", "SSDT", 1, "_ASUS_", "SPKRAMPS", 0x00000002)
{
    External (_SB_.GPI0, DeviceObj)
    External (_SB_.PC00.SPI1, DeviceObj)

    Scope (\_SB.PC00.SPI1)
    {
        Device (SPK1)
        {
            Name (_HID, "CSC3551")  // _HID: Hardware ID
            Name (_SUB, "10431F62")  // _SUB: Subsystem ID
            Name (_UID, One)  // _UID: Unique ID
            Method (_CRS, 0, NotSerialized)  // _CRS: Current Resource Settings
            {
                Name (SBUF, ResourceTemplate ()
                {
                    SpiSerialBusV2 (0x0000, PolarityLow, FourWireMode, 0x08,
                        ControllerInitiated, 0x003D0900, ClockPolarityLow,
                        ClockPhaseFirst, "\\_SB.PC00.SPI1",
                        0x00, ResourceConsumer, , Exclusive,
                        )
                    SpiSerialBusV2 (0x0001, PolarityLow, FourWireMode, 0x08,
                        ControllerInitiated, 0x003D0900, ClockPolarityLow,
                        ClockPhaseFirst, "\\_SB.PC00.SPI1",
                        0x00, ResourceConsumer, , Exclusive,
                        )
                    GpioIo (Exclusive, PullUp, 0x0000, 0x0000, IoRestrictionOutputOnly,
                        "\\_SB.GPI0", 0x00, ResourceConsumer, ,
                        )
                        {   // Pin list
                            0x0017
                        }
                    GpioIo (Exclusive, PullDown, 0x0000, 0x0000, IoRestrictionOutputOnly,
                        "\\_SB.GPI0", 0x00, ResourceConsumer, ,
                        )
                        {   // Pin list
                            0x0131
                        }
                    GpioIo (Exclusive, PullUp, 0x0000, 0x0000, IoRestrictionInputOnly,
                        "\\_SB.GPI0", 0x00, ResourceConsumer, ,
                        )
                        {   // Pin list
                            0x012E
                        }
                    GpioIo (Shared, PullUp, 0x0064, 0x0000, IoRestrictionInputOnly,
                        "\\_SB.GPI0", 0x00, ResourceConsumer, ,
                        )
                        {   // Pin list
                            0x012F
                        }
                    GpioInt (Edge, ActiveBoth, Shared, PullUp, 0x0064,
                        "\\_SB.GPI0", 0x00, ResourceConsumer, ,
                        )
                        {   // Pin list
                            0x012F
                        }
                })
                Return (SBUF) /* \_SB_.PC00.SPI1.SPK1._CRS.SBUF */
            }

            Method (_STA, 0, NotSerialized)  // _STA: Status
            {
                Return (0x0F)
            }

            Method (_DIS, 0, NotSerialized)  // _DIS: Disable Device
            {
            }
        }
    }
}


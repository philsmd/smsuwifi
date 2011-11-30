/* SMSUWIFI
 * Copyright (C) 2009 by William Greiman
 *  
 * This file is part of the SMSUWIFI project and the Arduino WaveHC Library
 * Arduino's and Wave Shield's pin definitions
 *  
 * This Library is free software: you can redistribute it and/or modify 
 * it under the terms of the GNU General Public License as published by 
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This Library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *  
 * You should have received a copy of the GNU General Public License
 * along with this source files. If not, see
 * <http://www.gnu.org/licenses/>.
 */

/**
 * Pin definitions
 */
#include "ArduinoPins.h"
#ifndef WavePinDefs_h
#define WavePinDefs_h

//SPI pin definitions

/** SPI slave select pin. Warning: SS may be redefined as another pin
 but the hardware SS_PIN must be set to output mode before any calls to
 WaveHC functions. The SS_PIN can then be used as a general output pin */
#define SS   SS_PIN

/** SPI master output, slave input pin. */
#define MOSI MOSI_PIN

/** SPI master input, slave output pin. */
#define MISO MISO_PIN

/** SPI serial clock pin. */
#define SCK  SCK_PIN

//------------------------------------------------------------------------------
// DAC pin definitions

// LDAC may be connected to ground to save a pin
/** Set USE_MCP_DAC_LDAC to 0 if LDAC is grounded. */
#define USE_MCP_DAC_LDAC 1

// use arduino pins 10, 11, 12, 13 for DAC

// pin 10 is DAC chip select

/** Data direction register for DAC chip select. */
#define MCP_DAC_CS_DDR  PIN10_DDRREG
/** Port register for DAC chip select. */
#define MCP_DAC_CS_PORT PIN10_PORTREG
/** Port bit number for DAC chip select. */
#define MCP_DAC_CS_BIT  PIN10_BITNUM

// pin 11 is DAC serial clock
/** Data direction register for DAC clock. */
#define MCP_DAC_SCK_DDR  PIN11_DDRREG
/** Port register for DAC clock. */
#define MCP_DAC_SCK_PORT PIN11_PORTREG
/** Port bit number for DAC clock. */
#define MCP_DAC_SCK_BIT  PIN11_BITNUM

// pin 12 is DAC serial data in

/** Data direction register for DAC serial in. */
#define MCP_DAC_SDI_DDR  PIN12_DDRREG
/** Port register for DAC clock. */
#define MCP_DAC_SDI_PORT PIN12_PORTREG
/** Port bit number for DAC clock. */
#define MCP_DAC_SDI_BIT  PIN12_BITNUM

// pin 13 is LDAC if used
#if USE_MCP_DAC_LDAC
/** Data direction register for Latch DAC Input. */
#define MCP_DAC_LDAC_DDR  PIN13_DDRREG
/** Port register for Latch DAC Input. */
#define MCP_DAC_LDAC_PORT PIN13_PORTREG
/** Port bit number for Latch DAC Input. */
#define MCP_DAC_LDAC_BIT  PIN13_BITNUM
#endif // USE_MCP_DAC_LDAC

#endif // WavePinDefs_h

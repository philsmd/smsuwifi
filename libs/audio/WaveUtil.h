/* SMSUWIFI
 * Copyright (C) 2009 by William Greiman
 *  
 * This file is part of the SMSUWIFI project and the Arduino WaveHC Library
 * Utility functions for the Wave Shield
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

#ifndef WaveUtil_h
#define WaveUtil_h
#include <avr/pgmspace.h>

// ladayada uses this name
#define putstring(x) SerialPrint_P(PSTR(x))

// ladayada uses this name
#define putstring_nl(x) SerialPrintln_P(PSTR(x))

/** Store and print a string in flash memory.*/
#define PgmPrint(x) SerialPrint_P(PSTR(x))

/** Store and print a string in flash memory followed by a CR/LF.*/
#define PgmPrintln(x) SerialPrintln_P(PSTR(x))

int FreeRam(void);
void SerialPrint_P(PGM_P str);
void SerialPrintln_P(PGM_P str);
#endif //WaveUtil_h

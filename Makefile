TARGET       = $(shell ls -1 *.pde|head -1)
ARDUINO_LIBS = LiquidCrystal
include Arduino.mk

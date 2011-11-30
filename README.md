# About

SMSUWIFI (Send SMS Using Wifi) is an Arduino library with example sketch.
It's aim is to make it possible to send SMS w/ an Arduino, a WiFly (or other WIFI,not tested) shields, a DAUL-/QUADBAND SMS module, a LCD Display (optional) and a Wave Shield (optional):

[Screenshot 1] (http://pschmidt.com/image/arduino1.png)  [Screenshot 2] (http://pschmidt.com/image/arduino2.png) [Screenshot 3] (http://pschmidt.com/image/arduino3.png)

# Features  
* SMSUWIFI is able to recive SMS and send a predefined auto-response
* it is possible to send SMS using your browser (and the WIFI module listening on a specific port)
* it allows one to trigger sound notifications that will be send to the Wave Shield
* SMSUWIFI can be configured to s.t. a max. of auto-responses per time interval (e.g. 1 per day) will be sent
* it can display incomming SMS on the LCD display

# Requirements

Software:  
- Arduino open-source environment (http://www.arduino.cc/en/Main/software)  
- LiquidCrystal library (should be pre-installed w/ the environment)  
- AvrDude  
- ard-parse-boards (http://mjo.tc/atelier/2009/02/arduino-cli.html)  

Hardware:  
- Arduino board (tested w/ MEGA 2560 only)  
- DUAL-/QUADBAND SMS MODULE  
- WiFly Wireless Shield for Arduino  

Suggested hardware:  
- LCD (LiquidCrystal display, 16\*2 Characters)  
- Wave Shield for Arduino (w/ SD Card holder)  

# Installation and First Steps
* Copy ard-parse-board to your local bin folder and make it executable (you get the perl script from the link above)  
    cp ard-parse-board /usr/local/bin/  
    sudo chmod +x /usr/local/bin/ard-parse-board 

* Edit the script file s.t. it contains the right reference to your board.txt (should be in your Arduino developer lib directory,e.g. under hardware/arduino/boards.txt)  
    sudo vim /usr/locatl/bin/ard-parse-board (edit OPT variable boards_txt and save)  

* Clone THIS repository:  
    git clone https://github.com/philsmd/smsuwifi.git  

* SET the correct configuration variables for your environment:  
    vim Arduino.mk (especially the ARDUINO_DIR and ARDUINO_PORT variable must be modified to fit to your environment)  
    (Note: you should also check the BOARD_TAG variable)  
     
* Check if it compiles:  
    make  
    
* Connect Arduino to one USB port. When connected and recognized you can upload the sketch to your Arduino:  
    make upload (w/ Arduino connected)  
    (Note: you can compile and upload the sketch also via the Arduino Developer Gui)  

    
* Customize the settings:  
    vim smsWifi.pde (edit the self-explaning configuration variables as you like)  
    make  
    make upload  


* Change Port/Pin settings:  
    vim libs/audio/ArduinoPins.h (for the wave shield and SD Card)  
    vim smsWifi.pde (for the correct Serial settings)  
    make  
    make upload  
  
* After wiring and letting the modules start (test it):  
   -  go to your browser and issue http://[IP]/?tel=[your\_number]&msg=[the\_msg]  
   -  send a SMS to the mobile phone number (connected w/ the SIM in the SMS module)  

# Hacking

* Add more features to this library (e.g. generalize the auto-response settings)
* Make the project more flexible (more hardware-independent)
* Test w/ different Shields etc.
* Report bugs and suggest improvements
* Build a nicer web front-end for sending SMS
* Add full wiring instructions (and schemas)

# Credits and Contributors 
Credits go to all developers of the following libraries:
  
* Arduino Sd2Card Library  
* Arduino WaveHC Library  
* Arduino FAT16 Library  
* Arduino FatReader Library  

Special thank go also to William Greiman (developer of WaveHC).
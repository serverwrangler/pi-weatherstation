# pi-weatherstation
Weather station using RaspberryPI and Argent Data Systems ADS-WS1 weather station sensors to send data to WeatherUnderground/APRS/CWOP/Grafana

## Requirements
### Hardware
 - RaspberryPi 2/3/4/zero
 - ADS-WS1 Weatherstation http://wiki.argentdata.com/index.php?title=ADS-WS1
 - usb-to-serial adapter

### Software
 - Raspian (Latest)
 - Packages:
  -  minicom
  -  wget
  -  apache2
  -  weewx
  -  Weather.sh -> http://server1.nuge.com/~weather/
  -  Cron jobs and scripts -> http://server1.nuge.com/~weather/

### Build
#### Power and data connections to ADS-WS1
You only need 3 wires plus 2 power wires to wire up the controller. In my photo there are wires in the top 5 screw-down terminals, those are for sending TNC/APRS data to a ham radio and are not required for this tutorial.

So, first you need to wire up a serial cable to the weather controller. Connect your cable to your Serial-to-USB adapter. Now cut the remaining end of the serial cable off, be sure to give yourself enough slack to route the cable as needed and to strip the outer sheath over the wires at least 2 inches. The individual wires only need to be stripped 1/4″ or so. You will need to use a multimeter to map out the pins of the cable and find the wires which match up to pins 2, 3, and 5 of the pins inside the DB9 shell. Usually if you look closely the pin numbers are listed next to the pins.

The wire for pin 2 goes to TXD1 on the controller.
The wire for pin 3 goes to RXD1 on the controller.
The wire for pin 5 goes to ground on the controller.

Once that is all wired up you need some power for the controller. A 9V battery will work fine for testing, or a 5V or 12V supply. Wire the positive up to the “DC in” and the ground wire to the lower GND input on the controller.


#!/bin/bash
#
# V1 - includes Wind Chill (only below 46 degF and above 2mph)
#      and Heat Index (only above 80 degF and 40%) <------------ seems to be 10 degF too low  (84 66% gave 80 H.I.)
# V2 - added hourly rain statistics
# V2.1 - added 5 second sleep (hope to prevent crashed due to overruns)
#
#

PORT=/dev/ttyS0

# Set to 1 to show the Serial Data String
# at the bottom of the display, including any bad receives.
COMMTEST=0

# Correction factor for the barometric pressure.  
# Adjust as needed for your own altidude.
# example:  20  -8.6
BAROFIX=20

FIRSTPASS=1

# peak wind speed starting values
MPHPEAK=0
DAILYPEAK=0

# Daily logging
DAILY=0
LOGFILE='weather.log'

# TEMP Min/Max starting values
TEMPHI='0'
TEMPLO='100'

# BARO starting values
BARO00='00.00'
BARO06='00.00'
BARO12='00.00'
BARO18='00.00'

# Preset Hourly Rain to zeros so we don't get math errors
HR1=0;  HR2=0;  HR3=0;  HR4=0;  HR5=0;  HR6=0
HR7=0;  HR8=0;  HR9=0;  HR10=0; HR11=0; HR12=0
HR13=0; HR14=0; HR15=0; HR16=0; HR17=0; HR18=0
HR19=0; HR20=0; HR21=0; HR22=0; HR23=0; HR24=0
#

#Heat Index constants
C1=-42.38
C2=2.049
C3=10.14
C4=-0.2248
C5=-0.006838
C6=-0.05482
C7=0.001228
C8=0.0008528
C9=-0.00000199

SEPARATOR='-----------------------------------------------------------------'

# Set up serial port
/bin/stty -F $PORT 2400 raw cs8 -echo -ignpar -cstopb

# COMMTEST clear screen flag
CT=0

#  +-----------+
#  | Main Loop |
#  +-----------+
while true; do

  if ((CT == 0)); then
    clear
    echo
    echo '   Argent Data Systems - Weather Station Display '
    echo '    By: Jay Nugent - WB8TKL - V1.0 (c) 2012 GPL '
    echo '    Contributions by KR6K     V2.0 (c) 2012 GPL '
    echo
    CT=1 # toggle COMMTEST clear screen flag
  fi

  sleep 5

  read ADSWS1 < $PORT
  ADSWS1="${ADSWS1#!!}" # strip !! chars
  ADSLEN=${#ADSWS1} # get string length

  if ((ADSLEN == 49)); then
  # Continue with the report
  # else is near the bottom of this script

  HOUR=$(date +%k) # no leading zero
  MINUTE=$(date +%M)
  MINUTE=${MINUTE#0} #strip leading zero
  DOY=$(date +%j)
  ((MOD=$HOUR * 60 + $MINUTE))

  echo -en "\033[6;1H" # move cursor to row 6, col 1
  echo '   '$(date)
  echo '   Day of Year: '$DOY'   Minute of Day: '$MOD
  echo $SEPARATOR

  TEMPFLT=$(printf "%.1f" $(echo "$[0x${ADSWS1:8:4}] * 0.1" | bc)) # floating point result
  TEMPDEC=$(printf "%.0f" $(echo "$[0x${ADSWS1:8:4}] * 0.1" | bc)) # integer result
  echo 'Temperature        : '$TEMPFLT'F'

  # Test for Midnight, reset values
  if (($MOD == 0)); then
     TEMPHI=0
     TEMPLO=100
  fi

  # compare current temp to high temp
  if (($TEMPDEC > $TEMPHI)); then
     TEMPHI=$TEMPDEC
  fi

  # compare current temp to low temp
  if (($TEMPDEC < $TEMPLO)); then
     TEMPLO=$TEMPDEC
  fi

  echo '24Hr High/Low      : '$TEMPHI'/'$TEMPLO

  #-------------------------------------------------

  HUMIDITY=$(printf "%.0f" $(echo "$[0x${ADSWS1:24:4}] * 0.1" | bc))
  echo 'Humidity           : '$HUMIDITY'%'

  DEWPOINT=$(printf "%0.f" $(echo "$TEMPDEC - (9 * (100 - $HUMIDITY))/25" | bc))
  echo 'Dew Point          : '$DEWPOINT'F'

  #-------------------------------------------------

  # This formula approximates the Heat Index for temperature => 80F and RH => 40%
  # HI=c1 + c2*T + c3*R + c4*T*R + c5*T^2 + c6*R^2 + c7*T^2R + c8*T*R^2 + c9*T^2*R^2
  T=$TEMPDEC
  R=$HUMIDITY/10

  if (($TEMPDEC > 80)) && (($HUMIDITY > 40)); then
     HI=$(printf "%.0f" $(echo "$C1 + ($C2*$T) + ($C3*$R) + ($C4*$T*$R) + ($C5*($T^2)) + ($C6*($R^2)) + ($C7*($T^2)*$R) + ($C8*$T*($R^2)) + ($C9*($T^2)*($R^2))" | bc))
     echo 'Heat Index         : '$HI'F'
   else
     echo 'Heat Index         : --  '
  fi

  #-------------------------------------------------

  PRESMB=$(printf "%.1f" $(echo "$[0x${ADSWS1:16:4}] * 0.1" | bc)) # pressure in millibars

  # Add a correction factor for your site's altitude
  PRESCOR=$(printf "%.1f" $(echo "$PRESMB+$BAROFIX" | bc)) # corrected pressure (mb)

  # 1 millibar = 0.0295333727 inHg
  INHG=$(printf "%.2f" $(echo "$PRESCOR * 0.0295333727" | bc)) # corrected pres in inches of Hg
  echo 'Pressure           : '$PRESCOR' MilliBars   '$INHG' InHg'

  #-------------------------------------------------

  case $MOD in
       0) BARO00=$INHG;;
     360) BARO06=$INHG;;
     720) BARO12=$INHG;;
    1080) BARO18=$INHG;;
  esac

  echo "Pressure Trend     : Mid=$BARO00  6am=$BARO06  Noon=$BARO12  6pm=$BARO18"

  echo $SEPARATOR

  KPH=$(printf "%.1f" $(echo "$[0x${ADSWS1:0:4}] * 0.1" | bc)) # wind speed in Kilometers/Hr
  MPH=$(printf "%.1f" $(echo "$KPH * 0.621371" | bc)) # floating point result
  echo 'Wind Speed         : '$KPH' KPH  '$MPH' MPH   '
  MPH=$(printf "%.0f" $(echo "$KPH * 0.621371" | bc)) # integer result
  #-------------------------------------------------

  # Wind dir calculated in degrees
  WINDIR=$(printf "%.0f" $(echo "$[0x${ADSWS1:6:2}] * 1.411764" | bc))

  if ((WINDIR < 12)); then DIR='N'
    elif ((WINDIR >  11)) && ((WINDIR <  34)); then DIR='NNE'
    elif ((WINDIR >  33)) && ((WINDIR <  57)); then DIR='NE'
    elif ((WINDIR >  56)) && ((WINDIR <  79)); then DIR='ENE'
    elif ((WINDIR >  78)) && ((WINDIR < 102)); then DIR='E'
    elif ((WINDIR > 101)) && ((WINDIR < 124)); then DIR='ESE'
    elif ((WINDIR > 123)) && ((WINDIR < 147)); then DIR='SE'
    elif ((WINDIR > 146)) && ((WINDIR < 169)); then DIR='SSE'
    elif ((WINDIR > 168)) && ((WINDIR < 192)); then DIR='S'
    elif ((WINDIR > 191)) && ((WINDIR < 214)); then DIR='SSW'
    elif ((WINDIR > 213)) && ((WINDIR < 237)); then DIR='SW'
    elif ((WINDIR > 236)) && ((WINDIR < 259)); then DIR='WSW'
    elif ((WINDIR > 258)) && ((WINDIR < 282)); then DIR='W'
    elif ((WINDIR > 281)) && ((WINDIR < 303)); then DIR='WNW'
    elif ((WINDIR > 303)) && ((WINDIR < 327)); then DIR='NW'
    elif ((WINDIR > 326)) && ((WINDIR < 349)); then DIR='NNW'
    elif ((WINDIR > 348)); then DIR='N'
  fi

  printf "%s %3s %3s\n" 'Wind Direction     : '$DIR' '$WINDIR' Deg'

  #-------------------------------------------------

  AVGMPH=$(printf "%.0f" $(echo "$[0x${ADSWS1:44:4}] * 0.0868809" | bc))
  echo 'Wind Avg/Minute    : '$AVGMPH' MPH   '

  #-------------------------------------------------

  # Perform 10 minute test and reset the MPHPEAK counter.
  # The FIRSTPASS flag is needed to run the following snippett of code 
  # only the *first* time the program is started.  This is because we have
  # no idea what the Minute Of Day (MOD) timer contains at startup.

  if ((FIRSTPASS == 1)); then 
     MODSTORE=$MOD+10
     FIRSTPASS=0
  fi

  if ((MOD == MODSTORE)); then
     # Reset the counter
     MPHPEAK=0
     MODSTORE=$MOD+10
     else
     # Keep collecting the highest peak
     if ((MPH > MPHPEAK)); then
       MPHPEAK=$MPH
     fi
     # Store the highest peak for the Day
     if ((MPH > DAILYPEAK)); then
        DAILYPEAK=$MPH
     fi
  fi 

  # How to deal with midnight and going too far
  if ((MODSTORE > 1439)); then
     MODSTORE=10
  fi
  echo 'Max 10 Min Gust    : '$MPHPEAK' MPH   '
  echo 'Max Daily Gust     : '$DAILYPEAK' MPH   '

  #-------------------------------------------------

  # wind chill formula
  # 35.74 + 0.6215*T - 35.75(V^0.16)) + 0.4275*T(V^0.16)
  # where T = air temp(F) V = wind speed(mph)

  if ((TEMPDEC < 46)) && ((TEMPDEC > -46)) && ((MPH > 2)) && ((MPH < 61)); then
     WINDCHILL=$(awk -v T="$TEMPDEC" -v V="$MPH" 'END { printf "%.0f", 35.74 + (0.6215 * T) - (35.75 * (V^0.16)) + (0.4275 * T * (V^0.16)) }' /dev/null)
     echo 'Wind Chill         : '$WINDCHILL'F'
    else
     echo 'Wind Chill         : --  '
  fi

  echo $SEPARATOR

  #-------------------------------------------------

  DAILYRAIN=$(printf "%.2f" $(echo "$[0x${ADSWS1:40:4}] * 0.01" | bc))
  echo 'Daily Rainfall     : '$DAILYRAIN' inches'

  LONGTERMRAIN=$(printf "%.2f" $(echo "$[0x${ADSWS1:12:4}] * 0.01" | bc))
  echo 'Long Term Rain     : '$LONGTERMRAIN' inches'

#
#----------
echo    "Rain Rate (in/hr)  : "
#
# Get a running total of all previous hours.  Subtract that total from 
# the Daily Rainfall total (RAINDEC) and the difference is the rainfall 
# for the past 60 minutes.

##   echo -n "Daily Rainfall @10': "
##   RAINHEX=`echo $ADSWS1 | cut -b 45-48`
##   RAINDEC=`echo "ibase=16; $RAINHEX" | bc`

# we never set $RAINDEC so the HR1= gets an operand error
# so we added +0 as a temp fix





#
if [ $MOD -eq 60 ];
   then
      let HR1=$RAINDEC+0
      # Add 1000 so we have a few zeros to work with
      let HR1K1=$HR1+1000
fi
#
if [ $MOD -eq 120 ];
   then
      let HR2=$RAINDEC-$HR1
      let HR2K1=$HR2+1000
fi
#
if [ $MOD -eq 180 ];
   then
      let HR3="$RAINDEC-($HR2+$HR1)"
      let HR3K1=$HR3+1000
fi
#
if [ $MOD -eq 240 ];
   then
      let HR4="$RAINDEC-($HR3+$HR2+$HR1)"
      let HR4K1=$HR4+1000
fi
#
if [ $MOD -eq 300 ];
   then
      let HR5="$RAINDEC-($HR4+$HR3+$HR2+$HR1)"
      let HR5K1=$HR5+1000
fi
#
if [ $MOD -eq 360 ];
   then
      let HR6="$RAINDEC-($HR5+$HR4+$HR3+$HR2+$HR1)"
      let HR6K1=$HR6+1000
fi
#
if [ $MOD -eq 420 ];
   then
      let HR7="$RAINDEC-($HR6+$HR5+$HR4+$HR3+$HR2+$HR1)"
      let HR7K1=$HR7+1000
fi
#
if [ $MOD -eq 480 ];
   then
      let HR8="$RAINDEC-($HR7+$HR6+$HR5+$HR4+$HR3+$HR2+$HR1)"
      let HR8K1=$HR8+1000
fi
#
if [ $MOD -eq 540 ];
   then
      let HR9="$RAINDEC-($HR8+$HR7+$HR6+$HR5+$HR4+$HR3+$HR2+$HR1)"
      let HR9K1=$HR9+1000
fi
#
if [ $MOD -eq 600 ];
   then
      let HR10="$RAINDEC-($HR9+$HR8+$HR7+$HR6+$HR5+$HR4+$HR3+$HR2+$HR1)"
      let HR10K1=$HR10+1000
fi
#
if [ $MOD -eq 660 ];
   then
      let HR11="$RAINDEC-($HR10+$HR9+$HR8+$HR7+$HR6+$HR5+$HR4+$HR3+$HR2+$HR1)"
      let HR11K1=$HR11+1000
fi
#
if [ $MOD -eq 720 ];
   then
      let HR12="$RAINDEC-($HR11+$HR10+$HR9+$HR8+$HR7+$HR6+$HR5+$HR4+$HR3+$HR2+$HR1)"
      let HR12K1=$HR12+1000
fi
#
if [ $MOD -eq 780 ];
   then
      let HR13="$RAINDEC-($HR12+$HR11+$HR10+$HR9+$HR8+$HR7+$HR6+$HR5+$HR4+$HR3+$HR2+$HR1)"
      let HR13K1=$HR13+1000
fi
#
if [ $MOD -eq 840 ];
   then
      let HR14="$RAINDEC-($HR13+$HR12+$HR11+$HR10+$HR9+$HR8+$HR7+$HR6+$HR5+$HR4+$HR3+$HR2+$HR1)"
      let HR14K1=$HR14+1000
fi
#
if [ $MOD -eq 900 ];
   then
      let HR15="$RAINDEC-($HR14+$HR13+$HR12+$HR11+$HR10+$HR9+$HR8+$HR7+$HR6+$HR5+$HR4+$HR3+$HR2+$HR1)"
      let HR15K1=$HR15+1000
fi
#
if [ $MOD -eq 960 ];
   then
      let HR16="$RAINDEC-($HR15+$HR14+$HR13+$HR12+$HR11+$HR10+$HR9+$HR8+$HR7+$HR6+$HR5+$HR4+$HR3+$HR2+$HR1)"
      let HR16K1=$HR16+1000
fi
#
if [ $MOD -eq 1020 ];
   then
      let HR17="$RAINDEC-($HR16+$HR15+$HR14+$HR13+$HR12+$HR11+$HR10+$HR9+$HR8+$HR7+$HR6+$HR5+$HR4+$HR3+$HR2+$HR1)"
      let HR17K1=$HR17+1000
fi
#
if [ $MOD -eq 1080 ];
   then
      let HR18="$RAINDEC-($HR17+$HR16+$HR15+$HR14+$HR13+$HR12+$HR11+$HR10+$HR9+$HR8+$HR7+$HR6+$HR5+$HR4+$HR3+$HR2+$HR1)"
      let HR18K1=$HR18+1000
fi
#
if [ $MOD -eq 1140 ];
   then
      let HR19="$RAINDEC-($HR18+$HR17+$HR16+$HR15+$HR14+$HR13+$HR12+$HR11+$HR10+$HR9+$HR8+$HR7+$HR6+$HR5+$HR4+$HR3+$HR2+$HR1)"
      let HR19K1=$HR19+1000
fi
#
if [ $MOD -eq 1200 ];
   then
      let HR20="$RAINDEC-($HR19+$HR18+$HR17+$HR16+$HR15+$HR14+$HR13+$HR12+$HR11+$HR10+$HR9+$HR8+$HR7+$HR6+$HR5+$HR4+$HR3+$HR2+$HR1)"
      let HR20K1=$HR20+1000
fi
#
if [ $MOD -eq 1260 ];
   then
      let HR21="$RAINDEC-($HR20+$HR19+$HR18+$HR17+$HR16+$HR15+$HR14+$HR13+$HR12+$HR11+$HR10+$HR9+$HR8+$HR7+$HR6+$HR5+$HR4+$HR3+$HR2+$HR1)"
      let HR21K1=$HR21+1000
fi
#
if [ $MOD -eq 1320 ];
   then
      let HR22="$RAINDEC-($HR21+$HR20+$HR19+$HR18+$HR17+$HR16+$HR15+$HR14+$HR13+$HR12+$HR11+$HR10+$HR9+$HR8+$HR7+$HR6+$HR5+$HR4+$HR3+$HR2+$HR1)"
      let HR22K1=$HR22+1000
fi
#
if [ $MOD -eq 1380 ];
   then
      let HR23="$RAINDEC-($HR22+$HR21+$HR20+$HR19+$HR18+$HR17+$HR16+$HR15+$HR14+$HR13+$HR12+$HR11+$HR10+$HR9+$HR8+$HR7+$HR6+$HR5+$HR4+$HR3+$HR2+$HR1)"
      let HR23K1=$HR23+1000
fi
#
if [ $MOD -eq 1439 ];
   then
      let HR24="$RAINDEC-($HR23+$HR22+$HR21+$HR20+$HR19+$HR18+$HR17+$HR16+$HR15+$HR14+$HR13+$HR12+$HR11+$HR10+$HR9+$HR8+$HR7+$HR6+$HR5+$HR4+$HR3+$HR2+$HR1)"
      let HR24K1=$HR24+1000
fi
#
#
echo -n "   01="
echo -n "`echo $HR1K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR1K1 | cut -b 3-4`"
echo -n "   02="
echo -n "`echo $HR2K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR2K1 | cut -b 3-4`"
echo -n "   03="
echo -n "`echo $HR3K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR3K1 | cut -b 3-4`"
echo -n "   04="
echo -n "`echo $HR4K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR4K1 | cut -b 3-4`"
echo -n "   05="
echo -n "`echo $HR5K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR5K1 | cut -b 3-4`"
echo -n "   06="
echo -n "`echo $HR6K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR6K1 | cut -b 3-4`"
echo " "
#
echo -n "   07="
echo -n "`echo $HR7K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR7K1 | cut -b 3-4`"
echo -n "   08="
echo -n "`echo $HR8K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR8K1 | cut -b 3-4`"
echo -n "   09="
echo -n "`echo $HR9K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR9K1 | cut -b 3-4`"
echo -n "   10="
echo -n "`echo $HR10K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR10K1 | cut -b 3-4`"
echo -n "   11="
echo -n "`echo $HR11K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR11K1 | cut -b 3-4`"
echo -n "   12="
echo -n "`echo $HR12K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR12K1 | cut -b 3-4`"
echo " "
#
echo -n "   13="
echo -n "`echo $HR13K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR13K1 | cut -b 3-4`"
echo -n "   14="
echo -n "`echo $HR14K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR14K1 | cut -b 3-4`"
echo -n "   15="
echo -n "`echo $HR15K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR15K1 | cut -b 3-4`"
echo -n "   16="
echo -n "`echo $HR16K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR16K1 | cut -b 3-4`"
echo -n "   17="
echo -n "`echo $HR17K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR17K1 | cut -b 3-4`"
echo -n "   18="
echo -n "`echo $HR18K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR18K1 | cut -b 3-4`"
echo " "
#
echo -n "   19="
echo -n "`echo $HR19K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR19K1 | cut -b 3-4`"
echo -n "   20="
echo -n "`echo $HR20K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR20K1 | cut -b 3-4`"
echo -n "   21="
echo -n "`echo $HR21K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR21K1 | cut -b 3-4`"
echo -n "   22="
echo -n "`echo $HR22K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR22K1 | cut -b 3-4`"
echo -n "   23="
echo -n "`echo $HR23K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR23K1 | cut -b 3-4`"
echo -n "   24="
echo -n "`echo $HR24K1 | cut -b 2`"
echo -n "."
echo -n "`echo $HR24K1 | cut -b 3-4`"
echo " "
#
#----------

  #-------------------------------------------------
  # Save daily statistics to a log file
  if ((MOD == 1439)); then

     # Test if we have already logged it today
     if ((DAILY == 0)); then
   
        # Timestamp the entry
        echo "------------------------------" >> $LOGFILE
        echo "$(date)" >> $LOGFILE
      
        # Save Temperate High/Low
        echo "High = $TEMPHI" >> $LOGFILE
        echo "Low  = $TEMPLO"  >> $LOGFILE
      
        # Save Peak Wind Gust 
        echo "Peak Wind = $DAILYPEAK mph" >> $LOGFILE
      
        # Save Daily and Long Term Rain Totals
        echo 'Daily Rainfall = '$DAILYRAIN' inches' >> $LOGFILE
        echo 'Long Term Rain = '$LONGTERMRAIN' inches' >> $LOGFILE

        # Set flag that we have already logged today
        DAILY=1
     fi
  fi

  if ((MOD == 0 )); then 
     # Reset the daily log flag and daily peak wind value
     DAILY=0
     DAILYPEAK=0
  fi

  echo $SEPARATOR

#----------
     else
     # data string length is wrong and COMMTEST is set to 1
     if ((COMMTEST == 1)); then
        echo '    String Length is:  '$ADSLEN
        echo '     String contents:  '$ADSWS1
        sleep 3
        clear
        CT=0 # ensures screen gets cleared, as we send the cursor to row 1
             # column 1 instead of clearing the screen each time we loop through
             # the script.
     fi
  fi
done
exit 0

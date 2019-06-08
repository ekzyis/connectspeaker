#!/bin/bash

: '
This script writes a connect command to bluetoothctl
and then waits until an output line of bluetoothctl
matches our pattern in the while loop at the end.
'

DEVICEMAC="08:EB:ED:04:A1:63"

if [ ! -p /tmp/csIn ]; then
  mkfifo /tmp/csIn
fi
if [ ! -p /tmp/csOut ]; then
  mkfifo /tmp/csOut
fi

trap "rm /tmp/csIn /tmp/csOut" EXIT

bluetoothctl < /tmp/csIn > /tmp/csOut &
: '
A reader of a named pipe receives an EOF if no writers
are left thus we open a writer by attaching file descriptor 3
of the current shell to it.
If we would not do this, bluetoothctl would immediately exit
after the echo command.
'
exec 3> /tmp/csIn

connect() {
  NEXT_REMOVE=0
  NEXT_CONNECT=0
  NEXT_CHECK_DEVICE=0
  NEXT_SCAN=0
  # write connect command to bluetoothctl
  echo "connect $DEVICEMAC" > /tmp/csIn
  while read line;
  do
    echo "$line"
    echo "$line" | grep -q "Connection successful"
    if [ $? -eq 0 ]; then
      exit
    fi
    echo "$line" | grep -q "org.bluez.Error.Failed"
    if [ $? -eq 0 ]; then
      # resolve issue with device by removing it
      NEXT_REMOVE=1
      break;
    fi
    echo "$line" | grep -q "org.bluez.Error.InProgress"
    if [ $? -eq 0 ]; then
      NEXT_CONNECT=1
      break;
    fi
    echo "$line" | grep -q "Device $DEVICEMAC not available"
    if [ $? -eq 0 ]; then
      NEXT_SCAN=1
      #NEXT_CHECK_DEVICE=1
      break;
    fi
  done < /tmp/csOut
  if [ $NEXT_REMOVE -eq 1 ]; then
    removeDevice
  fi
  if [ $NEXT_CONNECT -eq 1 ]; then
    connect
  fi
  if [ $NEXT_SCAN -eq 1 ]; then
    scan
  fi
  if [ $NEXT_CHECK_DEVICE -eq 1 ]; then
    echo "Please make sure the device is turned on!"
    echo "If the device is turned on, please wait a few seconds for bluetoothctl to find the device."
    echo "If the issue is still present, please make sure that the device is not already connected to something."
    echo "If all of this does not help, then guess I am bugged. Fix me!"
    exit 1
  fi
}

scan() {
  echo "scan on" > /tmp/csIn
  while read line;
  do
    echo "$line"
    echo "$line" | grep -q "Device $DEVICEMAC"
    if [ $? -eq 0 ]; then
      break;
    fi
  done < /tmp/csOut
  # FIXME Can't write two times without reading?
  #echo "scan off" > /tmp/csIn

  connect
}

removeDevice() {
  echo "remove $DEVICEMAC" > /tmp/csIn
  while read line;
  do
    echo "$line"
    echo "$line" | grep -q "Device has been removed"
    if [ $? -eq 0 ]; then
      break;
    fi
  done < /tmp/csOut

  connect
}

connect;

// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import gpio
import i2c

import lis3dh as acc_sensor
import hd44780 as display

RSpin := gpio.Pin.out 13
ENpin := gpio.Pin.out 12
D4pin := gpio.Pin.out 18
D5pin := gpio.Pin.out 17
D6pin := gpio.Pin.out 16
D7pin := gpio.Pin.out 15

main:
  display.lcd_init RSpin ENpin D4pin D5pin D6pin D7pin
  acc  := []
  rate := 10

  display.lcd_clear

  bus := i2c.Bus
    --sda=gpio.Pin 21
    --scl=gpio.Pin 22

  accelerometer := bus.device 0x18
  acc_sensor := acc_sensor.lis3dh accelerometer

  acc_sensor.enable --max_g_force = 2 --output_data_rate = rate

  while true:
    acc = acc_sensor.read_acceleration
    print_ "$(%5.2f acc[0]), $(%5.2f acc[1]), $(%5.2f acc[2])"
    display.lcd_write "X:$(%5.2f acc[0])  Y:$(%5.2f acc[1])" 0 0
    display.lcd_write "     Z:$(%5.2f acc[2])    " 1 0
    sleep --ms=200
  
  acc_sensor.disable
  //bus.close
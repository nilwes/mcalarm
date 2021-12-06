// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import gpio
import i2c
import math

import lis3dh as acc_sensor
import hd44780 as display

RSpin := gpio.Pin.out 13
ENpin := gpio.Pin.out 12
D4pin := gpio.Pin.out 18
D5pin := gpio.Pin.out 17
D6pin := gpio.Pin.out 16
D7pin := gpio.Pin.out 15

alpha ::= 0.5

main:
  display.lcd_init RSpin ENpin D4pin D5pin D6pin D7pin
  acc  := [0,0,0]
  filtered_acc := [0,0,0]
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
    // Low-pass filtering of accelerometer data.
    filtered_acc[0] = acc[0] * alpha + (filtered_acc[0] * (1.0 - alpha))
    filtered_acc[1] = acc[1] * alpha + (filtered_acc[1] * (1.0 - alpha))
    filtered_acc[2] = acc[2] * alpha + (filtered_acc[2] * (1.0 - alpha))
    // Calculate roll and pitch angles.
    roll  := (math.atan2 -filtered_acc[0]  filtered_acc[2]) * (180/math.PI)
    pitch := (math.atan2  filtered_acc[1]  (math.sqrt( filtered_acc[0]*filtered_acc[0] + filtered_acc[2]*filtered_acc[2] ))) * (180/math.PI)

    display.lcd_write "Roll: $(%5.2f roll)  " 0 0
    display.lcd_write "Pitch: $(%5.2f pitch)    " 1 0
    sleep --ms=200
  
  acc_sensor.disable
  //bus.close

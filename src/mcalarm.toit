// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import net
import http

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

alpha    ::= 0.75    // LP filter coefficient.
rate     ::= 10      // Sensor measurement rate
max_g    ::= 8       // Sensor range
gravity  ::= 9.80665

max_roll := 0.0

main:
  display := display.hd44780

  display.lcd_init --lcd_type="20x4" RSpin ENpin D4pin D5pin D6pin D7pin --cursor_blink=false --cursor_enabled=false
  acc  := [0,0,0]
  filtered_acc := [0,0,0]

  display.lcd_clear

  bus := i2c.Bus
    --sda=gpio.Pin 21
    --scl=gpio.Pin 22

  accelerometer := bus.device 0x18
  acc_sensor := acc_sensor.lis3dh accelerometer

  acc_sensor.enable --max_g_force = max_g --output_data_rate = rate

  display.lcd_write "Lean angle: " 0 0
  display.lcd_write "Wheelie angle: " 1 0
  display.lcd_write "Acceleration: " 2 0
  display.lcd_write "Max lean: " 3 0

  while true:
    acc = acc_sensor.read_acceleration

    // Low-pass filtering of accelerometer data.
    for ix := 0 ; ix < 3 ; ix += 1:
      filtered_acc[ix] = acc[ix] * alpha + (filtered_acc[ix] * (1.0 - alpha))

    // Calculate roll and pitch angles, and total acceleration (all three vectors).
    tot_acc   := math.sqrt(filtered_acc[0]*filtered_acc[0] + filtered_acc[1]*filtered_acc[1] + filtered_acc[2]*filtered_acc[2])
    tot_acc = (tot_acc-gravity).abs //Normalize to 1g
    pitch := (math.atan2  filtered_acc[1]  (math.sqrt( filtered_acc[0]*filtered_acc[0] + filtered_acc[2]*filtered_acc[2] ))) * (180/math.PI)
    roll  := (math.atan2 -filtered_acc[0]  filtered_acc[2]) * (180/math.PI)
    if roll.abs > max_roll.abs:
      max_roll = roll

    line1 := display.translate_to_rom_a_00 "$(%7d roll.to_int)°"
    line2 := display.translate_to_rom_a_00 "$(%4d pitch.to_int)°"
    line3 := "$(%5.1f tot_acc)g"
    line4 := display.translate_to_rom_a_00 "$(%9d max_roll)°"

    display.lcd_write line1 0 12
    display.lcd_write line2 1 15
    display.lcd_write line3 2 14
    display.lcd_write line4 3 10

    sleep --ms = 100
  
  acc_sensor.disable
  bus.close
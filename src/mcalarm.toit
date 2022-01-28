// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import .bno055
import font show *
// Import the font and size that you need, and give it a name.
import font.x11_100dpi.sans.sans_08 as chars08
import font.x11_100dpi.sans.sans_10 as chars10
import gpio
import serial.protocols.spi as spi
import i2c
import ssd1306
import pixel_display show *
import pixel_display.two_color show *

sans08 ::= Font [chars08.ASCII, chars08.LATIN_1_SUPPLEMENT, chars08.CURRENCY_SYMBOLS]
sans10 ::= Font [chars10.ASCII, chars10.LATIN_1_SUPPLEMENT, chars10.CURRENCY_SYMBOLS]

RSTpin := gpio.Pin 25 --output 

main:

  spi_bus := spi.Bus
    --mosi=gpio.Pin  22   // SDA
    --clock=gpio.Pin 15  // SCL
  oled := spi_bus.device
    --cs=gpio.Pin 4
    --frequency=3_000_000  // Adjust up if it works.
    --dc=gpio.Pin 2

  i2c_bus := i2c.Bus
   --sda=gpio.Pin 12
   --scl=gpio.Pin 13
   --frequency=100000


  i2c_device := i2c_bus.device I2C_ADDRESS
  sensor := bno055 i2c_device

  driver := ssd1306.SpiSSD1306 oled --reset=RSTpin
  display := TwoColorPixelDisplay driver
  display.background = BLACK
  sans_context_08 := display.context --landscape --font=sans08 --color=WHITE
  sans_context_10 := display.context --landscape --font=sans10 --color=WHITE


  euler        := [0.0,0.0,0.0]
  quaternion   := [0.0, 0.0, 0.0, 0.0]
  gyro         := [0.0, 0.0, 0.0]
  calibration  := [0, 0, 0, 0]
  linacc       := [0.0, 0.0, 0.0]
  gravity      := [0.0, 0.0, 0.0]
  magnetometer := [0.0, 0.0, 0.0]
  units        := [0, 0, 0, 0, 0]
  max_pitch    := 0.0
  max_acc      := 0.0
  max_break    := 0.0
  

  while true:
    euler        = sensor.read_euler
    gyro         = sensor.read_gyro
    linacc       = sensor.read_linear_acceleration
    gravity      = sensor.read_gravity
    quaternion   = sensor.read_quaternion
    magnetometer = sensor.read_magnetometer
    calibration  = sensor.read_calibration
    
    //print_ "EV: $(%6.1f euler[0]), $(%6.1f euler[1]), $(%6.1f euler[2]) === Mag: $calibration[0], Acc: $calibration[1], Gyr: $calibration[2], Sys: $calibration[3] "
    //print_ "$(%7f gyro[0]), $(%7f gyro[1]), $(%7f gyro[2])   === Mag: $calibration[0], Acc: $calibration[1], Gyr: $calibration[2], Sys: $calibration[3] "
    //print_ "$(%5.2f quaternion[0]), $(%5.2f quaternion[1]), $(%5.2f quaternion[2]), $(%5.2f quaternion[3])"
    //print_ "LA: $(%6.1f linacc[0]), $(%6.1f linacc[1]), $(%6.1f linacc[2]) === Mag: $calibration[0], Acc: $calibration[1], Gyr: $calibration[2], Sys: $calibration[3] "
    //print_ "$(%5.2f gravity[0]), $(%5.2f gravity[1]), $(%5.2f gravity[2])   === Mag: $calibration[0], Acc: $calibration[1], Gyr: $calibration[2], Sys: $calibration[3] "
    //print_ "$(%5.2f magnetometer[0]), $(%5.2f magnetometer[1]), $(%5.2f magnetometer[2])   === Mag: $calibration[0], Acc: $calibration[1], Gyr: $calibration[2], Sys: $calibration[3] "
    
    print_ "$(%6.1d euler[0]), $(%6.1d euler[1]), $(%6.1d euler[2])" // === Mag: $calibration[0], Acc: $calibration[1], Gyr: $calibration[2], Sys: $calibration[3] "
    roll  := -1 * euler[1].to_int
    pitch := euler[2].to_int
    x_acc := -1 * linacc[1].to_int 
    y_acc := -1 * linacc[0].to_int // -1 <--- Change axis orientation
    
    if pitch >= 0:
      if pitch > max_pitch:
        max_pitch = pitch
    
    if x_acc >= 0:        // Save max acceleration
      if x_acc > max_acc:
        max_acc = x_acc
    else:                 // Save max deceleration
      if x_acc < max_break:
        max_break = x_acc

    display.remove_all
    display.text sans_context_08 1  10 "Wheelie angle:"
    display.text sans_context_08 105 10 "$(%4d pitch)°" 
    display.text sans_context_08 1  22 "Longitudinal acc:"
    display.text sans_context_08 105 22 "$(%5.1f x_acc)"
    display.text sans_context_08 1  34 "Lateral acc:"
    display.text sans_context_08 105 34 "$(%5.1f y_acc)" 
    display.text sans_context_10 20 50 "$(%2d max_pitch)° / $(%3f max_acc) / $(%4f max_break)" 
    display.draw
    sleep --ms=10

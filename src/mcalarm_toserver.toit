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

alpha ::= 0.25 // LP filter coefficient.
alpha_totacc ::= 0.25
rate  ::= 10
max_g ::= 8
secs  ::= 1
gravity  ::= 9.80665

port  ::= 80              //NOTE: Port!
php_script := "sendsms.php"

max_roll := 0.0

main:
  display := display.hd44780

  display.lcd_init --lcd_type="20x4" RSpin ENpin D4pin D5pin D6pin D7pin --cursor_blink=false --cursor_enabled=false
  acc  := [0,0,0]
  filtered_acc := [0,0,0]
  filtered_tot_acc := 0.0
  sms_sent := 0
  convergence_time := 20

  display.lcd_clear
  display.lcd_write "Acceleration: " 0 0

  bus := i2c.Bus
    --sda=gpio.Pin 21
    --scl=gpio.Pin 22

  accelerometer := bus.device 0x18
  acc_sensor := acc_sensor.lis3dh accelerometer

  acc_sensor.enable --max_g_force = max_g --output_data_rate = rate

  while true:
    acc = acc_sensor.read_acceleration

    // Low-pass filtering of accelerometer data.
    for ix := 0 ; ix < 3 ; ix += 1:
      filtered_acc[ix] = acc[ix] * alpha + (filtered_acc[ix] * (1.0 - alpha))

    // Total acceleration (all three vectors).
    tot_acc   := math.sqrt(filtered_acc[0]*filtered_acc[0] + filtered_acc[1]*filtered_acc[1] + filtered_acc[2]*filtered_acc[2])
    tot_acc   = tot_acc - gravity
    filtered_tot_acc = tot_acc * alpha_totacc + (filtered_tot_acc * (1.0 - alpha_totacc))

    if convergence_time > 0: // Allow for acceleration to settle. Otherwise SMS will always be sent initially.
      convergence_time -= 1
    if filtered_tot_acc > 0.5 and sms_sent == 0 and convergence_time == 0:
      send_to_server filtered_tot_acc
      sms_sent = 1

    line1 := "$(%5.1f filtered_tot_acc)g"

    display.lcd_write line1 0 14

    sleep --ms = 100

  
  acc_sensor.disable
  bus.close
  
send_to_server tot_acc/float:
  network_interface := net.open
  host := "ip.address.to.server"
  socket := network_interface.tcp_connect host port
  connection := http.Connection socket host
  parameters := ""  // HTTP parameters.
  request := connection.new_request "GET" "/$php_script"  // Create an HTTP request.
  request.send
// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import cellular
import http
import log
import net
import uart
import sequans_cellular.monarch show Monarch

import .bno055
import font show *
import font.x11_100dpi.sans.sans_08 as chars08
import font.x11_100dpi.sans.sans_10 as chars10
import gpio
import serial.protocols.spi as spi
import i2c
import ssd1306
import pixel_display show *
import pixel_display.two_color show *

import encoding.base64
import math

// Cellular 
APN ::= "iot.1nce.net"
BANDS ::= [ 20, 8 ]
RATS ::= null

TX_PIN_NUM  ::= 5
RX_PIN_NUM  ::= 23
RTS_PIN_NUM ::= 19
CTS_PIN_NUM ::= 18
PWR_ON_NUM  ::= 27

logger ::= log.default

sans08 ::= Font [chars08.ASCII, chars08.LATIN_1_SUPPLEMENT, chars08.CURRENCY_SYMBOLS]
sans10 ::= Font [chars10.ASCII, chars10.LATIN_1_SUPPLEMENT, chars10.CURRENCY_SYMBOLS]

RSTpin := gpio.Pin 25 --output 
ARMpin := gpio.Pin 26 --input
CALIBpin := gpio.Pin 33 --input

main:

  spi_bus := spi.Bus
    --mosi=gpio.Pin  22  // SDA
    --clock=gpio.Pin 15  // SCL
  oled := spi_bus.device
    --cs=gpio.Pin 4
    --frequency=1_000_000
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
  linacc       := [0.0, 0.0, 0.0]

  max_pitch    := 0.0
  max_acc      := 0.0
  max_break    := 0.0

  arm_pin := 0
  calib_pin := 0
  calib_pitch := 0

  display.remove_all
  display.text sans_context_08 1 10 "Connecting to cellular net..."
  display.draw
  cellular_driver := create_driver
  if not connect cellular_driver: return
  network_interface := cellular_driver.network_interface
  display.text sans_context_08 1 23 "Connected!"
  display.draw
  sleep --ms=500

  while true:
    arm_pin = ARMpin.get
    if arm_pin == 1:
      armed_state arm_pin display sans_context_10 sans_context_08 network_interface sensor

    euler        = sensor.read_euler
    linacc       = sensor.read_linear_acceleration
    
    print_ "$(%6.1d euler[0]), $(%6.1d euler[1]), $(%6.1d euler[2])"
    pitch := -1 * euler[1].to_int
    y_acc := -1 * linacc[1].to_int 
    x_acc := -1 * linacc[0].to_int // -1 <--- Change axis orientation
    
    if CALIBpin.get == 1:
      print_ "Calibrating..."
      calib_pitch = pitch
      max_pitch = max_acc = max_break = 0.0


    pitch = pitch - calib_pitch
    
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
    display.text sans_context_10 20 55 "$(%2d max_pitch)° / $(%3f max_acc) / $(%4f max_break)" 
    display.draw
    sleep --ms=10

    driver.close

armed_state arm_pin display sans_context_10 sans_context_08 network_interface sensor:
  sent_alert := 0
  linacc := [0.0, 0.0, 0.0]
  sleep --ms=10
  arm_pin = ARMpin.get
  display.remove_all
  display.text sans_context_10 10 15 "ALARM ARMED!"
  display.draw

  while arm_pin == 1:
    linacc = sensor.read_linear_acceleration
    if (math.sqrt ((linacc[0] * linacc[0] + linacc[1] * linacc[1] + linacc[2] * linacc[2]).abs)) > 5:
      if sent_alert == 0:
        display.text sans_context_08 15 30 "Movement detected"
        display.text sans_context_08 25 45 "Sending alert..."
        display.draw
        //send_alert_rpi network_interface
        send_alert_twilio network_interface
        display.text sans_context_08 35 60 "Alert sent"
        display.draw
        sent_alert = 1
        //start GPS tracking here...
      
    sleep --ms=100
    arm_pin = ARMpin.get
  
  //if switch is reset
  display.remove_all
  display.text sans_context_10 10 14 "Disarming Alarm"
  display.draw
  sleep --ms=2000

create_driver -> Monarch:
  pwr_on := gpio.Pin PWR_ON_NUM
  pwr_on.config --output --open_drain
  pwr_on.set 1
  tx := gpio.Pin TX_PIN_NUM
  rx := gpio.Pin RX_PIN_NUM
  rts := gpio.Pin RTS_PIN_NUM
  cts := gpio.Pin CTS_PIN_NUM

  port := uart.Port --tx=tx --rx=rx --rts=rts --cts=cts --baud_rate=cellular.Cellular.DEFAULT_BAUD_RATE

  return Monarch port --logger=logger

connect driver/cellular.Cellular -> bool:
  logger.info "WAITING FOR MODULE..."
  driver.wait_for_ready
  logger.info "model: $driver.model"
  logger.info "version $driver.version"
  logger.info "iccid: $driver.iccid"
  logger.info "CONFIGURING..."
  driver.configure APN --bands=BANDS --rats=RATS
  logger.info "ENABLING RADIO..."
  driver.enable_radio
  logger.info "CONNECTING..."
  try:
    dur := Duration.of:
      driver.connect
    logger.info "CONNECTED (in $dur)"
  finally: | is_exception exception |
    if is_exception:
      critical_do:
        driver.close
        logger.info "CONNECTION FAILED WITH '$exception'"
        return false
  return true

send_alert_twilio network_interface/net.Interface:
  my_host := "api.twilio.com"
  my_port := 80

  credentials := base64.encode "my:credentials"
  client := http.Client network_interface
  headers := http.Headers
  data:="To=+4612345678&From=+123456789&Body=test".to_byte_array
  headers.set "Authentication" "Basic $credentials"
  client.post
    data
    --host=my_host 
    --port=my_port
    --path="2010-04-01/Accounts/myAccountId/Messages.json"
    --headers=headers 

send_alert_rpi network_interface/net.Interface:
  my_host := "my.server.url"
  my_port := 8008

  client := http.Client network_interface
  headers := http.Headers
  data:="".to_byte_array

  client.post
    data
    --host=my_host 
    --port=my_port
    --path="/send_alert.php"

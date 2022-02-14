// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import cellular
import http
import log
import net
import uart
import sequans_cellular.monarch show Monarch
import certificate_roots

import bno055
import font show *
import font.x11_100dpi.sans.sans_08 as chars08
import font.x11_100dpi.sans.sans_10 as chars10
import gpio
import serial.protocols.spi as spi
import i2c
import ssd1306
import pixel_display show *
import pixel_display.two_color show *
import pixel_display.histogram show *

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

movement_threshold ::= 1

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
  
  oled_scale := 6

  i2c_device := i2c_bus.device I2C_ADDRESS
  sensor := bno055 i2c_device

  driver := ssd1306.SpiSSD1306 oled --reset=RSTpin
  display := TwoColorPixelDisplay driver
  display.background = BLACK
  sans_context_08 := display.context --landscape --font=sans08 --color=WHITE
  sans_context_10 := display.context --landscape --font=sans10 --color=WHITE
  plus_histo  := TwoColorHistogram --x=1 --y=25 --width=128 --height=19 --transform=display.landscape --scale=oled_scale --color=WHITE
  display.add plus_histo
  minus_histo := TwoColorHistogram --x=1 --y=44 --width=128 --height=19 --transform=display.landscape --scale=oled_scale --color=WHITE --reflected
  display.add minus_histo

  euler        := [0.0,0.0,0.0]
  linacc       := [0.0, 0.0, 0.0]

  max_pitch    := 0.0
  max_acc      := 0.0
  max_break    := 0.0

  arm_pin := 0
  calib_pin := 0
  calib_pitch := 0

  network_interface := net.open

  Connect to cellular
  display.remove_all
  display.text sans_context_08 1 10 "Connecting to cellular net..."
  display.draw
  cellular_driver := create_driver
  if not connect cellular_driver: return
  network_interface := cellular_driver.network_interface
  display.text sans_context_08 1 23 "Connected!"
  display.draw
  sleep --ms=500
  display.remove_all
  
  display.text sans_context_08 1  10 "Wheelie angle:"
  display.text sans_context_08 1  22 "Acc/Break:"
  pitch_text := display.text sans_context_08 80 10 "0°"
  x_acc_text := display.text sans_context_08 50 22 "0.0"

  while true:
    arm_pin = ARMpin.get
    sleep --ms=1 //to avoid detecing movement due to toggle switch.
    if arm_pin == 1:
      armed_state arm_pin display sans_context_10 sans_context_08 network_interface sensor
      //Re-initialize display text objects after returning from armed_state.
      display.text sans_context_08 1  10 "Wheelie angle:"
      display.text sans_context_08 1  22 "Acc/Break:"
      pitch_text = display.text sans_context_08 80 10 ""
      x_acc_text = display.text sans_context_08 50 22 ""
      plus_histo  = TwoColorHistogram --x=1 --y=25 --width=128 --height=19 --transform=display.landscape --scale=oled_scale --color=WHITE
      display.add plus_histo
      minus_histo = TwoColorHistogram --x=1 --y=44 --width=128 --height=19 --transform=display.landscape --scale=oled_scale --color=WHITE --reflected
      display.add minus_histo

    euler        = sensor.read_euler
    linacc       = sensor.read_linear_acceleration
    
    //print_ "$(%6.1d euler[0]), $(%6.1d euler[1]), $(%6.1d euler[2])"
    pitch := -1 * euler[1].to_int
    x_acc := -1 * linacc[0] // -1 <--- Change axis orientation.
    
    if CALIBpin.get == 1:
      print_ "Calibrating..."
      calib_pitch = pitch
      max_pitch = max_acc = max_break = 0.0
      sleep --ms=500 //avoid reading button press bounce acceleration.

    pitch = pitch - calib_pitch
    
    if pitch >= 0:
      if pitch > max_pitch:
        max_pitch = pitch
    
    if x_acc >= 0:        // Save max acceleration.
      if x_acc > max_acc:
        max_acc = x_acc
    else:                 // Save max deceleration.
      if x_acc < max_break:
        max_break = x_acc

    pitch_text.text = "$(%4d pitch)° / $(%2d max_pitch)°"
    x_acc_text.text = "$(%5.1f x_acc) / $(%3.1f max_acc) / $(%3.1f max_break)"

    print_ x_acc

    if x_acc < 0.1 and x_acc > -0.1 : x_acc = 0.2
    if x_acc >= 0.0: 
      plus_histo.add x_acc
      minus_histo.add 0       //force scroll of negative histogram.
    else: 
      plus_histo.add 0        //force scroll of positive histogram.
      minus_histo.add -x_acc
    display.draw


armed_state arm_pin display sans_context_10 sans_context_08 network_interface sensor:
  sent_alert := 0
  linacc := [0.0, 0.0, 0.0]
  sleep --ms=10

  display.remove_all
  display.text sans_context_10 10 15 "ALARM ARMED!"
  display.draw

  while arm_pin == 1:
    linacc = sensor.read_linear_acceleration
    tot_acc := math.sqrt ((linacc[0] * linacc[0] + linacc[1] * linacc[1] + linacc[2] * linacc[2]).abs)
    txt := display.text sans_context_08 42 25 "Acc: $(%.1f (tot_acc-0.29).abs)" // -.29 to remove noise
    display.draw
    if (math.sqrt ((linacc[0] * linacc[0] + linacc[1] * linacc[1] + linacc[2] * linacc[2]).abs)) > movement_threshold:
      if sent_alert == 0:
        display.text sans_context_08 15 35 "Movement detected"
        display.text sans_context_08 25 48 "Sending alert..."
        display.draw
        //send_alert_rpi network_interface
        send_alert_twilio network_interface
        display.text sans_context_08 35 60 "Alert sent"
        display.draw
        sent_alert = 1
        //start GPS tracking here...
      
    sleep --ms=250
    display.remove txt
    arm_pin = ARMpin.get

  //if switch is reset
  display.remove_all
  display.text sans_context_10 10 14 "Disarming Alarm"
  display.draw
  sleep --ms=2000
  display.remove_all

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
  my_host ::= "api.twilio.com"
  my_port ::= 443
  credentials := base64.encode "mytwilio:credentials"
  data := "To=+46123456789&From=+1123456789&MessagingServiceSid=MyMessagingServiceSID&Body=Motorcycle movement detected!".to_byte_array

  client := http.Client.tls network_interface
      --root_certificates=[certificate_roots.DIGICERT_GLOBAL_ROOT_CA]
  headers := http.Headers
  headers.set "Authorization" "Basic $credentials"
  headers.set "Content-Type" "application/x-www-form-urlencoded"

  response := client.post
    data
    --host=my_host 
    --port=my_port
    --path="/2010-04-01/Accounts/MyTwilioAccountID/Messages.json"
    --headers=headers

  print_ "HTTP Response code: $response.status_code"

  data2 := #[]
  while chunk := response.body.read: 
    data2 += chunk
  print_ data2.to_string

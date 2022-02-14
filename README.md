# A Toit-powered motorcycle alarm

The idea is to build a motorcycle alarm that tracks movement and sends alerts. While driving, information about wheelie angle and lateral/longitudinal acceleration should be displayed on a 128x64 OLED driven by SSD1309. The sensor used is the versatile BNO055 from Bosch. A toggle switch arms the alarm and if the bike moves while the alarm is armed, a text message is sent.

Future features to be implemented:
- Adding GPS and posting position data to a backend.
- Deep sleep if the alarm is armed. Wake-on-movement.


# Requirements

Toit CLI should be installed on you system. Find instructions here:
https://docs.toit.io/getstarted/installation

Toit open source can be found here:
https://github.com/toitlang/toit

I strongly recommend using Toit's tool Jaguar with live reloading of your code. Save your Toit file and two seconds later your code runs on your ESP32. Find instructions here:
https://github.com/toitlang/jaguar

Three Toit packages are needed to run this are listet below. Install them with the following toit commands:
```
toit pkg install github.com/toitware/toit-ssd1306
toit pkg install github.com/nilwes/bno055
toit pkg install github.com/toitware/toit-pixel-display
toit pkg install github.com/nilwes/bno055
toit pkg install github.com/toitware/cellular
toit pkg install github.com/toitware/sequans-cellular
toit pkg install github.com/toitlang/pkg-http
toit pkg install github.com/toitware/toit-cert-roots
```

# Picture or it didn't happen

https://user-images.githubusercontent.com/58735688/153921074-399c3a40-8d7e-4ecb-b3c3-12848e5c9c9e.mov


# A Toit-powered motorcycle flight tracker

The [LIS3DH accelerometer](https://www.st.com/en/mems-and-sensors/lis3dh.html) is a MEMS accelerometer with nice specs. It can easily be interfaced to an ESP32 using I2C along with the classic [HD44780-powered 16x2 character LCD](https://www.adafruit.com/product/181). The idea is to build a motorcycle flight computer that tracks
- Lean angle, including storage of max lean angle
- Wheelie angle
- Acceleration

In addition, the flight computer should react and send an alert somewhere, if the bike moves when it shouldn't.

Future features to be implemented:
- Alerts if unauthorized movement.
- Posting of data to a backend.

# Steps

## 1. Get the source code

Clone the mcalarm repository into a suitable directory:

``` sh
git clone https://github.com/nilwes/mcalarm
```

You also need the Toit packages for the LIS3DH accelerometer and the LCD. Step into the `mcalarm` folder and install these packages with
```sh
toit pkg install github.com/nilwes/LIS3DH
toit pkg install github.com/nilwes/HD44780
```

## 2. Set up the build environment for Toit

Instructions can be found [here](https://github.com/toitlang/toit/blob/master/README.md)

## 3. Hook up the hardware

You need the following parts:
- ESP32 dev board
- LIS3DH sensor
- 1602 LCD
- 10k potentiometer
 
Here's the Fritzing diagram of the whole hardware setup. Note that the Adafruit LIS3DH breakout board contain circuitry that allows you to hook it up to either 3v3 or 5V.

<img width="1327" alt="Screenshot 2021-12-03 at 15 48 44" src="https://user-images.githubusercontent.com/58735688/144622289-d21bd520-5c67-4298-af13-d95438f04810.png">


## 4. Run the demo

The next step is to build the ESP32 firmware for the `mcalarm.toit`. This is done from the `toit/` directory:

``` sh
make esp32 ESP32_ENTRY=../mcalarm/mcalarm.toit
```

Now it is time for the moment of truth: Flashing the binary to your ESP32!

Notice that the full `python esptool.py ...` command for flashing is shown at the end of the output of the make-command, and typically looks something like this:

``` sh
python /Users/nils/esp-idf/components/esptool_py/esptool/esptool.py --chip esp32 --port /dev/cu.usbserial-14330 --baud 921600 --before default_reset --after hard_reset write_flash -z --flash_mode dio --flash_freq 40m --flash_size detect 0xd000 /Users/nils/toit/toit/build/esp32/ota_data_initial.bin 0x1000 /Users/nils/toit/toit/build/esp32/bootloader/bootloader.bin 0x10000 /Users/nils/toit/toit/build/esp32/toit.bin 0x8000 /Users/nils/toit/toit/build/esp32/partitions.bin
```
However, the `/dev/cu.usbserial-14330` port setting may have to be changed. To figure out which port to use, on macOS do 
```sh
ls -ltr /dev
```
to list the available ports. Look for something like `cu.usbserial-14330` on Mac. If you are running Linux the port is called something like `ttyUSB0`.

It is often useful to see the serial output from the device while it is running and you can use the `toit` command-line interface for that too:

``` sh
toit serial monitor
```
or you can stick to alternatives like `screen` on Linux/MacOS:

``` sh
screen /dev/cu.usbserial-14330 115200
```
where `115200` is your serial baud rate.

## 5. Play!

Edit the `mcalarm/mcalarm.toit` to tweak the code. For example, the rate at which the LIS3DH sensor measures acceleration can be modified:
Valid values for the rate are:
- 1  Hz
- 10 Hz <-- Default value
- 25 Hz
- 50 Hz
- 100 Hz
- 200 Hz
- 400 Hz

Make sure you match the loop rate to this data rate from the sensor. If you for example set the data rate to 1 Hz and read from the sensor at 10 Hz, you will get 10 identical readings every second.

Once you have changed the example, you need to build and run the demo again from step 4. Have fun!

# Picture or it didn't happen

https://user-images.githubusercontent.com/58735688/145566406-a4a29793-a528-4bfa-a552-6c041bcde617.mov



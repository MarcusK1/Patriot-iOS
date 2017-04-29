# Patriot-iOS
Patriot is an open source, Arduino hobby IoT project using 
Particle.io devices, Alexa, and iOS apps.

<img src="https://www.lucidchart.com/publicSegments/view/e3bd6201-11ed-484a-a632-496d1f8f6c8a/image.png" alt="Patriot IoT Diagram" style="width: 640px;"/>

It is intended to help other hobbyists quickly create Internet-of-Things
projects that can be controlled using Voice (Alexa) and iOS devices
without having to recreate new Alexa skills or iOS apps.

This is a work in progress. 
Your Photon based IoT projects can be created using any of the 
standard particle.io development tools (Web IDE,
Particle IDE, or Particle CLI).

The main objective is to allow the creation of networks of IoT
devices that can communicate with each other, and is:
1. Easily extensible: new devices can be added without having to modify existing devices.
2. Super simple to program
3. Reuses existing code, including the Alexa skills, iOS apps, and Photon library code.

Refer to [Alexa Controlled Photon Project without Alexa Coding](https://www.hackster.io/patriot-iot/alexa-controlled-photon-project-without-alexa-coding-f47d84)
on Hackster.io or my blog at lisles.net for more information.

## iOS Apps
This repository contains the iOS control panel app that allows you to interact with Patriot devices using your 4s or newer iPhone. A separate Patriot-iOS6 reposity is used for code supporting older iPhones (3GS and 4)

This app can be used to control devices from your iPhone or iPad.
For example, you can use your old iOS devices as control panels
to turn on and off devices that you implement using Photons.

In addition, I've created a separate iOS app that can run on older
iOS devices. I use this to provide control panels by mounting unused,
older iPhones directly to the wall in various places around my RV.

Currently the apps must be compiled in Xcode with your Particle.io credentials
and downloaded to your iPhone or iPad manually, but I intend to allow the use
of a single, published app using particle.io OAuth in the future.
It remains to be seen whether Apple will allow certifying a hobbyist
app such as this, but I'm going to try.

## Release History
Refer to the (Releases page)[https://github.com/rlisle/Patriot-iOS/releases]
for release history.

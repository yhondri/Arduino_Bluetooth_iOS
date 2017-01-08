#include <CurieBLE.h>
#include <Servo.h>

const int ledPin = 13;
Servo myServo;
BLEPeripheral blePeripheral; // BLE Peripheral Device (the board you're programming)
BLEService servoService("19B10000-E8F2-537E-4F6C-D104768A1214"); 
// BLE LED Switch Characteristic - custom 128-bit UUID, read and writable by central
BLEIntCharacteristic switchCharacteristic("19B10001-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite);

void setup() {
  Serial.begin(9600);

  // set advertised local name and service UUID:
  blePeripheral.setLocalName("Servo");
  blePeripheral.setDeviceName("Servo Connection");
  blePeripheral.setAdvertisedServiceUuid(servoService.uuid());

  // add service and characteristic:
  blePeripheral.addAttribute(servoService);
  blePeripheral.addAttribute(switchCharacteristic);

  // assign event handlers for connected, disconnected to peripheral
  blePeripheral.setEventHandler(BLEConnected, blePeripheralConnectHandler);
  blePeripheral.setEventHandler(BLEDisconnected, blePeripheralDisconnectHandler);

  // assign event handlers for characteristic
  switchCharacteristic.setEventHandler(BLEWritten, switchCharacteristicWritten);
  // set an initial value for the characteristic
  switchCharacteristic.setValue(180);

  // begin advertising BLE service:
  blePeripheral.begin();
  Serial.println(("Bluetooth device active, waiting for connections..."));
  
  myServo.attach(9);
  myServo.write(switchCharacteristic.value());
  
  pinMode(ledPin, OUTPUT);
}

void loop() {
  // poll peripheral
  blePeripheral.poll();
}

void blePeripheralConnectHandler(BLECentral& central) {
      digitalWrite(ledPin, HIGH);
    delay(1000);
          digitalWrite(ledPin, LOW);
  // central connected event handler
  Serial.print("Connected event, central: ");
  Serial.println(central.address());
}

void blePeripheralDisconnectHandler(BLECentral& central) {
  // central disconnected event handler
  Serial.print("Disconnected event, central: ");
  Serial.println(central.address());
}

void switchCharacteristicWritten(BLECentral& central, BLECharacteristic& characteristic) {
  // central wrote new value to characteristic, update LED
  Serial.print("Characteristic event, written: ");

  if (characteristic.value()) {
     myServo.write(switchCharacteristic.value());
    Serial.println("LED on");
    digitalWrite(ledPin, HIGH);
  } else {
    Serial.println("LED off");
    digitalWrite(ledPin, LOW);
  }
}



/*int LED = 13;

void setup() {
  pinMode(LED, OUTPUT);
  digitalWrite(LED, HIGH);
}

void loop() {
  delay(500);
  digitalWrite(LED, LOW);
  delay(500);
  digitalWrite(LED, HIGH);
}
*/


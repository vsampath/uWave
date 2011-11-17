#include <avr/interrupt.h> 
#include <avr/io.h>
#include <stdio.h>
// TimerOne: http://code.google.com/p/arduino-timerone/
#include "TimerOne.h"

#define ONLINE

#ifdef ONLINE
#include <SPI.h>
#include <Ethernet.h>
#endif

// D0, D1 -> Serial RX, TX
// D11, D12, D13 -> Ethernet SPI
// D2, D3, D5, D6 -> CC1, CC2, CC3, CC4 (PCINT2)
// D7, D8 -> CC3, CC4 (PCINT2, PCINT0)
// A5, A4, A3, A2, A1, A0 -> A, B, C, D, F, G segments

#define THRESHOLD 300
#define CLOCK_PERIOD 1500000	// 1.5s
#define START 4 // start at PD2

#define WAITING 0
#define COOKING 1
volatile byte state = WAITING;

volatile byte digits[4];

volatile byte old_time[4];
volatile byte time[4];

//volatile byte pin[] = {4, 8, 0x20, 0x40};  
volatile byte pin = START;
volatile byte index = 0;  // start at CC1 (left-most)

#ifdef ONLINE
#include "web_settings.h"
Client client(server, 3000);
#endif

void setup()
{
	Serial.begin(115200);
	Timer1.initialize(CLOCK_PERIOD);
	Timer1.attachInterrupt(tick);
	PCMSK2 = 0x6C;	// PCI2 enabled for D2, D3, D5, D6 
	PCICR = 4;	// PCI2 enabled

#ifdef ONLINE
 	Ethernet.begin(mac, ip);
	delay(1000);
	/*
	Serial.println("start connecting");
  if (client.connect()) {
		Serial.println("connected");
  } else {
    Serial.println("connection failed");
  }
	*/
#endif
}

void loop()
{
}

void copy_time() {
	old_time[0] = time[0];
	old_time[1] = time[1];
	old_time[2] = time[2];
	old_time[3] = time[3];
}

unsigned int get_time_val(volatile byte * time) {
	return ((time[0] * 10) + time[1])*60 + (time[2] * 10) + time[3];
}

boolean has_decremented() {
	unsigned int time_val = get_time_val(time);
	unsigned int old_time_val = get_time_val(old_time);
	unsigned int diff = old_time_val - time_val;
	return (diff > 0 && diff < 3 * CLOCK_PERIOD / 1000000);
}

void push_time(unsigned int time) {
	Serial.println("pushing time");
#ifdef ONLINE
	if (client.connect()) {
		char get_request[40];
		sprintf(get_request, "GET /arduino/start?time=%d HTTP/1.0", time);
		client.println(get_request);
		client.println();
		client.stop();
		client.flush();
		Serial.println("pushed");
	}
	else {
		Serial.println("could not connect to push time");
	}
	
#endif
}

void push_finish() {
	Serial.println("pushing finish");
#ifdef ONLINE
	if (client.connect()) {
		client.println("GET /arduino/finish HTTP/1.0");
		client.println();
		client.stop();
		client.flush();
		Serial.println("pushed");
	}
	else {
		Serial.println("could not connect to push finish");
	}
#endif
}

void tick() {
	print_time();
	// if there is previous time
	if (!(old_time[0] == 0 && old_time[1] == 0 
				&& old_time[2] == 0 && old_time[3] == 0)) {
		if (has_decremented()) {
			if (state == WAITING) {
				state = COOKING;
				push_time(get_time_val(time));
			}
			else if (state == COOKING) {}
		}
		else { // clock hasn't decremented
			if (state == WAITING) {}
			else if (state == COOKING) {
				state = WAITING;
				push_finish();
			}
		}
	}
	copy_time();
}

void print_digits() {
	Serial.print(digits[0], BIN);
	Serial.print(',');
	Serial.print(digits[1], BIN);
	Serial.print(':');
	Serial.print(digits[2], BIN);
	Serial.print(',');
	Serial.println(digits[3], BIN);
}

void print_time() {
	Serial.print(time[0], DEC);
	Serial.print(time[1], DEC);
	Serial.print(':');
	Serial.print(time[2], DEC);
	Serial.println(time[3], DEC);
}

byte convert(byte digit) {
	switch (digit) {
		case 0:
			return 0;
		case 0x37:
			return 0;
		case 0x10:
			return 1;
		case 0x3B:
			return 2;
		case 0x3A:
			return 3;
		case 0x1C:
			return 4;
		case 0x2E:
			return 5;
		case 0x2F:
			return 6;
		case 0x30:
			return 7;
		case 0x3F:
			return 8;
		case 0x3E:
			return 9;
		default:
			return -1;
	}
}

void handle_digit_change() {
	digits[index] = 0;
	for (int i = 0; i <= 5; i++) {
		digits[index] |= (analogRead(i) > THRESHOLD) << i;
	}
	time[index] = convert(digits[index]);
}

ISR (PCINT2_vect) {
	if (!(PIND & pin)) {
		handle_digit_change();
		index++;
		pin <<= 1;
		if (index == 4) {
			index = 0;
			pin = START;
		}
	}
}

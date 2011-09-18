#include <avr/interrupt.h> 
#include <avr/io.h>

// D0, D1 -> Serial RX, TX
// D11, D12, D13 -> Ethernet SPI
// D2, D3 -> CC1, CC2 (INT0, INT1)
// D7, D8 -> CC3, CC4 (PCINT2, PCINT0)
// A5, A4, A3, A2, A1, A0 -> A, B, C, D, F, G segments

#define THRESHOLD 300
#define START 4 // start at PD2

volatile byte digits[4];
volatile byte pin = START;  
volatile byte index = 0;  // start at CC1 (left-most)

void setup()
{
	Serial.begin(115200);
	PCMSK2 = 0x3C;	// PCI2 enabled for D5-D2
	PCICR = 4;	// PCI2 enabled

	Serial.println("start");
}

void loop()
{
	//if (digits[0] == 0x24) {
		//if (digits[1] == 0x73) {
		//	Serial.println("got it");
		//	while(1);
		//}
	//}
        print_digits();
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

//byte check_segment(byte pin) {
//        while (!(ADCSRA & _BV(ADIF)));
//        Serial.print("i'm here");
//        int a = ADCL;
//        ADCSRA |= _BV(ADIF);
//        return a > THRESHOLD;
//}

void handle_digit_change() {
        digits[index] = 0;
        for (int i = 0; i <= 5; i++) {
          digits[index] |= (analogRead(i) > THRESHOLD) << i;
        }
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

SerialWatcher
=============

A still very basic tool for watching multiple serial ports at once.

The reason for this is when you have a duplex UART between two MCUs and 
you want to spy on the traffic between.  

I use this typically by plugging two FTDI cables into my computer, and
running SerialWatcher on both.  Then just connecting ground and RX from the
FTDIs to the two lines on the circuit board.


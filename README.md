# VLSI-PS2-Keyboard-controller
Simple PS/2 keyboard controller designed for Cyclone 3 FPGA device with done verification according to UVM standard.

This project has been made within the course "Computer Systems for VLSI".
Controller captures two lowest bytes of data received from keyboard via PS/2 protocol. Verification runs 10.000 iterations with pseudo-random bits generated for keyboard clock and keyboard data (input ports for controller).

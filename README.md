# 🔌 UART_FPGA

An FPGA-based UART implementation with separate TX/RX modules, a configurable baud rate generator, runtime status flags, and LED indicators for instant visual debugging. Designed for learning, integration, and reliable serial communication between your FPGA and a PC.

---

## 📂 Repository structure

```
├── uart_project/                       # Gowin project folder
├── sim/                                # Simulation folder
├── UART Implementation.pdf             # UART theory & implementation notes
├── Tang_Nano_20K_3921_Schematics.pdf   # FPGA Schematics
└── README.md                           # This file 
```

---

## 🧠 How it works – high level

1. **TX path** – Start bit → data bits → stop bit  
2. **RX path** – Start-bit detection, mid-bit sampling, error flagging  

---

## 🚀 Quick start

### 1️⃣ Prerequisites
- Gowin EDA IDE & Gowin Programmer  
- Sipeed Tang Nano 20K FPGA board with USB-C cable  
- Serial terminal on PC (e.g. TeraTerm)

### 2️⃣ Build & program
1. Open `uart_project/gowin/*.gprj` in Gowin IDE  
2. Verify `constraints.cst` matches your board’s pinout  
3. Set top module to `uart_top`  
4. Synthesize, place & route, generate bitstream  
5. Program the board via USB-C

### 3️⃣ Connect & test
- Connect the board via USB-C — the onboard USB-UART bridge exposes a serial port  
- Open the serial port in your PC terminal at the configured baud rate (8-N-1)  

### 4️⃣ Loopback demo
- With TX and RX connected internally (or looped externally), type in the terminal — characters should echo back  
- **TX LED** blinks on transmit, **RX LED** blinks on receive  
- Change baud intentionally to trigger framing errors — **ERR LED** should light up

---

## 💡 LED Indicators

- **TX LED** – pulses on each transmitted byte  
- **RX LED** – pulses on each received byte  
- **ERR LED** – lights on framing, clears on next valid frame or reset

---

## 🧪 Simulation (Modelsim) + Real-Life Tests

<img width="500" height="500" alt="image" src="https://github.com/user-attachments/assets/fc2f2705-e055-4de1-b6f7-f2008206f44a" />

<img width="500" height="500" alt="image" src="https://github.com/user-attachments/assets/5760efc9-bf29-4a8c-b876-df0fd5804910" />


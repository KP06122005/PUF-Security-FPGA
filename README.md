# Ring Oscillator PUF for Hardware Security

**RTL Design and Simulation using Verilog and AMD/Xilinx Vivado**

## Overview

This project focuses on the design and simulation of a Ring Oscillator Physically Unclonable Function (RO PUF), a hardware security primitive that exploits physical variations in electronic circuits to generate device-dependent responses.

Ring oscillators produce oscillating signals whose frequencies can differ due to variations in circuit characteristics. By comparing the frequencies of selected oscillators, an RO PUF can generate digital responses that may be used for hardware identification and authentication.

## Objectives

- Design an RO PUF architecture using RTL.
- Understand the operating principle of ring oscillators and frequency comparison.
- Implement response-generation logic.
- Verify the designed architecture through simulation in Vivado.
- Examine the generated signals and evaluate the observed functional behavior.

## Working Principle

The RO PUF architecture is based on the following process:

1. **Ring Oscillator Generation:** Ring oscillators produce periodic signals through feedback paths.
2. **Oscillator Selection:** A pair of oscillators is selected for comparison.
3. **Frequency Comparison:** The selected oscillators are compared to determine their relative frequencies.
4. **Response Generation:** The comparison result is converted into a digital response bit.
5. **PUF Response Evaluation:** The response behavior can be studied for potential hardware identification and authentication applications.

*The exact implementation depends on the oscillator architecture, comparison circuit and response-generation logic used in this project.*

## Design Methodology

The project follows an RTL-based design and verification workflow:

- Develop the RO PUF modules using Verilog/SystemVerilog.
- Integrate the oscillator, selection and comparison logic as required by the architecture.
- Create a testbench to exercise the design.
- Simulate the RTL using AMD/Xilinx Vivado.
- Inspect relevant waveforms and response signals.
- Document simulation observations and available implementation results.

## Tools and Technologies

- **HDL:** Verilog / SystemVerilog
- **Design and Simulation:** AMD/Xilinx Vivado
- **Domain:** VLSI Design, Digital Hardware Security and PUF Architectures


## Simulation and Verification

RTL simulation is used to inspect the implemented design's functional behavior and response-generation logic.

Simulation screenshots and relevant observations can be added to the `simulation/` directory.

> RTL simulation demonstrates modeled functional behavior. It does not, by itself, establish physical oscillator operation, PUF uniqueness, response reliability or resistance to attacks.

## Applications

RO PUFs can support research into:

- Hardware device identification.
- Device authentication.
- Hardware-rooted security.
- PUF-based key-generation architectures.

These are potential applications of the technology and are not claims that every application has been implemented in this project.

## Future Scope

- Evaluate the effects of implementation constraints on oscillator behavior.
- Investigate response repeatability and reliability.
- Analyze uniqueness using suitable measurements across multiple devices or instances.
- Explore FPGA implementation and hardware resource utilization.
- Study the suitability of the architecture for hardware authentication.

## Conclusion

This project explores the RTL design and simulation of an RO PUF for hardware security. It provides a foundation for understanding oscillator-based PUF architectures, digital response generation and the verification challenges involved in hardware security primitives.

## Author

**Electronics and Communication Engineering**

Areas of Interest: Digital VLSI Design, RTL Design, FPGA Prototyping and Hardware Security.

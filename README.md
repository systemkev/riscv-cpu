# RISC-V 32-bit Processor & SoC

This is a fully pipelined 32-bit RISC-V processor (RV32I) and System-on-Chip (SoC) written from scratch in SystemVerilog. 

The goal of this project was to go a bit beyond a basic 5-stage pipeline and build something that functions more like a standalone microcontroller. It features a custom memory subsystem, an L1 data cache, hardware branch prediction, and a UART-based bootloader for dynamic programming over serial.

## Architecture Overview

At its core, this is a standard 5-stage RISC-V pipeline (Fetch, Decode, Execute, Memory, Writeback) implementing the base RV32I integer instruction set. 

*   **Pipelining & Hazards:** Fully bypassed. A dedicated hazard unit handles data forwarding (Writeback to Execute, Memory to Execute) and manages pipeline stalls for load-use dependencies or cache misses. 
*   **Memory Subsystem:** Memory-mapped I/O (MMIO) architecture with Instruction and Data memories backed by synchronous Block RAMs. 
*   **Cache:** A direct-mapped L1 Data Cache sits between the pipeline and the main data RAM to help hide memory latency.
*   **MMIO & Peripherals:** A hardware UART acts as both the standard I/O interface and the programming interface, mapped to `0x8000_0000`.

## Design Highlights

Here is a breakdown of a few specific architectural choices made to improve performance, debuggability, and code structure.

### 1. UART "Over-the-Air" Program Loader
To avoid having to recompile the FPGA bitstream or rely on JTAG just to update the instruction memory, the SoC includes a custom hardware packet parser and serializer (`uart_program_loader.sv`, `uart_packet_parser.sv`). It intercepts serial data looking for a specific sync byte (`0xA5`), allowing you to dynamically halt the CPU, write directly into instruction memory, and resume execution. It also uses a hardware CRC8 engine to validate packets on the fly to prevent flashing corrupted instructions.

### 2. Write-Back L1 Data Cache
The memory subsystem uses a direct-mapped Write-Back cache (`l1_dcache.sv`) with dirty bits and a dedicated write-back state machine. It handles 64 lines of 4 words each. This setup reduces write traffic to main memory and helps keep the CPU from stalling on consecutive stores.

### 3. Dynamic Branch Prediction
To help reduce pipeline flushes on loops and branches, the Fetch and Execute stages use a dynamic branch predictor (`branch_predictor.sv`). It pairs a 64-entry Branch Target Buffer (BTB) with a standard 2-bit saturating counter (Branch History Table) to track taken/not-taken states. PC redirection is calculated combinationally in the execute stage to resolve mispredicts as early as possible.

### 4. Synthesis-Aware Coding
The codebase is written with physical FPGA synthesis and timing closure in mind. Critical control signals (like stall and flush nets) use pragmas like `(* max_fanout = 32 *)`, and memory components are explicitly hinted with `(* ram_style = "distributed" *)` or `(* ram_style = "block" *)` to help the synthesis tool manage routing congestion.

### 5. Type-Safe SystemVerilog Enums
To keep the decode and execute logic clean, the project relies on a centralized package (`common_pkg.sv`) with typed enumerations for ALU operations (`ARITH_ADD`, `SHIFT_L_LOGIC`), branch types, and memory access sizes. This helps avoid passing around raw binary magic numbers for pipeline control flow.

## Project Structure

*   **`riscv_core.sv`**: The top-level wrapper for the 5-stage CPU pipeline.
*   **`riscv_soc.sv`**: The true top-level module. Wires up the CPU core, memory decoding, L1 cache, UART peripherals, and the program loader.
*   **Pipeline Stages**: `fetch.sv`, `decoder.sv`, `execute.sv`, `memory.sv`, `writeback.sv`.
*   **Core Logic**: `alu.sv`, `reg_file.sv`, `hazard_unit.sv`, `branch_predictor.sv`.
*   **Memory & SoC**: `l1_dcache.sv`, `data_memory.sv`, `instruction_memory.sv`, `dmem_addr_decoder.sv`.
*   **UART & IO**: `uart_tx/rx.sv`, `uart_mmio.sv`, and the packet parser/loader stack.

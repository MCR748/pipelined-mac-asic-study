#include <stdlib.h>
#include <iostream>
#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vmac_top.h"

#define MAX_SIM_TIME 300
#define PIPELINE_LATENCY 3

vluint64_t sim_time = 0;

int main(int argc, char** argv, char** env) {
    Vmac_top *dut = new Vmac_top;

    Verilated::traceEverOn(true);
    VerilatedVcdC *m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    // ---------------- Expected model ----------------
    vluint64_t exp_data_q[PIPELINE_LATENCY] = {0};
    bool       exp_valid_q[PIPELINE_LATENCY] = {0};

    // ---------------- Initial conditions ----------------
    dut->clk = 0;
    dut->rst = 1;
    dut->input_a = 0;
    dut->input_b = 0;
    dut->input_valid = 0;

    while (sim_time < MAX_SIM_TIME) {

        // ---------------- Clock toggle ----------------
        dut->clk ^= 1;

        // ---------------- Rising edge behavior ----------------
        if (dut->clk) {

            int cycle = sim_time / 2;

            // -------- Reset logic (matches SV TB) --------
            dut->rst = (cycle < 4);

            // -------- Stimulus schedule --------
            dut->input_valid = 0;

            if (cycle == 5) {
                dut->input_a = 0x01;
                dut->input_b = 0x02;
                dut->input_valid = 1;
            }
            else if (cycle == 7) {
                dut->input_a = 0x03;
                dut->input_b = 0x04;
                dut->input_valid = 1;
            }
            else if (cycle == 8) {
                dut->input_a = 0x05;
                dut->input_b = 0x06;
                dut->input_valid = 1;
            }
            else if (cycle == 11) {
                dut->input_a = 0x07;
                dut->input_b = 0x08;
                dut->input_valid = 1;
            }

            // -------- Expected pipeline model --------
            if (dut->rst) {
                for (int i = 0; i < PIPELINE_LATENCY; i++) {
                    exp_data_q[i]  = 0;
                    exp_valid_q[i] = 0;
                }
            } else {
                // shift
                for (int i = PIPELINE_LATENCY - 1; i > 0; i--) {
                    exp_data_q[i]  = exp_data_q[i - 1];
                    exp_valid_q[i] = exp_valid_q[i - 1];
                }

                // stage 0
                exp_data_q[0] =
                  (((vluint64_t)dut->input_a << 16) | (vluint64_t)dut->input_b) << 16;
                exp_valid_q[0] = dut->input_valid;
            }
        }

        // ---------------- Evaluate ----------------
        dut->eval();

        // ---------------- Checking (after eval, rising edge only) ----------------
        if (dut->clk && !dut->rst) {

            if (dut->output_valid != exp_valid_q[PIPELINE_LATENCY - 1]) {
                std::cerr << "VALID mismatch at cycle "
                          << (sim_time / 2)
                          << " exp=" << exp_valid_q[PIPELINE_LATENCY - 1]
                          << " got=" << dut->output_valid
                          << std::endl;
                exit(1);
            }

            if (dut->output_valid) {
                if (dut->output_val != exp_data_q[PIPELINE_LATENCY - 1]) {
                    std::cerr << "DATA mismatch at cycle "
                              << (sim_time / 2)
                              << " exp=0x" << std::hex << exp_data_q[PIPELINE_LATENCY - 1]
                              << " got=0x" << dut->output_val
                              << std::dec << std::endl;
                    exit(1);
                }
            }
        }

        m_trace->dump(sim_time);
        sim_time++;
    }

    std::cout << "STAGE 0 TB PASSED" << std::endl;

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}

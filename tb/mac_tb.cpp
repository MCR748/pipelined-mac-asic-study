#include <stdlib.h>
#include <iostream>
#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vmac_top.h"

#define MAX_SIM_TIME 300
#define PIPELINE_LATENCY 8

vluint64_t sim_time = 0;

int16_t a = 0;
int16_t b = 0;
int32_t product = 0;
int64_t shifted = 0;

bool test_failed = false;

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
    dut->i_clk = 0;
    dut->i_rst = 1;
    dut->i_a = 0;
    dut->i_b = 0;
    dut->i_valid = 0;

    while (sim_time < MAX_SIM_TIME) {

        // ---------------- Clock toggle ----------------
        dut->i_clk ^= 1;

        // ---------------- Rising edge behavior ----------------
        if (dut->i_clk) {

            int cycle = sim_time / 2;

            // -------- Reset logic (matches SV TB) --------
            dut->i_rst = (cycle < 4);

            // -------- Stimulus schedule --------
            dut->i_valid = 0;

            if (cycle == 5) {
                dut->i_a = 0x01;
                dut->i_b = 0x02;
                dut->i_valid = 1;
            }
            else if (cycle == 7) {
                dut->i_a = 0x03;
                dut->i_b = 0x04;
                dut->i_valid = 1;
            }
            else if (cycle == 8) {
                dut->i_a = 0x05;
                dut->i_b = 0x06;
                dut->i_valid = 1;
            }
            else if (cycle == 11) {
                dut->i_a = 0x07;
                dut->i_b = 0x08;
                dut->i_valid = 1;
            }

            // -------- Expected pipeline model --------
            if (dut->i_rst) {
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
                a = (int16_t)dut->i_a;
                b = (int16_t)dut->i_b;
                product = (int32_t)a * (int32_t)b;
                shifted = ((int64_t)product) << 16;

                exp_data_q[0]  = (int64_t)shifted;
                exp_valid_q[0] = dut->i_valid;

            }
        }

        // ---------------- Evaluate ----------------
        dut->eval();

        // ---------------- Checking (after eval, rising edge only) ----------------
        if (dut->i_clk && !dut->i_rst) {

            if (dut->o_valid != exp_valid_q[PIPELINE_LATENCY - 1]) {
                std::cerr << "VALID mismatch at cycle "
                          << (sim_time / 2)
                          << " exp=" << exp_valid_q[PIPELINE_LATENCY - 1]
                          << " got=" << dut->o_valid
                          << std::endl;
                test_failed = true;
                break;

            }

            if (dut->o_valid) {
                if (dut->o_val != exp_data_q[PIPELINE_LATENCY - 1]) {
                    std::cerr << "DATA mismatch at cycle "
                              << (sim_time / 2)
                              << " exp=0x" << std::hex << exp_data_q[PIPELINE_LATENCY - 1]
                              << " got=0x" << dut->o_val
                              << std::dec << std::endl;
                    test_failed = true;
                    break;
                }
            }
        }

        m_trace->dump(sim_time);
        sim_time++;
    }

    // Dump a few extra cycles if failed (post-mortem visibility)
    if (test_failed) {
        for (int i = 0; i < 10; i++) {
            dut->eval();
            m_trace->dump(sim_time++);
        }
    }

    m_trace->close();
    delete dut;

    if (test_failed) {
        std::cerr << "TEST FAILED — waveform preserved" << std::endl;
        return EXIT_FAILURE;
    } else {
        std::cout << "STAGE 0 TB PASSED" << std::endl;
        return EXIT_SUCCESS;
    }
}

#include <stdlib.h>
#include <iostream>
#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vmac_top.h"

#define MAX_SIM_TIME 300
#define PIPELINE_LATENCY 12

struct test_vec {int cycle; uint16_t a;  uint16_t b;};

static const test_vec tests[] = {
    {  5,     0,      0      },
    {  6,     1,      1      },
    {  7,     2,      3      },
    {  9,     255,    4      },
    { 10,   1024,    8      },
    { 12,  32767,    1      },
    { 14,  65535,    1      },   // max unsigned
    { 16,  0x5555, 0x3333   },
};

static const int NUM_TESTS = sizeof(tests) / sizeof(tests[0]);
int current_test = -1;

static const uint64_t OUT_MASK = ((1ULL << 40) - 1);

vluint64_t sim_time = 0;

uint16_t a = 0;
uint16_t b = 0;
uint64_t shifted = 0;
uint64_t product64 = 0;

bool test_failed = false;

int main(int argc, char** argv, char** env) {
    Vmac_top *dut = new Vmac_top;

    Verilated::traceEverOn(true);
    VerilatedVcdC *m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    // ---------------- Expected model ----------------
    vluint64_t exp_data_q[PIPELINE_LATENCY];
    bool       exp_valid_q[PIPELINE_LATENCY];
    int exp_test_q[PIPELINE_LATENCY];


    // ---------------- Initial conditions ----------------
    dut->i_clk = 0;
    dut->i_rst = 1;
    dut->i_a = 0;
    dut->i_b = 0;
    dut->i_valid = 0;

    for (int i = 0; i < PIPELINE_LATENCY; i++) {
        exp_test_q[i]  = -1;
        exp_data_q[i]  = 0;
        exp_valid_q[i] = 0;
    }

    while (sim_time < MAX_SIM_TIME) {

        // ---------------- Clock toggle ----------------
        dut->i_clk ^= 1;

        // ---------------- Rising edge behavior ----------------
        if (dut->i_clk) {

            int cycle = sim_time / 2;
        
            // -------- Reset logic (matches SV TB) --------
            dut->i_rst = (cycle < 4);
        
            dut->i_valid = 0;
            current_test = -1;
                
            for (int t = 0; t < NUM_TESTS; t++) {
                if (cycle == tests[t].cycle) {
                    dut->i_a = tests[t].a;
                    dut->i_b = tests[t].b;
                    dut->i_valid = 1;
                    current_test = t;   // <-- capture test index
                    break;
                }
            }

            // -------- Expected pipeline model --------
            if (dut->i_rst) {
                for (int i = 0; i < PIPELINE_LATENCY; i++) {
                    exp_data_q[i]  = 0;
                    exp_valid_q[i] = 0;
                    exp_test_q[i] = -1;
                }
            } else {
                // shift
                for (int i = PIPELINE_LATENCY - 1; i > 0; i--) {
                    exp_data_q[i]  = exp_data_q[i - 1];
                    exp_valid_q[i] = exp_valid_q[i - 1];
                    exp_test_q[i]  = exp_test_q[i - 1];
                }

                // stage 0
                a = (uint16_t)dut->i_a;
                b = (uint16_t)dut->i_b;
                product64 = (uint64_t)a * (uint64_t)b;
                shifted   = product64 << 8;
                shifted &= ((1ULL << 40) - 1);


                exp_data_q[0] = shifted;
                exp_valid_q[0] = dut->i_valid;
                exp_test_q[0]  = current_test;

            }
        }

        // ---------------- Evaluate ----------------
        dut->eval();

        // ---------------- Checking (after eval, rising edge only) ----------------
        if (dut->i_clk && !dut->i_rst) {

            if (dut->o_valid != exp_valid_q[PIPELINE_LATENCY - 1]) {
                std::cerr << "VALID mismatch at cycle "
                          << (sim_time / 2)
                          << " test=" << exp_test_q[PIPELINE_LATENCY - 1]
                          << " exp=" << exp_valid_q[PIPELINE_LATENCY - 1]
                          << " got=" << dut->o_valid
                          << " (a=" << a << ", b=" << b << ")"
                          << std::endl;
                test_failed = true;
                break;

            }

            uint64_t exp40 = ((uint64_t)exp_data_q[PIPELINE_LATENCY - 1]) & OUT_MASK;
            uint64_t got40 = ((uint64_t)dut->o_val) & OUT_MASK;

            if (got40 != exp40) {
                std::cerr << "DATA mismatch at cycle "
                    << (sim_time / 2)
                    << " test=" << exp_test_q[PIPELINE_LATENCY - 1]
                    << " exp=0x" << std::hex << exp40
                    << " got=0x" << got40
                    << std::dec
                    << " (a=" << tests[exp_test_q[PIPELINE_LATENCY - 1]].a
                    << ", b=" << tests[exp_test_q[PIPELINE_LATENCY - 1]].b
                    << ")"
                    << "RAW exp_data_q = 0x" << std::hex << exp_data_q[PIPELINE_LATENCY - 1]
                    << " masked exp40 = 0x" << exp40
                    << " got40 = 0x" << got40
                    << std::dec << std::endl;
                test_failed = true;
                break;
            }
        }

        m_trace->dump(sim_time);
        sim_time++;
    }

    // Dump a few extra cycles if failed
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

// Ascon-p12 known-answer test.
//
// Runs a single call to the full 320-bit state, 12-round permutation p^12 and
// checks the resulting state against a vector computed on the host with the
// untouched NIST-LWC reference implementation.
//
// Build with ACCEL=1 (-DUSE_COPROCESSOR_AXI) to offload the permutation to the
// loosely-coupled Ascon AXI accelerator mapped at DEV_ASCON (0x5000_1000);
// otherwise a pure-software C P12 (ported verbatim from the NIST-LWC reference
// round.h) runs on the base RV64 core.

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "encoding.h"
#include "uart.h"

#ifdef USE_COPROCESSOR_AXI
#define BUILD_MODE "Ascon AXI accelerator"
#include "ascon_axi.h"

#define ASCON_BASE_ADDR 0x50001000

static void P12(uint64_t *s)
{
    uint64_t volatile *cryptoState = (uint64_t volatile *)(ASCON_BASE_ADDR + ASCON_DATA_0_REG_OFFSET);
    uint64_t volatile *csreg       = (uint64_t volatile *)(ASCON_BASE_ADDR + ASCON_CSREG_REG_OFFSET);

    // Copy crypto state to Ascon AXI accelerator
    cryptoState[0] = s[0];
    cryptoState[1] = s[1];
    cryptoState[2] = s[2];
    cryptoState[3] = s[3];
    cryptoState[4] = s[4];

    // Order the input DATA writes before START. DATA and CSREG are distinct
    // addresses of the same AXI slave; RVWMO does not order stores to different
    // addresses, so without this fence START can overtake the DATA writes and
    // the core latches a stale state.
    __asm__ volatile("fence" ::: "memory");

    // Set round count (12) and start permutation
    *csreg = ((uint64_t)12 << ASCON_CSREG_ROUNDS_OFFSET) | (1ULL << ASCON_CSREG_START_BIT);

    // Wait for permutation and clear start bit at end
    while (((*csreg) & (1ULL << ASCON_CSREG_DONE_BIT)) == 0);
    *csreg &= ~(1ULL << ASCON_CSREG_START_BIT);

    // Order the DONE observation before the result readback.
    __asm__ volatile("fence" ::: "memory");

    // Copy crypto state from Ascon AXI accellerator
    s[0] = cryptoState[0];
    s[1] = cryptoState[1];
    s[2] = cryptoState[2];
    s[3] = cryptoState[3];
    s[4] = cryptoState[4];
}
#else
#define BUILD_MODE "software (RV64 base ISA)"
// Pure-software Ascon-p12, ported verbatim from the NIST-LWC reference
// implementation (round.h).
#define ROR(x, n) (((x) << (64 - (n))) | ((x) >> (n)))

static void P12(uint64_t *s)
{
    static const uint64_t rc[12] = {
        0xf0, 0xe1, 0xd2, 0xc3, 0xb4, 0xa5, 0x96, 0x87, 0x78, 0x69, 0x5a, 0x4b
    };

    uint64_t s00, s01, s02, s03, s04;

    s00 = s[0];
    s01 = s[1];
    s02 = s[2];
    s03 = s[3];
    s04 = s[4];

    for (int round = 0; round < 12; round++) {
        uint64_t t00, t01, t02, t03, t04;

        s02 ^= rc[round];
        s00 ^= s04;
        s04 ^= s03;
        s02 ^= s01;

        t00 = s00 ^ (~s01 & s02);
        t01 = s01 ^ (~s02 & s03);
        t02 = s02 ^ (~s03 & s04);
        t03 = s03 ^ (~s04 & s00);
        t04 = s04 ^ (~s00 & s01);

        t01 ^= t00;
        t00 ^= t04;
        t03 ^= t02;
        t02 = ~t02;

        s00 = t00 ^ ROR(t00, 19) ^ ROR(t00, 28);
        s01 = t01 ^ ROR(t01, 61) ^ ROR(t01, 39);
        s02 = t02 ^ ROR(t02, 1)  ^ ROR(t02, 6);
        s03 = t03 ^ ROR(t03, 10) ^ ROR(t03, 17);
        s04 = t04 ^ ROR(t04, 7)  ^ ROR(t04, 41);
    }

    s[0] = s00;
    s[1] = s01;
    s[2] = s02;
    s[3] = s03;
    s[4] = s04;
}
#endif

int main(){
    static uint64_t Din[5], D_expected[5];
    int cycles;
    int errors = 0;

    // Initial state
    memset(Din, 0, sizeof(Din));
    Din[0] = 0x0123456789ABCDEFULL;
    Din[1] = 0xFEDCBA9876543210ULL;
    Din[2] = 0x1111111111111111ULL;
    Din[3] = 0xAAAAAAAAAAAAAAAAULL;
    Din[4] = 0x00000000DEADBEEFULL;

    // Expected state after P12 (computed on the host with the untouched
    // NIST-LWC reference implementation)
    D_expected[0] = 0xdfc62157582c5b09ULL;
    D_expected[1] = 0x6ddb027baeb942f1ULL;
    D_expected[2] = 0xf31c5f11bb27d581ULL;
    D_expected[3] = 0x38ace12e4290287aULL;
    D_expected[4] = 0x79794f839b5628c0ULL;

    // Speed up simulation by minimizing the UART divider
    set_uart_div(1);

    printf("Ascon P12 Benchmark - %s\n", BUILD_MODE);

    clear_csr(mcountinhibit, 1);
    write_csr(mcycle, 0);
    P12(Din);
    cycles = read_csr(mcycle);

    printf("Number of clock cycles for Ascon P12: %d\n", cycles);

    for (int i = 0; i < 5; i++) {
        if (Din[i] != D_expected[i]) {
            printf("!!! Mismatch at index %d: expected 0x%016llx, got 0x%016llx !!!\n", i, D_expected[i], Din[i]);
            errors++;
        }
    }

    if (errors == 0)    printf("Ascon P12 Benchmark terminated with no errors.\n");
    else                printf("Ascon P12 Benchmark terminated with %d errors\n", errors);

    return 0;
}

// TPA benchmark - Ascon-p12 loosely-coupled AXI accelerator, configured for
// Ascon-XOF128 (r = 64 bits).
//
// Measures C_perm: the clock-cycle cost of a single call to the full 320-bit
// state, 12-round permutation p^12 (the permutation Ascon-XOF128 v1.2 uses
// throughout absorb/squeeze). C_perm feeds TPA = r * f_clk / (C_perm * A).
//
// Build with ACCEL=1 (-DUSE_COPROCESSOR_AXI) to offload the permutation to the
// loosely-coupled Ascon AXI accelerator mapped at 0x5000_1000; otherwise a
// pure-software C P12 (ported verbatim from the NIST-LWC reference) runs on the
// base RV64 core. Permutation input/output vectors mirror the sw/ascon KAT.

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "encoding.h"
#include "uart.h"

#define ALGO_NAME  "Ascon-XOF128"
#define RATE_BITS  64

#ifdef USE_COPROCESSOR_AXI
#define BUILD_MODE "Ascon AXI accelerator"
#include "ascon_axi.h"

#define ASCON_BASE_ADDR 0x50001000

// Ascon-p12 offloaded to the loosely-coupled Ascon AXI accelerator mapped at
// 0x5000_1000. The 5 state lanes are pushed to the DATA registers, the 12-round
// permutation is kicked off through CSREG (ROUNDS=12, START) and polled on
// CSREG.DONE, then the permuted state is read back. Mirrors the offload path in
// sw/ml-kem-512-ascon/ascon.h.
static void P12(uint64_t *s)
{
    uint64_t volatile *cryptoState = (uint64_t volatile *)(ASCON_BASE_ADDR + ASCON_DATA_0_REG_OFFSET);
    uint64_t volatile *csreg       = (uint64_t volatile *)(ASCON_BASE_ADDR + ASCON_CSREG_REG_OFFSET);

    // Copy the Ascon state to the accelerator
    for (int i = 0; i < 5; i++)
        cryptoState[i] = s[i];

    // Ensure all input DATA writes have reached the accelerator before START is
    // issued. DATA and CSREG are distinct addresses of the same AXI slave, and
    // RVWMO does not order stores to different addresses, so without this fence
    // the START store can overtake the DATA stores and the core latches a stale
    // state.
    __asm__ volatile("fence" ::: "memory");

    // Set round count (12) and start permutation
    *csreg = ((uint64_t)12 << ASCON_CSREG_ROUNDS_OFFSET) | (1ULL << ASCON_CSREG_START_BIT);

    // Wait for permutation and clear start bit at end
    while (((*csreg) & (1ULL << ASCON_CSREG_DONE_BIT)) == 0);
    *csreg &= ~(1ULL << ASCON_CSREG_START_BIT);

    // Order the DONE observation before the result readback
    __asm__ volatile("fence" ::: "memory");

    // Copy the permuted state back from the accelerator
    for (int i = 0; i < 5; i++)
        s[i] = cryptoState[i];
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

    uint64_t s00 = s[0], s01 = s[1], s02 = s[2], s03 = s[3], s04 = s[4];

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

int main(void)
{
    static uint64_t Din[5], D_expected[5];
    unsigned long cycles;
    int fails = 0;

    // To increase simulation speed, set baudrate to a high value.
    // BAUDRATE = CLK_FREQ / (DIV - 1)
    set_uart_div(1);

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

    printf("TPA benchmark - Ascon-p12 - %s (r=%d bits) - %s\n", ALGO_NAME, RATE_BITS, BUILD_MODE);

    clear_csr(mcountinhibit, 1);
    write_csr(mcycle, 0);
    P12(Din);
    cycles = read_csr(mcycle);

    printf("algo: %s\n", ALGO_NAME);
    printf("rate_bits: %d\n", RATE_BITS);
    printf("cycles permute: %lu\n", cycles);

    for (int i = 0; i < 5; i++) {
        if (Din[i] != D_expected[i]) {
            printf("!!! Mismatch at index %d: expected 0x%016llx, got 0x%016llx !!!\n",
                   i, (unsigned long long)D_expected[i], (unsigned long long)Din[i]);
            fails++;
        }
    }

    if (fails == 0) printf("Test Successful (1 KAT vector(s))\n");
    else            printf("Test FAILED: %d mismatch(es)\n", fails);

    return fails != 0;
}

///////////////////////////////////////////////////////////////////////////////////////
// Static (no file I/O) KAT test for ml-kem-512 (SHAKE symmetric primitives),
// bare-metal RV64 using the UART flow.
///////////////////////////////////////////////////////////////////////////////////////

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "kem.h"
#include "test_vectors_512.h"
#include "encoding.h"
#include "uart.h"

#ifndef PERF_CNT_CYCLES
#define PERF_CNT_CYCLES 1
#endif

#define RUN_KEYGEN  1
#define RUN_ENCAPS  1
#define RUN_DECAPS  1

static void printVect(const char *name, const uint8_t *buf, size_t size) {
    print_uart(name);
    for (size_t i = 0; i < size; i++)
        print_uart_hex8(buf[i]);
    print_uart("\n");
}

static uint8_t pk[KYBER_PUBLICKEYBYTES];
static uint8_t sk[KYBER_SECRETKEYBYTES];
static uint8_t ct[KYBER_CIPHERTEXTBYTES];
static uint8_t key_a[KYBER_SSBYTES];
static uint8_t key_b[KYBER_SSBYTES];

int main(void)
{
#if PERF_CNT_CYCLES
    unsigned int cycles, instrs;
    clear_csr(mcountinhibit, 0x5); /* bit0=CY (mcycle), bit2=IR (minstret) */
#endif /* PERF_CNT_CYCLES */

    int fails = 0;

    for (int i = 0; i < N_KAT; i++) {
        print_uart("=== KAT ");
        print_uart_dec(i + 1);
        print_uart("/");
        print_uart_dec(N_KAT);
        print_uart(" ===\n");

#if RUN_KEYGEN
        #if PERF_CNT_CYCLES
        write_csr(mcycle, 0);
        write_csr(minstret, 0);
        #endif /* PERF_CNT_CYCLES */
        crypto_kem_keypair_derand(pk, sk, TVEC_IN_KEM_KEYPAIR[i]);
        #if PERF_CNT_CYCLES
        cycles = read_csr(mcycle);
        instrs = read_csr(minstret);
        print_uart("cycles crypto_kem_keypair_derand: ");
        print_uart_dec(cycles);
        print_uart("\n");
        print_uart("instructions crypto_kem_keypair_derand: ");
        print_uart_dec(instrs);
        print_uart("\n");
        #endif /* PERF_CNT_CYCLES */
        if (memcmp(pk, TVEC_OUT_PK[i], KYBER_PUBLICKEYBYTES)) { print_uart("ERROR: PK mismatch\n"); fails++; }
        if (memcmp(sk, TVEC_OUT_SK[i], KYBER_SECRETKEYBYTES)) { print_uart("ERROR: SK mismatch\n"); fails++; }
#else
        memcpy(pk, TVEC_OUT_PK[i], KYBER_PUBLICKEYBYTES);
        memcpy(sk, TVEC_OUT_SK[i], KYBER_SECRETKEYBYTES);
#endif /* RUN_KEYGEN */

#if RUN_ENCAPS
        #if PERF_CNT_CYCLES
        write_csr(mcycle, 0);
        write_csr(minstret, 0);
        #endif /* PERF_CNT_CYCLES */
        crypto_kem_enc_derand(ct, key_b, pk, TVEC_IN_KEM_ENC[i]);
        #if PERF_CNT_CYCLES
        cycles = read_csr(mcycle);
        instrs = read_csr(minstret);
        print_uart("cycles crypto_kem_enc_derand: ");
        print_uart_dec(cycles);
        print_uart("\n");
        print_uart("instructions crypto_kem_enc_derand: ");
        print_uart_dec(instrs);
        print_uart("\n");
        #endif /* PERF_CNT_CYCLES */
        if (memcmp(ct, TVEC_OUT_CT[i], KYBER_CIPHERTEXTBYTES)) { print_uart("ERROR: CT mismatch\n"); fails++; }
        if (memcmp(key_b, TVEC_OUT_SS[i], KYBER_SSBYTES)) { print_uart("ERROR: SS(enc) mismatch\n"); fails++; }
#else
        memcpy(ct, TVEC_OUT_CT[i], KYBER_CIPHERTEXTBYTES);
        memcpy(key_b, TVEC_OUT_SS[i], KYBER_SSBYTES);
#endif /* RUN_ENCAPS */

#if RUN_DECAPS
        #if PERF_CNT_CYCLES
        write_csr(mcycle, 0);
        write_csr(minstret, 0);
        #endif /* PERF_CNT_CYCLES */
        crypto_kem_dec(key_a, ct, sk);
        #if PERF_CNT_CYCLES
        cycles = read_csr(mcycle);
        instrs = read_csr(minstret);
        print_uart("cycles crypto_kem_dec: ");
        print_uart_dec(cycles);
        print_uart("\n");
        print_uart("instructions crypto_kem_dec: ");
        print_uart_dec(instrs);
        print_uart("\n");
        #endif /* PERF_CNT_CYCLES */
        if (memcmp(key_a, TVEC_OUT_SS[i], KYBER_SSBYTES)) { print_uart("ERROR: SS(dec) mismatch\n"); fails++; }
#endif /* RUN_DECAPS */
    }

    if (fails == 0) {
        print_uart("Test Successful (");
        print_uart_dec(N_KAT);
        print_uart(" KAT vector(s))\n");
    } else {
        print_uart("Test FAILED: ");
        print_uart_dec(fails);
        print_uart(" mismatch(es)\n");
    }

    return fails != 0;
}

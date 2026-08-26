// TPA benchmark - Keccak-f[1600] loosely-coupled AXI accelerator, configured for
// SHAKE128 (r = 1344 bits).
//
// Measures C_perm: the clock-cycle cost of a single call to the full-state
// permutation. C_perm is a property of the Keccak-f[1600] permutation itself,
// not of the sponge rate -- so this is the same IP call used by SHAKE256,
// differing only in the rate label used downstream to compute
// TPA = r * f_clk / (C_perm * A).
//
// Build with ACCEL=1 (-DUSE_COPROCESSOR_AXI) to offload the permutation to the
// loosely-coupled Keccak AXI accelerator mapped at 0x5000_1000; otherwise a
// pure-software C Keccak-f[1600] permutation runs on the base RV64 core.
// Permutation input/output vectors mirror the SHAKE KAT.

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "encoding.h"
#include "uart.h"

#define ALGO_NAME  "SHAKE128"
#define RATE_BITS  1344

#ifdef USE_COPROCESSOR_AXI
#define BUILD_MODE "Keccak AXI accelerator"
#include "keccak_axi.h"

#define KECCAK_BASE_ADDR 0x50001000

// Keccak-f[1600] offloaded to the loosely-coupled Keccak AXI accelerator mapped
// at 0x5000_1000. The 25 state lanes are pushed to the DATA registers, the
// permutation is kicked off through CSREG.START and polled on CSREG.DONE, then
// the permuted state is read back. Mirrors the offload path in
// sw/ml-kem-512/fips202.c.
static void KeccakF1600_StatePermute(uint64_t *state)
{
    volatile uint64_t *cryptoState = (volatile uint64_t *)(KECCAK_BASE_ADDR + KECCAK_DATA_0_REG_OFFSET);
    volatile uint64_t *csreg       = (volatile uint64_t *)(KECCAK_BASE_ADDR + KECCAK_CSREG_REG_OFFSET);

    // Copy the Keccak state to the accelerator
    for (int i = 0; i < 25; i++)
        cryptoState[i] = state[i];

    // Ensure all input DATA writes have reached the accelerator before START is
    // issued. DATA and CSREG are distinct addresses of the same AXI slave, and
    // RVWMO does not order stores to different addresses, so without this fence
    // the START store can overtake the DATA stores and the core latches a stale
    // state.
    __asm__ volatile("fence" ::: "memory");

    // Kick off the permutation. Writing the full word with START=1 also clears
    // DONE, arming the DONE poll below for this invocation.
    *csreg = (1ULL << KECCAK_CSREG_START_BIT);

    // Wait for completion, then clear the start bit
    while (((*csreg) & (1ULL << KECCAK_CSREG_DONE_BIT)) == 0);
    *csreg &= ~(1ULL << KECCAK_CSREG_START_BIT);

    // Order the DONE observation before the result readback
    __asm__ volatile("fence" ::: "memory");

    // Copy the permuted state back from the accelerator
    for (int i = 0; i < 25; i++)
        state[i] = cryptoState[i];
}
#else
#define BUILD_MODE "software (RV64 base ISA)"
// Pure-software Keccak-f[1600] (24 rounds), taken verbatim from the FIPS-202
// reference permutation used elsewhere in this repo (sw/ml-kem-512/fips202.c).
#define NROUNDS 24
#define ROL(a, offset) ((a << offset) ^ (a >> (64 - offset)))

static const uint64_t KeccakF_RoundConstants[NROUNDS] = {
    0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808aULL,
    0x8000000080008000ULL, 0x000000000000808bULL, 0x0000000080000001ULL,
    0x8000000080008081ULL, 0x8000000000008009ULL, 0x000000000000008aULL,
    0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000aULL,
    0x000000008000808bULL, 0x800000000000008bULL, 0x8000000000008089ULL,
    0x8000000000008003ULL, 0x8000000000008002ULL, 0x8000000000000080ULL,
    0x000000000000800aULL, 0x800000008000000aULL, 0x8000000080008081ULL,
    0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL
};

static void KeccakF1600_StatePermute(uint64_t *state)
{
    int round;

    uint64_t Aba, Abe, Abi, Abo, Abu;
    uint64_t Aga, Age, Agi, Ago, Agu;
    uint64_t Aka, Ake, Aki, Ako, Aku;
    uint64_t Ama, Ame, Ami, Amo, Amu;
    uint64_t Asa, Ase, Asi, Aso, Asu;
    uint64_t BCa, BCe, BCi, BCo, BCu;
    uint64_t Da, De, Di, Do, Du;
    uint64_t Eba, Ebe, Ebi, Ebo, Ebu;
    uint64_t Ega, Ege, Egi, Ego, Egu;
    uint64_t Eka, Eke, Eki, Eko, Eku;
    uint64_t Ema, Eme, Emi, Emo, Emu;
    uint64_t Esa, Ese, Esi, Eso, Esu;

    Aba = state[ 0]; Abe = state[ 1]; Abi = state[ 2]; Abo = state[ 3]; Abu = state[ 4];
    Aga = state[ 5]; Age = state[ 6]; Agi = state[ 7]; Ago = state[ 8]; Agu = state[ 9];
    Aka = state[10]; Ake = state[11]; Aki = state[12]; Ako = state[13]; Aku = state[14];
    Ama = state[15]; Ame = state[16]; Ami = state[17]; Amo = state[18]; Amu = state[19];
    Asa = state[20]; Ase = state[21]; Asi = state[22]; Aso = state[23]; Asu = state[24];

    for (round = 0; round < NROUNDS; round += 2) {
        BCa = Aba^Aga^Aka^Ama^Asa;
        BCe = Abe^Age^Ake^Ame^Ase;
        BCi = Abi^Agi^Aki^Ami^Asi;
        BCo = Abo^Ago^Ako^Amo^Aso;
        BCu = Abu^Agu^Aku^Amu^Asu;

        Da = BCu^ROL(BCe, 1);
        De = BCa^ROL(BCi, 1);
        Di = BCe^ROL(BCo, 1);
        Do = BCi^ROL(BCu, 1);
        Du = BCo^ROL(BCa, 1);

        Aba ^= Da; BCa = Aba;
        Age ^= De; BCe = ROL(Age, 44);
        Aki ^= Di; BCi = ROL(Aki, 43);
        Amo ^= Do; BCo = ROL(Amo, 21);
        Asu ^= Du; BCu = ROL(Asu, 14);
        Eba = BCa ^((~BCe)& BCi); Eba ^= KeccakF_RoundConstants[round];
        Ebe = BCe ^((~BCi)& BCo);
        Ebi = BCi ^((~BCo)& BCu);
        Ebo = BCo ^((~BCu)& BCa);
        Ebu = BCu ^((~BCa)& BCe);

        Abo ^= Do; BCa = ROL(Abo, 28);
        Agu ^= Du; BCe = ROL(Agu, 20);
        Aka ^= Da; BCi = ROL(Aka,  3);
        Ame ^= De; BCo = ROL(Ame, 45);
        Asi ^= Di; BCu = ROL(Asi, 61);
        Ega = BCa ^((~BCe)& BCi);
        Ege = BCe ^((~BCi)& BCo);
        Egi = BCi ^((~BCo)& BCu);
        Ego = BCo ^((~BCu)& BCa);
        Egu = BCu ^((~BCa)& BCe);

        Abe ^= De; BCa = ROL(Abe,  1);
        Agi ^= Di; BCe = ROL(Agi,  6);
        Ako ^= Do; BCi = ROL(Ako, 25);
        Amu ^= Du; BCo = ROL(Amu,  8);
        Asa ^= Da; BCu = ROL(Asa, 18);
        Eka = BCa ^((~BCe)& BCi);
        Eke = BCe ^((~BCi)& BCo);
        Eki = BCi ^((~BCo)& BCu);
        Eko = BCo ^((~BCu)& BCa);
        Eku = BCu ^((~BCa)& BCe);

        Abu ^= Du; BCa = ROL(Abu, 27);
        Aga ^= Da; BCe = ROL(Aga, 36);
        Ake ^= De; BCi = ROL(Ake, 10);
        Ami ^= Di; BCo = ROL(Ami, 15);
        Aso ^= Do; BCu = ROL(Aso, 56);
        Ema = BCa ^((~BCe)& BCi);
        Eme = BCe ^((~BCi)& BCo);
        Emi = BCi ^((~BCo)& BCu);
        Emo = BCo ^((~BCu)& BCa);
        Emu = BCu ^((~BCa)& BCe);

        Abi ^= Di; BCa = ROL(Abi, 62);
        Ago ^= Do; BCe = ROL(Ago, 55);
        Aku ^= Du; BCi = ROL(Aku, 39);
        Ama ^= Da; BCo = ROL(Ama, 41);
        Ase ^= De; BCu = ROL(Ase,  2);
        Esa = BCa ^((~BCe)& BCi);
        Ese = BCe ^((~BCi)& BCo);
        Esi = BCi ^((~BCo)& BCu);
        Eso = BCo ^((~BCu)& BCa);
        Esu = BCu ^((~BCa)& BCe);

        BCa = Eba^Ega^Eka^Ema^Esa;
        BCe = Ebe^Ege^Eke^Eme^Ese;
        BCi = Ebi^Egi^Eki^Emi^Esi;
        BCo = Ebo^Ego^Eko^Emo^Eso;
        BCu = Ebu^Egu^Eku^Emu^Esu;

        Da = BCu^ROL(BCe, 1);
        De = BCa^ROL(BCi, 1);
        Di = BCe^ROL(BCo, 1);
        Do = BCi^ROL(BCu, 1);
        Du = BCo^ROL(BCa, 1);

        Eba ^= Da; BCa = Eba;
        Ege ^= De; BCe = ROL(Ege, 44);
        Eki ^= Di; BCi = ROL(Eki, 43);
        Emo ^= Do; BCo = ROL(Emo, 21);
        Esu ^= Du; BCu = ROL(Esu, 14);
        Aba = BCa ^((~BCe)& BCi); Aba ^= KeccakF_RoundConstants[round+1];
        Abe = BCe ^((~BCi)& BCo);
        Abi = BCi ^((~BCo)& BCu);
        Abo = BCo ^((~BCu)& BCa);
        Abu = BCu ^((~BCa)& BCe);

        Ebo ^= Do; BCa = ROL(Ebo, 28);
        Egu ^= Du; BCe = ROL(Egu, 20);
        Eka ^= Da; BCi = ROL(Eka,  3);
        Eme ^= De; BCo = ROL(Eme, 45);
        Esi ^= Di; BCu = ROL(Esi, 61);
        Aga = BCa ^((~BCe)& BCi);
        Age = BCe ^((~BCi)& BCo);
        Agi = BCi ^((~BCo)& BCu);
        Ago = BCo ^((~BCu)& BCa);
        Agu = BCu ^((~BCa)& BCe);

        Ebe ^= De; BCa = ROL(Ebe,  1);
        Egi ^= Di; BCe = ROL(Egi,  6);
        Eko ^= Do; BCi = ROL(Eko, 25);
        Emu ^= Du; BCo = ROL(Emu,  8);
        Esa ^= Da; BCu = ROL(Esa, 18);
        Aka = BCa ^((~BCe)& BCi);
        Ake = BCe ^((~BCi)& BCo);
        Aki = BCi ^((~BCo)& BCu);
        Ako = BCo ^((~BCu)& BCa);
        Aku = BCu ^((~BCa)& BCe);

        Ebu ^= Du; BCa = ROL(Ebu, 27);
        Ega ^= Da; BCe = ROL(Ega, 36);
        Eke ^= De; BCi = ROL(Eke, 10);
        Emi ^= Di; BCo = ROL(Emi, 15);
        Eso ^= Do; BCu = ROL(Eso, 56);
        Ama = BCa ^((~BCe)& BCi);
        Ame = BCe ^((~BCi)& BCo);
        Ami = BCi ^((~BCo)& BCu);
        Amo = BCo ^((~BCu)& BCa);
        Amu = BCu ^((~BCa)& BCe);

        Ebi ^= Di; BCa = ROL(Ebi, 62);
        Ego ^= Do; BCe = ROL(Ego, 55);
        Eku ^= Du; BCi = ROL(Eku, 39);
        Ema ^= Da; BCo = ROL(Ema, 41);
        Ese ^= De; BCu = ROL(Ese,  2);
        Asa = BCa ^((~BCe)& BCi);
        Ase = BCe ^((~BCi)& BCo);
        Asi = BCi ^((~BCo)& BCu);
        Aso = BCo ^((~BCu)& BCa);
        Asu = BCu ^((~BCa)& BCe);
    }

    state[ 0] = Aba; state[ 1] = Abe; state[ 2] = Abi; state[ 3] = Abo; state[ 4] = Abu;
    state[ 5] = Aga; state[ 6] = Age; state[ 7] = Agi; state[ 8] = Ago; state[ 9] = Agu;
    state[10] = Aka; state[11] = Ake; state[12] = Aki; state[13] = Ako; state[14] = Aku;
    state[15] = Ama; state[16] = Ame; state[17] = Ami; state[18] = Amo; state[19] = Amu;
    state[20] = Asa; state[21] = Ase; state[22] = Asi; state[23] = Aso; state[24] = Asu;
}
#endif

int main(void)
{
    static uint64_t Din[25], D_expected[25];
    unsigned long cycles;
    int fails = 0;

    // To increase simulation speed, set baudrate to a high value.
    // BAUDRATE = CLK_FREQ / (DIV - 1)
    set_uart_div(1);

    memset(Din, 0, sizeof(Din));
    Din[0]  = 0xEC4AFF517369C667ULL;
    Din[1]  = 0x00000010ABBACD29ULL;
    Din[15] = 0x8000000000000000ULL;

    D_expected[0]  = 0xE1ADB0E2E7CB8356ULL;
    D_expected[1]  = 0xBB3F5FB8573A5BD7ULL;
    D_expected[2]  = 0xF7CA02A1E9784CC5ULL;
    D_expected[3]  = 0x6E54F25660A4C685ULL;
    D_expected[4]  = 0x77051F83243FCBAAULL;
    D_expected[5]  = 0x6459DB0B4C063DD5ULL;
    D_expected[6]  = 0xE046DE71CB4B81C6ULL;
    D_expected[7]  = 0x94051793DB31F24CULL;
    D_expected[8]  = 0xA13FC86CF16E32DDULL;
    D_expected[9]  = 0xB962FC91B7737708ULL;
    D_expected[10] = 0xD3CA2E7AFA27C801ULL;
    D_expected[11] = 0x53C85108F72A3CCAULL;
    D_expected[12] = 0x73E732CDADF0E783ULL;
    D_expected[13] = 0x8470BD54C4BDD1BFULL;
    D_expected[14] = 0xD10B916F7C8C1F77ULL;
    D_expected[15] = 0x51129474440A2670ULL;
    D_expected[16] = 0x3D77CB49E9960C44ULL;
    D_expected[17] = 0xEC5001EBE4251E39ULL;
    D_expected[18] = 0x77A0EEC5EA4FD653ULL;
    D_expected[19] = 0xEBC86BD47B6773E7ULL;
    D_expected[20] = 0xE77DF6B0128FDC4BULL;
    D_expected[21] = 0x0DB0D48A02F1B12EULL;
    D_expected[22] = 0x241B344D0DC38AE5ULL;
    D_expected[23] = 0xC3EE4E27532483D8ULL;
    D_expected[24] = 0x0271BFE284B1B424ULL;

    printf("TPA benchmark - Keccak-f[1600] - %s (r=%d bits) - %s\n", ALGO_NAME, RATE_BITS, BUILD_MODE);

    clear_csr(mcountinhibit, 1);
    write_csr(mcycle, 0);
    KeccakF1600_StatePermute(Din);
    cycles = read_csr(mcycle);

    printf("algo: %s\n", ALGO_NAME);
    printf("rate_bits: %d\n", RATE_BITS);
    printf("cycles permute: %lu\n", cycles);

    for (int i = 0; i < 25; i++) {
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

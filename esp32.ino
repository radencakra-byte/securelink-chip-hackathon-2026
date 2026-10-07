#include <Preferences.h>
#include "mbedtls/md.h"

#define RXD2 16
#define TXD2 17

uint8_t KEY[32];
uint8_t WRONG_KEY[32];
uint32_t nextCtr = 1;
Preferences prefs;
int passAll = 0, failAll = 0;

void hmacSha256(const uint8_t* key, size_t keyLen, const uint8_t* msg, size_t msgLen, uint8_t out[32]) {
  mbedtls_md_context_t ctx;
  mbedtls_md_init(&ctx);
  mbedtls_md_setup(&ctx, mbedtls_md_info_from_type(MBEDTLS_MD_SHA256), 1);
  mbedtls_md_hmac_starts(&ctx, key, keyLen);
  mbedtls_md_hmac_update(&ctx, msg, msgLen);
  mbedtls_md_hmac_finish(&ctx, out);
  mbedtls_md_free(&ctx);
}

// frame: A5 | ver src dst len | ctr(4, BE) | payload | tag(16)
// tag = HMAC(ver,src,dst,len,ctr,payload)[0..15]
size_t buildFrame(uint8_t* out, uint32_t ctr, uint8_t len, const uint8_t* key,
                  bool flipPayload, bool flipTag) {
  uint8_t msg[8 + 32];
  size_t m = 0;
  msg[m++] = 0x01; msg[m++] = 0x11; msg[m++] = 0x22; msg[m++] = len;
  msg[m++] = (ctr >> 24) & 0xFF; msg[m++] = (ctr >> 16) & 0xFF;
  msg[m++] = (ctr >> 8) & 0xFF;  msg[m++] = ctr & 0xFF;
  for (uint8_t i = 0; i < len; i++) msg[m++] = 0x10 + i;

  uint8_t full[32];
  hmacSha256(key, 32, msg, m, full);

  size_t n = 0;
  out[n++] = 0xA5;
  memcpy(out + n, msg, m); n += m;
  if (flipPayload && len > 0) out[1 + 8] ^= 0x01;   // ubah byte payload pertama SETELAH tag dihitung
  memcpy(out + n, full, 16); n += 16;
  if (flipTag) out[n - 16] ^= 0x01;
  return n;
}

bool readReply(uint8_t* r, unsigned long timeoutMs) {
  size_t got = 0;
  unsigned long t0 = millis();
  while (got < 4 && millis() - t0 < timeoutMs) {
    if (Serial2.available()) r[got++] = Serial2.read();
  }
  return got == 4;
}

void sendAndCheck(const char* name, const uint8_t* f, size_t n, char expect, uint32_t ctr) {
  uint8_t r[4];
  while (Serial2.available()) Serial2.read();
  Serial2.write(f, n);
  bool got = readReply(r, 300);
  bool pass = got && r[0] == expect && (expect == 'E' || r[2] == (uint8_t)(ctr & 0xFF));
  if (pass) passAll++; else failAll++;
  if (got) Serial.printf("[%s] %-28s harus %c, dapat %c (len=%u ctr=%u)\n",
                         pass ? "PASS" : "FAIL", name, expect, (char)r[0], r[1], r[2]);
  else     Serial.printf("[FAIL] %-28s harus %c, TIDAK ADA BALASAN\n", name, expect);
}

void attackRound() {
  uint8_t f[64]; size_t n;

  uint32_t c1 = nextCtr++;
  n = buildFrame(f, c1, 4, KEY, false, false);
  sendAndCheck("1 frame valid", f, n, 'O', c1);
  sendAndCheck("2 replay frame sama", f, n, 'R', c1);

  uint32_t c2 = nextCtr++;
  n = buildFrame(f, c2, 4, KEY, true, false);
  sendAndCheck("3 data diubah", f, n, 'A', c2);
  n = buildFrame(f, c2, 4, WRONG_KEY, false, false);
  sendAndCheck("4 kunci salah", f, n, 'A', c2);
  n = buildFrame(f, c2, 4, KEY, false, true);
  sendAndCheck("5 tag diubah", f, n, 'A', c2);

  n = buildFrame(f, c2, 4, KEY, false, false);
  sendAndCheck("6 valid ctr berikutnya", f, n, 'O', c2);
  n = buildFrame(f, c1, 4, KEY, false, false);
  sendAndCheck("7 counter lama", f, n, 'R', c1);

  uint32_t c3 = nextCtr++;
  n = buildFrame(f, c3, 8, KEY, false, false);
  const uint8_t noise[3] = {0x00, 0xFF, 0x12};
  while (Serial2.available()) Serial2.read();
  Serial2.write(noise, 3);
  sendAndCheck("8 noise + frame valid", f, n, 'O', c3);

  const uint8_t badLen[5] = {0xA5, 0x01, 0x11, 0x22, 33};
  sendAndCheck("9 LEN=33", badLen, 5, 'E', 0);
  const uint8_t cut[3] = {0xA5, 0x01, 0x11};
  sendAndCheck("10 frame terpotong", cut, 3, 'E', 0);

  Serial.printf("== Ringkasan: PASS=%d FAIL=%d ==\n", passAll, failAll);
}

void stressTest(int count) {
  uint8_t f[64], r[4];
  int ok = 0, bad = 0;
  unsigned long t0 = millis();
  for (int i = 0; i < count; i++) {
    uint32_t c = nextCtr++;
    size_t n = buildFrame(f, c, 4 + (i % 8), KEY, false, false);
    while (Serial2.available()) Serial2.read();
    Serial2.write(f, n);
    if (readReply(r, 100) && r[0] == 'O') ok++; else bad++;
  }
  Serial.printf("Ketahanan: %d frame, diterima=%d, ditolak/hilang=%d, waktu=%lu ms\n",
                count, ok, bad, millis() - t0);
}

void setup() {
  Serial.begin(115200);
  Serial2.begin(115200, SERIAL_8N1, RXD2, TXD2);
  for (int i = 0; i < 32; i++) { KEY[i] = i; WRONG_KEY[i] = i; }
  WRONG_KEY[0] ^= 0xFF;

  prefs.begin("securelink", false);
  uint32_t base = prefs.getUInt("ctr", 0);
  prefs.putUInt("ctr", base + 100000);   // cadangkan 100.000 counter untuk sesi ini
  prefs.end();
  nextCtr = base + 1;

  delay(500);
  Serial.println("SecureLink uji serangan. Ketik 'a' = skenario serangan, 's' = 10.000 frame");
}

void loop() {
  if (Serial.available()) {
    char ch = Serial.read();
    if (ch == 'a') attackRound();
    else if (ch == 's') stressTest(10000);
  }
}
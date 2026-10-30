-- Fantasy Scripts license runtime — pure Lua 5.4 crypto (no dependencies).
-- ChaCha20 (RFC 8439 block function, initial counter 0) and SHA-256.
-- Kept in sync with src/lib/protect/crypto.ts on the website.

local FSCrypto = {}

local M32 = 0xffffffff

local function rotl(x, n)
  return ((x << n) | (x >> (32 - n))) & M32
end

local function quarter(s, a, b, c, d)
  s[a] = (s[a] + s[b]) & M32; s[d] = rotl(s[d] ~ s[a], 16)
  s[c] = (s[c] + s[d]) & M32; s[b] = rotl(s[b] ~ s[c], 12)
  s[a] = (s[a] + s[b]) & M32; s[d] = rotl(s[d] ~ s[a], 8)
  s[c] = (s[c] + s[d]) & M32; s[b] = rotl(s[b] ~ s[c], 7)
end

local function hexToBytes(hex)
  return (hex:gsub('..', function(h) return string.char(tonumber(h, 16)) end))
end
FSCrypto.hexToBytes = hexToBytes

function FSCrypto.toHex(bytes)
  return (bytes:gsub('.', function(c) return string.format('%02x', c:byte()) end))
end

--- XORs `data` with the ChaCha20 keystream (encrypt == decrypt).
--- @param key string 32 raw bytes (or 64 hex chars)
--- @param nonce string 12 raw bytes
function FSCrypto.chacha20(key, nonce, data)
  if #key == 64 then key = hexToBytes(key) end
  assert(#key == 32 and #nonce == 12, 'chacha20: bad key or nonce length')
  local k = { string.unpack('<I4I4I4I4I4I4I4I4', key) }
  local n = { string.unpack('<I4I4I4', nonce) }
  local init = { 0x61707865, 0x3320646e, 0x79622d32, 0x6b206574, k[1], k[2], k[3], k[4], k[5], k[6], k[7], k[8], 0, n[1], n[2], n[3] }
  local out, s, counter = {}, {}, 0
  local len = #data
  for pos = 1, len, 64 do
    init[13] = counter
    for i = 1, 16 do s[i] = init[i] end
    for _ = 1, 10 do
      quarter(s, 1, 5, 9, 13); quarter(s, 2, 6, 10, 14); quarter(s, 3, 7, 11, 15); quarter(s, 4, 8, 12, 16)
      quarter(s, 1, 6, 11, 16); quarter(s, 2, 7, 12, 13); quarter(s, 3, 8, 9, 14); quarter(s, 4, 5, 10, 15)
    end
    for i = 1, 16 do s[i] = (s[i] + init[i]) & M32 end
    if pos + 63 <= len then
      local w = { string.unpack('<I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4', data, pos) }
      for i = 1, 16 do w[i] = w[i] ~ s[i] end
      out[#out + 1] = string.pack('<I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4', table.unpack(w, 1, 16))
    else
      local ks = string.pack('<I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4', table.unpack(s, 1, 16))
      local tail = {}
      for i = 0, len - pos do
        tail[#tail + 1] = string.char(data:byte(pos + i) ~ ks:byte(i + 1))
      end
      out[#out + 1] = table.concat(tail)
    end
    counter = (counter + 1) & M32
  end
  return table.concat(out)
end

local K = {
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local function rotr(x, n)
  return ((x >> n) | (x << (32 - n))) & M32
end

--- SHA-256 of a string, as 64 lowercase hex characters.
function FSCrypto.sha256(msg)
  local h = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }
  local ml = #msg * 8
  msg = msg .. '\128' .. string.rep('\0', (55 - #msg) % 64) .. string.pack('>I8', ml)
  local w = {}
  for chunk = 1, #msg, 64 do
    for i = 1, 16 do w[i] = string.unpack('>I4', msg, chunk + (i - 1) * 4) end
    for i = 17, 64 do
      local s0 = rotr(w[i - 15], 7) ~ rotr(w[i - 15], 18) ~ (w[i - 15] >> 3)
      local s1 = rotr(w[i - 2], 17) ~ rotr(w[i - 2], 19) ~ (w[i - 2] >> 10)
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & M32
    end
    local a, b, c, d, e, f, g, hh = h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8]
    for i = 1, 64 do
      local S1 = rotr(e, 6) ~ rotr(e, 11) ~ rotr(e, 25)
      local ch = (e & f) ~ ((~e & M32) & g)
      local t1 = (hh + S1 + ch + K[i] + w[i]) & M32
      local S0 = rotr(a, 2) ~ rotr(a, 13) ~ rotr(a, 22)
      local maj = (a & b) ~ (a & c) ~ (b & c)
      local t2 = (S0 + maj) & M32
      hh, g, f, e, d, c, b, a = g, f, e, (d + t1) & M32, c, b, a, (t1 + t2) & M32
    end
    h[1] = (h[1] + a) & M32; h[2] = (h[2] + b) & M32; h[3] = (h[3] + c) & M32; h[4] = (h[4] + d) & M32
    h[5] = (h[5] + e) & M32; h[6] = (h[6] + f) & M32; h[7] = (h[7] + g) & M32; h[8] = (h[8] + hh) & M32
  end
  return string.format(string.rep('%08x', 8), table.unpack(h))
end

return FSCrypto

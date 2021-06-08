import bigint, unittest

test "initBigInt":
  let a = BigInt.init(1234567)
  check a == 1234567'i32

  let n: int32 = -1234567
  let b = BigInt.init(n)
  check b == n
  check (a + b) == BigInt.init(0)

test "addBigInt":
  let a = BigInt.init(7)
  let b = a + BigInt.init(6)
  echo "a = ", toUInt64(a)
  echo "b = ", toUInt64(b)
  check b == BigInt.init(13)


test "addBigInt1":
  let a = BigInt.init(0xFFFF_FFFF'u64)
  let b = a + BigInt.init(1)
  let c = BigInt.init(0xF0F0_F0F0'u64)
  check b == BigInt.init(0x1_0000_0000'u64)
  echo "a = ", toUInt64(a)
  echo "c = ", toUInt64(c)
  echo "c + a = ", toUInt64(c + a)
  
test "addBigInt2":
  let a = BigInt.init(0xF0F0_F0F0_F0F0_F0F0'u64)
  let b = BigInt.init(0x0F0F_0F0F_0F0F_0F0F'u64)
  let c = a + b
  check c == BigInt.init(0xFFFF_FFFF_FFFF_FFFF'u64)

test "addBigInt3":
  let a = BigInt.init(0xFFFF_FFFF'u64)
  let b = a + 1'u64
  check b == BigInt.init(0x1_0000_0000'u64)

test "subBigInt":
  let a = BigInt.init(0x1_0000_0000'u64)
  let b = a - BigInt.init(1'u32)
  echo "a = ", toUInt64(a)
  echo "b = ", toUInt64(b)
  check b == BigInt.init(0xFFFF_FFFF'u32)

test "subBiggerInt":
  let a = BigInt.init(0xFFFF_FFFF_FFFF_FFFF'u64)
  let b = a - BigInt.init(0xF0F0_F0F0_F0F0_F0F0'u64)
  let c = BigInt.init(0x0F0F_0F0F_0F0F_0F0F'u64)
  
  echo "a = ", toUInt64(a)
  echo "b = ", toUInt64(b)
  echo "c = ", toUInt64(c)
  check b == BigInt.init(0x0F0F_0F0F_0F0F_0F0F'u64)

test "mulBigInt":
  let a = BigInt.init(0xFFFF_FFFF'u64)
  let b = BigInt.init(2)
  let c = b * a
  let d = a + a
  
  echo "a = ", toUInt64(a)
  echo "b = ", toUInt64(b)
  echo "c = ", toUInt64(c)
  echo "d = ", toUInt64(d)
  check c == d
  # BigInt.init(0x1_FFFF_FFFe'u64)

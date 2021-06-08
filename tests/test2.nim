import bigint

proc main() =
  let a = BigInt.init(0xFFFF_FFFF_FFFF_FFFF'u64)
  let b = BigInt.init(0xF0F0_F0F0_F0F0_F0F0'u64)
  let c = BigInt.init(0x0F0F_0F0F_0F0F_0F0F'u64)
  echo "a = ", toUInt64(a)
  echo "b = ", toUInt64(b)
  echo "c = ", toUInt64(c)
  echo "a - c = ", toUInt64(a - c)

when isMainModule:
  main()

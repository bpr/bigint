import bitops

type
  BigInt* = object
    isNegative: bool
    used, cap: int
    limbs: ptr UncheckedArray[uint32]
  Unsigned = uint8 | uint16 | uint32 | uint64
  Signed = int8 | int16 | int32 | int64
  UnsignedSmall = uint8 | uint16 | uint32
  SignedSmall = int8 | int16 | int32

proc `=destroy`*(x: var BigInt) =
  if x.limbs != nil:
    dealloc(x.limbs)

proc `=copy`*(a: var BigInt; b: BigInt) =
  # do nothing for self-assignments:
  if a.limbs == b.limbs: return
  `=destroy`(a)
  wasMoved(a)
  a.isNegative = b.isNegative
  a.used = b.used
  a.cap = b.cap
  if b.limbs != nil:
    a.limbs = cast[typeof(a.limbs)](alloc(a.cap * sizeof(uint32)))
    for i in 0..<a.used:
      a.limbs[i] = b.limbs[i]

proc `=sink`*(a: var BigInt; b: BigInt) =
  # move assignment, optional.
  # Compiler is using `=destroy` and `copyMem` when not provided
  `=destroy`(a)
  wasMoved(a)
  a.isNegative = b.isNegative
  a.used = b.used
  a.cap = b.cap
  a.limbs = b.limbs

const defaultCapacity = 4

# We don't shrink the number of limbs via setCapacity. Hopefully not a problem?
proc setCapacity(n: var BigInt; cap: int = defaultCapacity) =
  if cap > n.cap:
    n.limbs = cast[typeof(n.limbs)](realloc(n.limbs, cap * sizeof(uint32)))
    n.cap = cap

  n.used = 0
  for i in 0..n.cap-1:
    n.limbs[i] = 0'u32

proc clamp(n: var BigInt) =
  while n.used > 0 and n.limbs[n.used - 1] == 0:
    n.used -= 1

proc clear(n: var BigInt) =
  n.used = 0
  for i in 0..n.cap-1:
    n.limbs[i] = 0'u32

proc init*[V: int8|int16|int32](T: type BigInt, val: V): T =
  # Bigint with nil limbs and cap == used == 0 is zero
  if val == 0:
    return

  result.setCapacity()

  if val < 0:
    result.isNegative = true
    result.limbs[0] = (not val.int32).uint32 + 1
  else:  
    result.isNegative = false
    result.limbs[0] = val.int32.uint32

  result.used = 1

proc init*[V: uint8|uint16|uint32](T: type BigInt, val: V): T =
  if val == 0:
    return # Bigint with nil limbs and cap == used == 0 is zero
  result.setCapacity()

  result.isNegative = false
  result.limbs[0] = val.uint32
  result.used = 1

template load(bigint: var BigInt; val: uint64) =
  if val > uint32.high.uint64:
    bigint.limbs[0] = (val and uint32.high).uint32
    bigint.limbs[1] = (val shr 32).uint32
    bigint.used = 2
  else:
    bigint.limbs[0] = val.uint32
    bigint.used = 1
  
proc init*(T: type BigInt, val: int64): T =
  if val == 0:
    return
  result.setCapacity()
  var a = val.uint64
  if val < 0:
    a = uint64(-val)
    result.isNegative = true
  else:
    result.isNegative = false

  load(result, a)
  clamp(result)

proc init*(T: type BigInt, val: uint64): T =
  result.isNegative = false
  result.setCapacity()
  load(result, val)
  clamp(result)

when sizeof(int) == 4:
  template init*(T: type BigInt, val: int): T = init(BigInt, val.int32)
  template init*(T: type BigInt, val: uint): T = init(BigInt, val.uint32)
else:
  template init*(T: type BigInt, val: int): T = init(BigInt, val.int64)
  template init*(T: type BigInt, val: uint): T = init(BigInt, val.uint64)

proc isZero(a: BigInt): bool {.inline.} =
  for i in countdown(a.used - 1, 0):
    if a.limbs[i] != 0'u32:
      return false
  return true

proc unsignedCmp(a: BigInt, b: int32): int64 =
  # here a and b have same sign a none of them is zero.
  # in particular we have that a.limbs.used >= 1
  result = int64(a.used) - 1

  if result != 0:
    return

  result = int64(a.limbs[0]) - int64(abs(b))

proc unsignedCmp(a: int32, b: BigInt): int64 = -unsignedCmp(b, a)

proc unsignedCmp(a, b: BigInt): int64 =
  result = int64(a.used) - int64(b.used)

  if result != 0:
    return

  for i in countdown(a.used - 1, 0):
    result = int64(a.limbs[i]) - int64(b.limbs[i])

    if result != 0:
      return

  return 0

proc cmp*(a, b: BigInt): int64 =
  ## Returns:
  ## * a value less than zero, if `a < b`
  ## * a value greater than zero, if `a > b`
  ## * zero, if `a == b`
  if a.isZero:
    if b.isZero:
      return 0
    elif b.isNegative:
      return 1
    else:
      return -1
  elif a.isNegative:
    if b.isZero or not b.isNegative: # b >= 0
      return -1
    else:
      return unsignedCmp(b, a) 
  else: # a > 0
    if b.isZero or b.isNegative: # b <= 0
      return 1
    else:
      return unsignedCmp(a, b)

proc cmp*(a: BigInt, b: int32): int64 =
  ## Returns:
  ## * a value less than zero, if `a < b`
  ## * a value greater than zero, if `a > b`
  ## * zero, if `a == b`
  if a.isZero:
    if b < 0:
      return 1
    elif b == 0:
      return 0
    else:
      return -1
  elif a.isNegative:
    if b < 0:
      return unsignedCmp(b, a)
    else:
      return -1
  else: # a > 0
    if b <= 0:
      return 1
    else:
      return unsignedCmp(a, b)

proc toUInt64*(a: BigInt): uint64 =
  if a.used == 0:
    result = 0
  elif a.used == 1:
    result = a.limbs[0].uint64
  elif a.used > 1:
    result = rotateLeftBits(a.limbs[1].uint64, 32) + a.limbs[0].uint64 

proc cmp*(a: int32, b: BigInt): int64 = -cmp(b, a)

proc `<` *(a, b: BigInt): bool = cmp(a, b) < 0
proc `<` *(a: BigInt, b: int32): bool = cmp(a, b) < 0
proc `<` *(a: int32, b: BigInt): bool = cmp(a, b) < 0

proc `<=` *(a, b: BigInt): bool = cmp(a, b) <= 0
proc `<=` *(a: BigInt, b: int32): bool = cmp(a, b) <= 0
proc `<=` *(a: int32, b: BigInt): bool = cmp(a, b) <= 0

proc `==` *(a, b: BigInt): bool = cmp(a, b) == 0
proc `==` *(a: BigInt, b: int32): bool = cmp(a, b) == 0
proc `==` *(a: int32, b: BigInt): bool = cmp(a, b) == 0

proc negate*(a: var BigInt) =
  if not a.isZero:
    a.isNegative = not a.isNegative

proc `-`*(a: BigInt): BigInt =
  result = a
  negate(result)

proc addWithCarry(a: uint32, b: uint32, c: var uint32): uint32 =
  let val: uint64 = a.uint64 + b.uint64 + c.uint64
  result = val.masked(0xFFFF_FFFF'u32).uint32
  c = if val - result > 0: 1 else: 0

proc minmax[T](x: T, y: T): tuple[lo: T, hi: T] =
  return (min(x, y), max(x, y))

proc unsignedAdd(a: BigInt, b: Bigint): BigInt =
  let (lo, hi)  = minmax[int](a.used, b.used)
  result.cap = 1 + hi
  result.used = hi

  result.limbs =  cast[typeof(result.limbs)](alloc(result.cap * sizeof(uint32)))
  for i in 0 .. result.cap-1:
    result.limbs[i] = 0'u32

  var carry: uint32 = 0
  for i in 0 .. lo-1:
    result.limbs[i] = addWithCarry(a.limbs[i], b.limbs[i], carry)

  for i in lo .. a.used-1:
    result.limbs[i] = addWithCarry(a.limbs[i], 0, carry)

  for i in lo .. b.used-1:
    result.limbs[i] = addWithCarry(0, b.limbs[i], carry)

  if carry != 0:
    result.limbs[result.cap-1] = carry
    result.used = result.cap

  clamp(result)

proc subWithCarry(a: uint32, b: uint32, c: var uint32): uint32 =
  let val: uint64 = a.uint64 - b.uint64 - c.uint64
  result = val.masked(0xFFFF_FFFF'u32).uint32
  if a < b + c:
    c = 1
  else:
    c = 0

# Requires |lhs| >= |rhs|
proc unsignedSub(lhs: BigInt, rhs: Bigint): BigInt =
  let (lo, hi)  = (rhs.used, lhs.used)
  result.cap = hi
  result.used = hi

  result.limbs =  cast[typeof(result.limbs)](alloc(result.cap * sizeof(uint32)))
  for i in 0 .. result.cap - 1:
    result.limbs[i] = 0'u32

  var carry: uint32 = 0
  for i in 0 .. lo - 1:
    result.limbs[i] = subWithCarry(lhs.limbs[i], rhs.limbs[i], carry)

  for i in lo .. hi - 1:
    result.limbs[i] = subWithCarry(lhs.limbs[i], 0, carry)

  clamp(result)

proc add(a: BigInt, b: Bigint): BigInt =
  if a.isNegative == b.isNegative:
    result = unsignedAdd(a, b)
    result.isNegative = a.isNegative
  elif unsignedCmp(a, b) < 0:
    result = unsignedSub(b, a)
    result.isNegative = b.isNegative
  else:
    result = unsignedSub(a, b)
    result.isNegative = a.isNegative

proc sub(a: BigInt, b: Bigint): BigInt =
  if a.isNegative != b.isNegative:
    result = unsignedAdd(a, b)
    result.isNegative = a.isNegative
  elif unsignedCmp(a, b) >= 0:
    result = unsignedSub(a, b)
    result.isNegative = a.isNegative
  else:
    result = unsignedSub(b, a)
    result.isNegative = not a.isNegative

proc `+` *(a, b: BigInt): BigInt=
  add(a, b)

proc `-` *(a, b: BigInt): BigInt=
  sub(a, b)

# TODO: Write type specialized code for the following two cases
proc `+` *[V: Signed | Unsigned](a: BigInt; val: V): BigInt =
  a + BigInt.init(val)

proc `+` *[V: Signed | Unsigned](val: V; a: BigInt): BigInt =
  a + BigInt.init(val)

proc shiftLeftDigits[V: Signed | Unsigned](a: BigInt; digits: V): BigInt =
  discard

proc multByDigitWithShiftUpBy(a: BigInt; digit: uint32; shift: int; res: var BigInt) =
  if a.isZero or digit == 0'u32:
    res.used = 0
    res.isNegative = false
  elif digit == 1'u32 and shift == 0:
    for i in 0 ..< a.used:
      res.limbs[i] = a.limbs[i]
    for i in a.used ..< res.cap:
      res.limbs[i] = 0
    res.used = a.used
  else:
    # res.cap = result.used
    # result.limbs =  cast[typeof(result.limbs)](alloc(result.cap * sizeof(uint32)))

    var carry = 0'u32
    for i in 0..a.used - 1:
      let prod: uint64 = a.limbs[i].uint64 * digit.uint64 + carry.uint64
      carry = (prod shr 32).uint32
      res.limbs[i + shift] = prod.uint32

    if carry == 0:
      res.used = a.used + shift
      res.limbs[res.used] = 0
    else:
      res.used = a.used + 1 + shift
      res.limbs[res.used-1] = carry

proc unsignedAddTo(res: var BigInt, a: BigInt) =
  var carry: uint32 = 0
  for i in 0 .. a.used-1:
    res.limbs[i] = addWithCarry(a.limbs[i], res.limbs[i], carry)
  res.used = a.used

  if carry != 0:
    res.limbs[res.used] = carry
    res.used += 1

  clamp(res)

proc unsignedMul(a: BigInt, b: Bigint): BigInt =
  result.setCapacity(a.used + b.used)
  var tmp: BigInt
  tmp.setCapacity(a.used + b.used)
  for i in 0 .. a.used-1:
    multByDigitWithShiftUpBy(b, a.limbs[i], i, tmp)
    echo "tmp = ", toUInt64(tmp)
    result.unsignedAddTo(tmp)
    tmp.clear()

  clamp(result)

proc `*` *(a, b: BigInt): BigInt=
  result = unsignedMul(a, b)
  if a.isNegative != b.isNegative:
     result.isNegative = true

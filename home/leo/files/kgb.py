#!/usr/bin/env python3
import random
import string
import sys

symbols = "!#$%&()*+,-./:;?@[\\]^_`{|}~"
numbers = '1234567890'

def randomString(l, _symbols=False, _mayhem=False):
    charset = string.ascii_lowercase + string.ascii_lowercase.upper()
    if _symbols:
        s = ''.join(random.choice(charset) for i in range(l-2)) + random.choice(symbols) + random.choice(numbers)
    elif _mayhem:
        s = charset + symbols + numbers
        for i in range(l):
            s += random.choice(s)
    else:
        s = ''.join(random.choice(charset) for i in range(l-2)) + random.choice(numbers)
    L = list(s)
    random.shuffle(L)
    return ''.join(L)

def checkSum(word, seed):
    total = seed
    for ch in word:
        total += ord(ch)**2 - seed
    return total

if len(sys.argv) < 3:
    print("Usage: kgb <length> <seed> [ns|mayhem]")
    sys.exit(1)

random.seed(checkSum(sys.argv[2], int(sys.argv[1])))
mode = sys.argv[3] if len(sys.argv) == 4 else ''
print(randomString(int(sys.argv[1]), mode == 'ns', mode == 'mayhem'))

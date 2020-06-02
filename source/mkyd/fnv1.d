module mkyd.fnv1;

private enum FNV1_64_OFFSET_BASIS = 0xcbf29ce484222325;
private enum FNV1_64_PRIME = 0x100000001b3;

/// Simple FNV1 hash implementation for strings.
/// Only returns 64 bit integers
ulong fnv1(string data)
{
    ulong hash = FNV1_64_OFFSET_BASIS;

    foreach (byte c; data)
    {
        hash *= FNV1_64_PRIME;
        hash ^= c;
    }

    return hash;
}

/// Just like FNV1 but the data is XOR'd first then multipled
ulong fnv1a(string data)
{
    ulong hash = FNV1_64_OFFSET_BASIS;

    foreach (byte c; data)
    {
        hash ^= c;
        hash *= FNV1_64_PRIME;
    }

    return hash;
}
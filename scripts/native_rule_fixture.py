"""Synthetic ruleset lookup keyed by native full-label FNV-1a hashes.
The caller's pre-seeded hash function must execute original instructions.
"""
def ruleset_hash(label):
    value=0xcbf29ce484222325
    for byte in label.encode('cp1252'):
        signed=byte if byte<128 else byte-256
        value=((value^(signed&0xffffffffffffffff))*0x100000001b3)&0xffffffffffffffff
    return value

def ruleset_value(overrides,key,default):
    for label,value in overrides.items():
        if ruleset_hash(label)==key:return value
    return default

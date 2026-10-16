"""Execute the complete verified CGameEffect copy constructor in owner probes.
Only allocation and zero-initialization helpers are captured. Each fixture owns
eight INT cells and calls prepare() during setup; no game state is patched.
"""
class NativeEffectCopyFixture:
 def __init__(self,m):
  from unicorn.x86_const import UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8
  self.m=m;self.registers=[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8];self.destination=None;self.active=False;self.executions=0
 def prepare(self,ptr):self.m.wi(ptr+0x40,8)
 def handle(self,address):
  m=self.m;u=m.u
  if address==0x140423570:
   self.destination=u.reg_read(self.registers[0]);self.active=True;self.executions+=1
  if not self.active:return False
  if 0x140423570<=address<0x140423768:
   if address==0x140423767:self.active=False
   return True
  x,y,z=[u.reg_read(r) for r in self.registers]
  if address==0x140c11414:u.mem_write(x,bytes(y*z));m.finish()
  elif address==0x140047300:u.mem_write(x,bytes(12));m.finish(x)
  elif address==0x140c10370:
   assert x==0,'fixture constructor owns only empty strings';m.finish()
  elif address==0x140c10368:
   assert x==32,'fixture source must own exactly eight INTs';m.finish(self.destination+0x400)
  elif address==0x140c42060:u.mem_write(x,bytes(z));m.finish(x)
  else:raise AssertionError(f'Uncaptured effect copy constructor dependency {address:x}')
  return True
